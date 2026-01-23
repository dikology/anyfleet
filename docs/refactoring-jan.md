# anyfleet iOS App - Refactoring Review
**Date:** January 2026  
**Reviewer:** Senior iOS Engineer  
**Scope:** Full codebase review and refactoring recommendations

---

## Executive Summary

The anyfleet iOS app is a **well-architected SwiftUI application** for yacht charter management with checklists, practice guides, and content discovery. The codebase demonstrates solid engineering fundamentals with clear separation of concerns, modern Swift patterns, and comprehensive testing.

### Key Findings

**Strengths:**
- Clean layered architecture (UI → ViewModel → Store → Repository → Database)
- Modern Swift 6 with `@Observable` macro and structured concurrency
- Comprehensive dependency injection via `AppDependencies`
- Good test coverage with protocol-oriented design for testability
- Consistent logging infrastructure with `AppLogger`
- Well-structured design system with reusable components

**Critical Issues:**
- Mixed responsibilities in coordinator (navigation + background sync)
- Force unwraps and `fatalError` in production code paths
- Large view files (ProfileView ~660 lines) need decomposition
- Hardcoded fallback UUID scattered across codebase
- Some performance inefficiencies in data refresh patterns

**Priority:** 🟡 Medium - Solid foundation with architectural debt requiring systematic refactoring

---

## 1. High-Level Review

### What This Code Does

The anyfleet app manages yacht charter lifecycle with:
- **Charter management:** Create, edit, track charter trips with dates, locations, boats
- **Content library:** User-created checklists and practice guides with publishing to community
- **Checklist execution:** Track checklist completion state per charter
- **Content discovery:** Browse and fork community-shared content
- **User profiles:** Authentication, profile editing, contribution metrics

**Data Flow:**
```
View → ViewModel → Store → Repository → GRDB Database
                      ↓
                 SyncQueue → APIClient → Backend
```

**Side Effects:**
- Local SQLite persistence with GRDB
- Background sync timer (60s interval)
- Keychain storage for auth tokens
- Network requests with token refresh
- Image upload and caching

### Main Problems (Ranked)

#### 🔴 **1. Architecture Issues**

**Problem:** `AppCoordinator` violates Single Responsibility Principle
```swift
// AppModel.swift lines 69-76
private func startBackgroundSync() {
    syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.syncService.syncPending()
        }
    }
}
```
**Impact:** Navigation logic mixed with background sync, harder to test and maintain.

**Problem:** Implicit nil-UUID placeholder used in 6+ locations
```swift
// LocalRepository.swift lines 307, 413, 458
creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
```
**Impact:** Magic constant scattered, unclear intent, fragile fallback.

**Problem:** `LibraryStore.fatalError` on unsupported type
```swift
// LibraryStore.swift line 161
} else {
    fatalError("Unsupported content type for caching")
}
```
**Impact:** App crashes instead of graceful error handling.

#### 🟡 **2. Code Quality Issues**

**Problem:** Large view files breaking composition principle
- `ProfileView`: 664 lines with 10+ subviews mixed into single file
- `AuthService`: 615 lines with auth, token management, profile updates

**Impact:** Poor readability, hard to test individual components.

**Problem:** Force unwraps in production code
```swift
// APIClient.swift line 341
if T.self == EmptyResponse.self {
    return EmptyResponse() as! T  // Force cast
}
```
**Impact:** Potential runtime crashes.

**Problem:** Complex nested closures reduce readability
```swift
// AppView.swift line 16
TabView(selection: Binding<Tab>(get: { coordinator.selectedTab }, 
                                 set: { coordinator.selectedTab = $0 })) {
```

#### 🟢 **3. Swift/SwiftUI Best Practices**

**Problem:** No memoization for expensive computed properties
```swift
// HomeViewModel.swift lines 44-57
var activeCharter: CharterModel? {
    // Recalculated on every access, filtering entire array
    charterStore.charters.filter { ... }
}
```

**Problem:** Inefficient library reloads on single item changes
```swift
// LibraryListViewModel.swift line 309
await loadLibrary()  // Reloads ALL items after one publish
```

#### 🟢 **4. Performance Concerns**

**Problem:** Background sync at 60s might be aggressive
```swift
// AppModel.swift line 71
syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true)
```
**Impact:** Unnecessary battery drain if no pending operations.

**Problem:** No debouncing on rapid operations
- Multiple rapid pin/unpin actions trigger separate DB writes

#### 🟢 **5. UX & UI Issues**

**Problem:** Accessibility labels incomplete
- Missing `.accessibilityHint` on many interactive elements
- No `.accessibilityValue` for dynamic state (sync status, completion %)

**Problem:** Loading states too coarse-grained
- Single `isLoading` flag for entire library doesn't show per-item progress

---

## Refactor Plan

### **Phase 1: Critical Architecture (1-2 weeks)**

1. **Extract `SyncCoordinator` from `AppCoordinator`**
   - Create dedicated `SyncCoordinator` for background sync timer
   - Keep `AppCoordinator` focused on navigation only
   - Inject `SyncCoordinator` into `AppDependencies`

2. **Replace hardcoded nil-UUID with named constant**
   - Create `extension UUID { static let placeholder = UUID(...) }`
   - Document intent clearly in comments
   - Replace all 6+ instances

3. **Replace `fatalError` with proper error handling**
   - Convert `LibraryStore.fetchFullContent` to throw custom error
   - Handle error in view models with user-facing message

### **Phase 2: Code Quality (2-3 weeks)**

4. **Decompose large files**
   - Split `ProfileView` into:
     - `ProfileView` (main navigation)
     - `AuthenticatedProfileView`
     - `UnauthenticatedProfileView`
     - `ProfileEditForm` (extracted from inline form)
     - `AccountManagementSection`
   
   - Split `AuthService` into:
     - `AuthService` (core authentication)
     - `TokenManager` (token refresh logic)
     - `ProfileService` (profile update, image upload)

5. **Eliminate force unwraps**
   - Replace `as!` casts with safe `guard let` or throw
   - Add `@preconcondition` documentation where force unwrap is intentional

6. **Simplify bindings**
   - Extract computed `@Binding` wrappers into view extensions
   - Use `@Bindable` where appropriate for simpler syntax

### **Phase 3: Performance & UX (1-2 weeks)**

7. **Add memoization to expensive computed properties**
   - Cache `activeCharter` result, invalidate on charter changes
   - Use `@ObservationIgnored` for cache storage

8. **Implement incremental updates**
   - After publish/unpublish, update single item in `library` array
   - Only reload from DB if operation fails

9. **Smart background sync**
   - Only schedule timer if pending operations exist
   - Use exponential backoff for failed operations
   - Cancel timer when app is backgrounded

10. **Enhanced accessibility**
    - Add `.accessibilityHint` to all buttons/rows
    - Add `.accessibilityValue` for sync status, completion %
    - Test with VoiceOver for all primary flows

---

## 2. Architecture & Patterns

### Current Architecture Evaluation

**Layering:** ✅ Good separation into logical layers

```
┌─────────────────────────────────────────┐
│  Views (SwiftUI)                        │  ✅ Presentation logic only
├─────────────────────────────────────────┤
│  ViewModels (@Observable)               │  ✅ UI state + coordinator calls
├─────────────────────────────────────────┤
│  Stores (CharterStore, LibraryStore)    │  ✅ Domain model cache
├─────────────────────────────────────────┤
│  Repositories (LocalRepository)         │  ✅ Data access abstraction
├─────────────────────────────────────────┤
│  Database (GRDB) + Records              │  ✅ Persistence
└─────────────────────────────────────────┘
```

