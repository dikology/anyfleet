# Anyfleet – Code Review & Refactor Plan (March 2026)

**Scope:** iOS app (`anyfleet/anyfleet/`) + FastAPI backend (`anyfleet-backend/`)  
**Reviewer:** Senior iOS engineer pass — architecture, code quality, Swift/SwiftUI, UX/UI, tests, reliability

---

## 1. Summary

- **Architecture is sound overall.** MVVM + `@Observable` on iOS, layered FastAPI on the backend. The right foundations are in place; issues are tactical, not structural.
- **Unimplemented feature reachable from UI.** The flashcard deck editor is wired up in navigation (`CreateContentMenu → coordinator.editDeck`) but the reader/editor is a `TODO` `break`. Users can trigger it today and get a silent no-op.
- **No universal/deep-link support.** `AppCoordinator` handles navigation entirely via `AppRoute` but has no `onOpenURL` handler. For a social-sharing app (charter links, forked content), this is a significant gap.
- **Backend has two correctness bugs.** `list_user_charters` returns `total=len(page)` instead of the true total count (pagination is broken), and `CharterRepository.find_discoverable` has a dead-expression `radius_km * 1000.0` that computes a value and discards it.
- **Cross-cutting data contract risk.** Visibility enums exist in both Swift and Python with no shared schema contract. A new backend value will silently break the iOS client.
- **Dual localization system is redundant.** Both a `LocalizationService` class and a SwiftGen `L10n` enum exist for the same purpose, creating confusion.

---

## 2. Refactor Plan

| Priority | Step | Files |
|---|---|---|
| P0 | Hide or gate the flashcard deck option until implemented | `LibraryListView.swift`, `LibraryListViewModel.swift` |
| P0 | Fix `list_user_charters` total count | `charter_service.py`, `charter.py` |
| P1 | Add `onOpenURL` deep-link handler to `AppCoordinator` | `AppModel.swift`, `AppView.swift` |
| P1 | Fix N+1 DELETE in `delete_user_tokens` | `user.py` |
| P1 | Replace `get_content_stats` in-memory aggregation with SQL | `content.py` |
| P2 | Add `unknown` case to all iOS visibility enums | `CharterVisibility.swift`, `LibraryModel.swift` |
| P2 | Invalidate `ContentCache` on delete | `LibraryStore.swift`, `ContentCache.swift` |
| P2 | Remove dead audience check in `apple_auth.py` | `apple_auth.py` |
| P3 | Remove `LocalizationService` for string access, keep only for runtime language switching | `LocalizationService.swift` |
| P3 | Restrict `test-signin` endpoint to compile-time exclusion | `auth.py`, router setup |

---

## 3. Issues & Recommendations

### 3.1 Architecture

#### iOS — Flashcard Deck: Reachable Dead End

`CreateContentMenu` presents a "New Flashcard Deck" option. Tapping it calls `viewModel.onCreateDeckTapped()` → `coordinator.editDeck(nil)`. The reader tap handler in `LibraryContentList` is:

```swift
case .flashcardDeck:
    // TODO: Implement deck reader when ready
    break
```

The swipe-to-edit action also calls `viewModel.onEditDeckTapped(item.id)` with no guard. This is silent and confusing.

**Fix:** Hide the menu item and swipe action until the feature is ready.

```swift
// In CreateContentMenu.body
Menu {
    Button { viewModel.onCreateChecklistTapped() } label: {
        Label(L10n.Library.newChecklist, systemImage: "checklist")
    }
    Button { viewModel.onCreateGuideTapped() } label: {
        Label(L10n.Library.newPracticeGuide, systemImage: "book")
    }
    // Flashcard deck item removed until feature ships
} label: {
    Image(systemName: "plus.circle.fill")
        .font(.system(size: 22))
        .foregroundColor(DesignSystem.Colors.primary)
}
```

In `LibraryContentList` swipe actions, remove the `.flashcardDeck` branch from the edit button or replace it with a "Coming soon" alert.

**Rationale:** Unreachable UI states erode user trust and make bug reports harder to diagnose.

---

#### iOS — No Deep-Link / Universal Link Support

`AppCoordinator` uses a well-structured `AppRoute` enum but `AppView` has no `onOpenURL` modifier. Charter sharing links will open Safari, not the app.

**Partial fix outline:**

```swift
// AppView.swift — add to NavigationStack
.onOpenURL { url in
    coordinator.handle(url: url)
}
```

```swift
// AppModel.swift — add to AppCoordinator
func handle(url: URL) {
    // Example scheme: anyfleet://charter/<id>
    guard
        url.scheme == "anyfleet",
        let host = url.host,
        let idString = url.pathComponents.dropFirst().first,
        let id = UUID(uuidString: idString)
    else { return }

    switch host {
    case "charter":
        navigate(to: .charterDetail(id))
    default:
        break
    }
}
```

Also register the URL scheme and associated domains (`applinks:`) in `Info.plist` and entitlements.

**Rationale:** Deep linking is table stakes for any social or sharing feature. Without it, every shared link creates friction.

---

#### iOS — `UUID.localUserPlaceholder` in Data Layer

`UUID+Constants.swift` exposes a static placeholder UUID for use before full auth. If this is used as a `creatorID` fallback in local storage, all unauthenticated users share a phantom creator identity — a data integrity hazard when sync eventually assigns real server IDs.

**Audit:** Search for every call site:

```bash
rg "localUserPlaceholder" anyfleet/anyfleet/
```

Replace with `Optional<UUID>` in the data model and handle the `nil` case explicitly at each point. Never write a placeholder UUID to persistent storage.

---

#### Backend — `list_user_charters` Total Count Is Wrong

```python
# charter_service.py lines 59-65
return CharterListResponse(
    items=[CharterResponse.model_validate(c) for c in charters],
    total=len(charters),   # ← BUG: this is the page size, not the total
    limit=limit,
    offset=offset,
)
```

`len(charters)` is at most `limit`. Any iOS pagination logic that checks `total > offset + limit` to decide whether to fetch the next page will always conclude there are no more pages.

**Fix:**

```python
# charter_service.py — add a count query
async def get_user_charters(
    self, user_id: UUID, limit: int = 20, offset: int = 0
) -> CharterListResponse:
    charters = await self.charter_repo.get_user_charters(
        user_id=user_id, limit=limit, offset=offset
    )
    total = await self.charter_repo.count_user_charters(user_id=user_id)

    return CharterListResponse(
        items=[CharterResponse.model_validate(c) for c in charters],
        total=total,
        limit=limit,
        offset=offset,
    )
```

