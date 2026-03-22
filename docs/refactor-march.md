# AnyFleet iOS — March 2026 Refactor Review

**Scope:** Full-codebase review across 112 production Swift files (App, Core, Data, DesignSystem, Features, Services).  
**Audience:** Junior–mid iOS engineers working on the codebase.  
**Goal:** Identify technical debt, rank issues by impact, and tie refactoring work to the next planned feature areas.

---

## 1. Summary

- **Solid foundation.** MVVM + Coordinator, `@Observable` throughout, GRDB-backed offline-first sync, typed `AppRoute` navigation, and a clean `UI → ViewModel → Store → Repository → Database` layer boundary. The architecture is genuinely good.
- **One critical state-cache bug:** `CharterStore.updateCharter()` updates the repository but never refreshes `self.charters`, so any list/detail view reading `charterStore.charters` will silently show stale data after an edit until the next full reload.
- **Force-unwrap mines:** Three crash sites exist in production paths — `UUID!` and `SyncOperation!` in `LocalRepository`, and `EmptyResponse() as! T` in `APIClient`. None of these are behind feature flags.
- **God file and co-location inconsistencies:** `DiscoverableCharter.swift` hosts domain model + 5 API DTOs + request types. `ProfileView.swift` is 660 lines because it embeds `ProfileViewModel`. Both slow down navigation, compilation, and testability.
- **Next features need architectural groundwork:** Delete-with-unpublish, map user avatars, community badges, and profile overhaul all require new backend endpoints and corresponding client-side model extensions — the right time to fix the above issues is while implementing these features.
- **Missing `@MainActor` on `AuthService`** despite directly mutating observable state from async closures — a data race under Swift 6 strict concurrency.

---

## 2. Issues & Recommendations

### Architecture

| # | Issue | File(s) | Priority |
|---|-------|---------|----------|
| A1 | `updateCharter()` doesn't update in-memory cache | `CharterStore.swift:154` | **Critical** |
| A2 | `DiscoverableCharter.swift` is a god file (domain + DTOs + requests) | `Core/Models/DiscoverableCharter.swift` | High |
| A3 | `ProfileViewModel` co-located in `ProfileView.swift` (660 lines) | `Features/Profile/ProfileView.swift` | High |
| A4 | Fallback `init()` in `CharterListView` creates `AppDependencies()` (not `.shared`), spawning a second `SyncCoordinator` | `CharterListView.swift:15` | High |
| A5 | `AuthService` not `@MainActor` despite mutating observable state from async closures | `Services/AuthService.swift` | Medium |
| A6 | `AppDependencies.makeForTesting()` discards a `CharterStore` with `_ = ...` (documented bug, unfixed) | `AppDependencies.swift:283` | Medium |
| A7 | Delete-charter flow does **not** unpublish from backend if `serverID != nil` | `CharterStore.swift`, `CharterSyncService.swift` | High (feature gap) |

### Code Quality

| # | Issue | File(s) | Priority |
|---|-------|---------|----------|
| C1 | Force-unwrap crash: `UUID(uuidString:)!` and `SyncOperation(rawValue:)!` | `LocalRepository.swift:766–767` | **Critical** |
| C2 | Force-cast crash: `EmptyResponse() as! T` | `APIClient.swift:441` | **Critical** |
| C3 | Magic content-type strings (`"checklist"`, `"practice_guide"`) in fork logic | `LibraryStore.swift` | Medium |
| C4 | Hardcoded section titles "Upcoming" / "Past" bypass L10n | `CharterListView.swift:145,172` | Low |
| C5 | ~~Commented-out sync-enqueue TODOs in `LocalRepository`~~ **Resolved:** queue ops stay in `SyncQueueService` / `LibraryStore`; repository documents the boundary. | `LocalRepository.swift` | Done |
| C6 | `CLLocationManager` created inside `CharterDiscoveryViewModel.init()` — not injectable, untestable | `CharterDiscoveryViewModel.swift:46` | Medium |

### Swift / SwiftUI

