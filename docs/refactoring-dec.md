# anyfleet iOS - Refactoring & Architecture Plan

**Review Date:** December 15, 2025  
**Reviewer:** Senior iOS Developer  
**Codebase Status:** Early development, solid foundation with areas for improvement

---

## Executive Summary

The anyfleet codebase demonstrates strong architectural fundamentals with clean separation of concerns, modern Swift 6 concurrency adoption, and thoughtful design patterns. However, as an early-stage project, there are several areas requiring refactoring to ensure scalability, maintainability, and adherence to iOS best practices.

**Overall Assessment:** 7.5/10
- ✅ Strong: Architecture, Testing foundation, Modern Swift features
- ⚠️ Needs Work: State management consistency, Error handling, Dependency injection
- 🔄 In Progress: Navigation, Feature completion

**Reference Implementation:** The `sailaway` project (sibling codebase) demonstrates excellent implementation of many patterns recommended in this document, particularly:
- Consistent `@Observable` pattern with proper environment-based DI
- `ViewState<T>` enum for unified loading/error states
- Comprehensive `AppError` hierarchy with domain-specific errors
- Offline-first data loading patterns
- Clean separation of navigation (AppModel) from business logic (Stores)

---

## 0. Reference Implementation: sailaway Project

Before diving into specific refactoring recommendations, it's worth noting that the **sailaway** project (a sibling codebase in the automatic-parakeet repository) demonstrates excellent implementation of modern iOS patterns. Key learnings from sailaway that should be applied to anyfleet:

### 0.1 ViewState<T> Pattern ✨

**sailaway Implementation:**
```swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(AppError)
    
    var data: Value? { ... }
    var isLoading: Bool { ... }
    var isRetryable: Bool { ... }
}

// Usage in stores:
@Observable
final class CharterStore {
    private(set) var charterState: ViewState<[CharterModel]> = .idle
    
    @MainActor
    func loadCharters() async {
        charterState = .loading
        do {
            let charters = try await repository.fetchAllCharters()
            charterState = charters.isEmpty ? .empty : .loaded(charters)
        } catch {
            charterState = .error(error.asAppError)
        }
    }
}
```

**Benefits:**
- Single source of truth for loading, data, error, and empty states
- Type-safe state transitions
- Easy to test and reason about
- Eliminates multiple boolean flags (`isLoading`, `hasError`, etc.)

### 0.2 Comprehensive AppError Hierarchy ✨

**sailaway Implementation:**
```swift
enum AppError: Error, Identifiable {
    case network(NetworkError)
    case auth(AuthError)
    case content(ContentError)
    case sync(SyncError)
    case validation(ValidationError)
    case unknown(underlying: Error?)
    
    var id: String { ... }
    var isRetryable: Bool { ... }
    var localizedMessage: String { ... }
}

// Domain-specific errors
enum NetworkError {
    case offline
    case timedOut
    case server(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    // ...
}

// Convenient conversion
extension Error {
    var asAppError: AppError {
        AppError.map(self)
    }
}
```

**Benefits:**
- User-friendly error messages out of the box
- Retry logic based on error type
- Clear error categorization
- Easy error presentation in UI

### 0.3 Environment-Based Dependency Injection ✨

**sailaway Implementation:**
```swift
// sailawayApp.swift - Initialize dependencies once
init() {
    let repository = LocalRepository(database: .shared)
    self.localRepository = repository
    self.syncService = SyncService(repository: repository)
    
    // Initialize stores with shared dependencies
    _userStore = State(initialValue: UserStore(repository: repository, syncService: syncService))
    _charterStore = State(initialValue: CharterStore(repository: repository, syncService: syncService))
}

var body: some Scene {
    WindowGroup {
        AppView(model: appModel)
            .environment(\.localRepository, localRepository)
            .environment(\.charterStore, charterStore)
            .environment(\.userStore, userStore)
    }
}

// Stores accept dependencies via nonisolated init
@Observable
final class CharterStore {
    nonisolated init(
        repository: LocalRepository = LocalRepository(),
        apiClient: any CharterAPI = APIClient.shared,
        syncService: SyncService? = nil
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.syncService = syncService
    }
}

// EnvironmentKeys.swift - Centralized environment keys
private struct CharterStoreKey: EnvironmentKey {
    static var defaultValue: CharterStore {
        CharterStore()
    }
}

extension EnvironmentValues {
    var charterStore: CharterStore {
        get { self[CharterStoreKey.self] }
        set { self[CharterStoreKey.self] = newValue }
    }
}
```

**Benefits:**
- Clear dependency graph visible in app initialization
- Easy to test with mock dependencies
- Default values for previews/testing
- Type-safe environment injection

### 0.4 Offline-First Data Loading ✨

**sailaway Pattern:**
```swift
@MainActor
func loadChartersOfflineFirst() async {
    // Load from local database immediately
    await loadCharters()
    
    // Then refresh from server in background
    Task {
        await loadRemoteCharters(preserveExisting: true)
    }
}

@MainActor
func loadRemoteCharters(preserveExisting: Bool = false) async {
    // Don't show loading if we already have data
    if !preserveExisting || charters.isEmpty {
        charterState = .loading
    }
    
    do {
        let dtos = try await apiClient.get(path: "/charters")
        // Save to local database
        for dto in dtos {
            try await repository.saveCharterWithoutQueue(dto.toDomainModel())
        }
        charters = try await repository.fetchAllCharters()
        charterState = charters.isEmpty ? .empty : .loaded(charters)
    } catch {
        // If we have local data, keep showing it despite error
        if preserveExisting, !charters.isEmpty {
            charterState = .loaded(charters)
            return
        }
        charterState = .error(error.asAppError)
    }
}
```

**Benefits:**
- Instant UI response (no spinner wait)
- Works offline seamlessly
- Background refresh without disrupting UX
- Graceful error handling (keep showing cached data)

### 0.5 Protocol Abstractions for Testability ✨

**sailaway Pattern:**
```swift
// Define protocol for API operations
protocol CharterAPI: Sendable {
    func get<T: Decodable>(path: String, queryItems: [URLQueryItem]?) async throws -> T
    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T
    func patch<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T
}

// Production implementation
extension APIClient: CharterAPI {}

// Store depends on protocol, not concrete type
@Observable
final class CharterStore {
    private let apiClient: any CharterAPI
    
    nonisolated init(
        apiClient: any CharterAPI = APIClient.shared
    ) {
        self.apiClient = apiClient
    }
}

// Easy to mock in tests
struct MockCharterAPI: CharterAPI {
    var getHandler: ((String, [URLQueryItem]?) async throws -> Any)?
    
    func get<T: Decodable>(path: String, queryItems: [URLQueryItem]?) async throws -> T {
        // Mock implementation
    }
}
```

### 0.6 Computed Properties for Filtered Data ✨

**sailaway Pattern:**
```swift
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    
    // Computed properties instead of separate arrays
    var activeCharter: CharterModel? {
        charters.first { $0.isActive }
    }
    
    var pastCharters: [CharterModel] {
        charters.filter { !$0.isActive && $0.endDate < Date() }
    }
    
    var upcomingCharters: [CharterModel] {
        charters.filter { !$0.isActive && $0.startDate > Date() }
    }
}
```

**Benefits:**
- Single source of truth (only `charters` array)
- No manual synchronization needed
- Always up-to-date filtered views
- Less memory usage

---

## 1. Architecture & Design Patterns

### 1.1 ✅ Strengths

- **Clean Architecture Layers**: Clear separation between Domain (Models), Data (Repository/Database), and Presentation (Views/ViewModels)
- **Repository Pattern**: Well-implemented abstraction over data access
- **Coordinator Pattern**: Good navigation architecture with `AppCoordinator`
- **MVVM Pattern**: Proper separation of business logic from views

### 1.2 ⚠️ Issues & Refactoring Needed

#### Issue 1.2.1: Inconsistent State Management

**Current State:**
```swift
// CharterStore.swift - Using @Observable
@Observable
final class CharterStore { }

// CreateCharterView.swift - Creating new store instance per view
@State private var charterStore = CharterStore()

// HomeViewModel.swift - Using @ObservableObject
@MainActor
final class HomeViewModel: ObservableObject { }
```