```python
# charter.py — add to CharterRepository
async def count_user_charters(self, user_id: UUID) -> int:
    result = await self.session.execute(
        select(func.count(Charter.id)).where(
            Charter.user_id == user_id,
            Charter.deleted_at.is_(None),
        )
    )
    return result.scalar_one()
```

**Rationale:** Returning page size as total count is a correctness bug that silently breaks infinite scroll / load-more UIs on the client.

---

#### Backend — Dead Expression in `find_discoverable`

```python
# charter.py line 99
if near_lat is not None and near_lon is not None:
    radius_km * 1000.0   # ← result discarded, does nothing
```

This line computes a value and throws it away. If it was meant to convert to meters for a future `ST_DWithin` call, it was never wired up. The current distance calculation already works in km — this line is simply dead code.

**Fix:** Delete line 99.

---

#### Backend — N+1 DELETE in `delete_user_tokens`

```python
# user.py lines 183-188
tokens = await self.find_many(user_id=user_id)
count = len(tokens)
for token in tokens:
    await self.delete(token)   # one round-trip per token
return count
```

**Fix:**

```python
from sqlalchemy import delete as sql_delete

async def delete_user_tokens(self, user_id: uuid.UUID) -> int:
    result = await self.session.execute(
        sql_delete(RefreshToken).where(RefreshToken.user_id == user_id)
    )
    await self.session.flush()
    return result.rowcount
```

**Rationale:** A user logged in on 5 devices triggers 5 DELETE round-trips at logout. Bulk DELETE is a single statement regardless of row count.

---

#### Backend — `get_content_stats` Loads All Rows Into Memory

```python
# content.py lines 281-296
all_content = await self.get_all()        # fetches every row
total_content = len(all_content)
total_views = sum(c.view_count for c in all_content)
```

**Fix:**

```python
from sqlalchemy import func, select

async def get_content_stats(self, user_id: UUID | None = None) -> dict:
    base_filter = [SharedContent.deleted_at.is_(None)]
    if user_id:
        base_filter.append(SharedContent.user_id == user_id)

    result = await self.session.execute(
        select(
            func.count(SharedContent.id).label("total"),
            func.sum(SharedContent.view_count).label("views"),
            func.sum(SharedContent.fork_count).label("forks"),
        ).where(*base_filter)
    )
    row = result.one()
    total = row.total or 0
    return {
        "total_content": total,
        "published_content": total,
        "deleted_content": 0,
        "total_views": row.views or 0,
        "total_forks": row.forks or 0,
    }
```

**Rationale:** Aggregate queries run in the database engine in O(1) memory; Python-side aggregation scales linearly with row count and will OOM on large datasets.

---

### 3.2 Code Quality

#### iOS — `ContentCache` Not Invalidated on Delete

`LibraryStore.deleteContent` removes the record from SQLite and enqueues an unpublish sync op but never calls `contentCache.remove(for:)`. The in-memory `LRUCache` will serve stale content until the entry is naturally evicted.

**Fix:** After the `LocalRepository.deleteContent` call in `LibraryStore`, add:

```swift
contentCache.remove(for: contentID)
```

**Rationale:** A cache should always be invalidated when the source of truth changes. Serving deleted content from cache, even briefly, is incorrect behavior.

---

#### iOS — Dual Localization Systems

`LocalizationService` wraps `Bundle.localizedString(forKey:)` and is injected as a dependency. `L10n` (SwiftGen) is used directly in most views. Having both creates confusion — new engineers won't know which to use.

`LocalizationService` adds value only for runtime language switching. For all other string access, `L10n` is preferable because it is type-safe and validated at compile time.

**Recommendation:** Keep `LocalizationService` only for the runtime language-switching path. Annotate it clearly:

```swift
/// Manages runtime language switching only.
/// For all static string access, use the generated `L10n` enum.
final class LocalizationService { ... }
```

Remove any `LocalizationService.string(for:)` call sites that could be replaced with a direct `L10n.*` reference.

---

#### Backend — Redundant Apple Token Audience Check

```python
# apple_auth.py lines 56-74
payload = jwt.decode(
    identity_token,
    signing_key.key,
    algorithms=["RS256"],
    audience=self.settings.apple_client_ids,   # already validates audience
    ...
)

# Lines below are unreachable — jwt.decode raises InvalidAudienceError if aud mismatches
token_audience = payload.get("aud")
if token_audience not in self.settings.apple_client_ids:
    logger.warning(...)
    return None
```

`jwt.decode` with `audience=` will raise `InvalidAudienceError` before the second block is ever reached. The redundant check adds noise and a false sense of double-validation.

**Fix:** Remove lines 71–76 (the manual `token_audience` check).

---

#### Backend — `fork_content` Service Method Is Unreachable

`ContentService.fork_content()` is fully implemented but no API endpoint calls it. The `POST /{public_id}/fork` endpoint calls `increment_fork_count` directly on the repository, bypassing the service. The actual fork record is created client-side.

This means `fork_count` is an increment counter, not an authoritative record count. This is a valid design choice, but it should be documented explicitly and the unused `fork_content` method should either be wired up or deleted to avoid confusion.

---

### 3.3 Swift / SwiftUI

#### iOS — `CharterEditorViewModel`: No Sign-In Prompt for Non-Private Visibility

When a user selects `community` or `public` visibility while unauthenticated, the charter is saved locally and sync will silently fail (queued but never sent). `LibraryListView` handles this case correctly with `SignInModalView`. The charter editor should do the same.

**Pattern to follow (from `LibraryListViewModel`):**

```swift
// CharterEditorViewModel.swift
func onVisibilityChanged(_ newVisibility: CharterVisibility) {
    guard newVisibility != .private else { return }
    if !authObserver.isSignedIn {
        // surface sign-in modal before allowing non-private selection
        activeSheet = .signIn
        formState.visibility = .private   // revert to safe default
    }
}
```

Bind `onVisibilityChanged` to the visibility picker's `onChange` in the editor view.

---

#### iOS — `LibraryListView` Fallback `init` Creates Duplicate Dependencies

```swift
// LibraryListView.swift lines 9-22
@MainActor
init(viewModel: LibraryListViewModel? = nil) {
    if let viewModel = viewModel {
        _viewModel = State(initialValue: viewModel)
    } else {
        let deps = AppDependencies()   // creates a second full dependency graph
        _viewModel = State(initialValue: LibraryListViewModel(
            libraryStore: deps.libraryStore, ...
        ))
    }
}
```

The fallback `else` branch is only needed for the canvas preview, but it silently creates a second `AppDependencies` instance (with its own database connection, sync services, etc.) whenever this view is instantiated without a view model. At runtime this branch is never reached if the environment value is always set — but the `else` branch is misleading and wasteful.