**Dependency Injection:** ✅ Excellent via `AppDependencies`
- All services created once at app launch
- Injected via SwiftUI environment
- Test-friendly with protocol abstractions

**Issues to Address:**

1. **Coordinator Responsibilities Too Broad**

**Current Problem:**
```swift
// AppModel.swift
@Observable
final class AppCoordinator: AppCoordinatorProtocol {
    // Navigation paths (✅ Good - coordinator's job)
    var homePath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    
    // Sync timer (❌ Bad - infrastructure concern)
    private var syncTimer: Timer?
    private let syncService: ContentSyncService
    
    func startBackgroundSync() { ... }
}
```

**Recommended Fix:**

```swift
// New file: SyncCoordinator.swift

/// Manages background sync operations independently of navigation
@MainActor
@Observable
final class SyncCoordinator {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    var syncInterval: TimeInterval = 60.0
    var isEnabled: Bool = true {
        didSet { isEnabled ? start() : stop() }
    }
    
    init(syncService: ContentSyncService) {
        self.syncService = syncService
        observeAppLifecycle()
        startIfNeeded()
    }
    
    private func startIfNeeded() {
        guard isEnabled else { return }
        
        // Check if there are pending operations before starting timer
        Task {
            let (pending, _) = try? await syncService.getQueueCounts()
            if pending > 0 {
                start()
            }
        }
    }
    
    private func start() {
        guard syncTimer == nil else { return }
        
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: syncInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSync()
            }
        }
        
        AppLogger.sync.info("Background sync started (interval: \(syncInterval)s)")
    }
    
    private func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        AppLogger.sync.info("Background sync stopped")
    }
    
    private func performSync() async {
        AppLogger.sync.debug("Performing background sync")
        await syncService.syncPending()
        
        // Stop timer if no more pending operations (battery optimization)
        if let (pending, _) = try? await syncService.getQueueCounts(), pending == 0 {
            stop()
        }
    }
    
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stop()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // Immediate sync on resume
                Task { await self?.performSync() }
                self?.startIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stop()
    }
}
```

```swift
// AppDependencies.swift (updated)

@Observable
@MainActor
final class AppDependencies {
    // ... existing properties ...
    
    /// Sync coordinator for background operations
    let syncCoordinator: SyncCoordinator
    
    init() {
        // ... existing initialization ...
        
        // Initialize sync coordinator separately
        self.syncCoordinator = SyncCoordinator(syncService: contentSyncService)
        
        AppLogger.dependencies.info("AppDependencies initialized successfully")
    }
}
```

```swift
// AppCoordinator.swift (simplified)

@MainActor
@Observable
final class AppCoordinator: AppCoordinatorProtocol {
    private let dependencies: AppDependencies
    
    // Individual navigation paths per tab
    var homePath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    var discoverPath: [AppRoute] = []
    var chartersPath: [AppRoute] = []
    var profilePath: [AppRoute] = []
    
    // Tab selection state
    var selectedTab: AppView.Tab = .home
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        // ✅ No longer manages sync - that's SyncCoordinator's job
    }
    
    // Pure navigation methods only...
    func navigateToCreateCharter() { ... }
    func viewCharter(_ id: UUID) { ... }
    // etc.
}
```

**Rationale:** Separates infrastructure (sync) from application (navigation) concerns. Enables independent testing, configuration, and lifecycle management.

---

2. **Hardcoded Placeholder UUID Antipattern**

**Current Problem:**
```swift
// Repeated 6+ times across LocalRepository.swift
creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
```

**Recommended Fix:**

```swift
// New file: Core/Models/UUID+Constants.swift

import Foundation

extension UUID {
    /// Placeholder UUID for single-user local content before multi-user support.
    ///
    /// Used as a temporary `creatorID` for library content created locally.
    /// When multi-user auth is fully implemented, this will be replaced with
    /// the authenticated user's actual UUID.
    ///
    /// - Warning: Do not use for any security-sensitive operations.
    static let localUserPlaceholder = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
```

```swift
// LocalRepository.swift (updated usage)

func createChecklist(_ checklist: Checklist) async throws {
    try await database.dbWriter.write { db in
        _ = try ChecklistRecord.saveChecklist(checklist, db: db)
        
        let metadata = LibraryModel(
            id: checklist.id,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: .localUserPlaceholder,  // ✅ Clear intent, documented
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt,
            syncStatus: checklist.syncStatus
        )
        _ = try LibraryModelRecord.saveMetadata(metadata, db: db)
    }
}
```

**Rationale:** Makes placeholder UUID a first-class named constant with documentation explaining its purpose and lifecycle. Easier to find and replace when implementing real multi-user support.

---

3. **Replace `fatalError` with Error Handling**

**Current Problem:**
```swift
// LibraryStore.swift line 161
func fetchFullContent<T>(_ id: UUID) async throws -> T? {
    // ... type checking logic ...
    } else {
        fatalError("Unsupported content type for caching")
    }
}
```

**Recommended Fix:**

```swift
// LibraryError.swift (add new case)

enum LibraryError: LocalizedError {
    case notFound(UUID)
    case invalidContentData(String)
    case unsupportedContentType(String)  // ✅ New case
    
    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Content not found: \(id.uuidString)"
        case .invalidContentData(let reason):
            return "Invalid content data: \(reason)"
        case .unsupportedContentType(let typeName):
            return "Content type '\(typeName)' is not supported for caching"
        }
    }
}
```

```swift
// LibraryStore.swift (updated)

func fetchFullContent<T>(_ id: UUID) async throws -> T? {
    // Check cache first based on content type
    if T.self == Checklist.self {
        if let cached = checklistCache.get(id) as? T {
            return cached
        }
        // Fetch and cache...
    } else if T.self == PracticeGuide.self {
        if let cached = guideCache.get(id) as? T {
            return cached
        }
        // Fetch and cache...
    } else {
        // ✅ Throw instead of crash
        let typeName = String(describing: T.self)
        AppLogger.store.error("Attempted to fetch unsupported content type: \(typeName)")
        throw LibraryError.unsupportedContentType(typeName)
    }
    
    return content
}
```

**Rationale:** Enables graceful error handling in UI layer instead of crashing. View models can display error messages and recover.

---

### SOLID Compliance Review

| Principle | Current Status | Notes |
|-----------|---------------|-------|
| **Single Responsibility** | 🟡 Mostly Good | `AppCoordinator` violates (fixed above), large ViewModels need splitting |
| **Open/Closed** | ✅ Good | Protocol extensions allow behavior extension without modification |
| **Liskov Substitution** | ✅ Good | Protocol conformance is correct throughout |
| **Interface Segregation** | ✅ Good | Focused protocols (`AuthServiceProtocol`, `APIClientProtocol`) |
| **Dependency Inversion** | ✅ Excellent | All dependencies injected via protocols and `AppDependencies` |

---

## 3. Swift & SwiftUI Code Quality

### Modern Swift Usage

**Strengths:**
- ✅ Consistent use of `@Observable` macro (Swift 5.9+)
- ✅ Structured concurrency with `async/await` throughout
- ✅ `@MainActor` isolation for UI types
- ✅ `Sendable` conformance for data models
- ✅ Strong typing with minimal `Any` usage

**Issues to Address:**

### 1. Force Unwraps and Unsafe Casting