**Problems:**
- Multiple `CharterStore` instances being created per view
- No shared state across the app
- Mix of `@Observable` and `@ObservableObject`
- No proper dependency injection

**Recommended Refactoring:**

1. **Establish Single Source of Truth:**
```swift
// App-level dependency container
@MainActor
final class AppDependencies: ObservableObject {
    let charterStore: CharterStore
    let database: AppDatabase
    let repository: LocalRepository
    
    init() {
        self.database = .shared
        self.repository = LocalRepository(database: database)
        self.charterStore = CharterStore(repository: repository)
    }
}

// anyfleetApp.swift
@main
struct anyfleetApp: App {
    @StateObject private var dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environmentObject(dependencies.charterStore)
                .environment(\.appCoordinator, AppCoordinator())
        }
    }
}
```

2. **Inject dependencies in views:**
```swift
// CreateCharterView.swift
struct CreateCharterView: View {
    @EnvironmentObject private var charterStore: CharterStore
    
    // No more @State private var charterStore = CharterStore()
}
```

**Priority:** 🔴 HIGH - Critical for data consistency

---

#### Issue 1.2.2: Missing Proper Dependency Injection

**Current State:**
- Hardcoded dependencies: `LocalRepository()` created in `CharterStore`
- Difficult to test and swap implementations
- Tight coupling between layers

**Recommended Refactoring:**

Create a proper DI container:

```swift
// Core/DependencyContainer.swift
@MainActor
final class DependencyContainer {
    // MARK: - Shared Instance
    static let shared = DependencyContainer()
    
    // MARK: - Services
    private(set) lazy var database: AppDatabase = {
        .shared
    }()
    
    private(set) lazy var charterRepository: CharterRepository = {
        LocalRepository(database: database)
    }()
    
    private(set) lazy var charterStore: CharterStore = {
        CharterStore(repository: charterRepository)
    }()
    
    private(set) lazy var localizationService: LocalizationService = {
        LocalizationService()
    }()
    
    // For testing - allow injection
    func makeCharterStore(repository: CharterRepository) -> CharterStore {
        CharterStore(repository: repository)
    }
}
```

**Priority:** 🔴 HIGH

---

#### Issue 1.2.3: ViewModels Need Standardization

**Current State:**
- `HomeViewModel` exists but is minimal
- Most views have business logic directly in the view
- No consistent pattern for view state management

**Recommended Refactoring:**

Create comprehensive ViewModels for all feature views:

```swift
// Features/Charter/CreateCharterViewModel.swift
@MainActor
@Observable
final class CreateCharterViewModel {
    // MARK: - Dependencies
    private let charterStore: CharterStore
    private let coordinator: AppCoordinator
    
    // MARK: - State
    var form: CharterFormState
    var isSaving = false
    var saveError: Error?
    var completionProgress: Double { calculateProgress() }
    
    // MARK: - Init
    init(
        charterStore: CharterStore,
        coordinator: AppCoordinator,
        initialForm: CharterFormState = .init()
    ) {
        self.charterStore = charterStore
        self.coordinator = coordinator
        self.form = initialForm
    }
    
    // MARK: - Actions
    func saveCharter() async {
        guard !isSaving else { return }
        
        isSaving = true
        saveError = nil
        
        do {
            let charter = try await charterStore.createCharter(
                name: form.name,
                boatName: form.vessel.isEmpty ? nil : form.vessel,
                location: form.destination.isEmpty ? nil : form.destination,
                startDate: form.startDate,
                endDate: form.endDate
            )
            
            coordinator.pop(from: .charters)
        } catch {
            saveError = error
            isSaving = false
        }
    }
    
    private func calculateProgress() -> Double {
        // Progress calculation logic
    }
}
```

**Views become simpler:**
```swift
struct CreateCharterView: View {
    @State private var viewModel: CreateCharterViewModel
    
    init(viewModel: CreateCharterViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        // Simple view code that delegates to viewModel
    }
}
```

**Priority:** 🟡 MEDIUM

---

## 2. Code Quality & Best Practices

### 2.1 ✅ Strengths

- **Swift 6 Concurrency**: Proper use of `async/await`, `@MainActor`, `nonisolated`
- **Type Safety**: Good use of protocols and strong typing
- **Sendable Conformance**: Proper handling of concurrency requirements
- **Testing**: Good unit test coverage with Swift Testing framework

### 2.2 ⚠️ Issues & Refactoring Needed

#### Issue 2.2.1: Inconsistent Error Handling

**Current State:**
```swift
// CharterStore.swift - Errors are thrown and logged
func loadCharters() async {
    do {
        charters = try await repository.fetchAllCharters()
    } catch {
        AppLogger.store.failOperation("Load Charters", error: error)
        // Error is silently swallowed - user has no feedback
    }
}
```

**Problems:**
- Inconsistent error handling across layers
- Some errors silently logged, some thrown
- No user-facing error messages
- No retry mechanisms

**Recommended Refactoring (Based on sailaway Pattern):**

1. **Create Comprehensive AppError Hierarchy:**
```swift
// Core/Errors/AppError.swift
// Reference: sailaway/Core/Errors/AppError.swift
enum AppError: Error, Identifiable, @unchecked Sendable {
    case database(DatabaseError)
    case network(NetworkError)
    case validation(ValidationError)
    case sync(SyncError)
    case unknown(underlying: Error?)
    
    var id: String {
        switch self {
        case .database(let error): return "database.\(error.identifier)"
        case .network(let error): return "network.\(error.identifier)"
        case .validation(let error): return "validation.\(error.identifier)"
        case .sync(let error): return "sync.\(error.identifier)"
        case .unknown: return "unknown"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .database(let error): return error.isRetryable
        case .network(let error): return error.isRetryable
        case .validation: return false
        case .sync(let error): return error.isRetryable
        case .unknown: return true
        }
    }
    
    var localizedMessage: String {
        switch self {
        case .database(let error): return error.localizedMessage
        case .network(let error): return error.localizedMessage
        case .validation(let error): return error.localizedMessage
        case .sync(let error): return error.localizedMessage
        case .unknown(let underlying):
            return underlying?.localizedDescription ?? "An unexpected error occurred."
        }
    }
}

enum DatabaseError: @unchecked Sendable {
    case readFailed
    case writeFailed
    case migrationFailed
    case corrupted
    case notFound
    
    var identifier: String {
        switch self {
        case .readFailed: return "readFailed"
        case .writeFailed: return "writeFailed"
        case .migrationFailed: return "migrationFailed"
        case .corrupted: return "corrupted"
        case .notFound: return "notFound"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .corrupted, .migrationFailed: return false
        default: return true
        }
    }
    
    var localizedMessage: String {
        switch self {
        case .readFailed: return "Failed to read data. Please try again."
        case .writeFailed: return "Failed to save data. Please try again."
        case .migrationFailed: return "Database migration failed. Please reinstall the app."
        case .corrupted: return "Data is corrupted. Please contact support."
        case .notFound: return "The requested item was not found."
        }
    }
}

enum ValidationError: @unchecked Sendable {
    case emptyName
    case invalidDateRange
    case missingRequiredFields
    case tooShort(field: String, minimum: Int)
    case tooLong(field: String, maximum: Int)
    
    var identifier: String {
        switch self {
        case .emptyName: return "emptyName"
        case .invalidDateRange: return "invalidDateRange"
        case .missingRequiredFields: return "missingFields"
        case .tooShort(let field, _): return "tooShort.\(field)"
        case .tooLong(let field, _): return "tooLong.\(field)"
        }
    }
    
    var isRetryable: Bool { false }
    
    var localizedMessage: String {
        switch self {
        case .emptyName: return "Charter name is required."
        case .invalidDateRange: return "End date must be after start date."
        case .missingRequiredFields: return "Please fill in all required fields."
        case .tooShort(let field, let min): return "\(field) must be at least \(min) characters."
        case .tooLong(let field, let max): return "\(field) must be no more than \(max) characters."
        }
    }
}

// Convenient error mapping
extension Error {
    var asAppError: AppError {
        if let appError = self as? AppError {
            return appError
        }
        return AppError.map(self)
    }
}

extension AppError {
    static func map(_ error: Error) -> AppError {
        // Map known error types
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(underlying: error)
    }
}
```

