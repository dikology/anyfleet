# AnyFleet iOS App - Senior Engineering Review

**Date:** January 2026  
**Reviewer:** Senior iOS Engineer  
**Scope:** Full app review focusing on architecture, code quality, Swift/SwiftUI best practices, UX/UI, and testing

---

## Executive Summary

AnyFleet is a sailing charter management app with three main features:
- **Charters:** Create and manage sailing charters with dates, locations, and vessels
- **Library:** Build reusable content (checklists, practice guides, flashcard decks) with publishing/sharing capabilities
- **Discover:** Browse and fork community-published content

**Data Flow:** View → ViewModel → Store → Repository → Database/API  
**Side Effects:** Authentication state, background sync, content publishing operations

### Main Issues (Ranked by Severity)

1. **Architecture (High):** Singleton anti-pattern in `AuthService` breaks DI; state duplication between stores and view models; mixed actor isolation patterns
2. **Code Quality (Medium-High):** Force unwraps exist; long methods in services; duplicate error handling patterns; inconsistent optional handling
3. **Swift/SwiftUI (Medium):** Mix of `@StateObject`, `@Observable`, and `@EnvironmentObject`; some views exceed compiler complexity; manual state synchronization
4. **Performance (Low-Medium):** Unnecessary recomputations in filtered properties; timer-based sync without lifecycle awareness; no caching strategy for expensive operations
5. **UX/UI (Medium):** Complex modals with nested state; accessibility labels missing; inconsistent empty states; no haptic feedback

---

## Refactoring Plan (7 Steps)

1. **Eliminate AuthService singleton** → Inject via `AppDependencies`
2. **Consolidate error handling** → Single error handling protocol implementation
3. **Break down complex ViewModels** → Extract use cases and interactors
4. **Simplify view state management** → Reduce modal state flags, use enums
5. **Extract reusable view components** → Modals, cards, rows into design system
6. **Add caching layer** → LRU cache for library content lookups
7. **Improve accessibility** → Audit and add missing labels, hints, traits

---

## 1. Architecture Issues & Fixes

### Issue 1.1: AuthService Singleton Breaks Dependency Injection

**Problem:** `AuthService.shared` is accessed directly throughout the app, making testing difficult and violating SOLID principles.

**Files Affected:**
- `Services/AuthService.swift:69`
- `App/AppDependencies.swift:107,128,168,185`
- Multiple ViewModels referencing `AuthService.shared`

**Current Code (AppDependencies.swift:107):**

```swift
self.apiClient = APIClient(authService: AuthService.shared)
```

**Refactored Code:**

```swift
// Services/AuthService.swift
@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    // Remove: static let shared = AuthService()
    
    var isAuthenticated = false
    var currentUser: UserInfo?
    
    private let baseURL: String
    private let keychain = KeychainService.shared
    
    // Public initializer for DI
    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8000/api/v1"
            #else
            return "https://elegant-empathy-production-583b.up.railway.app/api/v1"
            #endif
        }()
        
        // Check if we have stored tokens
        if keychain.getAccessToken() != nil {
            AppLogger.auth.info("Found stored access token, restoring session")
            isAuthenticated = true
            Task {
                await loadCurrentUser()
            }
        }
    }
}

// App/AppDependencies.swift
@Observable
@MainActor
final class AppDependencies {
    let database: AppDatabase
    let repository: LocalRepository
    let authService: AuthService  // Add as dependency
    let apiClient: APIClient
    let charterStore: CharterStore
    let syncQueueService: SyncQueueService
    let libraryStore: LibraryStore
    let contentSyncService: ContentSyncService
    let localizationService: LocalizationService
    let visibilityService: VisibilityService
    let authStateObserver: AuthStateObserver
    
    init() {
        AppLogger.dependencies.info("Initializing AppDependencies")
        
        self.database = .shared
        self.repository = LocalRepository(database: database)
        
        // Initialize auth service ONCE
        self.authService = AuthService()
        
        // Inject auth service to dependencies
        self.apiClient = APIClient(authService: authService)
        
        self.syncQueueService = SyncQueueService(
            repository: repository,
            apiClient: apiClient
        )
        
        self.charterStore = CharterStore(repository: repository)
        self.libraryStore = LibraryStore(repository: repository, syncQueue: syncQueueService)
        
        self.contentSyncService = ContentSyncService(
            syncQueue: syncQueueService,
            repository: repository
        )
        
        self.localizationService = LocalizationService()
        self.authStateObserver = AuthStateObserver(authService: authService)
        self.visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: authService,
            syncService: contentSyncService
        )
        
        AppLogger.dependencies.info("AppDependencies initialized successfully")
    }
}
```