**Current Problem:**
```swift
// APIClient.swift line 341
switch httpResponse.statusCode {
case 200...299:
    if T.self == EmptyResponse.self {
        return EmptyResponse() as! T  // ❌ Force cast
    }
    return try decoder.decode(T.self, from: data)
```

**Recommended Fix:**

```swift
// APIClient.swift (updated)

private func request<T: Decodable, B: Encodable>(
    method: String,
    path: String,
    body: B
) async throws -> T {
    let url = baseURL.appendingPathComponent(path)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    
    let accessToken = try await authService.getAccessToken()
    urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    if !(body is EmptyBody) {
        urlRequest.httpBody = try encoder.encode(body)
    }
    
    let (data, response) = try await session.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }
    
    switch httpResponse.statusCode {
    case 200...299:
        // ✅ Use type-safe conditional cast
        guard let result = EmptyResponse() as? T else {
            // If T is not EmptyResponse, decode from data
            return try decoder.decode(T.self, from: data)
        }
        return result
        
    case 401:
        throw APIError.unauthorized
        
    // ... rest of error handling ...
    
    default:
        throw APIError.invalidResponse
    }
}
```

**Alternative Approach (More Explicit):**

```swift
// APIClient.swift (alternative using overloads)

/// Variant for requests that don't return data
private func performRequest<B: Encodable>(
    method: String,
    path: String,
    body: B
) async throws {
    // ... same logic but no return value ...
}

/// Variant for requests that return data
private func request<T: Decodable, B: Encodable>(
    method: String,
    path: String,
    body: B
) async throws -> T {
    // ... same logic, always decode T, no special case for EmptyResponse ...
}

// Usage becomes clearer:
func delete(_ path: String) async throws {
    try await performRequest(method: "DELETE", path: path, body: EmptyBody())
    // ✅ No return value needed, no casting issues
}

func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
    try await request(method: "POST", path: path, body: body)
    // ✅ Always returns decoded T, type-safe
}
```

**Rationale:** Eliminates potential runtime crashes from failed casts. Makes type requirements explicit.

---

### 2. Large View Decomposition

**Current Problem:**
`ProfileView.swift` is 664 lines with multiple responsibilities mixed together.

**Recommended Refactor:**

```swift
// ProfileView.swift (main file, simplified to ~100 lines)

@MainActor
struct ProfileView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ProfileViewModel
    
    init(viewModel: ProfileViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            let deps = AppDependencies()
            _viewModel = State(initialValue: ProfileViewModel(
                authService: deps.authService,
                authObserver: deps.authStateObserver
            ))
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                if viewModel.isSignedIn {
                    AuthenticatedProfileView(viewModel: viewModel)
                } else {
                    UnauthenticatedProfileView(viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.ProfileTab)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }
}
```

```swift
// ProfileView+Authenticated.swift (new file, ~200 lines)

extension ProfileView {
    @MainActor
    struct AuthenticatedProfileView: View {
        @Bindable var viewModel: ProfileViewModel
        
        var body: some View {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    if let user = viewModel.currentUser {
                        ProfileHeroSection(
                            user: user,
                            viewModel: viewModel
                        )
                        .sectionContainer()
                        
                        if viewModel.isEditingProfile {
                            ProfileEditForm(viewModel: viewModel)
                                .sectionContainer()
                        } else {
                            ProfileDisplaySection(user: user)
                                .sectionContainer()
                        }
                        
                        if let metrics = viewModel.contributionMetrics {
                            ProfileMetricsSection(metrics: metrics)
                        }
                        
                        AccountManagementSection(viewModel: viewModel)
                    }
                    
                    if viewModel.showErrorBanner, let error = viewModel.currentError {
                        ErrorBanner(
                            error: error,
                            onDismiss: { viewModel.clearError() },
                            onRetry: nil
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .task {
                if viewModel.isSignedIn {
                    // TODO: Load reputation metrics when Phase 2 backend is ready
                }
            }
        }
    }
}
```

```swift
// ProfileView+Unauthenticated.swift (new file, ~100 lines)

extension ProfileView {
    @MainActor
    struct UnauthenticatedProfileView: View {
        @Bindable var viewModel: ProfileViewModel
        
        var body: some View {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    Spacer()
                    
                    WelcomeSection()
                    
                    Spacer()
                    
                    SignInSection(viewModel: viewModel)
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private struct WelcomeSection: View {
        var body: some View {
            VStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text(L10n.Profile.welcomeTitle)
                        .font(DesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(L10n.Profile.welcomeSubtitle)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        }
    }
    
    private struct SignInSection: View {
        @Bindable var viewModel: ProfileViewModel
        
        var body: some View {
            VStack(spacing: DesignSystem.Spacing.md) {
                DesignSystem.SectionHeader(
                    L10n.Profile.getStartedTitle,
                    subtitle: L10n.Profile.getStartedSubtitle
                )
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.email, .fullName]
                        },
                        onCompletion: { result in
                            Task {
                                await viewModel.handleAppleSignIn(result: result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(DesignSystem.Spacing.md)
                    .disabled(viewModel.isLoading)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .accessibilityIdentifier("sign_in_apple_button")
                    .accessibilityLabel("Sign in with Apple")
                    .accessibilityHint("Double tap to sign in using your Apple ID")
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                            .accessibilityLabel("Signing in")
                    }
                    
                    if viewModel.showErrorBanner, let error = viewModel.currentError {
                        ErrorBanner(
                            error: error,
                            onDismiss: { viewModel.clearError() },
                            onRetry: nil
                        )
                    }
                }
            }
            .sectionContainer()
        }
    }
}
```

```swift
// ProfileComponents/ProfileEditForm.swift (new file, ~150 lines)

import SwiftUI

@MainActor
struct ProfileEditForm: View {
    @Bindable var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            DesignSystem.SectionHeader(
                L10n.Profile.editProfileTitle,
                subtitle: L10n.Profile.editProfileSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Username field
                DesignSystem.FormKit.TextField(
                    label: L10n.Profile.Form.username,
                    text: $viewModel.editedUsername,
                    placeholder: L10n.Profile.Form.usernamePlaceholder
                )
                .accessibilityLabel("Display name")
                .accessibilityHint("Enter your display name")
                
                // Bio field
                DesignSystem.FormKit.TextEditor(
                    label: L10n.Profile.Bio.title,
                    text: $viewModel.editedBio,
                    placeholder: L10n.Profile.Bio.placeholder,
                    minHeight: 100
                )
                .accessibilityLabel("Bio")
                .accessibilityHint("Enter a brief description about yourself")
                
                // Location field
                DesignSystem.FormKit.TextField(
                    label: L10n.Profile.Form.location,
                    text: $viewModel.editedLocation,
                    placeholder: L10n.Profile.Form.locationPlaceholder
                )
                .accessibilityLabel("Location")
                .accessibilityHint("Enter your location")
                
                // Nationality field
                DesignSystem.FormKit.TextField(
                    label: L10n.Profile.Form.nationality,
                    text: $viewModel.editedNationality,
                    placeholder: L10n.Profile.Form.nationalityPlaceholder
                )
                .accessibilityLabel("Nationality")
                .accessibilityHint("Enter your nationality")
            }
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(L10n.Common.cancel) {
                    viewModel.cancelEditingProfile()
                }
                .buttonStyle(DesignSystem.ButtonStyle.secondary)
                .accessibilityHint("Discard changes and return to profile view")
                
                Button(L10n.Common.save) {
                    Task { await viewModel.saveProfile() }
                }
                .buttonStyle(DesignSystem.ButtonStyle.primary)
                .disabled(viewModel.isSavingProfile)
                .accessibilityLabel("Save profile")
                .accessibilityHint("Save changes to your profile")
            }
            
            if viewModel.isSavingProfile {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
                    .accessibilityLabel("Saving profile")
            }
        }
    }
}
```