| # | Issue | File(s) | Priority |
|---|-------|---------|----------|
| S1 | `ProfileViewModel` has per-method `@MainActor` annotations instead of class-level (inconsistent with rest of codebase) | `ProfileView.swift:47,55,65` | Low |
| S2 | `resetFilters()` spawns a detached `Task { }` inside a `@MainActor` class — implicit structured-concurrency break | `CharterDiscoveryViewModel.swift:77` | Medium |
| S3 | Sorting (`sorted { $0.startDate < $1.startDate }`) done inline inside `body`, re-runs on every render | `CharterListView.swift:124,153` | Low |
| S4 | `returnIsInDifferentMonth` in `CharterTimelineRow` creates a `Calendar.current` on every evaluation | `CharterListView.swift:355` | Low |
| S5 | `FlashcardDeck` is a placeholder stub scattered across `LibraryStore`, `AppCoordinator`, and routes | Multiple | Medium (cleanup before expansion) |

### UX / UI

| # | Issue | File(s) | Priority |
|---|-------|---------|----------|
| U1 | Map pins (`CharterMapAnnotation`) are not tappable profiles — no avatar, no community badge | `CharterMapView.swift` | High (Phase 3) |
| U2 | Delete action on a publicly-synced charter gives no confirmation that it will be removed from discovery | `CharterListView.swift:132` | High |
| U3 | Swipe actions have no discovery affordance — no gesture hint on first launch | `CharterListView.swift:131` | Medium |
| U4 | Profile page has no communities section, no social links, no activity stats | `ProfileView.swift` | High (Phase 3) |
| U5 | Home tab has no "nearby captains" section even when an active charter exists | `HomeView.swift` | High (Phase 3) |
| U6 | Empty state on discovery map shows nothing (no messaging when 0 results) | `CharterMapView.swift` | Medium |
| U7 | "Delete Account" button in Profile has an empty action closure | `ProfileView.swift` | Medium |

### Tests

| # | Issue | Priority |
|---|-------|----------|
| T1 | `CharterStore.updateCharter()` cache-drift bug has no regression test | **Critical** |
| T2 | Delete-then-check-discovery flow (A7) has no integration test | High |
| T3 | `APIClient` force-cast path (`EmptyResponse as! T`) is not covered | High |
| T4 | `CharterDiscoveryViewModel` pagination + stale-cache behaviour lacks unit tests | Medium |
| T5 | `CharterSyncService.pushPendingCharters()` with unauthenticated user path is tested, but delete-while-public path is not | Medium |

---

## 3. Refactor Plan (8 steps, ordered by risk/impact)

### Step 1 — Fix `CharterStore.updateCharter()` cache drift *(Critical, ~30 min)*

**Problem:** `updateCharter()` returns the updated model from the repo but never writes it back to `self.charters`. Any view observing `charterStore.charters` shows stale data until the next `loadCharters()`.

```swift
// CharterStore.swift — current (broken)
func updateCharter(_ charterID: UUID, ...) async throws -> CharterModel {
    let charter = try await repository.updateCharter(charterID, ...)
    // ❌ self.charters is never updated here
    return charter
}

// CharterStore.swift — fixed
func updateCharter(_ charterID: UUID, ...) async throws -> CharterModel {
    let charter = try await repository.updateCharter(charterID, ...)
    if let index = charters.firstIndex(where: { $0.id == charterID }) {
        charters[index] = charter          // ✅ keep cache consistent
    }
    return charter
}
```

**Rationale:** Single source of truth. The in-memory `charters` array must always reflect the repository state without requiring a full reload.

---

### Step 2 — Eliminate force-unwrap crash sites *(Critical, ~1 hr)*

**`LocalRepository.swift`** (sync queue deserialization):

```swift
// Before — crashes on malformed DB row
let contentID = UUID(uuidString: record.contentID)!
let operation = SyncOperation(rawValue: record.operation)!

// After — skip and log corrupt rows rather than crash
guard let contentID = UUID(uuidString: record.contentID) else {
    AppLogger.sync.error("Corrupt sync record: invalid UUID '\(record.contentID)' — skipping")
    continue
}
guard let operation = SyncOperation(rawValue: record.operation) else {
    AppLogger.sync.error("Corrupt sync record: unknown operation '\(record.operation)' — skipping")
    continue
}
```

