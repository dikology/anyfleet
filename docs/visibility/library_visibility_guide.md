# Library Visibility Feature: UX/UI & Code Refactoring Guide

**Senior Developer Analysis**  
*AnyFleet Sailing - Phase 2 Community Content Preparation*

---

## EXECUTIVE SUMMARY

Your current implementation has solid foundations but requires:
1. **Clear visual distinction** between local (private/unlisted) and published (public) content
2. **Progressive disclosure** pattern for publishing workflow - don't enable until signed in
3. **Intent confirmation** with contextual modals, not swipe actions
4. **Persistent visibility state** in GRDB with sync-aware architecture
5. **Code refactoring** to separate concerns and enable Phase 2 features

---

## PART 1: CODE ANALYSIS & REFACTORING

### Current Issues

#### 1. **LibraryListView - Too Many Responsibilities**
```
LibraryListView handles:
- Filtering logic (ContentFilter enum)
- Row rendering (LibraryItemRow as nested struct)
- Swipe actions (delete, edit, pin)
- Empty state
- Toolbar creation
- No visibility toggle implementation

Problem: View is 400+ lines, mixing concerns
```

#### 2. **No Auth State Observable**
```
Current: ProfileView handles auth independently
Missing: LibraryListViewModel doesn't observe auth state
Impact: Can't disable publish actions based on login status
```

#### 3. **Visibility Enum Incomplete**
```
Assumed implementation:
enum Visibility: String, CaseIterable {
    case private = "private"
    case unlisted = "unlisted"
    case public = "public"
    
    var icon: String { ... }
    var displayName: String { ... }
}

Missing: 
- Sync state tracking (local vs pending sync)
- Publish timestamp
- Public URL generation
- Author attribution
```

#### 4. **No Confirmation Dialog Pattern**
```
Current swipe actions directly execute
Expected: Confirmation modal for publish action
```

---

## PART 2: REFACTORED ARCHITECTURE

### 2.1 Extend AuthService for Observable Auth State

```swift
// AuthService+Observable.swift
extension AuthService {
    @MainActor
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        Just(isAuthenticated)
            .merge(with: /* sign in notification stream */)
            .eraseToAnyPublisher()
    }
}
```

**Or better - use Observation macro:**

```swift
@Observable
final class AuthStateObserver {
    private let authService: AuthService
    
    var isSignedIn: Bool {
        authService.isAuthenticated
    }
    
    var currentUser: UserInfo? {
        authService.currentUser
    }
    
    init(authService: AuthService = .shared) {
        self.authService = authService
    }
}
```

Add to AppDependencies and inject into LibraryListViewModel.

---

### 2.2 Extend LibraryModel with Visibility Management

```swift
// LibraryModel+Visibility.swift
extension LibraryModel {
    
    /// Visibility state with sync awareness
    enum VisibilityState: Codable, Equatable {
        case `private`
        case unlisted
        case `public`(PublicMetadata)
        
        struct PublicMetadata: Codable, Equatable {
            let publishedAt: Date
            let publicID: String  // URL-friendly slug
            let canFork: Bool
            let authorUsername: String
            let viewCount: Int
        }
    }
    
    /// Sync state for content
    enum SyncState: String, Codable, CaseIterable {
        case local      // Never published
        case published  // Published, all synced
        case pending    // Publish action in progress
        case error      // Sync failed, waiting retry
    }
    
    // Computed properties for UI
    var isPublishedContent: Bool {
        if case .public = visibilityState { return true }
        return false
    }
    
    var isLocal: Bool {
        visibilityState == .private || visibilityState == .unlisted
    }
    
    var canPublish: Bool {
        syncState != .pending && visibilityState != .public
    }
}
```

---

### 2.3 Create VisibilityService for Business Logic

```swift
// VisibilityService.swift
@MainActor
@Observable
final class VisibilityService {
    private let libraryStore: LibraryStore
    private let authService: AuthService
    
    enum PublishError: LocalizedError {
        case notAuthenticated
        case networkError
        case validationError(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Sign in to publish content"
            case .networkError:
                return "Network error. Check connection and try again."
            case .validationError(let msg):
                return msg
            }
        }
    }
    
    /// Check if user can perform visibility actions
    func canToggleVisibility() -> Bool {
        authService.isAuthenticated
    }
    
    /// Publish content - with full validation
    func publishContent(_ item: LibraryModel) async throws {
        guard authService.isAuthenticated else {
            throw PublishError.notAuthenticated
        }
        
        guard item.title.trimmingCharacters(in: .whitespaces).count >= 3 else {
            throw PublishError.validationError("Title must be at least 3 characters")
        }
        
        // Update visibility state with sync tracking
        var updated = item
        updated.syncState = .pending
        
        do {
            try await libraryStore.updateVisibility(updated, newState: .public)
            updated.syncState = .published
            try await libraryStore.save(updated)
        } catch {
            updated.syncState = .error
            try? await libraryStore.save(updated)
            throw error
        }
    }
    
    /// Unpublish content
    func unpublishContent(_ item: LibraryModel) async throws {
        var updated = item
        updated.visibilityState = .private
        try await libraryStore.save(updated)
    }
    
    /// Change visibility
    func changeVisibility(_ item: LibraryModel, to state: LibraryModel.VisibilityState) async throws {
        guard authService.isAuthenticated else {
            throw PublishError.notAuthenticated
        }
        
        var updated = item
        updated.visibilityState = state
        try await libraryStore.save(updated)
    }
}
```

---

### 2.4 Refactor LibraryListViewModel

