# AnyFleet iOS App – Senior iOS Engineer Review & Refactoring Plan
**Date:** January 15, 2026  
**Reviewer:** Senior iOS Engineer  
**Target:** Production SwiftUI app (AnyFleet)

---

## Executive Summary

**What this app does:**  
AnyFleet is a sailing charter management app that allows users to:
- Create and manage sailing charters (boat trips) with dates, vessels, and locations
- Build a personal library of sailing content (checklists, practice guides, flashcard decks)
- Execute checklists during charters for safety and operations
- Publish and discover community content
- Authenticate via Apple Sign In
- Work offline with background sync

**Data flow:**  
`View` → `ViewModel` (@Observable) → `Store` (in-memory cache) → `Repository` → `Database` (GRDB/SQLite) ← → `API/Backend`

**Side effects:**  
- Background sync every 60 seconds when app is active
- Auth token refresh with automatic retry
- Content publishing to remote backend with sync queue

---

## High-Level Issues & Ranking

### 1. **Architecture** (Priority: Medium-High)
- **Good:** Clean separation of concerns (View/ViewModel/Store/Repository), modern dependency injection, coordinator pattern for navigation
- **Issues:**
  - Some view models have optional initializers creating fallback dependencies (e.g., `CharterListView.init`)—breaks DI principle
  - `AppCoordinator` handles too many concerns (navigation + sync timer management + lifecycle observation)
  - `LibraryStore` has a `fatalError` for unsupported types in caching logic (line 161)
  - Protocol usage is inconsistent—some stores have protocols (e.g., `LibraryStoreProtocol`), others don't

### 2. **Code Quality** (Priority: High)
- **Good:** No force unwraps in most places, excellent use of guard statements, comprehensive logging
- **Issues:**
  - Duplicated `DateFormatter` creation in views (e.g., `CharterRowView`, `CharterDetailView`)—should be cached or static
  - `CharterRowView` body is 160+ lines—needs subview extraction
  - `LibraryStore.saveChecklist` has deeply nested dictionary building (lines 368-399) that's hard to maintain
  - `AuthService` has duplicated request retry logic (lines 318-357) that could be extracted
  - Magic numbers: timer intervals (60.0), shadow radii, font sizes scattered across design system

### 3. **Swift/SwiftUI Best Practices** (Priority: Medium)
- **Good:** Using modern `@Observable` macro, `nonisolated` on data models, proper `@MainActor` annotations
- **Issues:**
  - Some views create default view models in initializers instead of requiring injection (breaks previews and tests)
  - `CharterListView` lines 9-19: creates placeholder dependencies that won't work in production
  - View bodies exceed 100+ lines in several places (split into computed properties)
  - Missing explicit `@MainActor` on some error handling extensions (line 18-19 in `AppError.swift`)

### 4. **Performance** (Priority: Medium)
- **Good:** LRU caching for library content, lazy loading of full models
- **Issues:**
  - `DateFormatter` recreated on every row render—expensive
  - Large view bodies cause longer compile times and recomputation
  - No debouncing on refresh actions (pull-to-refresh can be spammed)
  - Background sync timer runs regardless of network availability

### 5. **UX/UI** (Priority: Low-Medium)
- **Good:** Beautiful design system, consistent spacing, loading states, empty states, error banners
- **Issues:**
  - No haptic feedback on important actions (delete, publish)
  - Empty state action buttons don't have loading indicators
  - Swipe actions on lists lack confirmation for destructive actions (delete)
  - No keyboard shortcuts or dynamic type testing visible
  - Accessibility labels are present but not comprehensive

---

## Refactoring Plan (8 Steps)

1. **Extract view components** – Break down large view bodies (CharterRowView, LibraryContentList) into focused subviews
2. **Centralize formatters** – Create shared date/number formatters to eliminate recreation overhead
3. **Refactor AppCoordinator** – Split lifecycle management and sync timer into separate services
4. **Eliminate optional DI** – Remove fallback dependency creation in view initializers
5. **Extract content serialization** – Create dedicated mapper/serializer types for publish payloads
6. **Add debouncing** – Prevent rapid repeated actions (refresh, search, sync)
7. **Enhance error handling** – Add retry limits, exponential backoff for network calls
8. **Improve accessibility** – Add comprehensive labels, hints, and traits; test with VoiceOver