**`APIClient.swift`** (generic response dispatching):

```swift
// Before — force cast will crash if T is not EmptyResponse
if T.self == EmptyResponse.self {
    return EmptyResponse() as! T
}

// After — use a type-erased extension instead of a cast
extension Decodable {
    static func emptyFallback() -> Self? { nil }
}
// Or: constrain the method with a second overload for Void-returning endpoints
// The simplest safe fix:
if let empty = EmptyResponse() as? T {
    return empty
}
throw APIError.decodingFailed  // should never reach here, but safe
```

**Rationale:** Force-unwraps in data-path code are production crash sources. Logging and skipping a corrupt sync record is always safer than terminating the process.

---

### Step 3 — Delete charter → unpublish if public *(High, ~2 hr — do while building the feature)*

This is the most impactful **feature+refactor** pairing. Currently deleting a charter only removes it locally; if it was previously synced as `.community` or `.public`, it remains visible on the discovery screen for other users.

**iOS changes needed:**

```swift
// CharterStore.swift — extended deleteCharter
func deleteCharter(_ charterID: UUID) async throws {
    AppLogger.store.startOperation("Delete Charter")
    
    // 1. Fetch before delete so we know its sync state
    if let charter = charters.first(where: { $0.id == charterID }),
       let serverID = charter.serverID,
       charter.visibility != .private {
        // 2. Attempt remote unpublish (fire-and-forget; local delete always succeeds)
        try? await charterSyncService.unpublishCharter(serverID: serverID)
    }
    
    try await repository.deleteCharter(charterID)
    charters.removeAll { $0.id == charterID }
    AppLogger.store.completeOperation("Delete Charter")
}
```

```swift
// CharterSyncService.swift — new method
func unpublishCharter(serverID: String) async throws {
    guard authService.isAuthenticated else { return }
    try await apiClient.deleteCharter(serverID: serverID)
    AppLogger.sync.info("Charter \(serverID) unpublished from discovery")
}
```

**`PublishedContentDeleteModal`** (already in DesignSystem) should be used instead of the plain destructive button in swipe actions when `charter.visibility != .private`:

```swift
// CharterListView.swift — swipe action
Button(role: .destructive) {
    if charter.visibility != .private {
        charterPendingDelete = charter    // @State trigger for confirmation sheet
    } else {
        Task { try? await viewModel.deleteCharter(charter.id) }
    }
} label: { Label("Delete", systemImage: "trash") }
```

**Backend change needed:** `DELETE /charters/{id}` endpoint (or reuse the unpublish endpoint). See backend notes below.

---

### Step 4 — Split `DiscoverableCharter.swift` into focused files *(Medium, ~45 min)*

Move each type into its own file under an `API/` subfolder inside `Core/Models/`:

```
Core/Models/
├── CharterModel.swift          (domain — unchanged)
├── DiscoverableCharter.swift   (keep only the UI-facing domain struct)
├── CharterVisibility.swift     (unchanged)
└── API/
    ├── CharterAPIResponse.swift        (CharterAPIResponse, CharterWithUserAPIResponse)
    ├── CharterDiscoveryResponse.swift  (CharterDiscoveryAPIResponse, CharterListAPIResponse)
    └── CharterRequestPayloads.swift    (CharterCreateRequest, CharterUpdateRequest)
```

**Rationale:** SOLID single-responsibility. API DTOs change with every backend iteration; domain models should be stable. Separating them makes it easy to version the API layer without touching domain logic.

---

### Step 5 — Extract `ProfileViewModel` to its own file + add `@MainActor` *(Medium, ~30 min)*

Create `Features/Profile/ProfileViewModel.swift`. Add `@MainActor` at class level (replacing the per-method annotations). This aligns with the rest of the codebase and reduces `ProfileView.swift` from 660 to ~350 lines.