```swift
@MainActor
@Observable
final class LibraryListViewModel {
    // MARK: - Dependencies
    private let libraryStore: LibraryStore
    private let visibilityService: VisibilityService
    private let authObserver: AuthStateObserver
    private let coordinator: AppCoordinator
    
    // MARK: - UI State
    var isLoading = false
    var loadError: Error?
    var pendingPublishItem: LibraryModel?
    var publishError: Error?
    
    // MARK: - Filtered Data
    var library: [LibraryModel] { libraryStore.library }
    var localContent: [LibraryModel] { libraryStore.library.filter { $0.isLocal } }
    var publicContent: [LibraryModel] { libraryStore.library.filter { $0.isPublishedContent } }
    
    var isEmpty: Bool { library.isEmpty }
    var hasLocalContent: Bool { !localContent.isEmpty }
    var hasPublicContent: Bool { !publicContent.isEmpty }
    
    /// Is user authenticated for publishing?
    var isSignedIn: Bool { authObserver.isSignedIn }
    
    init(
        libraryStore: LibraryStore,
        visibilityService: VisibilityService,
        authObserver: AuthStateObserver,
        coordinator: AppCoordinator
    ) {
        self.libraryStore = libraryStore
        self.visibilityService = visibilityService
        self.authObserver = authObserver
        self.coordinator = coordinator
    }
    
    // MARK: - Visibility Actions
    
    func initiatePublish(_ item: LibraryModel) {
        // Set as pending, show confirmation
        pendingPublishItem = item
    }
    
    func confirmPublish() async {
        guard let item = pendingPublishItem else { return }
        
        publishError = nil
        
        do {
            try await visibilityService.publishContent(item)
            pendingPublishItem = nil
            await loadLibrary()
        } catch {
            publishError = error
        }
    }
    
    func cancelPublish() {
        pendingPublishItem = nil
        publishError = nil
    }
    
    func unpublish(_ item: LibraryModel) async {
        do {
            try await visibilityService.unpublishContent(item)
            await loadLibrary()
        } catch {
            AppLogger.view.error("Failed to unpublish: \(error)")
        }
    }
    
    // MARK: - Existing Actions
    
    func deleteContent(_ item: LibraryModel) async throws {
        try await libraryStore.deleteContent(item)
    }
    
    func togglePin(for item: LibraryModel) async {
        await libraryStore.togglePin(for: item)
    }
    
    // ... other existing methods
}
```

---

## PART 3: UX/UI DESIGN PATTERNS

### 3.1 Visual Distinction: Local vs Public Content

#### Design Decision: Content Layering with Visual Separation

Instead of just badges, use **progressive visual hierarchy**:

```
┌─────────────────────────────────────────┐
│ 📚 My Library                           │
├─────────────────────────────────────────┤
│                                         │
│ 🔒 LOCAL CONTENT (Not Published)       │
│ ──────────────────────────────────────   │
│                                         │
│ ✓ Sailing Pre-Check                  │ ← Private badge
│ ┌─ 📋 Checklist                        │
│ └─ [••] private                        │
│                                         │
│ ✓ Storm Preparation Guide             │
│ ┌─ 📖 Practice Guide                   │
│ └─ [••] private                        │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│ 🌐 PUBLIC CONTENT (Published)          │
│ ──────────────────────────────────────   │
│                                         │
│ ✓ Racing Tips                          │
│ ┌─ 📖 Practice Guide                   │
│ └─ [◉] public · 234 views              │
│    by @SailorMaria                     │
│                                         │
│ ✓ Knot Tying Flashcards               │
│ ┌─ 🎴 Flashcard Deck                   │
│ └─ [◉] public · 89 views               │
│    by @SailorMaria                     │
│                                         │
└─────────────────────────────────────────┘
```

---

### 3.2 GRDB Schema & Persistence

#### New Migration (v2.0.0)

```sql
-- Extend library_content table
ALTER TABLE library_content ADD COLUMN visibility_state TEXT DEFAULT 'private';
ALTER TABLE library_content ADD COLUMN sync_state TEXT DEFAULT 'local';
ALTER TABLE library_content ADD COLUMN published_at DATETIME;
ALTER TABLE library_content ADD COLUMN public_id TEXT;
ALTER TABLE library_content ADD COLUMN author_id TEXT;
ALTER TABLE library_content ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE library_content ADD COLUMN can_fork BOOLEAN DEFAULT 1;

-- New public_content table
CREATE TABLE public_content (
    id INTEGER PRIMARY KEY,
    public_id TEXT UNIQUE NOT NULL,
    content_id BLOB NOT NULL,
    content_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    author_username TEXT NOT NULL,
    published_at DATETIME NOT NULL,
    view_count INTEGER DEFAULT 0,
    can_fork BOOLEAN DEFAULT 1,
    updated_at DATETIME NOT NULL,
    synced_at DATETIME,
    FOREIGN KEY (content_id) REFERENCES library_content(id) ON DELETE CASCADE
);

-- New visibility_changes table for sync tracking
CREATE TABLE visibility_changes (
    id INTEGER PRIMARY KEY,
    content_id BLOB NOT NULL,
    from_state TEXT NOT NULL,
    to_state TEXT NOT NULL,
    created_at DATETIME NOT NULL,
    synced BOOLEAN DEFAULT 0,
    sync_error TEXT,
    FOREIGN KEY (content_id) REFERENCES library_content(id) ON DELETE CASCADE
);
```

---

## CONCLUSION

This refactoring:
- ✅ Separates concerns (views, services, models, database)
- ✅ Makes visibility state persistent and sync-aware
- ✅ Creates clear, intentional UX patterns
- ✅ Prepares for Phase 2 backend integration
- ✅ Improves testability and maintainability

**Ready to implement. Start with Part 2 refactoring.**