**Rationale:** This removes global mutable state, enables proper testing with mock auth services, and follows SOLID principles. All auth state flows through the dependency graph.

---

### Issue 1.2: Mixed Actor Isolation Causing Complexity

**Problem:** Mixing `nonisolated`, `@MainActor`, and actor-isolated code creates confusion and potential race conditions.

**Files Affected:**
- `Core/Stores/CharterStore.swift:32-52`
- Multiple repositories using `Sendable` without clear isolation

**Current Code (CharterStore.swift:39):**

```swift
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any CharterRepository
    
    nonisolated init(repository: any CharterRepository) {
        self.repository = repository
    }
    
    @MainActor
    func createCharter(...) async throws -> CharterModel {
        // Implementation
    }
}
```

**Refactored Code:**

```swift
@MainActor
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    private let repository: any CharterRepository
    
    init(repository: any CharterRepository) {
        self.repository = repository
    }
    
    func createCharter(
        name: String,
        boatName: String?,
        location: String?,
        startDate: Date,
        endDate: Date,
        checkInChecklistID: UUID? = nil
    ) async throws -> CharterModel {
        AppLogger.store.startOperation("Create Charter")
        
        let charter = CharterModel(
            id: UUID(),
            name: name,
            boatName: boatName,
            location: location,
            startDate: startDate,
            endDate: endDate,
            createdAt: Date(),
            checkInChecklistID: checkInChecklistID
        )
        
        do {
            try await repository.createCharter(charter)
            charters.append(charter)
            AppLogger.store.completeOperation("Create Charter")
            return charter
        } catch {
            AppLogger.store.failOperation("Create Charter", error: error)
            throw error
        }
    }
}
```

**Rationale:** Marking the entire store as `@MainActor` simplifies reasoning about concurrency. Since stores hold UI-facing state and use `@Observable`, they should always run on the main actor. Repositories remain `Sendable` and can be safely called from `@MainActor` contexts.

---

### Issue 1.3: State Duplication Between Stores and ViewModels

**Problem:** ViewModels cache data from stores, creating two sources of truth and manual synchronization overhead.

**Files Affected:**
- `Features/Charter/CharterDetailViewModel.swift:25-26`

**Current Code:**

```swift
@Observable
final class CharterDetailViewModel {
    private let charterStore: CharterStore
    
    var charter: CharterModel?  // Duplicate state!
    var isLoading = false
    
    func load() async {
        // Manual sync from store
        charter = charterStore.charters.first(where: { $0.id == charterID })
    }
}
```

**Refactored Code:**

```swift
@MainActor
@Observable
final class CharterDetailViewModel {
    private let charterStore: CharterStore
    let charterID: UUID
    
    var isLoading = false
    var loadError: String?
    
    // Computed property - single source of truth
    var charter: CharterModel? {
        charterStore.charters.first(where: { $0.id == charterID })
    }
    
    init(
        charterID: UUID,
        charterStore: CharterStore,
        libraryStore: LibraryStore
    ) {
        self.charterID = charterID
        self.charterStore = charterStore
        self.libraryStore = libraryStore
    }
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        // Ensure stores are populated
        if charterStore.charters.isEmpty {
            try? await charterStore.loadCharters()
        }
        
        guard charter != nil else {
            loadError = "Charter not found"
            return
        }
        
        await ensureCheckInChecklist()
    }
}
```

**Rationale:** Using computed properties eliminates synchronization bugs and reduces state complexity. The store is the single source of truth, and the ViewModel provides derived views of that data.

---

## 2. Code Quality Issues & Fixes

### Issue 2.1: Optional Force Unwrapping

**Problem:** Multiple force unwraps exist that could crash in production.

**Files Affected:**
- `Services/AuthService.swift:299,340`
- Various ViewModels

**Current Code (AuthService.swift:299):**

```swift
// Retry request with new token
accessToken = keychain.getAccessToken()!
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
```

**Refactored Code:**