**Fix:** Remove the `else` branch entirely and crash loudly in debug if the view model is missing, or use a preview-specific method:

```swift
@MainActor
init(viewModel: LibraryListViewModel) {
    _viewModel = State(initialValue: viewModel)
}
```

The `#Preview` block already constructs the full view model explicitly — the fallback is unnecessary.

---

#### iOS — `CharterSyncService.needsAuthForSync` Duplicates Auth Check

`SyncCoordinator` already gates sync behind an authentication check. `CharterSyncService` sets its own `needsAuthForSync` flag. This is a second, independent auth-check pathway for the same concern.

**Fix:** Remove `needsAuthForSync` from `CharterSyncService`. If `SyncCoordinator` decides sync should not run, it simply won't call the service. Trust the coordinator as the single gatekeeper.

---

#### iOS — `SyncQueueService` Has No Retry Backoff

Failed sync operations are retried without any delay. If the backend is down, the queue will hammer the API as fast as the device allows.

**Fix:** Add exponential backoff before re-enqueue:

```swift
private func retryDelay(for attempt: Int) -> Duration {
    let base: Double = 1.0
    let maxDelay: Double = 300.0  // 5 minutes
    let delay = min(base * pow(2.0, Double(attempt)), maxDelay)
    return .seconds(delay)
}

// In the retry path:
try await Task.sleep(for: retryDelay(for: record.retryCount))
```

---

### 3.4 Cross-Cutting: Visibility Enums Have No `unknown` Case

`CharterVisibility` (Swift) and `ContentVisibility` (Swift) are manually mirrored from the Python enums. If the backend ships a new visibility level (e.g., `friends_only`), the iOS `Codable` decoding will throw and the entire response object will fail to decode.

**Fix:** Add an `unknown` case with associated raw value to every visibility enum:

```swift
enum CharterVisibility: String, Codable, CaseIterable {
    case `private`
    case community
    case `public`
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = CharterVisibility(rawValue: raw) ?? .unknown
    }
}
```

Update all `switch` statements that handle `CharterVisibility` to include a `case .unknown: break` arm (or handle it gracefully in the UI).

**Rationale:** Defensive decoding prevents a backend schema change from crashing the app for all users until a new version ships.

---

### 3.5 UX / UI

#### Flashcard Deck in `ContentFilter` Picker

The `ContentFilter` enum exposes a `.decks` tab in the segmented picker. Tapping it shows an empty list (no decks exist) with no indication of why. Until the feature ships, remove the `.decks` case from `ContentFilter.allCases` or return a "Coming soon" empty state.

```swift
// ContentFilter in LibraryListViewModel.swift
static var activeFilters: [ContentFilter] {
    // Remove .decks until flashcard feature ships
    [.all, .checklists, .guides]
}
```

Use `activeFilters` in `ContentFilterPicker` instead of `ContentFilter.allCases`.

---

#### Empty State Accessibility

`LibraryEmptyState` wraps the empty state in `.accessibilityElement(children: .combine)` which is correct, but the label is a hard-coded string that duplicates the visible text. Use the design system's `EmptyStateView` semantic content and let VoiceOver derive labels from the view hierarchy instead of manually duplicating them.

---

#### `AuthorProfileModal` Has No Minimum Tap Target

`AuthorProfileModal` dismiss and action buttons should be at least 44×44 pt per Apple HIG. Verify all interactive elements in `DiscoverContentRow` and `LibraryItemRow` meet this requirement:

```swift
.frame(minWidth: 44, minHeight: 44)
```

---

#### Backend CORS: Wildcard + Credentials Is Invalid for Browser Clients

```python
# config.py lines 95-98
cors_origins: list[str] = ["*"]
cors_allow_credentials: bool = True
```

`Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` is rejected by all browsers per the CORS specification. The iOS native client is unaffected, but any future web client (the web PRD exists) will fail all credentialed requests.

**Fix:**

```python
# Per-environment origin lists
cors_origins: list[str] = Field(default_factory=list)
# Set in .env: CORS_ORIGINS=https://app.anyfleet.com,https://staging.anyfleet.com
```

For local development, set `CORS_ORIGINS=http://localhost:3000`.

---

### 3.6 Security

#### Backend — `test-signin` Endpoint Exposed at Runtime

The test signin endpoint is guarded by a runtime check:

```python
if settings.environment != "development":
    raise HTTPException(status_code=403, ...)
```

A misconfigured `ENVIRONMENT=development` in production exposes the ability to create or elevate any user to admin. The guard should be at the router inclusion level so the endpoint does not exist in the production process at all:

```python
# main.py or router setup
if settings.environment == "development":
    app.include_router(test_router, prefix="/api/v1/auth")
```

This way the endpoint is not registered in production, regardless of the environment variable.

---

#### iOS — `UUID.localUserPlaceholder` Audit

```swift
// UUID+Constants.swift
extension UUID {
    static let localUserPlaceholder = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
```

If this UUID ever reaches the backend as a `creatorID` or `userID` — for example, during a sync operation before auth completes — it could create records owned by a phantom user ID that silently conflicts across all unauthenticated installs.

**Audit command:**
```bash
rg "localUserPlaceholder" anyfleet/anyfleet/
```

Every write path that produces a `creatorID` should require a real `UUID?` and fail explicitly if nil, rather than falling back to the placeholder.

---

## 4. Refactored Code

### 4.1 `CharterVisibility.swift` — Defensive Decoding

**Full drop-in replacement:**

```swift
import Foundation

/// Charter visibility levels. Uses defensive decoding to handle
/// future backend values without crashing.
enum CharterVisibility: String, Codable, CaseIterable, Sendable {
    case `private` = "private"
    case community = "community"
    case `public` = "public"
    /// Received an unrecognized value from the server.
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = CharterVisibility(rawValue: raw) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .private:   return "Private"
        case .community: return "Community"
        case .public:    return "Public"
        case .unknown:   return "Unknown"
        }
    }

    var isPubliclyVisible: Bool {
        self == .public || self == .community
    }
}
```

**Rationale:** `unknown` case prevents a new backend enum value from crashing `Codable` decoding. All existing `switch` statements should add `case .unknown: break` or equivalent.

---

### 4.2 `charter.py` — Add `count_user_charters`

```python
async def count_user_charters(self, user_id: UUID) -> int:
    """Return the total number of non-deleted charters for a user."""
    result = await self.session.execute(
        select(func.count(Charter.id)).where(
            Charter.user_id == user_id,
            Charter.deleted_at.is_(None),
        )
    )
    return result.scalar_one()
```

Add this method to `CharterRepository` immediately after `get_user_charters`.