```swift
// ProfileViewModel.swift
@MainActor
@Observable
final class ProfileViewModel: ErrorHandling {
    // ... existing code, removing per-method @MainActor decorators
}
```

Also add `@MainActor` to `AuthService`:

```swift
// AuthService.swift
@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    // Eliminates potential data races from async closures mutating @Observable state
}
```

---

### Step 6 — Fix fallback `init()` in views that create duplicate `AppDependencies` *(High, ~1 hr)*

`CharterListView`, `DiscoverView`, and `ProfileView` each have a fallback `init()` that does:

```swift
let deps = AppDependencies()   // creates a SECOND SyncCoordinator + timer
```

Fix: Never create `AppDependencies()` in a view. Preview initializers should use `AppDependencies.makeForTesting()`. Remove the fallback entirely and require a `viewModel` parameter.

```swift
// Before
init(viewModel: CharterListViewModel? = nil) {
    if let viewModel = viewModel { ... } else {
        let deps = AppDependencies()   // ❌
        ...
    }
}

// After — previews must pass a viewModel
init(viewModel: CharterListViewModel) {
    _viewModel = State(initialValue: viewModel)
}

#Preview {
    MainActor.assumeIsolated {
        let deps = try! AppDependencies.makeForTesting()
        return CharterListView(viewModel: .init(charterStore: deps.charterStore,
                                                coordinator: AppCoordinator(dependencies: deps)))
        .environment(\.appDependencies, deps)
    }
}
```

---

### Step 7 — Map overhaul: avatars, clickable profiles, community badges *(Phase 3 feature — refactor while building)*

**Architecture changes needed before building:**

1. **`DiscoverableCharter` needs `captainAvatarURL`** — currently only has `captainName`. Backend must include this in `CharterWithUserAPIResponse`.

2. **Community affiliation** — `DiscoverableCharter` should gain `captainCommunities: [CommunityBadge]` (Phase 4 data model). For Phase 3 we can start with just the primary community name and color.

3. **`CharterMapAnnotation` refactor** — replace the plain circle with a `UserAvatarPin`:

```swift
// CharterMapView.swift — new annotation component
struct UserAvatarPin: View {
    let charter: DiscoverableCharter
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(communityRingColor)
                .frame(width: isSelected ? 52 : 42)
            
            AsyncImage(url: charter.captainAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
            }
            .frame(width: isSelected ? 44 : 36)
            .clipShape(Circle())
            
            if let badge = charter.primaryCommunityBadge {
                CommunityBadgeOverlay(badge: badge)
                    .offset(x: 12, y: 12)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.2), value: isSelected)
    }
    
    private var communityRingColor: Color {
        charter.primaryCommunityBadge?.color ?? DesignSystem.Colors.primary
    }
}
```

4. **Filtering logic** — `CharterDiscoveryFilters` should gain `communityID: String?` once community model exists. The `CharterFilterView` sheet gets a new "Community" section.

5. **`CLLocationManager` injection** — extract to `LocationProviding` protocol and inject into `CharterDiscoveryViewModel` (fixes testability):

```swift
protocol LocationProviding {
    var currentLocation: CLLocationCoordinate2D? { get }
    func requestWhenInUseAuthorization()
}

// CharterDiscoveryViewModel.swift
init(apiClient: APIClientProtocol, locationProvider: LocationProviding = CLLocationManager()) {
    self.apiClient = apiClient
    self.locationProvider = locationProvider
}
```

---

### Step 8 — Profile overhaul: communities, socials, stats *(Phase 3 feature — refactor while building)*

**Data model additions needed:**