```swift
func makeAuthenticatedRequest(to endpoint: String) async throws -> Data {
    guard let accessToken = keychain.getAccessToken() else {
        AppLogger.auth.warning("No access token available for authenticated request")
        throw AuthError.unauthorized
    }
    
    let url = URL(string: "\(baseURL)\(endpoint)")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // If unauthorized, try refreshing token
    if let httpResponse = response as? HTTPURLResponse,
       httpResponse.statusCode == 401 {
        try await refreshAccessToken()
        
        // Get refreshed token safely
        guard let newAccessToken = keychain.getAccessToken() else {
            throw AuthError.unauthorized
        }
        
        request.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpRetryResponse = retryResponse as? HTTPURLResponse,
              (200...299).contains(httpRetryResponse.statusCode) else {
            throw AuthError.invalidResponse
        }
        
        return retryData
    }
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw AuthError.invalidResponse
    }
    
    return data
}
```

**Rationale:** Explicit error handling prevents crashes and provides better error messages for debugging and user feedback.

---

### Issue 2.2: Long Methods in Services

**Problem:** `VisibilityService` and `AuthService` have methods exceeding 50 lines, reducing readability and testability.

**Files Affected:**
- `Services/VisibilityService.swift:95-338` (publishContent method is ~240 lines)

**Refactored Code:**

```swift
// Extract validation logic
final class ContentValidator {
    func validate(_ item: LibraryModel, for operation: PublishOperation) throws {
        try validateTitle(item.title)
        try validateDescription(item.description)
        try validateTags(item.tags)
    }
    
    private func validateTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PublishError.validationError("Title cannot be empty")
        }
        guard trimmed.count >= 3 else {
            throw PublishError.validationError("Title must be at least 3 characters")
        }
        guard trimmed.count <= 100 else {
            throw PublishError.validationError("Title must be 100 characters or less")
        }
    }
    
    private func validateDescription(_ description: String?) throws {
        guard let desc = description, !desc.isEmpty else {
            throw PublishError.validationError("Description is required for publishing")
        }
        guard desc.count <= 500 else {
            throw PublishError.validationError("Description must be 500 characters or less")
        }
    }
    
    private func validateTags(_ tags: [String]) throws {
        guard !tags.isEmpty else {
            throw PublishError.validationError("At least one tag is required")
        }
        guard tags.count <= 10 else {
            throw PublishError.validationError("Maximum 10 tags allowed")
        }
    }
}

// Simplified VisibilityService
@MainActor
@Observable
final class VisibilityService: VisibilityServiceProtocol {
    private let libraryStore: LibraryStore
    private let authService: AuthServiceProtocol
    private let syncService: ContentSyncService
    private let validator = ContentValidator()
    
    func publishContent(_ item: LibraryModel) async throws -> SyncSummary {
        AppLogger.auth.info("Publishing content: \(item.id)")
        
        // 1. Auth check
        try await ensureAuthenticated()
        
        // 2. Validation
        try validator.validate(item, for: .publish)
        
        // 3. Update visibility
        var updatedItem = item
        updatedItem.visibility = .public
        updatedItem.updatedAt = Date()
        
        // 4. Persist and sync
        try await libraryStore.updateMetadata(updatedItem)
        let summary = await syncService.syncPending()
        
        AppLogger.auth.info("Content published successfully: \(item.id)")
        return summary
    }
    
    private func ensureAuthenticated() async throws {
        guard authService.isAuthenticated else {
            AppLogger.auth.warning("Publish attempt without authentication")
            throw PublishError.notAuthenticated
        }
        try await authService.ensureCurrentUserLoaded()
    }
}
```

**Rationale:** Extracting validation into a separate class follows Single Responsibility Principle, improves testability, and makes the service method easier to understand at a glance.

---

### Issue 2.3: Inconsistent Error Handling Patterns

**Problem:** ViewModels handle errors differently - some use `ErrorHandling` protocol, others have custom properties.

**Files Affected:**
- `Features/Charter/CharterListViewModel.swift:28`
- `Features/Library/LibraryListViewModel.swift:31`

**Refactored Code:**