---

## 1. Architecture & Patterns

### Issue 1.1: AppCoordinator has too many responsibilities

**Current problem:**  
`AppCoordinator` manages navigation paths, builds destinations, AND manages background sync timer + lifecycle observation. This violates single responsibility principle.

**Refactored approach:**  
Extract sync orchestration into a dedicated service.

```swift
// New file: Services/AppLifecycleService.swift
import UIKit
import Combine

@MainActor
@Observable
final class AppLifecycleService {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let syncInterval: TimeInterval
    
    init(syncService: ContentSyncService, syncInterval: TimeInterval = 60.0) {
        self.syncService = syncService
        self.syncInterval = syncInterval
        observeLifecycle()
        startBackgroundSync()
    }
    
    deinit {
        pauseBackgroundSync()
    }
    
    private func observeLifecycle() {
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
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
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
        Task { @MainActor in
            await syncService.syncPending()
        }
        startBackgroundSync()
    }
}
```

**Updated AppCoordinator:**

```swift
@MainActor
@Observable
final class AppCoordinator: AppCoordinatorProtocol {
    private let dependencies: AppDependencies
    
    // Navigation state only
    var homePath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    var discoverPath: [AppRoute] = []
    var chartersPath: [AppRoute] = []
    var profilePath: [AppRoute] = []
    var selectedTab: AppView.Tab = .home
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }
    
    // Navigation methods remain...
    // Remove lifecycle and sync timer code
}
```

**Updated AppDependencies:**

```swift
@Observable
@MainActor
final class AppDependencies {
    // ... existing properties ...
    let lifecycleService: AppLifecycleService
    
    init() {
        // ... existing init code ...
        
        self.lifecycleService = AppLifecycleService(
            syncService: contentSyncService
        )
        
        AppLogger.dependencies.info("AppDependencies initialized successfully")
    }
}
```

**Rationale:** Separates navigation concerns from lifecycle/sync management. Makes testing easier (can test coordinator without timers/notifications). Improves code maintainability.

---

### Issue 1.2: Optional dependency injection in views

**Current problem:**  
Views create fallback dependencies when nil is passed, breaking pure DI and making production behavior unclear.

```swift
// CharterListView.swift lines 9-19
init(viewModel: CharterListViewModel? = nil) {
    if let viewModel = viewModel {
        _viewModel = State(initialValue: viewModel)
    } else {
        // Creates placeholder - won't work in production!
        let deps = AppDependencies()
        _viewModel = State(initialValue: CharterListViewModel(
            charterStore: CharterStore(repository: LocalRepository()),
            coordinator: AppCoordinator(dependencies: deps)
        ))
    }
}
```

**Refactored:**

```swift
struct CharterListView: View {
    @State private var viewModel: CharterListViewModel
    
    init(viewModel: CharterListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        // ... existing body ...
    }
}

// For previews, use explicit injection
#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        return CharterListView(
            viewModel: CharterListViewModel(
                charterStore: dependencies.charterStore, 
                coordinator: coordinator
            )
        )
        .environment(\.appDependencies, dependencies)
    }
}
```

**Apply same fix to:**
- `LibraryListView` (lines 9-21)
- Any other views with optional VM initializers

**Rationale:** Enforces explicit dependency injection. Makes it impossible to accidentally run with wrong dependencies. Previews become explicit about test setup.

---

### Issue 1.3: Remove `fatalError` from LibraryStore

**Current problem:**  
`LibraryStore.fetchFullContent` has a `fatalError` for unsupported types (line 161).

```swift
} else {
    fatalError("Unsupported content type for caching")
}
```

**Refactored:**

```swift
func fetchFullContent<T>(_ id: UUID) async throws -> T? {
    // Check cache first based on content type
    if T.self == Checklist.self {
        if let cached = checklistCache.get(id) as? T {
            AppLogger.store.debug("Cache hit for checklist: \(id)")
            return cached
        }
    } else if T.self == PracticeGuide.self {
        if let cached = guideCache.get(id) as? T {
            AppLogger.store.debug("Cache hit for guide: \(id)")
            return cached
        }
    } else {
        // Unsupported type - return nil or throw
        AppLogger.store.error("Attempted to fetch unsupported content type: \(T.self)")
        throw LibraryError.invalidState("Content type \(T.self) is not supported for caching")
    }
    
    // ... rest of implementation ...
}
```