```swift
// ProfileComponents/AccountManagementSection.swift (new file, ~100 lines)

import SwiftUI

@MainActor
struct AccountManagementSection: View {
    @Bindable var viewModel: ProfileViewModel
    let user: UserInfo
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Profile.accountTitle,
                subtitle: L10n.Profile.accountSubtitle
            )
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Danger zone: Delete account
                AccountActionButton(
                    icon: "trash.fill",
                    label: L10n.Profile.deleteAccount,
                    iconColor: DesignSystem.Colors.error,
                    action: { }  // TODO: Delete account flow
                )
                .accessibilityHint("Opens account deletion confirmation")
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)
                
                // Sign out button
                Button(action: {
                    Task { await viewModel.logout() }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(DesignSystem.Colors.error)
                        Text(L10n.Profile.signOut)
                            .foregroundColor(DesignSystem.Colors.error)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Sign out")
                .accessibilityHint("Sign out of your account")
            }
        }
        .sectionContainer()
    }
}

private struct AccountActionButton: View {
    let icon: String
    let label: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                Text(label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 14))
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Spacing.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

**Rationale:** Breaking large files into focused, single-responsibility components improves:
- **Readability:** Each file is ~100-200 lines, scannable in a single screen
- **Testability:** Can test `ProfileEditForm` in isolation with mock ViewModel
- **Reusability:** Components like `AccountActionButton` can be reused elsewhere
- **Performance:** SwiftUI can optimize smaller view trees better

---

### 3. Complex Binding Simplification

**Current Problem:**
```swift
// AppView.swift line 16
TabView(selection: Binding<Tab>(
    get: { coordinator.selectedTab },
    set: { coordinator.selectedTab = $0 }
)) {
```

**Recommended Fix:**

```swift
// AppCoordinator.swift (updated)

@MainActor
@Observable
final class AppCoordinator: AppCoordinatorProtocol {
    // ... existing properties ...
    
    /// Bindable wrapper for selectedTab
    /// Simplifies usage in TabView without manual Binding creation
    var selectedTabBinding: Binding<AppView.Tab> {
        Binding(
            get: { self.selectedTab },
            set: { self.selectedTab = $0 }
        )
    }
}
```

```swift
// AppView.swift (updated)

var body: some View {
    TabView(selection: coordinator.selectedTabBinding) {  // ✅ Cleaner
        // Home Tab
        NavigationStack(path: $coordinator.homePath) {  // ✅ Direct binding works
            HomeView(
                viewModel: HomeViewModel(
                    coordinator: coordinator,
                    charterStore: dependencies.charterStore,
                    libraryStore: dependencies.libraryStore
                )
            )
            // ...
```

**Alternative (if using `@Bindable`):**

```swift
// AppView.swift (alternative with @Bindable)

struct AppView: View {
    @Environment(\.appDependencies) private var dependencies
    @Bindable var coordinator: AppCoordinator  // ✅ Makes coordinator bindable
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {  // ✅ Even cleaner with $
            NavigationStack(path: $coordinator.homePath) {
                HomeView(...)
            }
            // ...
```

**Rationale:** Reduces boilerplate and visual noise. SwiftUI's `@Bindable` is designed for this exact pattern.

---

### 4. Optional Handling Improvements

**Current Problem:**
```swift
// AuthService.swift lines 222-235
var user = tokenResponse.user
if let imageUrl = user.profileImageUrl, !imageUrl.hasPrefix("http") {
    user = UserInfo(
        id: user.id,
        email: user.email,
        username: user.username,
        createdAt: user.createdAt,
        profileImageUrl: "https://\(imageUrl)",
        profileImageThumbnailUrl: user.profileImageThumbnailUrl?.hasPrefix("http") == false ? "https://\(user.profileImageThumbnailUrl!)" : user.profileImageThumbnailUrl,
        // ❌ Force unwrap in complex ternary
        // ❌ Repeated in 3 places (signIn, refresh, loadUser)
        bio: user.bio,
        location: user.location,
        nationality: user.nationality,
        profileVisibility: user.profileVisibility
    )
}
```

**Recommended Fix:**

```swift
// AuthService.swift (add helper extension)

private extension UserInfo {
    /// Returns a new UserInfo with image URLs normalized to include HTTPS protocol
    func withNormalizedImageURLs() -> UserInfo {
        let normalizedImageUrl = profileImageUrl.map { url in
            url.hasPrefix("http") ? url : "https://\(url)"
        }
        
        let normalizedThumbnailUrl = profileImageThumbnailUrl.map { url in
            url.hasPrefix("http") ? url : "https://\(url)"
        }
        
        // Only create new instance if URLs actually changed
        guard normalizedImageUrl != profileImageUrl || 
              normalizedThumbnailUrl != profileImageThumbnailUrl else {
            return self
        }
        
        return UserInfo(
            id: id,
            email: email,
            username: username,
            createdAt: createdAt,
            profileImageUrl: normalizedImageUrl,
            profileImageThumbnailUrl: normalizedThumbnailUrl,
            bio: bio,
            location: location,
            nationality: nationality,
            profileVisibility: profileVisibility
        )
    }
}
```

```swift
// AuthService.swift (updated usage)

private func signInWithBackend(identityToken: String, userInfo: [String: AnyCodable]?) async throws {
    // ... request logic ...
    
    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    
    keychain.saveAccessToken(tokenResponse.accessToken)
    keychain.saveRefreshToken(tokenResponse.refreshToken)
    AppLogger.auth.info("Tokens stored securely in keychain")
    
    // ✅ Clean, reusable transformation
    currentUser = tokenResponse.user.withNormalizedImageURLs()
    isAuthenticated = true
    
    AppLogger.auth.info("Sign-in successful for user: \(tokenResponse.user.email)")
}

func refreshAccessToken() async throws {
    // ... request logic ...
    
    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    
    keychain.saveAccessToken(tokenResponse.accessToken)
    keychain.saveRefreshToken(tokenResponse.refreshToken)
    AppLogger.auth.info("Tokens refreshed successfully")
    
    // ✅ Same helper, no duplication
    currentUser = tokenResponse.user.withNormalizedImageURLs()
}

func loadCurrentUser() async {
    // ... request logic ...
    
    let user = try JSONDecoder().decode(UserInfo.self, from: data)
    
    // ✅ Consistent normalization
    currentUser = user.withNormalizedImageURLs()
    AppLogger.auth.info("Current user loaded: \(currentUser?.email ?? "unknown")")
}
```

**Rationale:** Eliminates duplication, removes force unwraps, makes URL normalization explicit and testable.

---

## 4. Performance Optimizations

### 1. Memoize Expensive Computed Properties

**Current Problem:**
```swift
// HomeViewModel.swift lines 44-57
var activeCharter: CharterModel? {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    return charterStore.charters  // ❌ Filters ALL charters on EVERY access
        .filter { charter in
            let start = calendar.startOfDay(for: charter.startDate)
            let end = calendar.startOfDay(for: charter.endDate)
            return start <= today && end >= today
        }
        .sorted { $0.startDate > $1.startDate }
        .first
}
```

If `HomeView` body is recomputed 10 times (common during animations), this filters the entire charter array 10 times unnecessarily.

**Recommended Fix:**

```swift
// HomeViewModel.swift (updated)

@MainActor
@Observable
final class HomeViewModel: ErrorHandling {
    // ... existing properties ...
    
    // ✅ Cached result
    @ObservationIgnored
    private var cachedActiveCharter: CharterModel?
    
    @ObservationIgnored
    private var cachedCharterCount: Int = 0
    
    /// The currently active charter (latest with today in date range)
    /// Cached to avoid recomputing on every access
    var activeCharter: CharterModel? {
        // Invalidate cache if charter count changed
        if charterStore.charters.count != cachedCharterCount {
            cachedCharterCount = charterStore.charters.count
            cachedActiveCharter = computeActiveCharter()
        }
        
        return cachedActiveCharter
    }
    
    private func computeActiveCharter() -> CharterModel? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return charterStore.charters
            .filter { charter in
                let start = calendar.startOfDay(for: charter.startDate)
                let end = calendar.startOfDay(for: charter.endDate)
                return start <= today && end >= today
            }
            .sorted { $0.startDate > $1.startDate }
            .first
    }
    
    /// Call this when charters are updated to invalidate cache
    func invalidateActiveCharterCache() {
        cachedCharterCount = -1  // Force recomputation
    }
}
```

**Alternative (Simpler with Date Trigger):**

```swift
// HomeViewModel.swift (alternative approach)

@MainActor
@Observable
final class HomeViewModel: ErrorHandling {
    // ... existing properties ...
    
    // ✅ Store computed result directly
    private(set) var activeCharter: CharterModel?
    
    private var lastRefreshDate: Date?
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if charterStore.charters.isEmpty {
                try await charterStore.loadCharters()
            }
            
            if libraryStore.library.isEmpty {
                await libraryStore.loadLibrary()
            }
            
            // ✅ Compute once during refresh
            updateActiveCharter()
            lastRefreshDate = Date()
            
            AppLogger.view.info("Active charter: \(activeCharter?.name ?? "none")")
        } catch {
            handleError(error)
        }
    }
    
    private func updateActiveCharter() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        activeCharter = charterStore.charters
            .filter { charter in
                let start = calendar.startOfDay(for: charter.startDate)
                let end = calendar.startOfDay(for: charter.endDate)
                return start <= today && end >= today
            }
            .sorted { $0.startDate > $1.startDate }
            .first
    }
}
```

**Rationale:** Reduces computation from O(n) per access to O(1) for cached results. Significant performance gain when view redraws frequently.

---

### 2. Incremental Library Updates

**Current Problem:**
```swift
// LibraryListViewModel.swift line 309
func confirmPublish() async {
    // ...
    do {
        let syncSummary = try await visibilityService.publishContent(item)
        pendingPublishItem = nil
        activeModal = nil
        await loadLibrary()  // ❌ Reloads ALL items from database
        // ...
```

**Recommended Fix:**

```swift
// LibraryListViewModel.swift (updated)

func confirmPublish() async {
    guard let item = pendingPublishItem else {
        AppLogger.view.warning("confirmPublish called but no pending item")
        return
    }
    
    AppLogger.view.info("Confirming publish for item: \(item.id)")
    clearError()
    
    operationsInProgress.insert(item.id)
    defer { operationsInProgress.remove(item.id) }
    
    do {
        let syncSummary = try await visibilityService.publishContent(item)
        pendingPublishItem = nil
        activeModal = nil
        
        // ✅ Incremental update: only reload the changed item
        if let updatedItem = try? await libraryStore.fetchLibraryItem(item.id) {
            libraryStore.updateLocalCache(with: updatedItem)
        } else {
            // Fallback to full reload only if item fetch fails
            await loadLibrary()
        }
        
        AppLogger.view.info("Publish confirmed and completed for item: \(item.id) - \(syncSummary.succeeded) succeeded, \(syncSummary.failed) failed")
    } catch {
        AppLogger.view.error("Publish failed", error: error)
        publishError = error
        // On error, full reload to ensure consistency
        await loadLibrary()
    }
}
```

```swift
// LibraryStore.swift (add helper method)

/// Update a single item in the in-memory library cache
/// Use this for incremental updates to avoid full reloads
func updateLocalCache(with item: LibraryModel) {
    if let index = library.firstIndex(where: { $0.id == item.id }) {
        library[index] = item
        AppLogger.store.debug("Updated library cache for item: \(item.id)")
    } else {
        library.append(item)
        AppLogger.store.debug("Added item to library cache: \(item.id)")
    }
}
```

**Rationale:** Reduces database I/O from O(n) full reload to O(1) single item fetch. Improves responsiveness after publish/unpublish actions.

---

### 3. Smart Background Sync

**Current Problem:**
```swift
// AppModel.swift lines 69-76
private func startBackgroundSync() {
    // ❌ Always runs every 60s, even if no pending operations
    syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.syncService.syncPending()
        }
    }
}
```

**Recommended Fix:**

```swift
// SyncCoordinator.swift (see Architecture section for full implementation)

@MainActor
@Observable
final class SyncCoordinator {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    
    // ✅ Adaptive intervals based on state
    private let activeInterval: TimeInterval = 60.0
    private let idleInterval: TimeInterval = 300.0  // 5 minutes when idle
    private var currentInterval: TimeInterval
    
    // ✅ Track consecutive empty syncs
    private var consecutiveEmptySyncs: Int = 0
    private let maxEmptySyncsBeforeIdle = 3
    
    init(syncService: ContentSyncService) {
        self.syncService = syncService
        self.currentInterval = activeInterval
        observeAppLifecycle()
        start()
    }
    
    private func start() {
        guard syncTimer == nil else { return }
        
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: currentInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSync()
            }
        }
        
        AppLogger.sync.info("Background sync started (interval: \(currentInterval)s)")
    }
    
    private func restartWithNewInterval(_ interval: TimeInterval) {
        guard interval != currentInterval else { return }
        
        currentInterval = interval
        syncTimer?.invalidate()
        syncTimer = nil
        start()
        
        AppLogger.sync.info("Background sync interval changed to \(interval)s")
    }
    
    private func performSync() async {
        AppLogger.sync.debug("Performing background sync")
        
        // ✅ Check queue before syncing
        guard let (pending, _) = try? await syncService.getQueueCounts() else {
            return
        }
        
        if pending == 0 {
            consecutiveEmptySyncs += 1
            AppLogger.sync.debug("No pending operations (consecutive: \(consecutiveEmptySyncs))")
            
            // ✅ Slow down after multiple empty syncs (battery optimization)
            if consecutiveEmptySyncs >= maxEmptySyncsBeforeIdle {
                restartWithNewInterval(idleInterval)
            }
            return
        }
        
        // ✅ Reset counter when we have work
        if consecutiveEmptySyncs > 0 {
            consecutiveEmptySyncs = 0
            restartWithNewInterval(activeInterval)
        }
        
        // Perform actual sync
        await syncService.syncPending()
        
        // ✅ Check again after sync - stop timer if queue is now empty
        if let (pendingAfter, _) = try? await syncService.getQueueCounts(), pendingAfter == 0 {
            AppLogger.sync.info("Sync queue empty after sync, slowing down timer")
            restartWithNewInterval(idleInterval)
        }
    }
}
```

**Rationale:**
- Reduces unnecessary sync checks when idle (battery optimization)
- Adapts sync frequency based on workload
- Still responsive when operations are queued

---

## 5. UX, UI, and Accessibility

### Current Strengths

✅ **Design System**: Well-structured with consistent colors, typography, spacing  
✅ **Visual Hierarchy**: Clear distinction between primary and secondary actions  
✅ **Feedback**: Loading states, error banners, and success indicators present  
✅ **Accessibility Labels**: Many buttons and interactive elements have `.accessibilityLabel`

### Issues to Address

#### 1. Incomplete Accessibility Coverage

**Current Problem:**
Many interactive elements lack `.accessibilityHint` and `.accessibilityValue`, making VoiceOver navigation less informative.

**Examples:**

```swift
// HomeView.swift line 106
.onTapGesture {
    viewModel.onActiveCharterTapped(charter)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Active charter")
.accessibilityValue(charter.name)
// ❌ Missing hint about what happens when tapped
```

**Recommended Fix:**

```swift
// HomeView.swift (updated)

private func activeCharterCard(charter: CharterModel) -> some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
        Text(L10n.homeActiveCharterTitle)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(.white.opacity(0.85))
        
        Text(charter.name)
            .font(DesignSystem.Typography.title)
            .foregroundColor(.white)
        
        if let location = charter.location, !location.isEmpty {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "mappin.and.ellipse")
                Text(location)
            }
            .font(DesignSystem.Typography.caption)
            .foregroundColor(.white.opacity(0.9))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignSystem.Spacing.cardPadding)
    .background(DesignSystem.Gradients.ocean)
    .cornerRadius(DesignSystem.Spacing.cardCornerRadiusLarge)
    .shadow(color: DesignSystem.Colors.shadowStrong, radius: 12, y: 6)
    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    .onTapGesture {
        viewModel.onActiveCharterTapped(charter)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Active charter: \(charter.name)")
    .accessibilityValue(charter.location ?? "No location specified")
    .accessibilityHint("Double tap to view charter details and execute checklists")  // ✅ Added
    .accessibilityAddTraits(.isButton)  // ✅ Make it clear this is interactive
}
```

```swift
// LibraryItemRow (new accessibility example)