```swift
// Core/Errors/ErrorHandling.swift
@MainActor
protocol ErrorHandling: AnyObject {
    var currentError: AppError? { get set }
    var showErrorBanner: Bool { get set }
}

extension ErrorHandling {
    func handleError(_ error: Error) {
        currentError = error.toAppError()
        showErrorBanner = true
        AppLogger.view.error("Error handled: \(error.localizedDescription)")
    }
    
    func clearError() {
        currentError = nil
        showErrorBanner = false
    }
}

// Apply consistently to all ViewModels
@MainActor
@Observable
final class HomeViewModel: ErrorHandling {
    var currentError: AppError?
    var showErrorBanner: Bool = false
    
    private let coordinator: AppCoordinator
    private let charterStore: CharterStore
    private let libraryStore: LibraryStore
    
    var isLoading = false
    
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
        } catch {
            handleError(error)
        }
    }
}
```

**Rationale:** Consistent error handling reduces cognitive load and ensures uniform UX for error display across the app.

---

## 3. Swift & SwiftUI Best Practices

### Issue 3.1: Complex View Bodies Exceeding Compiler Limits

**Problem:** `LibraryListView` has a 450-line body with nested sheets and complex state.

**Files Affected:**
- `Features/Library/LibraryListView.swift:23-183`

**Refactored Code:**

```swift
struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    
    init(viewModel: LibraryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            contentView
            
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                ErrorBannerOverlay(
                    error: error,
                    onDismiss: { viewModel.clearError() },
                    onRetry: { Task { await viewModel.loadLibrary() } }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Library.myLibrary)
                    .font(DesignSystem.Typography.headline)
            }
            ToolbarItem(placement: .primaryAction) {
                CreateContentMenu(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadLibrary()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .libraryModals(viewModel: viewModel)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isEmpty && !viewModel.isLoading {
            LibraryEmptyState()
        } else {
            LibraryContentList(viewModel: viewModel)
        }
    }
}

// Extract modal management into view modifier
struct LibraryModalsModifier: ViewModifier {
    @Bindable var viewModel: LibraryListViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showingPublishConfirmation) {
                PublishConfirmationSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingSignInModal) {
                SignInModalView(
                    onSuccess: { viewModel.showingSignInModal = false },
                    onDismiss: { viewModel.showingSignInModal = false }
                )
            }
            .sheet(isPresented: $viewModel.showPrivateDeleteConfirmation) {
                PrivateDeleteConfirmationSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showPublishedDeleteConfirmation) {
                PublishedDeleteConfirmationSheet(viewModel: viewModel)
            }
    }
}

extension View {
    func libraryModals(viewModel: LibraryListViewModel) -> some View {
        modifier(LibraryModalsModifier(viewModel: viewModel))
    }
}

// Separate content list
struct LibraryContentList: View {
    let viewModel: LibraryListViewModel
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ContentFilterPicker(selection: $viewModel.selectedFilter)
            
            List {
                ForEach(viewModel.filteredItems) { item in
                    LibraryItemRow(item: item, viewModel: viewModel)
                        .listRowInsets(DesignSystem.Spacing.listRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            LibraryItemSwipeActions(item: item, viewModel: viewModel)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Gradients.subtleBackground)
        }
    }
}
```

**Rationale:** Breaking complex views into smaller, focused subviews improves compile times, readability, and makes individual components reusable and testable.

---

### Issue 3.2: Manual State Synchronization in ViewModels

**Problem:** Multiple boolean flags for modal state create complexity and potential bugs.

**Files Affected:**
- `Features/Library/LibraryListViewModel.swift:47-56`

**Current Code:**

```swift
var showingPublishConfirmation = false
var showingSignInModal = false
var pendingDeleteItem: LibraryModel?
var showPrivateDeleteConfirmation = false
var showPublishedDeleteConfirmation = false
var publishedDeleteModalItem: LibraryModel?
```

**Refactored Code:**