```swift
// Core/Models/UserInfo.swift (extend existing)
struct UserInfo: Codable {
    // ... existing fields ...
    var socialLinks: [SocialLink]?      // instagram, twitter, website
    var communities: [CommunityMembership]?
    var stats: CaptainStats?
}

struct SocialLink: Codable, Identifiable {
    var id: UUID = UUID()
    let platform: SocialPlatform         // .instagram, .twitter, .website
    let handle: String
    var url: URL? { platform.url(for: handle) }
}

enum SocialPlatform: String, Codable {
    case instagram, twitter, website
    func url(for handle: String) -> URL? { ... }
}

struct CaptainStats: Codable {
    let chartersCompleted: Int
    let contentPublished: Int
    let communitiesJoined: Int
    let regionsVisited: Int              // computed from charter destinations
}

struct CommunityMembership: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let role: CommunityRole              // .member, .moderator, .founder
    var isPrimary: Bool
}
```

**`ProfileView` decomposition** — the existing 660-line monolith should be split into:

```
Features/Profile/
├── ProfileView.swift           (~150 lines — container + state routing)
├── ProfileViewModel.swift      (~200 lines — extracted in Step 5)
├── Components/
│   ├── ProfileHeroCard.swift   (avatar, name, bio, edit button)
│   ├── ProfileStatsBar.swift   (4-stat row: charters, content, communities, regions)
│   ├── CommunitiesSection.swift (community chips with join/leave, primary toggle)
│   ├── SocialLinksSection.swift (instagram/twitter/website edit row)
│   └── ProfileEditForm.swift   (inline edit state — username, bio, location)
```

**Community selection** in the edit form:

```swift
// CommunitiesSection.swift
struct CommunitiesSection: View {
    @Binding var memberships: [CommunityMembership]
    let onJoin: (String) -> Void
    let onLeave: (String) -> Void
    let onSetPrimary: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            DesignSystem.SectionHeader(title: "Communities")
            
            ForEach(memberships) { membership in
                CommunityRow(
                    membership: membership,
                    onSetPrimary: { onSetPrimary(membership.id) },
                    onLeave: { onLeave(membership.id) }
                )
            }
            
            Button("+ Find Communities") { /* navigate to community directory */ }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }
}
```

---

## 4. Upcoming Features: Refactor Context

The following planned features each have a "refactor hook" — the right time to clean up adjacent code.

### Delete charter → unpublish (Step 3 above)

**What to do while building:**
- Extend `CharterSyncService` with `unpublishCharter(serverID:)`
- Replace plain swipe-delete with `PublishedContentDeleteModal` (already in DesignSystem) when `visibility != .private`
- Add `DELETE /charters/{id}` to backend (or reuse visibility PATCH to `.private` before delete)
- **Test to add:** `CharterSyncServiceTests` → `testDeletePublicCharterCallsUnpublish()`

**Backend note:** The FastAPI charter repository at `anyfleet-backend/app/repositories/charter.py` needs a `delete_charter(charter_id, user_id)` method, and `app/schemas/charter.py` should expose a `DELETE /charters/{id}` route with auth.

---

### Map overhaul (Steps 7 + backend)

**What to do while building:**
- Inject `LocationProviding` protocol (Step 7 — makes VM testable)
- Add `captainAvatarURL` to `CharterWithUserAPIResponse` in backend `app/schemas/charter.py`
- Introduce `CommunityBadge` as a lightweight struct in `Core/Models/` (even as stub)
- Replace `CharterMapAnnotation` with `UserAvatarPin` (Step 7)
- Add empty-state overlay when `charters.isEmpty && !isLoading` on the map

---

### Home tab: nearby captains when active charter

**What to do while building:**
- `HomeViewModel` needs a `nearbyCaptains: [NearbyCaption]` property (initially empty array)
- Add a `NearbyCaption` model: `{ id, name, avatarURL, distanceKm, activeCommunity }`
- Home tab shows a horizontal scroll strip of `NearbyCaptainCard` below the hero charter card — this strip is hidden when location permission is denied
- The backend needs `GET /captains/nearby?lat=&lon=&radius_km=` — add to `APIClientProtocol` now even if response is always `[]` while the backend feature is in progress
- **Refactor while building:** `HomeView` can be split from its current ~280-line body into `HomeHeroCard`, `UpcomingStrip`, `NearbyCaptainsStrip`, and `PinnedContentGrid` sub-views

---

### Onboarding + swipe gesture hints