---

### 4.3 `charter_service.py` — Fix `get_user_charters` Total

Replace the existing `get_user_charters` method body:

```python
async def get_user_charters(
    self, user_id: UUID, limit: int = 20, offset: int = 0
) -> CharterListResponse:
    """Get paginated charters for a user with accurate total count."""
    charters, total = await asyncio.gather(
        self.charter_repo.get_user_charters(
            user_id=user_id, limit=limit, offset=offset
        ),
        self.charter_repo.count_user_charters(user_id=user_id),
    )

    return CharterListResponse(
        items=[CharterResponse.model_validate(c) for c in charters],
        total=total,
        limit=limit,
        offset=offset,
    )
```

Add `import asyncio` at the top of the file.

---

### 4.4 `user.py` — Bulk DELETE for `delete_user_tokens`

Replace the existing `delete_user_tokens` method:

```python
from sqlalchemy import delete as sql_delete

async def delete_user_tokens(self, user_id: uuid.UUID) -> int:
    """Delete all refresh tokens for a user in a single query."""
    result = await self.session.execute(
        sql_delete(RefreshToken).where(RefreshToken.user_id == user_id)
    )
    await self.session.flush()
    return result.rowcount
```

---

### 4.5 `content.py` — SQL-Aggregate `get_content_stats`

Replace the existing `get_content_stats` method:

```python
async def get_content_stats(self, user_id: UUID | None = None) -> dict:
    """Get content statistics using SQL aggregation."""
    filters = []
    if user_id:
        filters.append(SharedContent.user_id == user_id)

    # Total (including deleted)
    total_result = await self.session.execute(
        select(func.count(SharedContent.id)).where(*filters)
    )
    total = total_result.scalar_one() or 0

    # Published only
    published_result = await self.session.execute(
        select(
            func.count(SharedContent.id),
            func.coalesce(func.sum(SharedContent.view_count), 0),
            func.coalesce(func.sum(SharedContent.fork_count), 0),
        ).where(*filters, SharedContent.deleted_at.is_(None))
    )
    row = published_result.one()
    published = row[0] or 0

    return {
        "total_content": total,
        "published_content": published,
        "deleted_content": total - published,
        "total_views": row[1],
        "total_forks": row[2],
    }
```

---

### 4.6 `apple_auth.py` — Remove Dead Audience Check

Remove lines 71–76 (the manual `token_audience` check after `jwt.decode`):

```python
# DELETE these lines — jwt.decode already raises InvalidAudienceError
# token_audience = payload.get("aud")
# if token_audience not in self.settings.apple_client_ids:
#     logger.warning(...)
#     return None
```

The method body after `jwt.decode` should proceed directly to the expiry check and the `apple_id` extraction.

---

### 4.7 `LibraryListView.swift` — Remove Fallback `init`

Replace the `init` with a single-path initializer:

```swift
// LibraryListView.swift
@MainActor
init(viewModel: LibraryListViewModel) {
    _viewModel = State(initialValue: viewModel)
}
```

Update the call site in `AppView` or wherever `LibraryListView()` is instantiated without arguments to always pass an explicit view model sourced from `@Environment(\.appDependencies)`.

---

## 5. Tests

### 5.1 High-Value Test Cases (iOS)

**`CharterVisibilityDecodingTests`**
```swift
func testUnknownVisibilityDecodesGracefully() throws {
    let json = #"{"visibility": "friends_only"}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(CharterModel.self, from: json)
    XCTAssertEqual(decoded.visibility, .unknown)
}
```
Catches future backend enum additions before they reach users.

---

**`LibraryListViewModelFilterTests`**
```swift
func testFilteredItemsUpdateWhenFilterChanges() {
    let vm = LibraryListViewModel(/* inject mock store */)
    vm.selectedFilter = .checklists
    XCTAssertTrue(vm.filteredItems.allSatisfy { $0.type == .checklist })
}
```
Validates the `updateFilteredItems()` cache stays consistent with `selectedFilter`.

---

**`SyncQueueRetryBackoffTests`**
```swift
func testRetryDelayDoublesWithEachAttempt() {
    let service = SyncQueueService(/* mock */)
    XCTAssertEqual(service.retryDelay(for: 0), .seconds(1))
    XCTAssertEqual(service.retryDelay(for: 1), .seconds(2))
    XCTAssertEqual(service.retryDelay(for: 8), .seconds(256).clamped(to: .seconds(300)))
}
```

---

### 5.2 High-Value Test Cases (Backend)

**`test_list_user_charters_total_count`**
```python
async def test_list_user_charters_total_count(db_session, test_user):
    # Create 25 charters for the user
    for _ in range(25):
        await charter_repo.create(user_id=test_user.id, ...)
    
    result = await charter_service.get_user_charters(
        user_id=test_user.id, limit=10, offset=0
    )
    assert len(result.items) == 10
    assert result.total == 25   # was broken: returned 10
```

---

**`test_delete_user_tokens_bulk`**
```python
async def test_delete_user_tokens_uses_single_query(db_session, test_user, monkeypatch):
    execute_calls = []
    original = db_session.execute
    async def tracking_execute(stmt, *a, **kw):
        execute_calls.append(stmt)
        return await original(stmt, *a, **kw)
    monkeypatch.setattr(db_session, "execute", tracking_execute)

    repo = RefreshTokenRepository(db_session)
    for _ in range(5):
        await repo.create_token(user_id=test_user.id, ...)
    await repo.delete_user_tokens(test_user.id)

    delete_calls = [c for c in execute_calls if "DELETE" in str(c).upper()]
    assert len(delete_calls) == 1   # was N+1
```

---

**`test_apple_token_expired_returns_none`**
```python
async def test_expired_apple_token_rejected(apple_auth_service):
    # Craft a JWT with exp in the past
    expired_token = create_test_jwt(exp=time.time() - 3600)
    result = await apple_auth_service.verify_identity_token(expired_token)
    assert result is None
```

---

## 6. Remaining Notes

| Area | Severity | Note |
|---|---|---|
| Backend | Medium | Image processing (`Pillow`) in async FastAPI endpoints blocks the event loop — offload to `asyncio.to_thread()` |
| Backend | Medium | `public_id_exists` does not filter `deleted_at` — soft-deleted public IDs can never be reused (may be intentional; document it) |
| Backend | Low | `CharterDiscoveryFilters.radius_km` default is set in both the Pydantic schema and the route signature — remove the route-level default |
| iOS | Medium | No sign-in prompt when setting non-private visibility in `CharterEditorView` — mirror `LibraryListView`'s `SignInModalView` pattern |
| iOS | Low | `MarkdownParser` has no depth or block-count guard — add a `maxDepth` limit as a safeguard against malformed input |
| iOS | Low | `CharterSyncService.needsAuthForSync` flag duplicates `SyncCoordinator`'s auth check — consolidate into the coordinator |
| Cross | Medium | No service-layer transaction boundary — multi-step operations (create user + create token) may leave partial state on failure if the DB session doesn't auto-rollback |
| Cross | Low | `serverID` (iOS) vs `id` (backend) naming inconsistency for charter identifiers — consider renaming iOS field to `remoteID` for clarity |