```swift
// Use enum for modal state
enum LibraryModal: Identifiable {
    case publishConfirmation(LibraryModel)
    case signIn
    case deletePrivate(LibraryModel)
    case deletePublished(LibraryModel)
    
    var id: String {
        switch self {
        case .publishConfirmation(let item): return "publish-\(item.id)"
        case .signIn: return "signin"
        case .deletePrivate(let item): return "delete-private-\(item.id)"
        case .deletePublished(let item): return "delete-published-\(item.id)"
        }
    }
}

@MainActor
@Observable
final class LibraryListViewModel: ErrorHandling {
    var activeModal: LibraryModal?
    var isLoading = false
    var currentError: AppError?
    var showErrorBanner: Bool = false
    
    // Simplified methods
    func initiatePublish(_ item: LibraryModel) {
        activeModal = .publishConfirmation(item)
    }
    
    func initiateDelete(_ item: LibraryModel) {
        if item.publicID != nil {
            activeModal = .deletePublished(item)
        } else {
            activeModal = .deletePrivate(item)
        }
    }
    
    func dismissModal() {
        activeModal = nil
    }
}

// In view
struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    
    var body: some View {
        contentView
            .sheet(item: $viewModel.activeModal) { modal in
                modalContent(for: modal)
            }
    }
    
    @ViewBuilder
    private func modalContent(for modal: LibraryModal) -> some View {
        switch modal {
        case .publishConfirmation(let item):
            PublishConfirmationModal(
                item: item,
                onConfirm: { await viewModel.confirmPublish() },
                onCancel: { viewModel.dismissModal() }
            )
        case .signIn:
            SignInModalView(
                onSuccess: { viewModel.dismissModal() },
                onDismiss: { viewModel.dismissModal() }
            )
        case .deletePrivate(let item):
            DeleteConfirmationModal(
                item: item,
                isPublished: false,
                onConfirm: { await viewModel.deleteContent(item) },
                onCancel: { viewModel.dismissModal() }
            )
        case .deletePublished(let item):
            PublishedContentDeleteModal(
                item: item,
                onUnpublishAndDelete: { await viewModel.deleteAndUnpublishContent(item) },
                onKeepPublished: { await viewModel.deleteLocalCopyKeepPublished(item) },
                onCancel: { viewModel.dismissModal() }
            )
        }
    }
}
```

**Rationale:** Using an enum eliminates impossible states (e.g., two modals being shown at once), reduces boilerplate, and makes state transitions explicit and type-safe.

---

### Issue 3.3: Inconsistent Property Wrapper Usage

**Problem:** Mix of `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, and `@Observable` creates confusion.

**Files Affected:**
- `anyfleetApp.swift:12-13`
- Multiple views

**Current Code:**

```swift
@main
struct anyfleetApp: App {
    @State private var dependencies = AppDependencies()
    @StateObject private var coordinator: AppCoordinator
    
    init() {
        let deps = AppDependencies()
        _dependencies = State(initialValue: deps)
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: deps))
    }
}
```

**Refactored Code:**

```swift
@main
struct anyfleetApp: App {
    @State private var dependencies = AppDependencies()
    @State private var coordinator: AppCoordinator
    
    init() {
        let deps = AppDependencies()
        _dependencies = State(initialValue: deps)
        _coordinator = State(initialValue: AppCoordinator(dependencies: deps))
    }
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(dependencies)
                .environment(coordinator)
        }
    }
}

// Update views to use @Environment instead of @EnvironmentObject
struct AppView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppCoordinator.self) private var coordinator
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // ...
        }
    }
}
```

**Rationale:** Swift's modern `@Observable` macro with `@State` and `@Environment` is the recommended approach for iOS 17+. It's more performant and has cleaner syntax than the older `ObservableObject` protocol.

---

## 4. UX & UI Improvements

### Issue 4.2: No Loading States for Async Operations

**Problem:** Users don't see feedback during long-running operations like publishing.

**Files Affected:**
- `Features/Library/LibraryListView.swift`

**Refactored Code:**

```swift
struct LibraryItemRow: View {
    let item: LibraryModel
    @State private var isPerformingAction = false
    
    var body: some View {
        HStack {
            itemContent
            
            if isPerformingAction {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isPerformingAction)
        .opacity(isPerformingAction ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPerformingAction)
    }
    
    private var itemContent: some View {
        // ... existing row content ...
    }
}

// In ViewModel
@MainActor
@Observable
final class LibraryListViewModel: ErrorHandling {
    var operationsInProgress: Set<UUID> = []
    
    func isOperationInProgress(_ itemID: UUID) -> Bool {
        operationsInProgress.contains(itemID)
    }
    
    func publishContent(_ item: LibraryModel) async {
        operationsInProgress.insert(item.id)
        defer { operationsInProgress.remove(item.id) }
        
        do {
            try await visibilityService.publishContent(item)
            await loadLibrary()
        } catch {
            handleError(error)
        }
    }
}
```

**Rationale:** Showing progress indicators for async operations improves perceived performance and prevents users from tapping multiple times.

---

### Issue 4.3: Inconsistent Empty State Messaging

**Problem:** Empty states use generic messages without actionable guidance.

**Files Affected:**
- `Features/Charter/CharterListView.swift:67-85`
- `Features/Library/LibraryListView.swift:216-234`

**Refactored Code:**

```swift
// Extract to DesignSystem
extension DesignSystem {
    struct EmptyStateView: View {
        let icon: String
        let title: String
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?
        
