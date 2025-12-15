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

**Recommended Refactoring:**

1. **Create Structured Error Types:**
```swift
// Core/Models/AppError.swift
enum AppError: LocalizedError, Identifiable {
    case database(DatabaseError)
    case network(NetworkError)
    case validation(ValidationError)
    case unknown(Error)
    
    var id: String { errorDescription ?? "unknown" }
    
    var errorDescription: String? {
        switch self {
        case .database(let error):
            return error.localizedDescription
        case .network(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .database:
            return "Please try again. If the problem persists, contact support."
        case .network:
            return "Please check your internet connection and try again."
        case .validation:
            return "Please check your input and try again."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

enum DatabaseError: LocalizedError {
    case readFailed
    case writeFailed
    case migrationFailed
    case corrupted
}

enum ValidationError: LocalizedError {
    case emptyName
    case invalidDateRange
    case missingRequiredFields
}
```

2. **Implement Result Type Pattern:**
```swift
// Core/Models/Result+Extensions.swift
extension CharterStore {
    @MainActor
    func loadCharters() async -> Result<Void, AppError> {
        AppLogger.store.startOperation("Load Charters")
        
        do {
            charters = try await repository.fetchAllCharters()
            AppLogger.store.completeOperation("Load Charters")
            return .success(())
        } catch {
            let appError = AppError.database(.readFailed)
            AppLogger.store.failOperation("Load Charters", error: error)
            return .failure(appError)
        }
    }
}
```

3. **Add Error Presentation Layer:**
```swift
// Core/Utilities/ErrorPresenter.swift
@MainActor
@Observable
final class ErrorPresenter {
    var currentError: AppError?
    var isShowingError = false
    
    func present(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    func dismiss() {
        isShowingError = false
        currentError = nil
    }
}

// In views:
.alert(isPresented: $errorPresenter.isShowingError) {
    Alert(
        title: Text("Error"),
        message: Text(errorPresenter.currentError?.errorDescription ?? ""),
        primaryButton: .default(Text("Retry"), action: { /* retry */ }),
        secondaryButton: .cancel()
    )
}
```

**Priority:** 🔴 HIGH

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

**Recommended Refactoring:**

```swift
// DesignSystem/Components/LoadingView.swift
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

// Update CharterStore
@Observable
final class CharterStore {
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(AppError)
    }
    
    private(set) var loadingState: LoadingState = .idle
    private(set) var charters: [CharterModel] = []
}

// Update view
var body: some View {
    Group {
        switch charterStore.loadingState {
        case .idle, .loading:
            DesignSystem.LoadingView(message: "Loading your charters...")
        case .loaded:
            if charterStore.charters.isEmpty {
                emptyState
            } else {
                charterList
            }
        case .error(let error):
            DesignSystem.ErrorView(
                error: error,
                retry: { await charterStore.loadCharters() }
            )
        }
    }
}
```

**Priority:** 🟡 MEDIUM

---

#### Issue 4.2.2: No Pull-to-Refresh

**Current State:**
- Users cannot manually refresh data
- No way to sync with backend

**Recommended Refactoring:**

```swift
struct CharterListView: View {
    @State private var charterStore = CharterStore()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(charterStore.charters) { charter in
                    CharterRowView(charter: charter)
                }
            }
        }
        .refreshable {
            await charterStore.refreshCharters()
        }
    }
}
```

**Priority:** 🟢 LOW

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

### Phase 1: Critical (Next Sprint)
1. ✅ Implement proper dependency injection
2. ✅ Fix state management inconsistencies
3. ✅ Add comprehensive error handling
4. ✅ Complete CRUD operations in CharterStore
5. ✅ Add loading states to all async operations

### Phase 2: Important (Sprint 2-3)
1. Create ViewModels for all features
2. Implement data validation
3. Add integration tests
4. Complete navigation implementation
5. Implement error presentation layer

### Phase 3: Nice to Have (Sprint 4+)
1. Add pagination
2. Implement sync service
3. Add snapshot tests
4. Reorganize file structure
5. Add comprehensive documentation
6. Optimize performance

---

## 13. Refactoring Checklist

### Before Starting
- [ ] Create feature branch: `refactor/architecture-improvements`
- [ ] Ensure all tests are passing
- [ ] Create backup of current codebase

### Core Architecture
- [ ] Implement `DependencyContainer`
- [ ] Convert to single `CharterStore` instance
- [ ] Update all views to use `@EnvironmentObject`
- [ ] Create `AppError` types
- [ ] Implement `ErrorPresenter`

### Data Layer
- [ ] Add missing CRUD operations
- [ ] Improve error handling in repository
- [ ] Add `throws` to `toDomainModel()`
- [ ] Create formatters utility

### UI Layer
- [ ] Create ViewModels for all features
- [ ] Add loading states
- [ ] Implement form validation
- [ ] Add error alerts
- [ ] Implement pull-to-refresh

### Testing
- [ ] Update unit tests for new architecture
- [ ] Add integration tests
- [ ] Add more edge case tests

### Documentation
- [ ] Add inline documentation
- [ ] Create architecture diagram
- [ ] Update README

---

## 14. Estimated Effort

**Total Estimated Effort:** 4-6 weeks (1 senior developer)

- Phase 1 (Critical): 2 weeks
- Phase 2 (Important): 2-3 weeks  
- Phase 3 (Nice to Have): 1-2 weeks

**Recommended Approach:** 
- Tackle Phase 1 items immediately
- Phase 2 can be done incrementally alongside new feature development
- Phase 3 items as time permits

---

## 15. Final Recommendations

### Immediate Actions
1. **Implement Dependency Injection**: This is blocking proper state management
2. **Fix Error Handling**: Critical for production readiness
3. **Complete CRUD Operations**: Essential for basic functionality

### Short-Term Goals
1. **Standardize on @Observable**: Swift 6's observation is the way forward
2. **Create Comprehensive ViewModels**: Improves testability and maintainability
3. **Add Loading States**: Better UX

### Long-Term Vision
1. **Build Sync Layer**: For multi-device support
2. **Performance Optimization**: As data grows
3. **Comprehensive Testing**: For production confidence

---

## Conclusion

The anyfleet codebase is well-structured and demonstrates strong understanding of modern iOS development practices. The main areas needing attention are:

1. **State Management**: Move from multiple store instances to singleton pattern with DI
2. **Error Handling**: Implement comprehensive error types and user feedback
3. **Completeness**: Finish CRUD operations and navigation implementation

With these refactorings, the codebase will be production-ready and highly maintainable.

---

**Review Completed By:** Senior iOS Developer  
**Next Review Date:** After Phase 1 completion