2. **Integrate ViewState<T> Pattern:**
```swift
// Core/Models/ViewState.swift
// Reference: sailaway/Core/Models/ViewState.swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(AppError)
    
    var data: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    var errorValue: AppError? {
        if case .error(let error) = self { return error }
        return nil
    }
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

// Update CharterStore
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    private(set) var charterState: ViewState<[CharterModel]> = .idle
    
    @MainActor
    func loadCharters() async {
        AppLogger.store.startOperation("Load Charters")
        charterState = .loading
        
        do {
            charters = try await repository.fetchAllCharters()
            charterState = charters.isEmpty ? .empty : .loaded(charters)
            AppLogger.store.completeOperation("Load Charters")
        } catch {
            let appError = error.asAppError
            charterState = .error(appError)
            AppLogger.store.failOperation("Load Charters", error: error)
        }
    }
}
```

3. **Add Error Presentation in Views:**
```swift
// In CharterListView
var body: some View {
    Group {
        switch charterStore.charterState {
        case .idle, .loading:
            ProgressView("Loading charters...")
        case .loaded:
            charterList
        case .empty:
            emptyState
        case .error(let error):
            ErrorView(
                error: error,
                retry: error.isRetryable ? { 
                    await charterStore.loadCharters() 
                } : nil
            )
        }
    }
}

// Reusable ErrorView component
struct ErrorView: View {
    let error: AppError
    let retry: (() async -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(error.localizedMessage)
                .font(.body)
                .multilineTextAlignment(.center)
            
            if let retry = retry {
                Button("Try Again") {
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

**Priority:** 🔴 HIGH

**Reference:** See `sailaway/Core/Errors/AppError.swift` for a production-ready implementation of this pattern.

---

#### Issue 2.2.2: Force Unwrapping and Optional Handling

**Current State:**
```swift
// CharterRecord.swift
CharterModel(
    id: UUID(uuidString: id) ?? UUID(), // Masking data corruption
    ...
)

// CharterListView.swift
.task {
    await charterStore.loadCharters()
}
.onAppear {
    Task {
        await charterStore.loadCharters() // Duplicate loading
    }
}
```

**Problems:**
- Using `??` to mask UUID parsing failures
- Duplicate async operations
- No handling of invalid data

**Recommended Refactoring:**

```swift
// CharterRecord.swift
nonisolated func toDomainModel() throws -> CharterModel {
    guard let uuid = UUID(uuidString: id) else {
        throw DatabaseError.corruptedData("Invalid UUID: \(id)")
    }
    
    return CharterModel(
        id: uuid,
        name: name,
        boatName: boatName,
        location: location,
        startDate: startDate,
        endDate: endDate,
        createdAt: createdAt,
        checkInChecklistID: checkInChecklistID.flatMap { UUID(uuidString: $0) }
    )
}

// Update repository
func fetchAllCharters() async throws -> [CharterModel] {
    try await database.dbWriter.read { db in
        try CharterRecord.fetchAll(db: db)
            .compactMap { record in
                try? record.toDomainModel() // Log failures
            }
    }
}
```

**Priority:** 🟡 MEDIUM

---

#### Issue 2.2.3: Magic Numbers and Hardcoded Values

**Current State:**
```swift
// CreateCharterView.swift
private var completionProgress: Double {
    let total = 6.0 // Magic number
    var count = 0.0
    if !form.name.isEmpty { count += 1 }
    // ...
}

// CharterFormState.swift
var guests: Int = 6 // Why 6?
in: 1...12 // Why 12?
```

**Recommended Refactoring:**

```swift
// Core/Constants.swift
enum CharterConstants {
    enum FormCompletion {
        static let totalSteps = 6
        static let requiredFields = ["name", "startDate", "endDate", "region", "vessel", "guests"]
    }
    
    enum GuestLimits {
        static let minimum = 1
        static let maximum = 12
        static let defaultCount = 6
    }
}

// Use constants
private var completionProgress: Double {
    let completedFields = form.completedFieldCount
    return Double(completedFields) / Double(CharterConstants.FormCompletion.totalSteps)
}
```

**Priority:** 🟢 LOW

---

## 3. Data Layer Improvements

### 3.1 ✅ Strengths

- **GRDB Integration**: Excellent offline-first approach
- **Repository Pattern**: Clean abstraction
- **Type Safety**: Strong typing with Records and Models
- **Migrations**: Proper database versioning

### 3.2 ⚠️ Issues & Refactoring Needed

#### Issue 3.2.1: Missing Update and Delete Operations in Store

**Current State:**
```swift
// CharterStore.swift
final class CharterStore {
    func createCharter(...) async throws -> CharterModel { }
    func loadCharters() async { }
    // Missing: update, delete, individual fetch
}
```

**Recommended Refactoring:**

```swift
extension CharterStore {
    @MainActor
    func updateCharter(_ charter: CharterModel) async throws {
        AppLogger.store.startOperation("Update Charter")
        
        do {
            try await repository.saveCharter(charter)
            
            if let index = charters.firstIndex(where: { $0.id == charter.id }) {
                charters[index] = charter
            }
            
            AppLogger.store.completeOperation("Update Charter")
        } catch {
            AppLogger.store.failOperation("Update Charter", error: error)
            throw error
        }
    }
    
    @MainActor
    func deleteCharter(_ charterID: UUID) async throws {
        AppLogger.store.startOperation("Delete Charter")
        
        do {
            try await repository.deleteCharter(charterID)
            charters.removeAll { $0.id == charterID }
            
            AppLogger.store.completeOperation("Delete Charter")
        } catch {
            AppLogger.store.failOperation("Delete Charter", error: error)
            throw error
        }
    }
    
    @MainActor
    func fetchCharter(_ id: UUID) async throws -> CharterModel? {
        try await repository.fetchCharter(id: id)
    }
    
    @MainActor
    func refreshCharters() async throws {
        AppLogger.store.startOperation("Refresh Charters")
        
        do {
            charters = try await repository.fetchAllCharters()
            AppLogger.store.completeOperation("Refresh Charters")
        } catch {
            AppLogger.store.failOperation("Refresh Charters", error: error)
            throw error
        }
    }
}
```

**Priority:** 🔴 HIGH

---

#### Issue 3.2.2: No Data Synchronization Strategy

**Current State:**
- Database has `syncStatus` field but no sync implementation
- No conflict resolution strategy
- No background sync mechanism

**Recommended Refactoring:**

```swift
// Services/SyncService.swift
@MainActor
@Observable
final class SyncService {
    enum SyncState {
        case idle
        case syncing
        case synced(Date)
        case failed(Error)
    }
    
    private let repository: LocalRepository
    private let apiClient: APIClient // To be implemented
    
    var syncState: SyncState = .idle
    
    func syncCharters() async throws {
        syncState = .syncing
        
        do {
            // 1. Fetch pending changes
            let pendingCharters = try await repository.fetchPendingSync()
            
            // 2. Upload to server
            try await apiClient.uploadCharters(pendingCharters)
            
            // 3. Download from server
            let serverCharters = try await apiClient.fetchCharters()
            
            // 4. Resolve conflicts
            let mergedCharters = resolveConflicts(local: pendingCharters, remote: serverCharters)
            
            // 5. Update local database
            for charter in mergedCharters {
                try await repository.saveCharter(charter)
            }
            
            // 6. Mark as synced
            try await repository.markChartersSynced(mergedCharters.map(\.id))
            
            syncState = .synced(Date())
        } catch {
            syncState = .failed(error)
            throw error
        }
    }
    