        init(
            icon: String,
            title: String,
            message: String,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }
        
        var body: some View {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.15),
                                    DesignSystem.Colors.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: icon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                }
                
                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text(actionTitle)
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(12)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.oceanDeep.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// Usage
private var emptyState: some View {
    DesignSystem.EmptyStateView(
        icon: "sailboat",
        title: "No Charters Yet",
        message: "Create your first charter to start planning your sailing adventure. Track dates, vessels, and locations all in one place.",
        actionTitle: "Create Charter",
        action: { viewModel.onCreateCharterTapped() }
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No charters. Create your first charter to start planning.")
}
```

**Rationale:** Consistent empty states with clear CTAs guide users toward the next action, improving conversion and reducing confusion.

---

## 5. Testing Strategy & Gaps

### Missing Test Coverage

**Critical Paths Needing Tests:**

1. **Authentication Flow**
   - Token refresh failure → logout
   - Offline authentication with cached tokens
   - Concurrent auth requests

2. **Publishing/Sync Operations**
   - Publish while offline → queue for retry
   - Sync conflict resolution
   - Partial sync failure handling

3. **Charter State Transitions**
   - Overlapping charter date ranges
   - Past charter archival
   - Charter deletion cascade

**Proposed Test Cases:**

```swift
import Testing
@testable import anyfleet

@MainActor
@Suite("VisibilityService Tests")
struct VisibilityServiceTests {
    
    @Test("Publish requires authentication")
    func publishRequiresAuth() async throws {
        // Given
        let mockAuth = MockAuthService(isAuthenticated: false)
        let mockStore = MockLibraryStore()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )
        let item = LibraryModel.fixture()
        
        // When/Then
        await #expect(throws: VisibilityService.PublishError.notAuthenticated) {
            try await service.publishContent(item)
        }
    }
    
    @Test("Publish validates content before submission")
    func publishValidatesContent() async throws {
        // Given
        let mockAuth = MockAuthService(isAuthenticated: true)
        let mockStore = MockLibraryStore()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )
        
        var item = LibraryModel.fixture()
        item.title = "AB" // Too short
        
        // When/Then
        await #expect(throws: VisibilityService.PublishError.validationError) {
            try await service.publishContent(item)
        }
    }
    
    @Test("Publish updates visibility and triggers sync")
    func publishUpdatesVisibility() async throws {
        // Given
        let mockAuth = MockAuthService(isAuthenticated: true, user: .fixture())
        let mockStore = MockLibraryStore()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )
        
        var item = LibraryModel.fixture()
        item.visibility = .private
        
        // When
        _ = try await service.publishContent(item)
        
        // Then
        #expect(mockStore.lastUpdatedItem?.visibility == .public)
        #expect(mockSync.syncPendingCalled == true)
    }
}

@Suite("AppCoordinator Navigation Tests")
struct AppCoordinatorNavigationTests {
    
    @Test("Cross-tab navigation to charter clears destination stack")
    @MainActor
    func crossTabNavigationClearsStack() async throws {
        // Given
        let deps = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: deps)
        coordinator.selectedTab = .home
        coordinator.chartersPath = [.charterDetail(UUID())]
        
        let charterID = UUID()
        
        // When
        coordinator.navigateToCharter(charterID)
        
        // Then
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charterID))
    }
}
```

**Rationale:** These tests cover critical business logic and edge cases that could cause production issues. Focusing on use cases rather than implementation details makes tests resilient to refactoring.

---

## 6. Performance Optimizations

### Issue 6.1: Inefficient Filtered List Computations

**Problem:** `filteredItems` in `LibraryListViewModel` recomputes on every access.

**Files Affected:**
- `Features/Library/LibraryListViewModel.swift:111-122`

**Current Code:**

```swift
var filteredItems: [LibraryModel] {
    switch selectedFilter {
    case .all:
        return library
    case .checklists:
        return checklists
    case .guides:
        return guides
    case .decks:
        return decks
    }
}
```

**Refactored Code:**

```swift
@MainActor
@Observable
final class LibraryListViewModel: ErrorHandling {
    var selectedFilter: ContentFilter = .all {
        didSet { updateFilteredItems() }
    }
    