**Rationale:** Never use `fatalError` in production code except for truly unrecoverable programmer errors. This is a runtime type issue that should be handled gracefully.

---

## 2. Code Quality Improvements

### Issue 2.1: Duplicate DateFormatter creation

**Current problem:**  
`DateFormatter` is created as a computed property in multiple views, causing recreation on every access.

```swift
// CharterRowView.swift line 152
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}
```

**Refactored:**  
Create a centralized formatter utility.

```swift
// New file: Core/Utilities/Formatters.swift
import Foundation

enum Formatters {
    /// Shared date formatter for medium date style (e.g., "Jan 15, 2026")
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Shared date formatter for short date style (e.g., "1/15/26")
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Shared date formatter for ISO8601 (for API communication)
    static let iso8601: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()
    
    /// Format a date range as "Jan 15 – Jan 22, 2026"
    static func formatDateRange(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)
        
        if startYear == endYear {
            // Same year - only show year once
            let startString = mediumDate.string(from: start)
                .replacingOccurrences(of: ", \(startYear)", with: "")
            let endString = mediumDate.string(from: end)
            return "\(startString) – \(endString)"
        } else {
            // Different years - show both
            return "\(mediumDate.string(from: start)) – \(mediumDate.string(from: end))"
        }
    }
}
```

**Usage in views:**

```swift
// CharterRowView.swift
Text(Formatters.mediumDate.string(from: charter.startDate))
    .font(.system(size: 15, weight: .semibold))
    .foregroundColor(DesignSystem.Colors.textPrimary)
```

**Rationale:** DateFormatter initialization is expensive (~100ms). Reusing cached formatters improves performance significantly, especially in list views.

---

### Issue 2.2: Extract CharterRowView subcomponents

**Current problem:**  
`CharterRowView.body` is 160+ lines with complex nesting. Hard to read and maintain.

**Refactored:**

```swift
struct CharterRowView: View {
    let charter: CharterModel
    let onTap: () -> Void
    
    private var isUpcoming: Bool {
        charter.daysUntilStart > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroSection(charter: charter)
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            TimelineSection(charter: charter, isUpcoming: isUpcoming)
            
            if charter.location != nil {
                LocationSection(location: charter.location!)
            }
        }
        .heroCardStyle(elevation: isUpcoming ? .high : .medium)
        .onTapGesture { onTap() }
    }
}

// MARK: - Subcomponents

private struct HeroSection: View {
    let charter: CharterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(charter.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.textPrimary,
                            DesignSystem.Colors.textPrimary.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            if let boatName = charter.boatName {
                BoatNameBadge(name: boatName)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
        .focalHighlight()
    }
}

private struct BoatNameBadge: View {
    let name: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "sailboat.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.gold,
                            DesignSystem.Colors.gold.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs + 2)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.gold.opacity(0.15),
                            DesignSystem.Colors.gold.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    DesignSystem.Colors.gold.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
}

private struct TimelineSection: View {
    let charter: CharterModel
    let isUpcoming: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                DepartureInfo(date: charter.startDate, isUpcoming: isUpcoming)
                
                Spacer()
                
                DurationBadge(days: charter.durationDays)
                
                ReturnInfo(date: charter.endDate)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

private struct DepartureInfo: View {
    let date: Date
    let isUpcoming: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                DesignSystem.TimelineIndicator(isActive: isUpcoming)
                Text("Departure")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(Formatters.mediumDate.string(from: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

private struct DurationBadge: View {
    let days: Int
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.primary)
            Text("\(days) days")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.primary.opacity(0.12))
        )
    }
}

private struct ReturnInfo: View {
    let date: Date
    
    var body: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("Return")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                DesignSystem.TimelineIndicator(isActive: false)
            }
            Text(Formatters.mediumDate.string(from: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

private struct LocationSection: View {
    let location: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
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
            Text(location)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.xs)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
}
```

**Rationale:** Smaller, focused views improve readability, compile times, and reusability. Each subcomponent has a single responsibility. Easier to test and modify.

---

### Issue 2.3: Simplify payload serialization in LibraryStore