    private func resolveConflicts(local: [CharterModel], remote: [CharterModel]) -> [CharterModel] {
        // Implement conflict resolution strategy
        // Last-write-wins, manual resolution, etc.
        []
    }
}
```

**Priority:** 🟡 MEDIUM (depends on backend availability)

---

#### Issue 3.2.3: No Offline-First Loading Pattern

**Current State:**
```swift
// CharterStore.swift - Always loads from local database
@MainActor
func loadCharters() async {
    do {
        charters = try await repository.fetchAllCharters()
    } catch {
        AppLogger.store.failOperation("Load Charters", error: error)
    }
}
// No mechanism to refresh from remote server
// No background sync
```

**Problems:**
- No way to sync with backend/server
- Users must manually trigger data refresh
- No background sync mechanism
- Can't distinguish between local and remote data

**Recommended Refactoring (Based on sailaway Pattern):**

```swift
// Core/Stores/CharterStore.swift
// Reference: sailaway/Core/Stores/CharterStore.swift

@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    private(set) var charterState: ViewState<[CharterModel]> = .idle
    
    private let repository: LocalRepository
    private let apiClient: any CharterAPI
    private let syncService: SyncService?
    
    // MARK: - Offline-First Load
    
    /// Load local data immediately, then refresh from server in background
    @MainActor
    func loadChartersOfflineFirst() async {
        AppLogger.store.startOperation("Load Charters (Offline-First)")
        
        // 1. Load from local database immediately (fast)
        await loadCharters()
        
        // 2. Refresh from server in background (don't block UI)
        Task {
            await loadRemoteCharters(preserveExisting: true)
        }
        
        AppLogger.store.completeOperation("Load Charters (Offline-First)")
    }
    
    // MARK: - Local Load
    
    @MainActor
    func loadCharters() async {
        charterState = .loading
        
        do {
            charters = try await repository.fetchAllCharters()
            charterState = charters.isEmpty ? .empty : .loaded(charters)
        } catch {
            charterState = .error(error.asAppError)
        }
    }
    
    // MARK: - Remote Sync
    
    @MainActor
    func loadRemoteCharters(preserveExisting: Bool = false) async {
        AppLogger.store.startOperation("Load Remote Charters")
        
        // Don't show loading spinner if we already have local data
        if !preserveExisting || charters.isEmpty {
            charterState = .loading
        }
        
        do {
            let dtos: [CharterDTO] = try await apiClient.get(path: "/charters", queryItems: nil)
            
            // Save to local database
            for dto in dtos {
                try await repository.saveCharterWithoutQueue(dto.toDomainModel())
            }
            
            // Reload from local database (source of truth)
            charters = try await repository.fetchAllCharters()
            charterState = charters.isEmpty ? .empty : .loaded(charters)
            
            AppLogger.store.completeOperation("Load Remote Charters")
        } catch {
            let appError = error.asAppError
            
            // If we have local data and were just refreshing, keep showing it
            if preserveExisting, !charters.isEmpty {
                charterState = .loaded(charters)
                AppLogger.store.warning("Remote sync failed but keeping local data", error: error)
                return
            }
            
            charterState = .error(appError)
            AppLogger.store.failOperation("Load Remote Charters", error: error)
        }
    }
    
    // MARK: - Create/Update/Delete
    
    @MainActor
    func createCharter(...) async throws -> CharterModel {
        // Create on server
        let dto: CharterDTO = try await apiClient.post(path: "/charters", body: request)
        let charter = dto.toDomainModel()
        
        // Save to local database (without queueing since already synced)
        try await repository.createCharterWithoutQueue(charter)
        try await repository.markChartersSynced([charter.id])
        
        // Update local state
        charters.append(charter)
        charterState = .loaded(charters)
        
        return charter
    }
    
    @MainActor
    func updateCharter(_ charter: CharterModel) async throws {
        // Update on server
        let dto: CharterDTO = try await apiClient.patch(
            path: "/charters/\(charter.id.uuidString)",
            body: request
        )
        let updated = dto.toDomainModel()
        
        // Update local database
        try await repository.saveCharter(updated)
        
        // Update local state
        if let index = charters.firstIndex(where: { $0.id == updated.id }) {
            charters[index] = updated
            charterState = .loaded(charters)
        }
    }
    
    @MainActor
    func deleteCharter(_ charter: CharterModel) async throws {
        // Delete from local database (sync service will handle server deletion)
        try await repository.deleteCharter(charter.id)
        
        // Update local state
        charters.removeAll { $0.id == charter.id }
        charterState = charters.isEmpty ? .empty : .loaded(charters)
    }
}

// MARK: - CharterAPI Protocol
protocol CharterAPI: Sendable {
    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]?
    ) async throws -> T
    
    func post<T: Decodable, B: Encodable>(
        path: String,
        body: B
    ) async throws -> T
    
    func patch<T: Decodable, B: Encodable>(
        path: String,
        body: B
    ) async throws -> T
    
    func delete(path: String) async throws
}
```

**Usage in Views:**

```swift
struct CharterListView: View {
    @Environment(\.charterStore) private var charterStore
    
    var body: some View {
        charterContent
            .refreshable {
                await charterStore.loadRemoteCharters(preserveExisting: true)
            }
            .task {
                // Load offline-first on appear
                if charterStore.charterState.isIdle {
                    await charterStore.loadChartersOfflineFirst()
                }
            }
    }
}
```

**Benefits:**
- ✅ Instant UI response (shows cached data immediately)
- ✅ Works fully offline
- ✅ Background refresh without disrupting UX
- ✅ Graceful error handling (keeps cached data on sync failure)
- ✅ Pull-to-refresh support built-in
- ✅ Clear separation between local and remote operations

**Priority:** 🟡 MEDIUM (High value for user experience)

**Reference:** See `sailaway/Core/Stores/CharterStore.swift` lines 75-202 for production implementation.

---

## 4. UI/UX Improvements

### 4.1 ✅ Strengths

- **Design System**: Well-organized, consistent styling
- **Accessibility**: Good foundation with semantic labels
- **Previews**: Comprehensive preview coverage
- **Dark Mode**: Proper support with dynamic colors

### 4.2 ⚠️ Issues & Refactoring Needed

#### Issue 4.2.1: Missing Loading and Empty States

**Current State:**
```swift
// CharterListView.swift
var body: some View {
    Group {
        if charterStore.charters.isEmpty {
            emptyState
        } else {
            charterList
        }
    }
    // No loading state
}
```

**Recommended Refactoring (Using sailaway's ViewState Pattern):**

**This issue is solved by implementing the ViewState<T> pattern from Issue 2.2.1 above.**

```swift
// Reference: sailaway/Core/Models/ViewState.swift
// Already covered in Issue 2.2.1

// CharterStore usage
@Observable
final class CharterStore {
    private(set) var charterState: ViewState<[CharterModel]> = .idle
    private(set) var charters: [CharterModel] = []
}

// View implementation
struct CharterListView: View {
    @Environment(\.charterStore) private var charterStore
    
    var body: some View {
        Group {
            switch charterStore.charterState {
            case .idle:
                // Initial state before first load
                EmptyView()
                
            case .loading:
                DesignSystem.LoadingView(message: "Loading your charters...")
                
            case .loaded:
                if charterStore.charters.isEmpty {
                    emptyState
                } else {
                    charterList
                }
                
            case .empty:
                emptyState
                
            case .error(let error):
                DesignSystem.ErrorView(
                    error: error,
                    retry: error.isRetryable ? {
                        await charterStore.loadCharters()
                    } : nil
                )
            }
        }
        .task {
            if charterStore.charterState.isIdle {
                await charterStore.loadCharters()
            }
        }
    }
    
    private var charterList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(charterStore.charters) { charter in
                    CharterRowView(charter: charter)
                }
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Charters",
            systemImage: "calendar.badge.plus",
            description: Text("Create your first charter to get started")
        )
    }
}

// Reusable loading component
extension DesignSystem {
    struct LoadingView: View {
        let message: String?
        
        init(message: String? = nil) {
            self.message = message
        }
        