    private(set) var filteredItems: [LibraryModel] = []
    
    var library: [LibraryModel] {
        libraryStore.library
    }
    
    func loadLibrary() async {
        // ... existing load logic ...
        updateFilteredItems()
    }
    
    private func updateFilteredItems() {
        switch selectedFilter {
        case .all:
            filteredItems = library
        case .checklists:
            filteredItems = library.filter { $0.type == .checklist }
        case .guides:
            filteredItems = library.filter { $0.type == .practiceGuide }
        case .decks:
            filteredItems = library.filter { $0.type == .flashcardDeck }
        }
    }
}
```

**Rationale:** Caching filtered results avoids redundant computations during view updates. This is especially important for lists with hundreds of items.

---

### Issue 6.2: Timer-Based Sync Without Lifecycle Awareness

**Problem:** Background sync timer continues even when app is backgrounded.

**Files Affected:**
- `App/AppModel.swift:62-69`

**Current Code:**

```swift
private func startBackgroundSync() {
    syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.syncService.syncPending()
        }
    }
}
```

**Refactored Code:**

```swift
import UIKit
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.syncService = dependencies.contentSyncService
        observeAppLifecycle()
        startBackgroundSync()
    }
    
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseBackgroundSync()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.resumeBackgroundSync()
            }
            .store(in: &cancellables)
    }
    
    private func startBackgroundSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncService.syncPending()
            }
        }
    }
    
    private func pauseBackgroundSync() {
        AppLogger.sync.info("Pausing background sync (app inactive)")
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func resumeBackgroundSync() {
        AppLogger.sync.info("Resuming background sync (app active)")
        
        // Immediate sync on resume
        Task { @MainActor in
            await syncService.syncPending()
        }
        
        // Restart timer
        startBackgroundSync()
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
}
```

**Rationale:** Pausing sync when the app is backgrounded saves battery and network resources. Immediate sync on resume ensures data freshness.

---

### Issue 6.3: No Caching for Expensive Content Fetches

**Problem:** Fetching full checklist/guide content repeatedly from disk.

**Refactored Code:**

```swift
// Core/Utilities/ContentCache.swift
@MainActor
final class ContentCache<Key: Hashable, Value> {
    private var cache = LRUCache<Key, Value>(capacity: 50)
    
    func get(_ key: Key) -> Value? {
        cache[key]
    }
    
    func set(_ key: Key, value: Value) {
        cache[key] = value
    }
    
    func remove(_ key: Key) {
        cache[key] = nil
    }
    
    func clear() {
        cache.removeAll()
    }
}

// Update LibraryStore
@MainActor
@Observable
final class LibraryStore: LibraryStoreProtocol {
    private let repository: LibraryRepository
    private let syncQueue: SyncQueueService
    
    private let checklistCache = ContentCache<UUID, Checklist>()
    private let guideCache = ContentCache<UUID, PracticeGuide>()
    
    func fetchFullContent<T>(_ contentID: UUID) async throws -> T where T: LibraryContent {
        // Check cache first
        if T.self == Checklist.self {
            if let cached = checklistCache.get(contentID) as? T {
                AppLogger.store.debug("Cache hit for checklist: \(contentID)")
                return cached
            }
        } else if T.self == PracticeGuide.self {
            if let cached = guideCache.get(contentID) as? T {
                AppLogger.store.debug("Cache hit for guide: \(contentID)")
                return cached
            }
        }
        
        // Fetch from repository
        let content: T
        if T.self == Checklist.self {
            let checklist = try await repository.fetchChecklist(contentID)
            checklistCache.set(contentID, value: checklist)
            content = checklist as! T
        } else if T.self == PracticeGuide.self {
            let guide = try await repository.fetchGuide(contentID)
            guideCache.set(contentID, value: guide)
            content = guide as! T
        } else {
            fatalError("Unsupported content type")
        }
        
        return content
    }
    
    func invalidateCache(for contentID: UUID) {
        checklistCache.remove(contentID)
        guideCache.remove(contentID)
    }
}
```

**Rationale:** Caching frequently accessed content reduces disk I/O and improves perceived performance, especially when navigating between detail views.