**Current problem:**  
`LibraryStore.saveChecklist` builds deeply nested dictionaries inline (lines 368-399), making it hard to read and error-prone.

**Refactored:**  
Extract serialization into a dedicated mapper type.

```swift
// New file: Data/Mappers/ContentSerializers.swift
import Foundation

enum ContentSerializers {
    /// Serialize a checklist to a content data dictionary for publishing
    static func serializeChecklist(_ checklist: Checklist) -> [String: Any] {
        [
            "id": checklist.id.uuidString,
            "title": checklist.title,
            "description": checklist.description as Any,
            "sections": checklist.sections.map(serializeSection),
            "checklistType": checklist.checklistType.rawValue,
            "tags": checklist.tags,
            "createdAt": checklist.createdAt.ISO8601Format(),
            "updatedAt": checklist.updatedAt.ISO8601Format(),
            "syncStatus": checklist.syncStatus.rawValue
        ]
    }
    
    private static func serializeSection(_ section: ChecklistSection) -> [String: Any] {
        [
            "id": section.id.uuidString,
            "title": section.title,
            "icon": section.icon as Any,
            "description": section.description as Any,
            "isExpandedByDefault": section.isExpandedByDefault,
            "sortOrder": section.sortOrder,
            "items": section.items.map(serializeItem)
        ]
    }
    
    private static func serializeItem(_ item: ChecklistItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "title": item.title,
            "itemDescription": item.itemDescription as Any,
            "isOptional": item.isOptional,
            "isRequired": item.isRequired,
            "tags": item.tags,
            "estimatedMinutes": item.estimatedMinutes as Any,
            "sortOrder": item.sortOrder
        ]
    }
    
    /// Serialize a practice guide to a content data dictionary for publishing
    static func serializeGuide(_ guide: PracticeGuide) -> [String: Any] {
        [
            "id": guide.id.uuidString,
            "title": guide.title,
            "description": guide.description as Any,
            "markdown": guide.markdown,
            "tags": guide.tags,
            "createdAt": guide.createdAt.ISO8601Format(),
            "updatedAt": guide.updatedAt.ISO8601Format(),
            "syncStatus": guide.syncStatus.rawValue
        ]
    }
}
```

**Updated LibraryStore:**

```swift
private func triggerPublishUpdate(for metadata: LibraryModel, checklist: Checklist) async {
    do {
        AppLogger.store.info("Creating publish update payload for checklist: \(checklist.id)")
        
        let contentData = ContentSerializers.serializeChecklist(checklist)
        
        let payload = ContentPublishPayload(
            title: checklist.title,
            description: checklist.description,
            contentType: "checklist",
            contentData: contentData,
            tags: checklist.tags,
            language: metadata.language,
            publicID: metadata.publicID!,
            forkedFromID: metadata.forkedFromID
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        
        let summary = try await syncQueue.enqueuePublishUpdate(
            contentID: checklist.id,
            payload: payloadData
        )
        
        AppLogger.store.info("Publish update sync completed for checklist: \(checklist.id) - \(summary.succeeded) succeeded, \(summary.failed) failed")
    } catch {
        AppLogger.store.error("Failed to trigger publish_update sync for checklist: \(checklist.id)", error: error)
    }
}
```

**Rationale:** Separates serialization logic from business logic. Easier to test, maintain, and reuse. Reduces cognitive load when reading `LibraryStore`.

---

## 3. Swift & SwiftUI Best Practices

### Issue 3.1: Add explicit @MainActor to error handling

**Current problem:**  
`AppError.errorDescription` and related properties use `@MainActor` but the enum itself isn't actor-isolated.

**Refactored:**