struct LibraryItemRow: View {
    let item: LibraryModel
    let onTap: () -> Void
    let isOperationInProgress: Bool
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                Image(systemName: item.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                    
                    if let description = item.description {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Sync status indicator
                if item.syncStatus != .synced {
                    SyncStatusBadge(status: item.syncStatus)
                }
                
                if isOperationInProgress {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                }
            }
        }
        .buttonStyle(.plain)
        // ✅ Comprehensive accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.displayName): \(item.title)")
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(isOperationInProgress ? .updatesFrequently : [])
    }
    
    // ✅ Computed accessibility strings
    private var accessibilityValueText: String {
        var components: [String] = []
        
        if let description = item.description {
            components.append(description)
        }
        
        switch item.syncStatus {
        case .synced:
            if item.visibility == .public {
                components.append("Published")
            }
        case .pending, .queued:
            components.append("Sync pending")
        case .syncing:
            components.append("Syncing")
        case .failed:
            components.append("Sync failed")
        }
        
        if isOperationInProgress {
            components.append("Operation in progress")
        }
        
        return components.joined(separator: ", ")
    }
    
    private var accessibilityHintText: String {
        if isOperationInProgress {
            return "Please wait for operation to complete"
        }
        
        switch item.type {
        case .checklist:
            return "Double tap to view or edit checklist"
        case .practiceGuide:
            return "Double tap to read or edit guide"
        case .flashcardDeck:
            return "Double tap to practice flashcards"
        }
    }
}
```

**Rationale:** VoiceOver users get complete information about element state, purpose, and what will happen on interaction.

---

#### 2. Dynamic Type Support

**Current Issue:** Some custom fonts may not scale properly with Dynamic Type.

**Recommended Enhancement:**

```swift
// DesignSystemTypography.swift (updated)