        var body: some View {
            VStack(spacing: Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                
                if let message {
                    Text(message)
                        .font(Typography.body)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

**Priority:** 🟡 MEDIUM (Implemented automatically with ViewState pattern)

**Reference:** See `sailaway/Core/Models/ViewState.swift` and `sailaway/Core/Stores/CharterStore.swift` for production implementation.

---

#### Issue 4.2.2: No Pull-to-Refresh

**Current State:**
- Users cannot manually refresh data
- No way to sync with backend

**Recommended Refactoring:**

**This issue is solved by implementing the offline-first pattern from Issue 3.2.3 above.**

```swift
struct CharterListView: View {
    @Environment(\.charterStore) private var charterStore
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(charterStore.charters) { charter in
                    CharterRowView(charter: charter)
                }
            }
        }
        .refreshable {
            // Refresh from server, keeping existing data visible
            await charterStore.loadRemoteCharters(preserveExisting: true)
        }
        .task {
            // Initial load: offline-first
            if charterStore.charterState.isIdle {
                await charterStore.loadChartersOfflineFirst()
            }
        }
    }
}
```

**Priority:** 🟢 LOW (Implemented automatically with offline-first pattern from Issue 3.2.3)

---

#### Issue 4.2.3: Missing Form Validation Feedback

**Current State:**
```swift
// CharterSummaryCard.swift
private var isValid: Bool {
    !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    form.endDate >= form.startDate
}

// No visual feedback on what's invalid
```

**Recommended Refactoring:**

```swift
// Features/Charter/CharterFormValidation.swift
struct CharterFormValidation {
    enum ValidationError: LocalizedError {
        case emptyName
        case invalidDateRange
        case emptyDestination
        case emptyVessel
        
        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Charter name is required"
            case .invalidDateRange:
                return "End date must be after start date"
            case .emptyDestination:
                return "Destination is required"
            case .emptyVessel:
                return "Vessel is required"
            }
        }
    }
    
    static func validate(_ form: CharterFormState) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        if form.endDate < form.startDate {
            errors.append(.invalidDateRange)
        }
        
        return errors
    }
}

// In ViewModel
@Published var validationErrors: [CharterFormValidation.ValidationError] = []

func validateForm() {
    validationErrors = CharterFormValidation.validate(form)
}

// In View - show inline errors
if viewModel.validationErrors.contains(.emptyName) {
    Text("Charter name is required")
        .font(.caption)
        .foregroundColor(.red)
}
```

**Priority:** 🟡 MEDIUM

---

## 5. Performance Optimizations

### 5.1 ⚠️ Issues & Refactoring Needed

#### Issue 5.1.1: Inefficient List Rendering

**Current State:**
```swift
// CharterRowView.swift - Complex rendering for each row
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}
// Creates new formatter for every row!
```

**Recommended Refactoring:**

```swift
// Core/Utilities/Formatters.swift
enum Formatters {
    static let dateShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let dateMedium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// Use in views
Text(Formatters.dateMedium.string(from: charter.startDate))
```

**Priority:** 🟡 MEDIUM

---

#### Issue 5.1.2: No Pagination for Large Lists

**Current State:**
```swift
// CharterListView.swift
LazyVStack {
    ForEach(charterStore.charters) { charter in
        CharterRowView(charter: charter)
    }
}
// Will load ALL charters at once
```

**Recommended Refactoring:**

```swift
// CharterStore.swift
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    private var hasMoreCharters = true
    private let pageSize = 20
    private var currentPage = 0
    
    @MainActor
    func loadMoreChartersIfNeeded(currentCharter: CharterModel?) async {
        guard hasMoreCharters else { return }
        
        guard let currentCharter else {
            await loadInitialCharters()
            return
        }
        
        let thresholdIndex = charters.index(charters.endIndex, offsetBy: -5)
        if let currentIndex = charters.firstIndex(where: { $0.id == currentCharter.id }),
           currentIndex >= thresholdIndex {
            await loadNextPage()
        }
    }
    
    private func loadNextPage() async {
        // Implement pagination
    }
}

// In view
ForEach(charterStore.charters) { charter in
    CharterRowView(charter: charter)
        .onAppear {
            Task {
                await charterStore.loadMoreChartersIfNeeded(currentCharter: charter)
            }
        }
}
```

**Priority:** 🟢 LOW (depends on data volume)

---

#### Issue 5.1.3: No Filtered Data Properties

**Current State:**
```swift
// CharterStore.swift
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    // No filtered views
}

// Views have to filter manually
struct HomeView: View {
    @Environment(\.charterStore) private var charterStore
    
    var body: some View {
        let activeCharter = charterStore.charters.first { $0.isActive }
        // Filtering logic in view
    }
}
```

**Problems:**
- Filtering logic scattered across views
- No reuse of common filters
- Performance impact (re-filtering on every view update)
- Hard to test filtering logic

**Recommended Refactoring (Based on sailaway Pattern):**

```swift
// Core/Stores/CharterStore.swift
// Reference: sailaway/Core/Stores/CharterStore.swift
@Observable
final class CharterStore {
    private(set) var charters: [CharterModel] = []
    
    // MARK: - Computed Filtered Views
    
    /// Currently active charter (if any)
    var activeCharter: CharterModel? {
        charters.first { $0.isActive }
    }
    
    /// Past charters (ended before today)
    var pastCharters: [CharterModel] {
        charters.filter { !$0.isActive && $0.endDate < Date() }
            .sorted { $0.endDate > $1.endDate } // Most recent first
    }
    
    /// Upcoming charters (starting in the future)
    var upcomingCharters: [CharterModel] {
        charters.filter { !$0.isActive && $0.startDate > Date() }
            .sorted { $0.startDate < $1.startDate } // Soonest first
    }
    
    /// Charters in progress (between start and end date)
    var inProgressCharters: [CharterModel] {
        let now = Date()
        return charters.filter { !$0.isActive && $0.startDate <= now && $0.endDate >= now }
    }
    
    /// Archived charters
    var archivedCharters: [CharterModel] {
        charters.filter { $0.isArchived }
    }
    
    /// Active (non-archived) charters
    var activeCharters: [CharterModel] {
        charters.filter { !$0.isArchived }
    }
    
    /// Total count of active charters
    var activeCharterCount: Int {
        activeCharters.count
    }
}

// Usage in views
struct HomeView: View {
    @Environment(\.charterStore) private var charterStore
    
    var body: some View {
        VStack {
            if let active = charterStore.activeCharter {
                ActiveCharterCard(charter: active)
            }
            
            Section("Upcoming") {
                ForEach(charterStore.upcomingCharters) { charter in
                    CharterRowView(charter: charter)
                }
            }
        }
    }
}
```

**Benefits:**
- ✅ Single source of truth (only `charters` array)
- ✅ No manual synchronization needed
- ✅ Centralized filtering logic (easier to test)
- ✅ Consistent filtering across the app
- ✅ SwiftUI automatically updates when `charters` changes
- ✅ Clean, readable view code

**Testing:**

```swift
@Test("CharterStore - filtered properties work correctly")
@MainActor
func testFilteredProperties() async throws {
    let store = CharterStore(repository: MockLocalRepository())
    
    let now = Date()
    let past = CharterModel(
        id: UUID(),
        name: "Past Charter",
        startDate: now.addingTimeInterval(-14 * 86400), // 14 days ago
        endDate: now.addingTimeInterval(-7 * 86400), // 7 days ago
        isActive: false
    )
    
    let upcoming = CharterModel(
        id: UUID(),
        name: "Upcoming Charter",
        startDate: now.addingTimeInterval(7 * 86400), // 7 days from now
        endDate: now.addingTimeInterval(14 * 86400), // 14 days from now
        isActive: false
    )
    
    store.charters = [past, upcoming]
    
    #expect(store.pastCharters.count == 1)
    #expect(store.pastCharters.first?.id == past.id)
    #expect(store.upcomingCharters.count == 1)
    #expect(store.upcomingCharters.first?.id == upcoming.id)
}
```

**Priority:** 🟡 MEDIUM (Improves code quality and maintainability)

**Reference:** See `sailaway/Core/Stores/CharterStore.swift` lines 46-59 for production implementation.

---

## 6. Testing Strategy

### 6.1 ✅ Strengths

- **Swift Testing**: Modern testing framework
- **Mock Repository**: Good testing infrastructure
- **Unit Tests**: Good coverage for `CharterStore`

### 6.2 ⚠️ Issues & Refactoring Needed

#### Issue 6.2.1: Missing Integration Tests

**Current State:**
- Only unit tests with mocks
- No tests for actual database operations
- No UI tests beyond basic launch tests

**Recommended Additions:**

```swift
// Tests/Integration/CharterRepositoryIntegrationTests.swift
@Suite("Charter Repository Integration Tests")
struct CharterRepositoryIntegrationTests {
    
    @Test("Create and fetch charter - full cycle")
    func testCreateAndFetchCharter() async throws {
        // Use real database (in-memory for tests)
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        
        let charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Create
        try await repository.createCharter(charter)
        
        // Fetch
        let fetched = try await repository.fetchCharter(id: charter.id)
        
        // Assert
        #expect(fetched?.id == charter.id)
        #expect(fetched?.name == charter.name)
    }
}
```

**Priority:** 🟡 MEDIUM

---

#### Issue 6.2.2: No Snapshot Tests for UI

**Recommended Addition:**

```swift
// Add swift-snapshot-testing dependency
// Tests/UI/CharterListSnapshotTests.swift
import SnapshotTesting

@Suite("Charter List Snapshot Tests")
struct CharterListSnapshotTests {
    
    @Test("Charter list empty state")
    func testEmptyState() {
        let view = CharterListView()
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13)))
    }
    
    @Test("Charter list with items")
    func testWithCharters() {
        // Setup mock data
        let view = CharterListView()
        assertSnapshot(matching: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

**Priority:** 🟢 LOW

---

## 7. Navigation & Routing

### 7.1 ✅ Strengths

- **Type-Safe Routes**: `AppRoute` enum is excellent
- **Coordinator Pattern**: Good separation of navigation logic
- **Per-Tab Navigation**: Proper independent navigation stacks

### 7.2 ⚠️ Issues & Refactoring Needed

#### Issue 7.2.1: Incomplete Navigation Implementation

**Current State:**
```swift
// AppModel.swift
enum AppRoute: Hashable {
    case createCharter
    case charterDetail(UUID)
    
    // TODO: Add more routes...
}

// AppView.swift
case .charterDetail(let id):
    // TODO: Implement CharterDetailView when ready
    Text("Charter Detail: \(id.uuidString)")
```

**Recommended Completion:**

```swift
// App/AppModel.swift
enum AppRoute: Hashable {
    // Charters
    case createCharter
    case charterDetail(UUID)
    case editCharter(UUID)
    
    // Checklists
    case checklistList
    case checklistDetail(UUID)
    case createChecklist
    case editChecklist(UUID)
    case executeChecklist(charterID: UUID, checklistID: UUID)
    
    // Library
    case library
    case guideDetail(UUID)
    case deckDetail(UUID)
    
    // Profile
    case profile
    case settings
    case about
}

// Add deep linking support
extension AppCoordinator {
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            return
        }
        
        switch host {
        case "charter":
            if let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: idString) {
                navigateToCharter(id)
            }
        case "checklist":
            // Handle checklist deep links
            break
        default:
            break
        }
    }
}
```

**Priority:** 🟡 MEDIUM

---

## 8. Code Organization & Structure

### 8.1 ✅ Strengths

- **Feature-Based Organization**: Clear folder structure
- **Separation of Concerns**: Good layer separation
- **Naming Conventions**: Consistent and clear

### 8.2 ⚠️ Issues & Refactoring Needed

#### Issue 8.2.1: Inconsistent File Organization

**Current Structure:**
```
Features/
  Charter/
    CreateCharterView.swift
    CharterListView.swift
    CharterFormState.swift  // Not a view
    Components/
      BudgetSection.swift
```

**Recommended Structure:**

```
Features/
  Charter/
    Views/
      CreateCharterView.swift
      CharterListView.swift
      CharterDetailView.swift
    ViewModels/
      CreateCharterViewModel.swift
      CharterListViewModel.swift
      CharterDetailViewModel.swift
    Models/
      CharterFormState.swift
      CharterListFilter.swift
    Components/
      BudgetSection.swift
      CrewSection.swift
      DateRangeSection.swift
```

**Priority:** 🟢 LOW

---

#### Issue 8.2.2: Scattered Environment Keys

**Current State:**
```swift
// CharterStore.swift
private struct CharterStoreKey: EnvironmentKey {
    static var defaultValue: CharterStore {
        MainActor.assumeIsolated {
            AppDependencies().charterStore
        }
    }
}

extension EnvironmentValues {
    var charterStore: CharterStore {
        get { self[CharterStoreKey.self] }
        set { self[CharterStoreKey.self] = newValue }
    }
}

// AppCoordinator.swift
private struct AppCoordinatorKey: EnvironmentKey {
    static let defaultValue = AppCoordinator()
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}
```

**Problems:**
- Environment keys scattered across multiple files
- Hard to discover all available environment values
- Inconsistent default value patterns
- Maintenance overhead

**Recommended Refactoring (Based on sailaway Pattern):**

```swift
// Core/Environment/EnvironmentKeys.swift
// Reference: sailaway/Core/Stores/EnvironmentKeys.swift
import SwiftUI

// MARK: - Local Repository

private struct LocalRepositoryKey: EnvironmentKey {
    static var defaultValue: LocalRepository {
        LocalRepository()
    }
}

extension EnvironmentValues {
    var localRepository: LocalRepository {
        get { self[LocalRepositoryKey.self] }
        set { self[LocalRepositoryKey.self] = newValue }
    }
}

// MARK: - Charter Store

private struct CharterStoreKey: EnvironmentKey {
    static var defaultValue: CharterStore {
        CharterStore()
    }
}

extension EnvironmentValues {
    var charterStore: CharterStore {
        get { self[CharterStoreKey.self] }
        set { self[CharterStoreKey.self] = newValue }
    }
}

// MARK: - App Coordinator

private struct AppCoordinatorKey: EnvironmentKey {
    static var defaultValue: AppCoordinator {
        AppCoordinator()
    }
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}

// MARK: - App Model

private struct AppModelKey: EnvironmentKey {
    static var defaultValue: AppModel {
        AppModel()
    }
}

extension EnvironmentValues {
    var appModel: AppModel {
        get { self[AppModelKey.self] }
        set { self[AppModelKey.self] = newValue }
    }
}

// MARK: - Localization Service

private struct LocalizationServiceKey: EnvironmentKey {
    static var defaultValue: LocalizationService {
        LocalizationService()
    }
}

extension EnvironmentValues {
    var localizationService: LocalizationService {
        get { self[LocalizationServiceKey.self] }
        set { self[LocalizationServiceKey.self] = newValue }
    }
}
```

**Benefits:**
- ✅ Single file for all environment keys
- ✅ Easy to discover available environment values
- ✅ Consistent patterns and default values
- ✅ Better maintainability
- ✅ Cleaner separation of concerns

**Migration Steps:**
1. Create `Core/Environment/EnvironmentKeys.swift`
2. Move all environment key definitions to this file
3. Remove environment key definitions from individual files
4. Update imports in files that use environment values

**Priority:** 🟢 LOW (Nice to have for organization)

**Reference:** See `sailaway/Core/Stores/EnvironmentKeys.swift` for production implementation.

---

## 9. Localization

### 9.1 ✅ Strengths

- **L10n Structure**: Clean enum-based approach
- **Multiple Languages**: Russian and English support
- **Localization Service**: Good abstraction

### 9.2 ⚠️ Issues & Refactoring Needed

#### Issue 9.2.1: Unused LocalizationService

**Current State:**
- `LocalizationService` exists but is never used
- Views use `L10n` directly
- No ability to change language at runtime

**Recommended Integration:**

```swift
// anyfleetApp.swift
@main
struct anyfleetApp: App {
    @StateObject private var localizationService = LocalizationService()
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.localization, localizationService)
        }
    }
}