**What to do while building:**
- Create `OnboardingService` (simple `UserDefaults` wrapper) storing which hints have been shown
- `CharterListView` should show a `SwipeHintOverlay` on first display (pointing right-to-left with "Swipe to edit or delete")
- The hint is a `ZStack` overlay that disappears after first swipe or a 3s timer
- Onboarding flow should be a new `AppRoute.onboarding` that `AppCoordinator` presents as a sheet on first launch (check `OnboardingService.hasCompletedOnboarding`)

---

### Caching strategy

**Current state:** `CharterDiscoveryViewModel` has an in-memory 120-second dict cache. `LibraryStore` has an `LRUCache`. No persistent response cache.

**Improvements while building Phase 3:**
- **Stale-while-revalidate for charters discovery:** Cache the last successful response to SQLite (`DiscoveryCacheRecord`) so the map/list shows results immediately after re-launch even without network
- **Avatar image caching:** Add `AsyncImageCache` (simple `NSCache<NSURL, UIImage>`) behind a custom `CachedAsyncImage` view component — reuse across map pins, profile, and author cards
- **Prefetch on WiFi:** When network changes to WiFi, trigger a background `CharterSyncService.pullRemoteCharters()` silently

---

### Profile overhaul (Step 8 above)

**What to do while building:**
- Extract `ProfileViewModel` to own file (Step 5) — prerequisite
- Add `SocialLinksSection`, `CommunitiesSection`, `ProfileStatsBar` (Step 8)
- Backend `app/schemas/profile.py` needs to accept and return `social_links: list[SocialLink]` and `communities: list[CommunityMembership]`
- Wire "Delete Account" button to `authService.deleteAccount()` — currently empty closure
- **Visual:** Hero card should use a `AsyncImage` background (sailing photo) falling back to a gradient — blueprint is in `DesignSystem+Profile.swift` under `ProfileHeroCard`

---

## 5. Recommended Tests (5 high-value cases)

```swift
// 1. CRITICAL — CharterStore cache after update
func testUpdateCharterUpdatesInMemoryCache() async throws {
    let store = CharterStore(repository: MockCharterRepository())
    let charter = try await store.createCharter(name: "Test", ...)
    let updated = try await store.updateCharter(charter.id, name: "Renamed", ...)
    XCTAssertEqual(store.charters.first(where: { $0.id == charter.id })?.name, "Renamed")
}

// 2. CRITICAL — Delete public charter calls unpublish
func testDeletePublicCharterCallsUnpublish() async throws {
    let mockAPI = MockAPIClient()
    let service = CharterSyncService(repository: mock, apiClient: mockAPI, ...)
    let charter = CharterModel(..., serverID: "srv-123", visibility: .community)
    await service.unpublishCharter(serverID: "srv-123")
    XCTAssertTrue(mockAPI.calledDeleteCharter)
    XCTAssertEqual(mockAPI.deletedServerID, "srv-123")
}

// 3. HIGH — APIClient EmptyResponse path doesn't crash
func testAPIClientEmptyResponsePathIsSafe() async throws {
    // Verify that performRequest (Void) doesn't crash when T is EmptyResponse
    let client = APIClient(session: MockURLSession(statusCode: 204, data: Data()))
    XCTAssertNoThrow(try await client.performRequest(method: "DELETE", path: "/test"))
}

// 4. HIGH — Discovery pagination loads page 2 from offset
func testDiscoveryViewModelPaginationAppendsResults() async throws {
    let vm = CharterDiscoveryViewModel(apiClient: MockAPIClient(pages: [page1, page2]))
    await vm.loadInitial()
    await vm.loadMore()
    XCTAssertEqual(vm.charters.count, 40)  // 20 + 20
    XCTAssertEqual(vm.currentOffset, 40)
}

// 5. MEDIUM — Stale cache triggers background refresh
func testStaleCacheEntryTriggersBackgroundFetch() async throws {
    let staleEntry = DiscoveryCacheEntry(charters: [old], fetchedAt: .init(timeIntervalSinceNow: -200), cacheKey: "k")
    XCTAssertTrue(staleEntry.isStale)
    // Verify that load() calls fetchAndCache(silent: true) when entry is stale
}
```