---

## 7. Sync Behaviour Deep-Dive

### 7.1 Charter Edits Don't Trigger Immediate Sync

In `CharterEditorViewModel.saveCharter()`, the edit path (`else` branch) only calls `charterSyncService?.pushPendingCharters()` when **visibility changes**:

```swift
// CharterEditorViewModel.swift lines 191-194
if charter.visibility != form.visibility {
    try await charterStore.updateVisibility(charterID, visibility: form.visibility)
    await charterSyncService?.pushPendingCharters()
}
```

If a user edits a community or public charter's name, vessel, or dates, `needsSync` is never set and push is never called. The edit is saved locally and sits in SQLite until the `SyncCoordinator` timer fires — either 60 s (active) or up to 5 minutes (idle after 3 empty cycles). This is the latency the user perceives.

**Root cause:** `CharterStore.updateCharter(...)` does not set `needsSync = true`, and the editor only sets it for visibility transitions.

**Fix — update `CharterEditorViewModel.saveCharter()` edit branch:**

```swift
// After charterStore.updateCharter(...)
let updatedCharter = try await charterStore.updateCharter(
    charterID, name: form.name, boatName: ..., ...
)

// Always re-push if the charter is not private
if form.visibility != .private {
    // Mark needsSync so the repository records it correctly
    var toSync = updatedCharter
    toSync.needsSync = true
    try await charterStore.saveCharter(toSync)
    await charterSyncService?.pushPendingCharters()
}
```

**Fix — also update `CharterStore.updateCharter(...)` signature to accept a `needsSync` flag, or add a dedicated `markNeedsSync` method to `CharterRepository`:**

```swift
// CharterStore.swift — new convenience
func markNeedsSync(_ charterID: UUID) async throws {
    try await repository.updateCharterVisibility(charterID, visibility: charters
        .first { $0.id == charterID }?.visibility ?? .private)
    // Set needsSync = true via dedicated repository call
}
```

**Rationale:** "Save → sync" should feel instant for any field change on a shared charter, not eventually consistent at a timer interval. The `SyncCoordinator` is the correct fallback for when push fails, not the primary path for user-initiated saves.

---

### 7.2 Stuck Sync Queue: Permanent-Failure Scenarios

The current retry logic in `SyncQueueService.isRetryableError` has gaps that leave operations in permanent limbo:

**Gap 1 — Terminal errors never increment `retryCount`, so the operation loops forever (always-pending bug).**

Look at the `else` branch for non-retryable errors:

```swift
// SyncQueueService.swift lines 247-256
} else {
    // Max retries exceeded OR terminal error
    await updateSyncState(contentID: operation.contentID, status: .failed)
    if operation.operation == .publish {
        await cancelPendingUnpublishOperations(for: operation.contentID)
    }
}
```

`updateSyncState` is a **no-op** — it only logs:

```swift
private func updateSyncState(contentID: UUID, status: ContentSyncStatus) async {
    AppLogger.services.debug("Updated sync state for content \(contentID) to \(status.rawValue)")
    // nothing else
}
```

Critically: neither `repository.markSyncOperationComplete(operation.id)` nor `repository.incrementSyncRetryCount(...)` is called in this `else` branch. The `SyncQueueRecord` remains with `syncedAt == nil` and `retryCount == 0`. `fetchPendingOperations` picks it up again on the very next tick, executes it, hits the same terminal error, enters the `else` branch, and the cycle repeats — forever. The user sees a persistent "syncing" spinner that never resolves and no error is surfaced.

**Affected error cases — all loop indefinitely without user feedback:**

| Error | Scenario |
|---|---|
| `.unauthorized` (401) | Token expired; every cycle re-attempts and gets 401 |
| `.forbidden` (403) | User lost account or content was moderated |
| `.conflict` on publish (409) | Duplicate `public_id`; re-sent every cycle |
| `.clientError` (400) | Malformed payload in DB; can never succeed |
| `SyncError.invalidPayload` | Corrupted JSON in `SyncQueueRecord.payload` |
| `SyncError.missingPublicID` | `publish_update` missing a server public ID |

**Fix — in the `else` (terminal) branch, exhaust `retryCount` immediately:**

```swift
} else {
    // Force the record past maxRetries so fetchPending never picks it up again
    try? await repository.incrementSyncRetryCountTo(
        operation.id,
        count: maxRetries,     // jump straight to exhausted state
        error: error.localizedDescription
    )
    // Now update LibraryModel.syncStatus to .failed in the DB (not just a log)
    if var item = try? await repository.fetchLibraryItem(operation.contentID) {
        item.syncStatus = .failed
        try? await repository.updateLibraryMetadata(item)
    }
    if operation.operation == .publish {
        await cancelPendingUnpublishOperations(for: operation.contentID)
    }
}
```

---

**Gap 2 — `isProcessing` lock can get permanently stuck (always-pending bug).**

`isProcessing` is set to `true` in `canSync()` and only reset to `false` in `processOperations()` at the end of the loop. There is no `defer` guarding it:

```swift
// canSync() sets it:
isProcessing = true
return true

// processOperations() resets it — but only if it is reached:
isProcessing = false
return summary
```

If the `Task` running `processQueue()` is **cancelled** between these two points — which happens when the app backgrounds mid-sync (`willResignActiveNotification` fires → `SyncCoordinator.stop()` invalidates the timer → the task is no longer driven forward) — `isProcessing` stays `true` until the next app launch. Every subsequent `canSync()` call returns `false` immediately. All queued operations sit in "pending" state indefinitely within that session. `pendingCount` stays > 0 but nothing ever processes.

**Fix — use `defer` so the lock always releases:**

```swift
private func canSync() async -> Bool {
    guard !isProcessing else { return false }
    guard await isNetworkReachable() else {
        await updatePendingCounts()
        return false
    }
    isProcessing = true
    return true
}

func processQueue() async -> SyncSummary {
    guard await canSync() else { return SyncSummary() }
    defer { isProcessing = false }   // ← guarantees release on cancellation or throw
    let operations = await fetchPendingOperations()
    return await processOperations(operations)
}
```