extension DesignSystem {
    struct Typography {
        // ✅ Use .scaledMetric for automatic Dynamic Type scaling
        @ScaledMetric(relativeTo: .largeTitle) private static var largeTitleSize: CGFloat = 34
        @ScaledMetric(relativeTo: .title) private static var titleSize: CGFloat = 28
        @ScaledMetric(relativeTo: .title2) private static var title2Size: CGFloat = 22
        @ScaledMetric(relativeTo: .headline) private static var headlineSize: CGFloat = 17
        @ScaledMetric(relativeTo: .body) private static var bodySize: CGFloat = 17
        @ScaledMetric(relativeTo: .callout) private static var calloutSize: CGFloat = 16
        @ScaledMetric(relativeTo: .caption) private static var captionSize: CGFloat = 12
        
        static var largeTitle: Font {
            .system(size: largeTitleSize, weight: .bold, design: .default)
        }
        
        static var title: Font {
            .system(size: titleSize, weight: .semibold, design: .default)
        }
        
        static var title2: Font {
            .system(size: title2Size, weight: .semibold, design: .default)
        }
        
        static var headline: Font {
            .system(size: headlineSize, weight: .semibold, design: .default)
        }
        
        static var body: Font {
            .system(size: bodySize, weight: .regular, design: .default)
        }
        
        static var callout: Font {
            .system(size: calloutSize, weight: .regular, design: .default)
        }
        
        static var caption: Font {
            .system(size: captionSize, weight: .regular, design: .default)
        }
    }
}
```

**Usage stays the same, but now automatically scales:**

```swift
Text(charter.name)
    .font(DesignSystem.Typography.title)  // ✅ Now scales with Dynamic Type
```

---

#### 3. Granular Loading States

**Current Problem:**
```swift
// LibraryListViewModel.swift
var isLoading = false  // ❌ Single flag for entire library

// In view:
if viewModel.isLoading {
    ProgressView()  // Shows for entire screen
}
```

**Recommended Fix:**

```swift
// LibraryListViewModel.swift (updated)

@MainActor
@Observable
final class LibraryListViewModel: ErrorHandling {
    // ... existing properties ...
    
    // ✅ Granular loading states
    var isLoadingLibrary = false
    var operationsInProgress: Set<UUID> = []  // ✅ Already has this!
    
    func isOperationInProgress(_ itemID: UUID) -> Bool {
        operationsInProgress.contains(itemID)
    }
    
    func loadLibrary() async {
        guard !isLoadingLibrary else { return }
        
        isLoadingLibrary = true  // ✅ Specific to library loading
        defer { isLoadingLibrary = false }
        
        await libraryStore.loadLibrary()
        updateFilteredItems()
        
        AppLogger.view.info("Loaded \(library.count) library items")
    }
    
    func confirmPublish() async {
        guard let item = pendingPublishItem else { return }
        
        operationsInProgress.insert(item.id)  // ✅ Per-item loading
        defer { operationsInProgress.remove(item.id) }
        
        do {
            let syncSummary = try await visibilityService.publishContent(item)
            // ...
        } catch {
            // ...
        }
    }
}
```

```swift
// LibraryListView.swift (updated)

var body: some View {
    ZStack {
        // Main content
        if viewModel.isEmpty && !viewModel.isLoadingLibrary {
            EmptyLibraryView()
        } else {
            libraryList
        }
        
        // ✅ Full-screen loading only for initial load
        if viewModel.isLoadingLibrary && viewModel.isEmpty {
            ProgressView("Loading library...")
                .padding()
        }
    }
}