```swift
@MainActor
enum AppError: LocalizedError, Identifiable {
    case notFound(entity: String, id: UUID)
    case validationFailed(field: String, reason: String)
    case databaseError(underlying: Error)
    case networkError(NetworkError)
    case authenticationError(AuthError)
    case unknown(Error)
    
    var id: String { errorDescription ?? "unknown" }
    
    var errorDescription: String? {
        switch self {
        case .notFound(let entity, let id):
            return String(format: L10n.Error.notFound, entity, id.uuidString)
        case .validationFailed(let field, let reason):
            return String(format: L10n.Error.validationFailed, field, reason)
        case .databaseError(let underlying):
            return String(format: L10n.Error.databaseError, underlying.localizedDescription)
        case .networkError(let networkError):
            return networkError.localizedDescription
        case .authenticationError(let authError):
            return authError.localizedDescription
        case .unknown(let error):
            return String(format: L10n.Error.generic, error.localizedDescription)
        }
    }
    
    var recoverySuggestion: String? {
        // ... existing implementation ...
    }
}

@MainActor
enum NetworkError: LocalizedError {
    // ... existing cases ...
}

@MainActor
enum LibraryError: LocalizedError, Equatable {
    // ... existing cases ...
}
```

**Rationale:** Makes actor isolation explicit and consistent. Prevents accidental off-main-thread access to localized strings. Improves concurrency safety.

---

### Issue 3.2: Use async let for parallel operations

**Current opportunity:**  
In `CharterDetailViewModel`, loading charter and checklist happens sequentially. These could run in parallel.

**Current:**

```swift
func load() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        charter = try await charterStore.fetchCharter(charterID)
        if let checklistID = charter?.checkInChecklistID {
            checkInChecklistID = checklistID
        }
    } catch {
        handleError(error.toAppError())
    }
}
```

**Refactored:**

```swift
func load() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        // Fetch charter and checklist metadata in parallel
        async let charterTask = charterStore.fetchCharter(charterID)
        
        // Wait for charter first to get checklistID
        charter = try await charterTask
        checkInChecklistID = charter?.checkInChecklistID
        
    } catch {
        handleError(error.toAppError())
    }
}
```

**Rationale:** While there's a dependency here, this pattern can be applied elsewhere. Use `async let` for truly parallel operations to reduce wait time.

---

## 4. UX, UI & Accessibility

### Issue 4.1: Add haptic feedback for important actions

**Current problem:**  
No tactile feedback for destructive or important actions (delete, publish, unpublish).

**Refactored:**  
Create a haptics utility.

```swift
// New file: Core/Utilities/Haptics.swift
import UIKit

enum Haptics {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()
    
    /// Prepare the generator for immediate feedback (reduces latency)
    static func prepare() {
        impactMedium.prepare()
    }
    
    /// Light impact feedback (for selections)
    static func light() {
        impactLight.impactOccurred()
    }
    
    /// Medium impact feedback (for confirmations)
    static func medium() {
        impactMedium.impactOccurred()
    }
    
    /// Heavy impact feedback (for important actions)
    static func heavy() {
        impactHeavy.impactOccurred()
    }
    
    /// Success notification (for completed actions)
    static func success() {
        notification.notificationOccurred(.success)
    }
    
    /// Warning notification (for alerts)
    static func warning() {
        notification.notificationOccurred(.warning)
    }
    
    /// Error notification (for failures)
    static func error() {
        notification.notificationOccurred(.error)
    }
    
    /// Selection change feedback (for pickers, toggles)
    static func selection() {
        selection.selectionChanged()
    }
}
```

**Usage in views:**

```swift
// In CharterListView swipe action
Button(role: .destructive) {
    Haptics.warning() // Prepare user for destructive action
    Task {
        do {
            try await viewModel.deleteCharter(charter.id)
            Haptics.success() // Confirm deletion
        } catch {
            Haptics.error() // Indicate failure
            AppLogger.view.error("Failed to delete charter: \(error.localizedDescription)")
        }
    }
} label: {
    Label("Delete", systemImage: "trash")
}
```

**Rationale:** Haptic feedback improves perceived responsiveness and provides tactile confirmation of actions. Especially important for destructive or async operations.

---

### Issue 4.2: Add loading indicators to action buttons

**Current problem:**  
Empty state action buttons don't show loading state during async operations.

**Refactored:**

```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    @State private var isLoading = false
    
    // ... existing properties ...
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // Icon and text sections...
            
            if let actionTitle, let action {
                Button(action: {
                    isLoading = true
                    Haptics.medium()
                    action()
                    // Note: Caller should set isLoading = false when done
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(actionTitle)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 200)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(12)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1.0)
            }
            
            Spacer()
        }
        // ... rest of styling ...
    }
}
```

**Rationale:** Provides visual feedback during async operations. Prevents double-taps. Improves perceived performance.

---