Remove the `isProcessing = false` line from `fetchPendingOperations()` and `processOperations()` — `defer` at the top level handles it exclusively.

---

**Gap 3 — `publish_update` with 404 retries 3 times then stays `failed` forever:**

```swift
case .notFound:
    return operation != .unpublish  // publish_update on 404 → retried 3 times → stuck
```

If content is deleted on the server but the iOS client still has a queued `publish_update`, the operation will exhaust its 3 retries and become a permanent `failed` entry. The user sees a red sync badge with no way to clear it except manual retry.

**Gap 4 — There is no automatic reset path for `failed` operations.** `SyncQueueRecord.fetchPending` filters `retryCount < maxRetries`. Failed records (retryCount ≥ 3) are invisible to the queue processor and never automatically re-attempted after conditions change (e.g., network restored, user signs back in).

**Gap 5 — No exponential backoff before retry.** Consecutive retries happen as fast as queue processing runs (next `SyncCoordinator` tick), which under bad network can waste battery.

**Recommended fixes:**

```swift
// SyncQueueService.swift

// 1. Treat publish_update 404 as terminal (content deleted server-side)
private func isRetryableError(_ error: Error, operation: SyncOperation) -> Bool {
    if let apiError = error as? APIError {
        switch apiError {
        case .networkError, .serverError, .invalidResponse:
            return true
        case .unauthorized, .forbidden, .clientError:
            return false
        case .notFound:
            // 404 is terminal for both unpublish AND publish_update
            return operation == .publish   // only plain publish retries on 404
        case .conflict:
            return operation != .publish
        }
    }
    // ... URLError cases unchanged
}

// 2. Exponential backoff (add nextRetryAt column to SyncQueueRecord)
private func retryDelay(attempt: Int) -> TimeInterval {
    min(pow(2.0, Double(attempt)), 300.0) // 1s, 2s, 4s, 8s … capped at 5 min
}

// In processOperation failure path:
let delay = retryDelay(attempt: operation.retryCount)
let nextRetry = Date().addingTimeInterval(delay)
try? await repository.incrementSyncRetryCount(
    operation.id,
    error: error.localizedDescription,
    nextRetryAt: nextRetry
)
```

```swift
// SyncQueueRecord.swift — add column
var nextRetryAt: Date?

// Update fetchPending to respect nextRetryAt:
nonisolated static func fetchPending(maxRetries: Int, db: Database) throws -> [SyncQueueRecord] {
    try SyncQueueRecord
        .filter(Columns.syncedAt == nil)
        .filter(Columns.retryCount < maxRetries)
        .filter(Columns.nextRetryAt == nil || Columns.nextRetryAt <= Date())
        .order(Columns.createdAt.asc)
        .fetchAll(db)
}
```

**For the permanent-failed cleanup path**, add a "retry all failed" action in the UI (e.g., long-press the sync badge) that resets `retryCount = 0` and `nextRetryAt = nil` for all failed records, re-surfacing them to the processor:

```swift
// SyncQueueService.swift — new public method
func resetFailedOperations() async throws {
    try await repository.resetFailedSyncOperations()
    await updatePendingCounts()
}
```

**Rationale:** A sync queue that can permanently block with no user-accessible resolution path erodes trust. The user should always have a "retry" escape hatch and the system should not indefinitely retry terminal errors.

---

### 7.3 `SyncCoordinator` Stops Timer on Background

`SyncCoordinator.observeAppLifecycle()` invalidates the timer when the app resigns active:

```swift
NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    .sink { [weak self] _ in self?.stop() }
```

This means queued operations are never processed when the user locks their phone. Use `BGProcessingTask` or at minimum `BGAppRefreshTask` to schedule a brief sync opportunity in the background. For offline-first apps, background sync is expected.

Minimal approach — register a `BGAppRefreshTask` in `AppDelegate` / `@main` and call `contentSyncService.syncPending()` + `charterSyncService.pushPendingCharters()` from its handler. This gives iOS permission to wake the app for ~30 s when conditions are good (Wi-Fi, charging).

---

### 7.4 Charter Sync: No Conflict Resolution on Pull

`CharterSyncService.pullMyCharters()` does a blind upsert:

```swift
for remoteCharter in response.items {
    let localModel = remoteCharter.toCharterModel()
    try await repository.saveCharter(localModel)   // overwrites local version
}
```

If the user edited a charter offline and a stale pull happens before push, the edit is silently overwritten. The correct last-write-wins strategy is: compare `updatedAt` timestamps and only overwrite the local record if the remote version is newer.

```swift
for remoteCharter in response.items {
    let remote = remoteCharter.toCharterModel()
    if let local = try? await repository.fetchCharter(id: remote.id) {
        // Only update if remote is genuinely newer AND local doesn't need sync
        if remote.updatedAt > local.updatedAt && !local.needsSync {
            try await repository.saveCharter(remote)
        }
    } else {
        try await repository.saveCharter(remote)
    }
}
```

**Rationale:** Blind overwrites violate the offline-first contract. The device is the source of truth until a successful push has been acknowledged.

---

## 8. Fork Count: Race Condition and Logging Bug

### 8.1 Backend: Optimistic Read-Modify-Write Is Not Atomic

```python
# content.py — fork endpoint
await content_service.content_repo.increment_fork_count(content)

# content.py (repository)
async def increment_fork_count(self, content: SharedContent) -> SharedContent:
    return await self.update(content, fork_count=content.fork_count + 1)
```

`content.fork_count` is the value read before the update. Two simultaneous fork requests on a popular item both read `fork_count = 42`, both write `fork_count = 43`, losing one increment.

**Fix — use a SQL atomic increment:**

```python
from sqlalchemy import update as sql_update

async def increment_fork_count(self, content: SharedContent) -> SharedContent:
    await self.session.execute(
        sql_update(SharedContent)
        .where(SharedContent.id == content.id)
        .values(fork_count=SharedContent.fork_count + 1)
    )
    await self.session.flush()
    await self.session.refresh(content)
    return content
```

Apply the same fix to `increment_view_count`.

### 8.2 Backend: Fork Endpoint Logs Stale Count

```python
# content.py lines at bottom of fork handler
await content_service.content_repo.increment_fork_count(content)

logger.info(
    f"Incremented fork count for content: {public_id}, new count: {content.fork_count}"
)
```

`content.fork_count` here is the **pre-increment** value because the update happens inside the repository and `content` is the stale in-memory object. The log will always report one less than the actual DB value.

**Fix:** Use the return value:

```python
updated = await content_service.content_repo.increment_fork_count(content)
logger.info(f"Fork count for {public_id}: {updated.fork_count}")
```

### 8.3 iOS: Fork Count Is Not Refreshed After Forking