private var libraryList: some View {
    List {
        ForEach(viewModel.filteredItems) { item in
            LibraryItemRow(
                item: item,
                onTap: { viewModel.onReadChecklistTapped(item.id) },
                isOperationInProgress: viewModel.isOperationInProgress(item.id)
                // ✅ Per-item loading indicator
            )
        }
    }
    .overlay {
        // ✅ Subtle loading indicator during refresh (library not empty)
        if viewModel.isLoadingLibrary && !viewModel.isEmpty {
            VStack {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}
```

**Rationale:** Users can continue interacting with the UI while individual operations are in progress. Better perceived performance.

---

#### 4. Empty State Improvements

**Current Issue:** Empty states could be more engaging and actionable.

**Recommended Enhancement:**

```swift
// LibraryListView+EmptyState.swift (new file)

extension LibraryListView {
    struct EmptyLibraryView: View {
        let filter: ContentFilter
        let onCreateChecklist: () -> Void
        let onCreateGuide: () -> Void
        let onCreateDeck: () -> Void
        
        var body: some View {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                
                // Illustration
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 64))
                    .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))
                    .padding(.bottom, DesignSystem.Spacing.lg)
                
                // Message
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(emptyStateTitle)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(emptyStateMessage)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                
                // Actions
                VStack(spacing: DesignSystem.Spacing.md) {
                    createActionButtons
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Spacer()
                Spacer()
            }
        }
        
        // ✅ Dynamic content based on filter
        private var emptyStateIcon: String {
            switch filter {
            case .all: return "tray"
            case .checklists: return "checklist"
            case .guides: return "book.closed"
            case .decks: return "rectangle.stack"
            }
        }
        
        private var emptyStateTitle: String {
            switch filter {
            case .all: return "Your Library is Empty"
            case .checklists: return "No Checklists Yet"
            case .guides: return "No Practice Guides Yet"
            case .decks: return "No Flashcard Decks Yet"
            }
        }
        
        private var emptyStateMessage: String {
            switch filter {
            case .all:
                return "Create your first checklist, practice guide, or flashcard deck to get started with anyfleet."
            case .checklists:
                return "Checklists help you track important tasks for your charter. Create one to get started."
            case .guides:
                return "Practice guides contain knowledge and procedures. Create one to document your expertise."
            case .decks:
                return "Flashcard decks help you memorize important information. Create one to start learning."
            }
        }
        
        @ViewBuilder
        private var createActionButtons: some View {
            switch filter {
            case .all:
                // Show all create options
                Button(action: onCreateChecklist) {
                    createButtonLabel(icon: "checklist", title: "Create Checklist")
                }
                .buttonStyle(DesignSystem.ButtonStyle.secondary)
                
                Button(action: onCreateGuide) {
                    createButtonLabel(icon: "book", title: "Create Guide")
                }
                .buttonStyle(DesignSystem.ButtonStyle.secondary)
                
                Button(action: onCreateDeck) {
                    createButtonLabel(icon: "rectangle.stack", title: "Create Deck")
                }
                .buttonStyle(DesignSystem.ButtonStyle.secondary)
                
            case .checklists:
                Button(action: onCreateChecklist) {
                    createButtonLabel(icon: "checklist", title: "Create Your First Checklist")
                }
                .buttonStyle(DesignSystem.ButtonStyle.primary)
                
            case .guides:
                Button(action: onCreateGuide) {
                    createButtonLabel(icon: "book", title: "Create Your First Guide")
                }
                .buttonStyle(DesignSystem.ButtonStyle.primary)
                
            case .decks:
                Button(action: onCreateDeck) {
                    createButtonLabel(icon: "rectangle.stack", title: "Create Your First Deck")
                }
                .buttonStyle(DesignSystem.ButtonStyle.primary)
            }
        }
        
        private func createButtonLabel(icon: String, title: String) -> some View {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
        }
    }
}
```

**Rationale:** Engaging empty states guide users to their next action, improving onboarding and discovery.

---

## 6. Tests, Reliability, and Tooling

### Current Test Coverage

✅ **Excellent coverage across all layers:**
- Unit tests for ViewModels (`HomeViewModelTests`, `CharterListViewModelTests`, etc.)
- Integration tests for repositories (`LocalRepositoryIntegrationTests`)
- Service tests (`AuthServiceTests`, `APIClientTests`, `ContentSyncServiceIntegrationTests`)
- UI tests for critical flows (`ProfileViewUITests`, `AuthorModalUITests`)

### Recommendations

#### 1. Add Focused Test Cases

**High-Value Test Cases to Add:**

```swift
// CharterStoreTests.swift (add test)

@Test("Creating charter with dates spanning multiple months")
func testCreateCharterAcrossMonths() async throws {
    let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 28))!
    let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 5))!
    
    let charter = try await store.createCharter(
        name: "February Crossing",
        boatName: "Sea Sprite",
        location: "Mediterranean",
        startDate: startDate,
        endDate: endDate
    )
    
    #expect(charter.startDate == startDate)
    #expect(charter.endDate == endDate)
    #expect(store.charters.count == 1)
}

@Test("Active charter calculation at date boundaries")
func testActiveCharterAtMidnight() async throws {
    // Create charter ending today
    let today = Calendar.current.startOfDay(for: Date())
    
    let charter = try await store.createCharter(
        name: "Ending Today",
        boatName: "Twilight",
        location: "Harbor",
        startDate: today.addingTimeInterval(-7 * 24 * 3600), // 7 days ago
        endDate: today
    )
    
    // Should still be active until end of day
    let homeVM = HomeViewModel(
        coordinator: coordinator,
        charterStore: store,
        libraryStore: libraryStore
    )
    
    #expect(homeVM.activeCharter?.id == charter.id)
}
```

```swift
// LibraryStoreTests.swift (add test)

@Test("Publishing content updates publicID and syncStatus")
func testPublishContentUpdatesMetadata() async throws {
    // Create checklist
    let checklist = Checklist(
        id: UUID(),
        title: "Test Checklist",
        sections: []
    )
    try await store.createChecklist(checklist)
    
    // Publish it
    let item = try await store.fetchLibraryItem(checklist.id)
    #expect(item != nil)
    
    var published = item!
    published.visibility = .public
    published.publicID = "test-checklist-123"
    published.syncStatus = .synced
    
    try await store.updateLibraryMetadata(published)
    
    // Verify updates persisted
    let updated = try await store.fetchLibraryItem(checklist.id)
    #expect(updated?.visibility == .public)
    #expect(updated?.publicID == "test-checklist-123")
    #expect(updated?.syncStatus == .synced)
}

@Test("Cache invalidation after content update")
func testCacheInvalidationOnUpdate() async throws {
    // Create and cache checklist
    let original = Checklist(id: UUID(), title: "Original", sections: [])
    try await store.createChecklist(original)
    
    // Fetch to populate cache
    let cached1: Checklist? = try await store.fetchFullContent(original.id)
    #expect(cached1?.title == "Original")
    
    // Update checklist
    var updated = original
    updated.title = "Updated"
    try await store.saveChecklist(updated)
    
    // Fetch again - should get updated version from cache
    let cached2: Checklist? = try await store.fetchFullContent(original.id)
    #expect(cached2?.title == "Updated")
}
```

```swift
// SyncCoordinatorTests.swift (new file)

import Testing
@testable import anyfleet