---

## 6. Backend Notes (anyfleet-backend)

These iOS changes require corresponding backend work:

| iOS need | Backend endpoint | File |
|----------|-----------------|------|
| Delete public charter → unpublish | `DELETE /charters/{id}` | `app/repositories/charter.py` + new route in `app/main.py` |
| Map pin avatars | Add `avatar_url` to `CharterWithUserResponse` | `app/schemas/charter.py` |
| Nearby captains | `GET /captains/nearby?lat&lon&radius_km` | New `app/repositories/captain.py` |
| Profile communities | `PATCH /profile` accepts `communities[]` | `app/schemas/profile.py` |
| Profile social links | `PATCH /profile` accepts `social_links[]` | `app/schemas/profile.py` |

---

## 7. File-change Map (quick reference)

| File | Change | Step |
|------|--------|------|
| `Core/Stores/CharterStore.swift` | Fix `updateCharter` cache + add `deleteCharter` unpublish call | 1, 3 |
| `Data/Repositories/LocalRepository.swift` | Replace force-unwraps with guarded logging | 2 |
| `Services/APIClient.swift` | Replace `as! T` with safe cast | 2 |
| `Services/CharterSyncService.swift` | Add `unpublishCharter(serverID:)` | 3 |
| `Core/Models/DiscoverableCharter.swift` | Keep domain struct; split DTOs to `Core/Models/API/` | 4 |
| `Features/Profile/ProfileView.swift` | Remove `ProfileViewModel`; decompose into sub-views | 5, 8 |
| `Features/Profile/ProfileViewModel.swift` | New file; add `@MainActor` at class level | 5 |
| `Services/AuthService.swift` | Add `@MainActor` | 5 |
| `Features/Charter/CharterListView.swift` | Remove fallback `init()`; wire `PublishedContentDeleteModal` | 6, 3 |
| `Features/Charter/Discovery/CharterMapView.swift` | `UserAvatarPin` + empty state overlay | 7 |
| `Features/Charter/Discovery/CharterDiscoveryViewModel.swift` | Inject `LocationProviding`; remove `Task {}` in `resetFilters` | 7 |
| `Core/Models/UserInfo.swift` (extend) | Add `socialLinks`, `communities`, `stats` | 8 |

---

## 8. Implementation checklist (severity order)

Status reflects **anyfleet** iOS + **anyfleet-backend** as verified after the original review. Within each severity, items are ordered: completed first (`[x]`), then remaining work (`[ ]`).

### Critical

- [x] **A1 / Step 1** — `CharterStore.updateCharter` writes the returned charter back into `charters` (no cache drift).
- [x] **C1 / Step 2** — `LocalRepository` sync-queue load: invalid UUID / unknown `SyncOperation` rows are skipped with logging (no force-unwrap).
- [x] **C2 / Step 2** — `APIClient` uses conditional `EmptyResponse() as? T` instead of force-cast to `T`.
- [x] **T1** — Regression test: after `updateCharter`, `store.charters` matches the updated model (see §5 example `testUpdateCharterUpdatesInMemoryCache`).

### High