When `LibraryStore.forkContent()` succeeds, the `DiscoverableCharter` displayed in the reader still shows the old `forkCount`. The view model needs to refresh the item after a successful fork:

```swift
// After the fork API call succeeds, update the local charter model:
if let idx = charters.firstIndex(where: { $0.publicID == publicID }) {
    charters[idx].forkCount += 1
}
```

This optimistic local update avoids a full reload while keeping the count accurate from the user's perspective.

### 8.4 Missing Test: Fork Count Actually Increments

The current test suite has no test verifying that `POST /{public_id}/fork` actually changes the persisted `fork_count`. The log bug in §8.2 went undetected because no test reads back the value after the call.

**Test outline:**

```python
async def test_fork_increments_persisted_count(client, db_session, published_content):
    public_id = published_content.public_id
    original_count = published_content.fork_count

    response = await client.post(f"/api/v1/content/{public_id}/fork")
    assert response.status_code == 204

    # Re-fetch from DB — not from the in-memory object
    await db_session.refresh(published_content)
    assert published_content.fork_count == original_count + 1

async def test_concurrent_forks_no_count_loss(client, db_session, published_content):
    """Two simultaneous forks must both register."""
    public_id = published_content.public_id
    original_count = published_content.fork_count

    import asyncio
    await asyncio.gather(
        client.post(f"/api/v1/content/{public_id}/fork"),
        client.post(f"/api/v1/content/{public_id}/fork"),
    )

    await db_session.refresh(published_content)
    assert published_content.fork_count == original_count + 2  # fails with current code
```

---

## 9. Charter Discovery: Authentication Gate and Caching

### 9.1 Discovery Requires Auth — It Shouldn't

```python
# charters.py
@router.get("/discover", response_model=CharterDiscoveryResponse)
@limiter.limit("30/minute")
async def discover_charters(
    request: Request,
    current_user: CurrentUser,   # ← blocks unauthenticated users
    ...
```

Compare with the content endpoints:

```python
# content.py — already public
@router.get("/public", response_model=list[SharedContentSummary])
async def list_public_content(...)   # no CurrentUser, no rate limit

@router.get("/{public_id}", response_model=SharedContentDetail)
async def get_content(...)           # no CurrentUser, no rate limit
```

Charter discovery shows only `PUBLIC` charters. There is no user-specific data in the response. Requiring auth to read public data is unnecessary friction and prevents sharing discovery links with non-users.

**Fix — remove `CurrentUser` and rely on rate limiting instead:**

```python
@router.get("/discover", response_model=CharterDiscoveryResponse)
@limiter.limit("60/minute")          # more generous for unauthenticated browsing
async def discover_charters(
    request: Request,
    charter_service: Annotated[CharterService, Depends(get_charter_service)],
    # current_user: CurrentUser    ← removed
    ...
) -> CharterDiscoveryResponse:
```

**Also add rate limits to the currently unprotected content endpoints:**

```python
# content.py
@router.get("/public", response_model=list[SharedContentSummary])
@limiter.limit("60/minute")          # add this
async def list_public_content(...):

@router.get("/{public_id}", response_model=SharedContentDetail)
@limiter.limit("120/minute")         # view_count increments on every hit — protect it
async def get_content(...):

@router.post("/{public_id}/fork", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")          # add this — already public, protect from abuse
async def increment_fork_count(...):
```

**Rationale:** Auth is the wrong mechanism for public resource access control. Rate limiting protects the backend from abuse while keeping the data accessible. The pattern is already established in the codebase — adopt it consistently.

---

### 9.2 Charter Discovery: Cache Strategy

`CharterDiscoveryViewModel.load()` makes a fresh network call on every visit to the tab, every filter change, and every `onChange` of `charterSyncService.lastSyncDate`. For a browse-heavy feature with public data that changes infrequently, this is wasteful and creates a jarring loading experience on every return visit.

**Recommended: stale-while-revalidate with a TTL**

The pattern: serve cached results immediately (zero latency for returning users) while silently fetching fresh data in the background. Show a subtle refresh indicator instead of a blocking spinner.

```swift
// DiscoveryCacheEntry.swift
struct DiscoveryCacheEntry {
    let charters: [DiscoverableCharter]
    let fetchedAt: Date
    let cacheKey: String

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 120  // 2-minute TTL
    }
}

// CharterDiscoveryViewModel.swift — add cache
private var cache: [String: DiscoveryCacheEntry] = [:]

private var cacheKey: String {
    // Stable string from current filters
    "\(filters.datePreset.rawValue)|\(filters.useNearMe)|\(Int(filters.radiusKm))"
}

private func load(appending: Bool = false) async {
    if !appending, let cached = cache[cacheKey], !cached.isStale {
        charters = cached.charters
        // Silently refresh in background
        Task { await fetchAndCacheFromNetwork(appending: false, silent: true) }
        return
    }
    await fetchAndCacheFromNetwork(appending: appending, silent: false)
}

private func fetchAndCacheFromNetwork(appending: Bool, silent: Bool) async {
    if !silent && !appending {
        isLoading = true
        defer { isLoading = false }
    }

    do {
        let response = try await apiClient.discoverCharters(...)
        let newItems = response.items.map { $0.toDiscoverableCharter() }
        let sorted = sort(newItems)

        if appending {
            charters.append(contentsOf: sorted)
        } else {
            charters = sorted
            cache[cacheKey] = DiscoveryCacheEntry(
                charters: sorted, fetchedAt: Date(), cacheKey: cacheKey
            )
        }

        currentOffset += newItems.count
        hasMore = newItems.count == pageSize
    } catch {
        if !silent { handleError(error) }
        // If silent background refresh fails, cached data is still shown — no error banner
    }
}
```