@MainActor
struct SyncCoordinatorTests {
    var mockSyncService: MockSyncService!
    var coordinator: SyncCoordinator!
    
    init() async throws {
        mockSyncService = MockSyncService()
        coordinator = SyncCoordinator(syncService: mockSyncService)
        coordinator.isEnabled = false  // Disable auto-start for tests
    }
    
    @Test("Sync coordinator starts timer when enabled")
    func testStartTimer() async throws {
        coordinator.syncInterval = 1.0  // Short interval for testing
        coordinator.isEnabled = true
        
        try await Task.sleep(for: .seconds(0.5))
        #expect(mockSyncService.syncCallCount == 0)
        
        try await Task.sleep(for: .seconds(0.6))
        #expect(mockSyncService.syncCallCount == 1)
    }
    
    @Test("Sync coordinator stops timer when queue is empty")
    func testStopsWhenQueueEmpty() async throws {
        mockSyncService.pendingCount = 5
        
        coordinator.syncInterval = 0.5
        coordinator.isEnabled = true
        
        // First sync
        try await Task.sleep(for: .seconds(0.6))
        #expect(mockSyncService.syncCallCount == 1)
        
        // Queue becomes empty
        mockSyncService.pendingCount = 0
        
        // Second sync should detect empty queue and stop
        try await Task.sleep(for: .seconds(0.6))
        #expect(mockSyncService.syncCallCount == 2)
        
        // Timer should be stopped, no more syncs
        try await Task.sleep(for: .seconds(1.0))
        #expect(mockSyncService.syncCallCount == 2)
    }
    
    @Test("Sync coordinator pauses on app background")
    func testPausesOnBackground() async throws {
        coordinator.isEnabled = true
        
        // Simulate app going to background
        NotificationCenter.default.post(
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        try await Task.sleep(for: .seconds(0.1))
        
        // Timer should be stopped
        let initialCallCount = mockSyncService.syncCallCount
        try await Task.sleep(for: .seconds(1.0))
        #expect(mockSyncService.syncCallCount == initialCallCount)
    }
}
```

#### 2. Improved Error Handling Tests

```swift
// AuthServiceTests.swift (add test)

@Test("Token refresh failure triggers logout")
func testRefreshFailureTrigersLogout() async throws {
    // Set up service with expired token
    let service = AuthService(baseURL: "http://localhost:8000/api/v1")
    
    // Manually set authenticated state (simulating expired session)
    service.isAuthenticated = true
    
    // Attempt to refresh with invalid token (mock server returns 401)
    do {
        try await service.refreshAccessToken()
        #fail("Expected refresh to throw unauthorized error")
    } catch AuthError.unauthorized {
        // Expected
    }
    
    // Service should have logged out
    #expect(service.isAuthenticated == false)
    #expect(service.currentUser == nil)
}

@Test("Network errors are properly propagated")
func testNetworkErrorPropagation() async throws {
    let service = AuthService(baseURL: "http://invalid-host-12345")
    
    do {
        try await service.handleAppleSignIn(
            result: .success(mockAppleIDAuthorization)
        )
        #fail("Expected network error")
    } catch {
        // Should be a network-related error (not generic)
        #expect(error is URLError)
    }
}
```

#### 3. Performance Tests

```swift
// PerformanceTests.swift (new file)

import Testing
@testable import anyfleet

@MainActor
struct PerformanceTests {
    
    @Test("Library store handles 1000 items efficiently")
    func testLargeLibraryPerformance() async throws {
        let dependencies = try AppDependencies.makeForTesting()
        let store = dependencies.libraryStore
        
        // Create 1000 checklists
        let start = Date()
        
        for i in 0..<1000 {
            let checklist = Checklist(
                id: UUID(),
                title: "Checklist \(i)",
                sections: []
            )
            try await store.createChecklist(checklist)
        }
        
        let creationTime = Date().timeIntervalSince(start)
        print("Created 1000 checklists in \(creationTime)s")
        
        // Load library
        let loadStart = Date()
        await store.loadLibrary()
        let loadTime = Date().timeIntervalSince(loadStart)
        
        print("Loaded 1000 items in \(loadTime)s")
        
        // Assertions
        #expect(store.library.count == 1000)
        #expect(creationTime < 10.0)  // Should complete in < 10s
        #expect(loadTime < 1.0)  // Should load in < 1s
    }
    
    @Test("Charter active charter calculation is fast")
    func testActiveCharterPerformance() async throws {
        let dependencies = try AppDependencies.makeForTesting()
        let charterStore = dependencies.charterStore
        let homeVM = HomeViewModel(
            coordinator: AppCoordinator(dependencies: dependencies),
            charterStore: charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Create 100 charters
        for i in 0..<100 {
            _ = try await charterStore.createCharter(
                name: "Charter \(i)",
                boatName: "Boat \(i)",
                location: "Location \(i)",
                startDate: Date().addingTimeInterval(TimeInterval(i * 86400)),
                endDate: Date().addingTimeInterval(TimeInterval((i + 7) * 86400))
            )
        }
        
        // Measure active charter computation
        let start = Date()
        for _ in 0..<1000 {
            _ = homeVM.activeCharter
        }
        let elapsed = Date().timeIntervalSince(start)
        
        print("1000 activeCharter accesses in \(elapsed)s")
        
        // With memoization, should be very fast (< 0.1s for 1000 accesses)
        #expect(elapsed < 0.1)
    }
}
```

#### 4. Static Analysis Recommendations

**SwiftLint Configuration:**

Create `.swiftlint.yml` in project root:

```yaml
# .swiftlint.yml

disabled_rules:
  - trailing_whitespace  # Handled by formatter

opt_in_rules:
  - explicit_init
  - explicit_type_interface
  - force_unwrapping  # Warn on force unwraps
  - implicitly_unwrapped_optional
  - fatal_error_message
  - closure_spacing
  - empty_count
  - redundant_optional_initialization
  - strict_fileprivate

line_length:
  warning: 120
  error: 150
  ignores_comments: true

file_length:
  warning: 500
  error: 800

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 400
  error: 600

cyclomatic_complexity:
  warning: 10
  error: 20

nesting:
  type_level:
    warning: 2

identifier_name:
  min_length:
    warning: 2
  excluded:
    - id
    - db
    - vm

force_unwrapping:
  severity: warning

excluded:
  - Pods
  - build
  - .build
  - DerivedData
  - fastlane
```

**Run in CI:**

```yaml
# .github/workflows/ci.yml (updated)

name: CI

on: [push, pull_request]

jobs:
  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint --strict
  
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme anyfleet \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
            -enableCodeCoverage YES
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
```

---

## Summary

This anyfleet iOS app demonstrates **strong engineering fundamentals** with clear architecture, modern Swift patterns, and comprehensive testing. The recommended refactorings focus on:

1. **Architectural Clarity:** Separate navigation from infrastructure concerns
2. **Code Maintainability:** Break large files into focused components
3. **Reliability:** Replace crashes with error handling
4. **Performance:** Add memoization and incremental updates
5. **User Experience:** Enhance accessibility and loading states

**Estimated Effort:** 4-6 weeks for all phases  
**Risk:** Low - changes are incremental and well-tested  
**Impact:** High - improved maintainability, performance, and UX

---

**Next Steps:**

1. Review this document with the team
2. Prioritize refactorings based on current pain points
3. Implement Phase 1 (critical architecture) first
4. Add performance benchmarks to prevent regressions
5. Update documentation with new patterns

---

*Review completed: January 2026*