// Update L10n to use service
enum L10n {
    @MainActor
    static func localized(_ key: String) -> String {
        // Get from environment or default service
        LocalizationService().localized(key)
    }
}
```

**Priority:** 🟢 LOW

---

## 10. Security & Privacy

### 10.1 ⚠️ Issues & Refactoring Needed

#### Issue 10.1.1: No Data Encryption

**Current State:**
- SQLite database is unencrypted
- Sensitive charter data stored in plain text

**Recommended Addition:**

```swift
// Update AppDatabase.swift to use SQLCipher
#if canImport(SQLCipher)
import SQLCipher

// In makeShared()
let config = Configuration()
config.prepareDatabase { db in
    let key = KeychainService.getDatabaseKey() ?? KeychainService.generateAndSaveDatabaseKey()
    try db.execute(sql: "PRAGMA key = '\(key)'")
}
#endif
```

**Priority:** 🔴 HIGH (for production)

---

## 11. Documentation

### 11.1 ⚠️ Missing Documentation

**Current State:**
- Minimal inline documentation
- No API documentation
- No architecture documentation

**Recommended Additions:**

1. **Add DocC documentation catalog**
2. **Document public APIs with DocC comments:**

```swift
/// Manages the charter lifecycle including creation, updates, and deletion.
///
/// `CharterStore` is the central point for charter-related operations in the app.
/// It maintains an in-memory cache of charters and synchronizes with the local
/// database through the repository layer.
///
/// ## Usage
///
/// ```swift
/// let store = CharterStore(repository: LocalRepository())
/// await store.loadCharters()
/// ```
///
/// - Important: This class must be accessed from the main actor.
/// - Note: Charter operations are automatically logged using `AppLogger`.
@MainActor
@Observable
final class CharterStore {
    // ...
}
```

3. **Create README files for each module**

**Priority:** 🟡 MEDIUM

---

## 12. Implementation Priority Matrix

### Phase 1: Critical (Next Sprint) ✅ **COMPLETED**
1. ✅ Implement proper dependency injection (AppDependencies)
2. ✅ Fix state management inconsistencies (@Observable pattern)
3. ✅ Environment-based DI with custom EnvironmentKeys
4. ✅ Add testing support (AppDependencies.makeForTesting)

### Phase 2: High Value (Sprint 2-3) - **Learn from sailaway**
1. 🔴 **Implement ViewState<T> Pattern** (Issue 2.2.1)
   - Reference: `sailaway/Core/Models/ViewState.swift`
   - Impact: Unifies loading/error/data states across the app
2. 🔴 **Create AppError Hierarchy** (Issue 2.2.1)
   - Reference: `sailaway/Core/Errors/AppError.swift`
   - Impact: User-friendly error messages and retry logic
3. 🟡 **Implement Offline-First Loading** (Issue 3.2.3)
   - Reference: `sailaway/Core/Stores/CharterStore.swift`
   - Impact: Better UX, offline support, background sync
4. 🟡 **Add Computed Filtered Properties** (Issue 5.1.3)
   - Reference: `sailaway/Core/Stores/CharterStore.swift` (lines 46-59)
   - Impact: Cleaner view code, single source of truth
5. ✅ Complete CRUD operations in CharterStore (Issue 3.2.1)

### Phase 3: Important (Sprint 3-4)
1. Create ViewModels for all features (Issue 1.2.3)
2. Implement data validation with ValidationError (Issue 4.2.3)
3. Add integration tests (Issue 6.2.1)
4. Complete navigation implementation (Issue 7.2.1)
5. Centralize environment keys (Issue 8.2.2)
   - Reference: `sailaway/Core/Stores/EnvironmentKeys.swift`

### Phase 4: Nice to Have (Sprint 5+)
1. Add pagination (Issue 5.1.2)
2. Implement full sync service (Issue 3.2.2)
   - Reference: `sailaway/Services/SyncService.swift`
3. Add snapshot tests (Issue 6.2.2)
4. Reorganize file structure (Issue 8.2.1)
5. Add comprehensive documentation (Issue 11.1)
6. Optimize performance (Issue 5.1.1)
7. Add data encryption (Issue 10.1.1)

---

## 13. Refactoring Checklist

### Phase 1: Critical Foundation ✅ **COMPLETED**
- [x] Create feature branch: `refactor/state-management`
- [x] Implement `AppDependencies` container
- [x] Convert to single `CharterStore` instance
- [x] Standardize on `@Observable` pattern
- [x] Update all views to use `@Environment` with custom keys
- [x] Add testing support (`AppDependencies.makeForTesting()`)
- [x] All tests passing

### Phase 2: sailaway Patterns (High Priority)
- [ ] **Implement ViewState<T> Pattern**
  - [ ] Create `Core/Models/ViewState.swift`
  - [ ] Update `CharterStore` to use `charterState: ViewState<[CharterModel]>`
  - [ ] Update views to switch on `charterState`
  - [ ] Add tests for ViewState
- [ ] **Create AppError Hierarchy**
  - [ ] Create `Core/Errors/AppError.swift`
  - [ ] Define `DatabaseError`, `NetworkError`, `ValidationError`, `SyncError`
  - [ ] Add `isRetryable` and `localizedMessage` properties
  - [ ] Implement `Error.asAppError` extension
  - [ ] Add reusable `ErrorView` component
- [ ] **Implement Offline-First Loading**
  - [ ] Add `loadChartersOfflineFirst()` to CharterStore
  - [ ] Add `loadRemoteCharters(preserveExisting:)` for background refresh
  - [ ] Create `CharterAPI` protocol abstraction
  - [ ] Update views to use offline-first loading
  - [ ] Add pull-to-refresh support
- [ ] **Add Computed Filtered Properties**
  - [ ] Add `activeCharter` computed property
  - [ ] Add `pastCharters` computed property
  - [ ] Add `upcomingCharters` computed property
  - [ ] Update views to use computed properties
  - [ ] Add tests for filtered properties

### Phase 3: Code Quality Improvements
- [ ] **Centralize Environment Keys**
  - [ ] Create `Core/Environment/EnvironmentKeys.swift`
  - [ ] Move all environment key definitions to this file
  - [ ] Remove environment keys from individual files
- [ ] **Add Missing CRUD Operations**
  - [ ] Implement `updateCharter()` in CharterStore
  - [ ] Implement `deleteCharter()` in CharterStore
  - [ ] Implement `fetchCharter(id:)` in CharterStore
  - [ ] Add tests for all CRUD operations
- [ ] **Create ViewModels**
  - [ ] `CreateCharterViewModel`
  - [ ] `CharterListViewModel`
  - [ ] `CharterDetailViewModel`
- [ ] **Form Validation**
  - [ ] Implement `ValidationError` enum
  - [ ] Add validation methods to ViewModels
  - [ ] Add inline error display in forms

### Phase 4: Testing & Documentation
- [ ] **Integration Tests**
  - [ ] Repository integration tests with real database
  - [ ] Store integration tests with repository
  - [ ] End-to-end charter creation flow
- [ ] **Documentation**
  - [ ] Add DocC comments to public APIs
  - [ ] Create architecture diagram
  - [ ] Update README with patterns used
  - [ ] Document sailaway pattern references

### Phase 5: Performance & Polish
- [ ] Create shared formatters utility
- [ ] Add pagination for large lists
- [ ] Implement full sync service
- [ ] Add snapshot tests
- [ ] Optimize database queries

---

## 14. Estimated Effort

**Total Estimated Effort:** 5-7 weeks (1 senior developer)

- **Phase 1 (Critical Foundation):** ✅ **COMPLETED** (~2 weeks)
  - AppDependencies implementation
  - @Observable standardization
  - Environment-based DI
  - Testing support

- **Phase 2 (sailaway Patterns - High Priority):** 2-3 weeks
  - ViewState<T> implementation: 2-3 days
  - AppError hierarchy: 2-3 days
  - Offline-first loading: 3-4 days
  - Computed properties: 1 day
  - Integration and testing: 2-3 days

- **Phase 3 (Code Quality):** 1-2 weeks
  - Centralized environment keys: 1 day
  - CRUD operations: 2-3 days
  - ViewModels: 3-4 days
  - Form validation: 2 days

- **Phase 4 (Testing & Docs):** 1 week
  - Integration tests: 2-3 days
  - Documentation: 2-3 days

- **Phase 5 (Performance & Polish):** 1 week (as time permits)

**Recommended Approach:** 

1. **Phase 1 is complete** ✅ - Foundation is solid
2. **Focus on Phase 2 next** - These are high-impact patterns proven in sailaway:
   - ViewState<T> dramatically improves state management
   - AppError provides excellent UX
   - Offline-first is a game-changer for user experience
3. **Phase 3** can be done incrementally alongside new feature development
4. **Phases 4-5** items as time permits

**Shortcut Available:** Since sailaway has production-ready implementations of Phase 2 patterns, significant time can be saved by adapting those implementations rather than building from scratch. With code reference, Phase 2 could be completed in 1.5-2 weeks instead of 2-3 weeks.

---

## 15. Final Recommendations

### Immediate Actions (Learn from sailaway)
1. **✅ Implement ViewState<T> Pattern**: Unifies loading, error, and data states (see Issue 2.2.1)
   - Reference: `sailaway/Core/Models/ViewState.swift`
2. **✅ Create AppError Hierarchy**: Comprehensive error handling with user-friendly messages (see Issue 2.2.1)
   - Reference: `sailaway/Core/Errors/AppError.swift`
3. **✅ Implement Offline-First Loading**: Better UX and offline support (see Issue 3.2.3)
   - Reference: `sailaway/Core/Stores/CharterStore.swift`
4. **Complete CRUD Operations**: Essential for basic functionality (see Issue 3.2.1)

### Short-Term Goals
1. **✅ Standardize on @Observable**: Swift 6's observation is the way forward (already done in Phase 1)
2. **✅ Environment-Based DI**: Already implemented in AppDependencies
3. **Add Computed Properties**: For filtered data views (see Issue 5.1.3)
   - Reference: `sailaway/Core/Stores/CharterStore.swift`
4. **Centralize Environment Keys**: Single file for all environment values (see Issue 8.2.2)
   - Reference: `sailaway/Core/Stores/EnvironmentKeys.swift`
5. **Create Comprehensive ViewModels**: Improves testability and maintainability (see Issue 1.2.3)

### Long-Term Vision
1. **Build Sync Layer**: For multi-device support (see Issue 3.2.2)
   - Reference: `sailaway/Services/SyncService.swift`
2. **Performance Optimization**: As data grows (see Issue 5.1.2)
3. **Comprehensive Testing**: For production confidence (see Issue 6.2.1)
4. **Add Data Encryption**: For production security (see Issue 10.1.1)

### Key Takeaways from sailaway

The **sailaway** project demonstrates several production-ready patterns that should be adopted:

1. **✨ ViewState<T>**: Single source of truth for async operation states
2. **✨ AppError**: Comprehensive error handling with retry logic and user messages
3. **✨ Offline-First**: Load local data immediately, sync in background
4. **✨ Protocol Abstractions**: Testable API clients via protocols
5. **✨ Computed Properties**: Filtered views without manual synchronization
6. **✨ Centralized Environment Keys**: Single file for all DI keys
7. **✨ @MainActor Isolation**: Only where truly needed (e.g., UserStore)
8. **✨ nonisolated init**: With default parameters for easy testing

### Migration Priority from sailaway Patterns

**Phase 1 (Critical - Do First):**
1. ✅ ViewState<T> enum pattern (Issue 2.2.1)
2. ✅ AppError hierarchy (Issue 2.2.1)
3. ✅ Offline-first loading (Issue 3.2.3)

**Phase 2 (High Value - Do Next):**
4. Computed filtered properties (Issue 5.1.3)
5. Centralized environment keys (Issue 8.2.2)
6. Protocol abstractions for API (Issue 3.2.3)

**Phase 3 (Nice to Have):**
7. Enhanced formatters (Issue 5.1.1)
8. Pagination (Issue 5.1.2)
9. Comprehensive documentation (Issue 11.1)

---

## Conclusion

The anyfleet codebase is well-structured and demonstrates strong understanding of modern iOS development practices. After refactoring Phase 1 (state management and dependency injection), the codebase is now much closer to production quality.

**Remaining areas for improvement:**

1. **Error Handling**: Adopt sailaway's ViewState<T> and AppError patterns for comprehensive error handling
2. **Offline-First UX**: Implement sailaway's offline-first loading pattern for better user experience
3. **Code Organization**: Centralize environment keys and add computed filtered properties
4. **Completeness**: Finish remaining CRUD operations and navigation implementation

**Key Learning:** The sailaway project serves as an excellent reference implementation, demonstrating that these patterns work well in production and should be adopted in anyfleet.

With the patterns from sailaway applied, the anyfleet codebase will be:
- ✅ Production-ready
- ✅ Highly maintainable
- ✅ Well-tested
- ✅ User-friendly (offline support, better error handling)
- ✅ Following modern iOS best practices

---

## 16. Quick Reference: sailaway Patterns

This section provides a quick lookup for sailaway pattern implementations that should be adopted in anyfleet.

### Pattern 1: ViewState<T>
**File:** `sailaway/Core/Models/ViewState.swift`  
**Lines:** 1-125  
**Usage:** Unified state management for async operations  
**Adopt in:** Issue 2.2.1, Issue 4.2.1

```swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(AppError)
}
```

### Pattern 2: AppError Hierarchy
**File:** `sailaway/Core/Errors/AppError.swift`  
**Lines:** 1-388  
**Usage:** Comprehensive error handling with user messages  
**Adopt in:** Issue 2.2.1

```swift
enum AppError: Error, Identifiable {
    case network(NetworkError)
    case auth(AuthError)
    case validation(ValidationError)
    // ...
    var isRetryable: Bool { ... }
    var localizedMessage: String { ... }
}
```

### Pattern 3: Offline-First Loading
**File:** `sailaway/Core/Stores/CharterStore.swift`  
**Lines:** 75-202  
**Usage:** Load local data first, sync in background  
**Adopt in:** Issue 3.2.3

```swift
@MainActor
func loadChartersOfflineFirst() async {
    await loadCharters() // Local first
    Task { await loadRemoteCharters(preserveExisting: true) } // Background refresh
}
```

### Pattern 4: Environment-Based DI
**File:** `sailaway/sailawayApp.swift`  
**Lines:** 33-48  
**Usage:** Initialize dependencies once, inject via environment  
**Adopt in:** ✅ Already implemented in anyfleet

```swift
init() {
    let repository = LocalRepository(database: .shared)
    _charterStore = State(initialValue: CharterStore(repository: repository))
}
```

### Pattern 5: Centralized Environment Keys
**File:** `sailaway/Core/Stores/EnvironmentKeys.swift`  
**Lines:** 1-108  
**Usage:** All environment keys in one file  
**Adopt in:** Issue 8.2.2

```swift
private struct CharterStoreKey: EnvironmentKey {
    static var defaultValue: CharterStore { CharterStore() }
}
```

### Pattern 6: Computed Filtered Properties
**File:** `sailaway/Core/Stores/CharterStore.swift`  
**Lines:** 46-59  
**Usage:** Filtered views without manual sync  
**Adopt in:** Issue 5.1.3

```swift
var activeCharter: CharterModel? { charters.first { $0.isActive } }
var pastCharters: [CharterModel] { charters.filter { ... } }
```

### Pattern 7: Protocol Abstractions
**File:** `sailaway/Core/Stores/CharterStore.swift`  
**Lines:** 11-30  
**Usage:** Testable API clients  
**Adopt in:** Issue 3.2.3

```swift
protocol CharterAPI: Sendable {
    func get<T: Decodable>(path: String) async throws -> T
}
```

### Pattern 8: nonisolated init with Defaults
**File:** `sailaway/Core/Stores/CharterStore.swift`  
**Lines:** 63-71  
**Usage:** Testable stores with dependency injection  
**Adopt in:** ✅ Already implemented in anyfleet

```swift
nonisolated init(
    repository: LocalRepository = LocalRepository(),
    apiClient: any CharterAPI = APIClient.shared
) { ... }
```

---

**Review Completed By:** Senior iOS Developer  
**Last Updated:** December 15, 2025  
**sailaway Patterns Analyzed:** December 15, 2025  
**Next Review Date:** After Phase 2 completion (sailaway patterns adoption)