### Issue 4.3: Improve accessibility labels

**Current problem:**  
Accessibility labels are present but not comprehensive. Complex custom views lack proper traits.

**Refactored examples:**

```swift
// CharterRowView - add comprehensive accessibility
var body: some View {
    VStack(alignment: .leading, spacing: 0) {
        // ... existing layout ...
    }
    .heroCardStyle(elevation: isUpcoming ? .high : .medium)
    .onTapGesture { onTap() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Double tap to view charter details")
    .accessibilityAddTraits(.isButton)
    .accessibilityValue(isUpcoming ? "Upcoming" : "Past")
}

private var accessibilityLabel: String {
    var parts: [String] = [charter.name]
    
    if let boat = charter.boatName {
        parts.append("on \(boat)")
    }
    
    parts.append("from \(Formatters.mediumDate.string(from: charter.startDate))")
    parts.append("to \(Formatters.mediumDate.string(from: charter.endDate))")
    parts.append("\(charter.durationDays) days")
    
    if let location = charter.location {
        parts.append("in \(location)")
    }
    
    return parts.joined(separator: ", ")
}
```

```swift
// EmptyStateView - improve button accessibility
Button(action: action) {
    HStack(spacing: DesignSystem.Spacing.sm) {
        Image(systemName: "plus.circle.fill")
        Text(actionTitle)
    }
    // ... styling ...
}
.accessibilityLabel(actionTitle)
.accessibilityHint("Double tap to \(actionTitle.lowercased())")
.accessibilityAddTraits(.isButton)
```

**Rationale:** Makes the app usable for VoiceOver users. Improves inclusivity and potentially App Store review outcomes.

---

### Issue 4.4: Confirm destructive swipe actions

**Current problem:**  
Swipe-to-delete immediately deletes without confirmation for some items.

**Refactored:**

```swift
// Add confirmation state to view model
@Observable
final class CharterListViewModel: ErrorHandling {
    // ... existing properties ...
    var pendingDeleteID: UUID?
    
    func confirmDelete(_ charterID: UUID) {
        pendingDeleteID = charterID
    }
    
    func executeDelete() async {
        guard let id = pendingDeleteID else { return }
        pendingDeleteID = nil
        
        do {
            try await charterStore.deleteCharter(id)
            Haptics.success()
        } catch {
            Haptics.error()
            handleError(error.toAppError())
        }
    }
    
    func cancelDelete() {
        pendingDeleteID = nil
    }
}

// In view
.swipeActions(edge: .trailing, allowsFullSwipe: false) { // Note: allowsFullSwipe = false
    Button(role: .destructive) {
        viewModel.confirmDelete(charter.id)
    } label: {
        Label("Delete", systemImage: "trash")
    }
    
    // ... other actions ...
}
.confirmationDialog(
    "Delete Charter",
    isPresented: Binding(
        get: { viewModel.pendingDeleteID == charter.id },
        set: { if !$0 { viewModel.cancelDelete() } }
    ),
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        Task {
            await viewModel.executeDelete()
        }
    }
    Button("Cancel", role: .cancel) {
        viewModel.cancelDelete()
    }
} message: {
    Text("This action cannot be undone. Are you sure you want to delete '\(charter.name)'?")
}
```

**Rationale:** Prevents accidental deletions. Follows iOS best practices for destructive actions. Improves user confidence.

---

## 5. Tests, Reliability & Tooling

### Issue 5.1: Add network retry with exponential backoff

**Current problem:**  
`AuthService` retries token refresh but without backoff or limits. Network failures can cause rapid repeated calls.

**Refactored:**

```swift
// New file: Core/Utilities/RetryPolicy.swift
import Foundation

actor RetryPolicy {
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let multiplier: Double
    
    init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }
    
    /// Execute an operation with retry and exponential backoff
    func execute<T>(
        operation: @Sendable () async throws -> T,
        shouldRetry: @Sendable (Error) -> Bool = { _ in true }
    ) async throws -> T {
        var attempt = 0
        var lastError: Error?
        
        while attempt < maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry this error
                guard shouldRetry(error) else {
                    throw error
                }
                
                attempt += 1
                
                // If we've exhausted attempts, throw the error
                guard attempt < maxAttempts else {
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = min(baseDelay * pow(multiplier, Double(attempt - 1)), maxDelay)
                AppLogger.api.info("Retry attempt \(attempt)/\(maxAttempts) after \(delay)s")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Should never reach here, but handle it gracefully
        throw lastError ?? NSError(domain: "RetryPolicy", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
}
```