**Cache invalidation:** Clear the relevant cache entry when `charterSyncService.lastSyncDate` changes (user's own charter was published), or when a pull-to-refresh is explicitly triggered.

```swift
func refresh() async {
    cache.removeValue(forKey: cacheKey)  // force fresh fetch
    await loadInitial()
}
```

**Backend `Cache-Control` headers (optional):** For truly public data, set HTTP cache headers so CDNs and the system URL cache can serve it:

```python
from fastapi import Response

@router.get("/discover")
async def discover_charters(..., response: Response):
    response.headers["Cache-Control"] = "public, max-age=60, stale-while-revalidate=120"
    ...
```

---

### 9.3 Discovery Sort Is Applied Client-Side to a Single Page

`CharterDiscoveryViewModel.sort()` re-orders items after they arrive. But the view uses pagination — items arrive 20 at a time. Sorting page 1 independently then sorting page 2 independently means the final merged list is not globally sorted. A date-ascending sort across 100 charters will show the earliest 20 from page 1, but appending page 2 places more items at the end regardless of their dates.

**Fix options:**
1. Move `dateAscending` / `distanceAscending` sort to the backend SQL (`ORDER BY start_date ASC` / `ORDER BY distance_km ASC`). The backend already does this for the default `recentlyPosted` and `distanceAscending` case.
2. Remove client-side sort and rely on backend ordering exclusively.
3. If client-side sort is required for instant filter feedback, disable "load more" when a non-default sort is active and fetch all results in one shot (only feasible for small total counts).

The cleanest fix is option 1 — pass `sort_by` as a query parameter to the backend:

```python
# charters.py
@router.get("/discover")
async def discover_charters(
    ...
    sort_by: Literal["date_asc", "date_desc", "distance_asc"] = "date_asc",
    ...
):
```

```python
# charter.py repository — apply in find_discoverable
if sort_by == "date_asc":
    query = query.order_by(Charter.start_date.asc())
elif sort_by == "date_desc":
    query = query.order_by(Charter.start_date.desc())
# distance_asc is already applied when geo filters are active
```

---

## 10. Loading Skeletons — Implementation Guide

`DesignSystem.SkeletonBlock` and `DesignSystem.CharterSkeletonRow` exist and are fully functional. They are **not used in any actual view** — only in a `#Preview`. This section shows where to wire them up.

### 10.1 Charter Discovery List

**Current state:** `CharterDiscoveryView.listView` shows a centered `ProgressView` + label when `isLoading && charters.isEmpty`. This is a full-screen block.

**Replace with skeletons:**

```swift
// CharterDiscoveryView.swift — replace loadingState in listView overlay
.overlay {
    if viewModel.isLoading && viewModel.charters.isEmpty {
        DiscoverySkeletonList()
    }
}

// New component:
private struct DiscoverySkeletonList: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    DesignSystem.CharterSkeletonRow()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .allowsHitTesting(false)
    }
}
```

The shimmer animation in `SkeletonBlock` is already implemented. No additional work needed — just use it.

### 10.2 Charter List (My Charters Tab)

Add a `CharterListSkeletonView` that mirrors the shape of `CharterTimelineRow`. The existing `CharterSkeletonRow` already matches this shape exactly:

```swift
// CharterListView.swift — in the body when isLoading && charters.isEmpty
if viewModel.isLoading {
    VStack(spacing: 0) {
        ForEach(0..<4, id: \.self) { _ in
            DesignSystem.CharterSkeletonRow()
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
} else if viewModel.charters.isEmpty {
    CharterEmptyState()
} else {
    // existing list
}
```

### 10.3 Library List

`LibraryListView` has no skeleton state either. The library items are `LibraryItemRow` cards. A `LibrarySkeletonRow` should be added to `DesignSystem`:

```swift
// SkeletonRow.swift — add alongside CharterSkeletonRow
extension DesignSystem {
    struct LibrarySkeletonRow: View {
        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    SkeletonBlock(width: 24, height: 24)
                    SkeletonBlock(width: 180, height: 18)
                    Spacer()
                    SkeletonBlock(width: 56, height: 16)
                }
                SkeletonBlock(height: 14)
                SkeletonBlock(width: 120, height: 12)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
        }
    }
}
```

Use in `LibraryListView`:

```swift
if viewModel.isLoading && viewModel.isEmpty {
    VStack(spacing: DesignSystem.Spacing.sm) {
        ForEach(0..<5, id: \.self) { _ in
            DesignSystem.LibrarySkeletonRow()
        }
    }
    .padding(.horizontal, DesignSystem.Spacing.lg)
    .padding(.top, DesignSystem.Spacing.sm)
}
```

### 10.4 `isLoading` State During Load-More (Pagination)

For the "load more" case in discovery (`viewModel.isLoadingMore`), the current pattern is a `ProgressView()` at the bottom of the list. This is fine — skeletons are most impactful on the initial load, not on pagination spinners.

### 10.5 Skeleton Animation Performance Note

`SkeletonBlock` uses `withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false))`. Each block creates its own independent animation timer. For a list of 6 skeleton rows with 3 blocks each (18 total), these will drift out of phase over time. To keep all skeletons in sync, share a single `animating` binding via a parent view:

```swift
struct SynchronizedSkeletonList: View {
    @State private var animating = false

    var body: some View {
        VStack {
            ForEach(0..<6, id: \.self) { _ in
                SyncedCharterSkeletonRow(animating: animating)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                animating = true
            }
        }
    }
}
```

Pass `animating` as a `let` (not `@Binding`) into each row — since it's a `Bool`, it will update correctly when the parent re-renders.

---

## 11. Additional Tests for New Findings

### Sync Behaviour

```swift
// CharterEditorViewModelSyncTests.swift

@Test("Editing charter name triggers immediate sync push")
func editNameTriggersSync() async throws {
    let mockSync = MockCharterSyncService()
    let vm = CharterEditorViewModel(
        charterStore: mockCharterStore,
        charterSyncService: mockSync,
        charterID: existingPublicCharterID,
        onDismiss: {}
    )
    vm.form.name = "Updated Name"
    await vm.saveCharter()
    #expect(mockSync.pushCalledCount == 1)
}

@Test("Failed sync after maxRetries is surfaced to user, not silently dropped")
func maxRetriesExposesFailedState() async throws {
    // Inject a mock API that always returns 500
    let vm = makeSyncQueueService(apiReturns: .serverError)
    for _ in 0..<4 { await vm.processQueue() }
    #expect(vm.failedCount == 1)
    #expect(vm.pendingCount == 0)
}
```

### Fork Count

```python
# test_content.py
async def test_fork_count_atomic_increment(client, db_session, published_content):
    """Concurrent forks must not lose increments (race condition test)."""
    import asyncio
    tasks = [client.post(f"/api/v1/content/{published_content.public_id}/fork")
             for _ in range(5)]
    await asyncio.gather(*tasks)
    await db_session.refresh(published_content)
    assert published_content.fork_count == 5
```

### Discovery Cache

```swift
@Test("Discovery serves cache on second visit without network call")
func secondVisitUsesCachedData() async throws {
    let mockAPI = MockAPIClient(latency: 0)
    let vm = CharterDiscoveryViewModel(apiClient: mockAPI)
    await vm.loadInitial()                     // populates cache
    mockAPI.shouldFail = true                  // network now broken
    await vm.loadInitial()                     // should serve from cache
    #expect(vm.charters.isEmpty == false)      // still has data
    #expect(mockAPI.discoverCallCount == 1)    // only one real network call
}
```