- [x] **Step 3 / backend** — Owner can remove a charter from the server (`DELETE /charters/{id}` soft delete); discovery excludes deleted charters.
- [x] **Step 3 / iOS** — Non-private delete flow unpublishes via `CharterSyncService.unpublishCharter` + confirmation UI (`CharterDeleteModal`) from charter list.
- [x] **A2 / Step 4** — `DiscoverableCharter` domain file slimmed; DTOs in `Core/Models/API/`.
- [x] **A3 / Step 5** — `ProfileViewModel` in `Features/Profile/ProfileViewModel.swift`.
- [x] **A4 / Step 6** — `CharterListView` and `DiscoverView` require injected view models (no `AppDependencies()` fallback in those entry points).
- [x] **A5 / Step 5** — `AuthService` is `@MainActor`.
- [x] **U1 / U6 / Step 7** — Map: `UserAvatarPin`, selection/callout path, localized empty overlay when there are no located charters.
- [x] **Backend §6 (partial)** — `CharterWithUser`-style responses include captain `avatar_url` (and related user fields); profile responses include social/community data (wired through auth/profile APIs—paths differ slightly from the table below).
- [x] **A7 (full)** — `CharterStore.deleteCharter` should call unpublish when `serverID != nil` and visibility ≠ `.private`, so **every** delete path stays consistent (today unpublish is driven from the list UI, not the store).
- [ ] **U5** — Home: “nearby captains” strip when an active charter exists; iOS model + API client; backend `GET /captains/nearby?lat=&lon=&radius_km=`.
- [x] **T2** — Integration test: delete public/community charter → no longer discoverable (or equivalent contract test).
- [x] **T3** — Unit test: `APIClient` empty-body / `EmptyResponse` path does not crash (e.g. 204-style response).

### Medium

- [x] **T4** — `CharterDiscoveryViewModelTests` cover pagination, cache-hit offset behavior, and stale background refresh expectations.
- [x] **C4** — Charter list section headers use `L10n` (not hardcoded “Upcoming” / “Past”).
- [ ] **A6** — `AppDependencies.makeForTesting(mockRepository:)` still constructs a discarded `CharterStore` (`_ = …`); fix or document a single supported test pattern.
- [ ] **C3** — Replace magic fork/publish strings (`"checklist"`, `"practice_guide"`, etc.) in `LibraryStore` with shared typed constants or an enum.
- [x] **C5** — Resolve or implement `LocalRepository` TODOs around enqueueing sync after local mutations.
- [ ] **C6 / Step 7** — Introduce `LocationProviding` (or equivalent) and inject into `CharterDiscoveryViewModel` instead of owning `CLLocationManager()` inside `init`.
- [ ] **S2 / Step 7** — Remove unstructured `Task { await loadInitial() }` from the filter-apply path (`applyFiltersImmediately` / related); prefer structured concurrency from the caller.
- [ ] **S5** — `FlashcardDeck` stub: consolidate or remove placeholders across `LibraryStore`, repositories, and discover reader until the feature is real.
- [ ] **U3** — Onboarding: `OnboardingService` (UserDefaults), first-launch swipe hint on `CharterListView`, optional `AppRoute.onboarding` sheet.
- [ ] **U7** — Profile “Delete Account”: replace empty button action with real `deleteAccount` flow (client + backend contract).
- [ ] **Step 8 / profile UI** — Further decompose `ProfileView` toward the ~150-line container + `Components/` split described in §8 (hero, stats, communities, socials, edit form).
- [ ] **Caching (§ “Caching strategy”)** — Persistent discovery cache in SQLite (`DiscoveryCacheRecord`); optional WiFi-triggered `pullRemoteCharters()` prefetch.
- [ ] **T5** — Test coverage for delete-while-public / push-queue edge cases called out in §5.
- [ ] **Step 3 (modal choice)** — Doc suggested `PublishedContentDeleteModal`; app uses `CharterDeleteModal` (functionally fine—align naming/docs if desired).
- [ ] **Step 6 (remainder)** — `LibraryListView` (and any other views) must not create bare `AppDependencies()` in production `init` paths (duplicate sync coordinator risk).

### Low

- [x] **S1** — `ProfileViewModel` uses class-level `@MainActor` instead of per-method annotations.
- [ ] **S3** — Move `sorted { … }` for upcoming/past charter rows out of hot `body` paths (e.g. computed properties on the view model).
- [ ] **S4** — `CharterTimelineRow` / month boundary: avoid allocating `Calendar.current` on every evaluation where possible.
- [ ] **§6 doc accuracy** — Table still says `PATCH /profile` for communities/socials; implementation uses **auth** `update_profile` with `community_memberships` / `social_links`. Update §6 when editing this doc next.

---

*Document version: 1.1 — March 2026*  
*§8 checklist added. Re-validate §2 line numbers and §6 endpoint names against the repo before each fix.*