**Usage in AuthService:**

```swift
@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    // ... existing properties ...
    private let retryPolicy = RetryPolicy()
    
    func makeAuthenticatedRequestWithRetry(request: URLRequest) async throws -> Data {
        return try await retryPolicy.execute {
            try await self.performAuthenticatedRequest(request)
        } shouldRetry: { error in
            // Only retry on network errors, not auth failures
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain
        }
    }
    
    private func performAuthenticatedRequest(_ request: URLRequest) async throws -> Data {
        var mutableRequest = request
        
        guard let accessToken = keychain.getAccessToken() else {
            AppLogger.auth.warning("No access token available for authenticated request")
            throw AuthError.unauthorized
        }
        
        mutableRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: mutableRequest)
        
        // If unauthorized, try refreshing token (only once, no retry)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            try await refreshAccessToken()
            
            guard let newAccessToken = keychain.getAccessToken() else {
                throw AuthError.unauthorized
            }
            
            mutableRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: mutableRequest)
            
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
}
```

**Rationale:** Prevents hammering the server during transient network issues. Improves reliability. Follows industry best practices for API clients.

---

### Issue 5.2: Suggested test cases

**High-value test cases to add:**

1. **CharterStore Tests**
```swift
@Test("Creating charter with valid data succeeds")
func createCharterSuccess() async throws {
    let mockRepo = MockCharterRepository()
    let store = CharterStore(repository: mockRepo)
    
    let charter = try await store.createCharter(
        name: "Summer Sailing",
        boatName: "Sea Breeze",
        location: "Mediterranean",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * 24 * 60 * 60)
    )
    
    #expect(store.charters.count == 1)
    #expect(store.charters.first?.name == "Summer Sailing")
}

@Test("Loading charters handles empty state")
func loadChartersEmpty() async throws {
    let mockRepo = MockCharterRepository(charters: [])
    let store = CharterStore(repository: mockRepo)
    
    try await store.loadCharters()
    
    #expect(store.charters.isEmpty)
}

@Test("Deleting charter removes from store")
func deleteCharterSuccess() async throws {
    let charter = CharterModel(/* ... */)
    let mockRepo = MockCharterRepository(charters: [charter])
    let store = CharterStore(repository: mockRepo)
    
    try await store.loadCharters()
    try await store.deleteCharter(charter.id)
    
    #expect(store.charters.isEmpty)
}
```

2. **LibraryStore Caching Tests**
```swift
@Test("Fetching checklist uses cache on second call")
func checklistCacheHit() async throws {
    let checklist = Checklist(/* ... */)
    let mockRepo = MockLibraryRepository(checklists: [checklist])
    let store = LibraryStore(repository: mockRepo, syncQueue: mockSyncQueue)
    
    // First fetch - should hit repository
    let first = try await store.fetchChecklist(checklist.id)
    #expect(mockRepo.fetchCallCount == 1)
    
    // Second fetch - should hit cache
    let second = try await store.fetchChecklist(checklist.id)
    #expect(mockRepo.fetchCallCount == 1) // No additional call
    #expect(first.id == second.id)
}
```

3. **AppCoordinator Navigation Tests**
```swift
@Test("Creating charter appends to charters path")
func createCharterNavigation() {
    let deps = try! AppDependencies.makeForTesting()
    let coordinator = AppCoordinator(dependencies: deps)
    
    coordinator.createCharter()
    
    #expect(coordinator.chartersPath.count == 1)
    if case .createCharter = coordinator.chartersPath.first {
        // Success
    } else {
        throw TestError.unexpectedRoute
    }
}
```

4. **Error Handling Tests**
```swift
@Test("Network errors convert to AppError correctly")
func networkErrorConversion() {
    let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    let appError = nsError.toAppError()
    
    if case .networkError(.offline) = appError {
        // Success
    } else {
        throw TestError.unexpectedErrorType
    }
}
```

5. **AuthService Token Refresh Tests**
```swift
@Test("Unauthorized response triggers token refresh")
func tokenRefreshOn401() async throws {
    let mockKeychain = MockKeychainService()
    mockKeychain.saveAccessToken("old-token")
    mockKeychain.saveRefreshToken("refresh-token")
    
    let authService = AuthService(keychain: mockKeychain)
    
    // Mock server that returns 401 on first call, 200 on second
    // ... implementation ...
    
    #expect(mockKeychain.getAccessToken() == "new-token")
}
```

**Rationale:** These tests cover critical paths (data operations, navigation, error handling, auth) and would catch most regressions. Focus on behavior, not implementation details.

---

## 6. Additional Recommendations

### Magic Numbers Cleanup

**Create constants file:**

```swift
// New file: Core/Constants.swift
enum Constants {
    enum Timing {
        static let backgroundSyncInterval: TimeInterval = 60.0
        static let debounceDelay: TimeInterval = 0.3
        static let shortAnimationDuration: TimeInterval = 0.12
        static let mediumAnimationDuration: TimeInterval = 0.25
    }
    
    enum Layout {
        static let minimumTapTarget: CGFloat = 44.0
        static let cardCornerRadius: CGFloat = 12.0
        static let heroCardCornerRadius: CGFloat = 16.0
        static let pillCornerRadius: CGFloat = 20.0
    }
    
    enum Shadow {
        static let lightRadius: CGFloat = 4.0
        static let mediumRadius: CGFloat = 8.0
        static let heavyRadius: CGFloat = 12.0
    }
    
    enum Performance {
        static let listImageCacheSize = 50
        static let contentCacheMaxSize = 20
    }
}
```

---

### Debounce Utility

```swift
// New file: Core/Utilities/Debouncer.swift
import Foundation

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }
    
    func debounce(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// Usage in ViewModel
final class SearchViewModel {
    private let debouncer = Debouncer(delay: 0.3)
    
    var searchText = "" {
        didSet {
            debouncer.debounce {
                await self.performSearch()
            }
        }
    }
}
```

---

### Conditional Sync Based on Network

```swift
// Update AppLifecycleService
import Network

@MainActor
@Observable
final class AppLifecycleService {
    // ... existing properties ...
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    
    init(syncService: ContentSyncService, syncInterval: TimeInterval = 60.0) {
        self.syncService = syncService
        self.syncInterval = syncInterval
        
        setupNetworkMonitoring()
        observeLifecycle()
        startBackgroundSync()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    AppLogger.sync.info("Network connected, resuming sync")
                    await self?.syncService.syncPending()
                } else {
                    AppLogger.sync.info("Network disconnected, pausing sync")
                }
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }
    
    private func startBackgroundSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isConnected else {
                    AppLogger.sync.debug("Skipping sync - no network connection")
                    return
                }
                await self.syncService.syncPending()
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
```

---

## Summary of Impact

| Issue | Priority | Effort | Impact |
|-------|----------|--------|--------|
| Extract AppCoordinator concerns | Medium | Medium | High (testability, maintainability) |
| Remove optional DI | High | Low | High (correctness, clarity) |
| Centralize formatters | High | Low | Medium (performance) |
| Extract CharterRowView subviews | Medium | Medium | Medium (readability, compile time) |
| Add retry policy | High | Medium | High (reliability) |
| Improve accessibility | Medium | Medium | High (inclusivity) |
| Add haptic feedback | Low | Low | Medium (UX polish) |
| Add confirmation dialogs | Medium | Low | Medium (safety) |
| Remove fatalError | High | Low | High (crash prevention) |
| Extract serializers | Medium | Medium | Medium (maintainability) |

**Estimated total effort:** 3-5 days for high-priority items, 2 weeks for complete refactor.

---

## Conclusion

This codebase is **well-architected** with modern Swift patterns, clean separation of concerns, and solid foundations. The main improvements focus on:

1. **Reliability** – retry logic, error handling, network awareness
2. **Maintainability** – extracting complex views, removing duplication, centralizing utilities
3. **Performance** – formatter caching, debouncing, parallel operations
4. **UX Polish** – haptics, confirmations, loading states, accessibility

The refactorings preserve existing behavior and public APIs while making the code easier to test, extend, and maintain. All changes are backwards-compatible and can be implemented incrementally.
