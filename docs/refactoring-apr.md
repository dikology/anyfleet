# Anyfleet iOS — April 2026 Refactoring Review

## 1. Summary

- **Anyfleet** is a yacht charter planning app with offline-first architecture: users create charters, manage library content (checklists, practice guides), discover community charters on a map, and maintain a sailing profile. Data flows through `View → ViewModel → Store/Service → LocalRepository (GRDB) → APIClient`, with a sync queue for publish/unpublish operations and a separate charter sync path.

- **Architecture is mostly sound** but suffers from **god objects** (`AppDependencies` mixes DI container with UI state; `LibraryStore` at 703 lines handles CRUD, caching, forking, and JSON payload construction; `LocalRepository` at 827 lines owns four separate data domains; `APIClient` at 929 lines mixes transport, endpoints, and response models).

- **ViewModels are instantiated inside `body`** in `AppView`, meaning every re-render creates fresh VM instances — the single most impactful SwiftUI anti-pattern in the codebase.

- **Duplicated logic across model layers**: `CharterModel` and `DiscoverableCharter` duplicate `daysUntilStart`, `durationDays`, and `urgencyLevel` with *divergent* implementations (the local model lacks `.ongoing`). `DateFormatter` is re-allocated in at least 4 view files on every render.

- **No Dynamic Type support**: All typography uses fixed `Font.system(size:)`. Accessibility labels are inconsistently applied. Several interactive elements use `.onTapGesture` instead of `Button`, breaking VoiceOver.

- **Dead code and commented-out flashcard deck remnants** span ~15 files, adding noise and confusing new contributors.

---

## 2. Issues & Recommendations

### 2.A — Architecture

| # | Issue | Severity | Location |
|---|-------|----------|----------|
| A1 | **`AppDependencies` is a god object** — acts as DI container *and* holds observable UI state (`toast`, `isAuthenticated`, `currentUser`). Toast logic (`showToast`, `toastDismissTask`) belongs in a dedicated `ToastManager`. | High | `App/AppDependencies.swift` |
| A2 | **Singleton + DI hybrid** — `AppDependencies.shared` is a true singleton but injected via SwiftUI environment, creating a false sense of DI. The `EnvironmentKey.defaultValue` eagerly constructs the entire dependency graph. | High | `App/AppDependencies.swift` |
| A3 | **ViewModels created in `body`** — `AppView.body` instantiates `HomeViewModel`, `CharterListViewModel`, `LibraryListViewModel`, `DiscoverViewModel`, `CharterDiscoveryViewModel`, and `ProfileViewModel` on every re-render, causing state loss and wasted allocations. | Critical | `App/AppView.swift` |
| A4 | **`LibraryStore` has too many responsibilities** — metadata CRUD, content caching, fork logic, publish-update payload construction, and domain model definitions (`PracticeGuide`, `FlashcardDeck`) all in one 703-line file. | High | `Core/Stores/LibraryStore.swift` |
| A5 | **`LocalRepository` is monolithic** — 827 lines spanning charters, library content, checklist execution state, and sync queue operations. Protocol conformances are implicit and spread across extensions. | Medium | `Data/Repositories/LocalRepository.swift` |
| A6 | **`APIClient` conflates transport, endpoints, and models** — 929 lines with duplicated request methods (`request`/`performRequest`/`requestUnauthenticated`/`performRequestUnauthenticated`) and response models mixed inline. | High | `Services/APIClient.swift` |
| A7 | **`AppModel.swift` filename is misleading** — contains `AppCoordinator`, `AppCoordinatorProtocol`, and `AppRoute`, not an "AppModel". | Low | `App/AppModel.swift` |
| A8 | **Coordinator doubles as view factory** — `destination(for:)` constructs VMs inline with closures capturing `self` and `dependencies`. Should use a factory or builder pattern. | Medium | `App/AppModel.swift` |
| A9 | **`CharterStore` duplicates repository state** — maintains an in-memory `[CharterModel]` manually synced with `LocalRepository`. Any write path touching one but not the other causes divergence. | Medium | `Core/Stores/CharterStore.swift` |
| A10 | **Sync side-effect in coordinator init** — `AppCoordinator.init` calls `dependencies.syncCoordinator.triggerImmediateSync()`, making it impossible to instantiate the coordinator in tests without network. | Medium | `App/AppModel.swift` |

#### Recommended Architecture Refactor Plan

**Step 1 — Fix ViewModel lifecycle (Critical).** Move all ViewModel instantiation out of `body` and into `@State` properties.

**Step 2 — Extract `ToastManager`.** Pull toast state and logic out of `AppDependencies` into a standalone `@Observable` class.

**Step 3 — Split `LibraryStore`.** Extract content caching into `ContentCacheService`, publish payload construction into `PublishPayloadBuilder`, and fork logic into `ForkService`.

**Step 4 — Split `LocalRepository`.** Create focused protocol conformances in separate files: `CharterRepository`, `LibraryRepository`, `ChecklistExecutionRepository`, `SyncQueueRepository`.

**Step 5 — Split `APIClient`.** Extract into `APIClient+Charters.swift`, `APIClient+Content.swift`, `APIClient+Profile.swift`, and move response models to `Core/Models/API/`.

**Step 6 — Unify charter computed properties.** Create a `CharterDateComputing` protocol shared by `CharterModel` and `DiscoverableCharter`.

**Step 7 — Remove dead code.** Delete all commented-out flashcard deck code, unused `CharterFormState` fields, and `#if DEBUG`-gate preview mocks.

**Step 8 — Add `@Sendable` and concurrency audit.** Fix missing `Sendable` conformances on ~10 types and resolve `URLSession.shared` bypasses in `AuthService`.

---

### 2.B — Code Quality

| # | Issue | Location |
|---|-------|----------|
| B1 | **`DateFormatter` re-allocated on every render** — `CharterDetailView.dateFormatter` (line 26), `DiscoverableCharter.dateRange`, `HomeView.dateText`, `ProfileView.formatDate` all create new formatters per call. | Multiple files |
| B2 | **`Date()` in computed properties** — `daysUntilStart`, `isUpcoming`, `timeUntilStartDisplay` use `Date()` inline, making them non-deterministic and untestable. | `CharterModel`, `DiscoverableCharter` |
| B3 | **Manual `[String: Any]` JSON construction** — `LibraryStore.triggerPublishUpdate` and `ContentPublishPayload.contentData` build dictionaries by hand via `AnyCodable`, losing type safety. | `LibraryStore`, `SyncPayloads` |
| B4 | **`print()` in production code** — `CharterMapView` has 6 `print()` calls; `LibraryStore` has 1. Should use `AppLogger`. | `CharterMapView`, `LibraryStore` |
| B5 | **`try?` swallowing errors** — `CharterListView` line 100 silently discards deletion errors. `LocalRepository.deleteContent` ignores content table deletion failures at lines 510-511. | Multiple files |
| B6 | **Inconsistent logger categories** — `ContentSyncService` logs to `AppLogger.auth` instead of `.sync`. | `ContentSyncService` |
| B7 | **`isNetworkReachable()` always returns `true`** — dead code that provides no actual network check. | `SyncQueueService` line 451 |
| B8 | **`ChecklistItem.isOptional` and `.isRequired` can both be true** — no validation prevents contradictory state. | `Checklist.swift` |
| B9 | **Mock data ships in production binary** — `CharterMapView` has ~140 lines of mock data not gated behind `#if DEBUG`. `LibraryListView` and `LibraryListViewModel` include `PreviewLibraryRepository` and `mockAuthorProfile` unconditionally. | Multiple files |
| B10 | **Unused computed property** — `CharterListViewModel.sortedByDate` (line 119) is never called; the view sorts its own copy. | `CharterListViewModel` |

---

### 2.C — Swift & SwiftUI Best Practices

| # | Issue | Location |
|---|-------|----------|
| C1 | **`UITabBar.appearance().isHidden = true` in View init** — global UIKit mutation that can't be undone. Should be set once at the app level. | `AppView.swift` |
| C2 | **Manual `Binding` wrappers instead of `@Bindable`** — `AppView` repeats `Binding(get:set:)` for 5 tab paths. With `@Bindable coordinator`, this becomes `$coordinator.homePath`. | `AppView.swift` |
| C3 | **`SwiftUI` imported in ViewModels** — `CharterEditorViewModel` imports `SwiftUI` when only `Foundation` + `Observation` are needed. Slows compilation and leaks UI framework into logic layer. | `CharterEditorViewModel` |
| C4 | **`SwiftUI` imported in model layer** — `LibraryModel.swift` and `ProfileModels.swift` import SwiftUI for `Color`-returning properties on domain enums. Presentation concerns should live in UI extensions. | `LibraryModel`, `ProfileModels` |
| C5 | **`@MainActor` on `errorDescription`** — `AppError`, `NetworkError`, `LibraryError`, and `AuthError` all require main-actor isolation for `localizedDescription`, which blocks use from background contexts. | `AppError.swift`, `AuthService.swift` |
| C6 | **Progress calculation bug** — `CharterEditorViewModel.calculateProgress` compares `form.startDate != .now`, but `.now` creates a new `Date()` each call, so this is almost always `true` after the first render. | `CharterEditorViewModel` line 341 |
| C7 | **Redundant guard in `loadCharter`** — checks `guard let charterID = charterID, !isNewCharter`, but `isNewCharter` is defined as `charterID == nil`, so the nil check already covers it. | `CharterEditorViewModel` line 138 |
| C8 | **`@Observable` on stateless class** — `ContentSyncService` is marked `@Observable` but exposes no mutable state for views to observe. Unnecessary overhead. | `ContentSyncService` |
| C9 | **Duplicate haptic fire** — `FloatingTabBar` triggers `HapticEngine.selection()` and `AppView`'s binding setter does the same, resulting in double haptic on tab change. | `FloatingTabBar`, `AppView` |
| C10 | **`nonisolated struct` annotation** — Multiple structs (`CharterModel`, `LibraryModel`, `Checklist`, etc.) are marked `nonisolated` explicitly. This is only meaningful with strict concurrency module-level inference and should be documented or removed for clarity. | Multiple model files |

---

### 2.D — UX & UI

| # | Issue | Location |
|---|-------|----------|
| D1 | **No Dynamic Type support** — all 50+ typography definitions use fixed `Font.system(size:)` instead of `Font.system(.body)` or `@ScaledMetric`. Users who increase text size see no change. | `DesignSystemTypography.swift` |
| D2 | **`onTapGesture` instead of `Button`** — `HomeView` hero card (line 155) uses `.onTapGesture`, losing visual press state, `.isButton` accessibility trait, and standard hit testing. | `HomeView.swift` |
| D3 | **No-op "View Voyage Log" button** — `CharterDetailView` line 531 has `Button { }` for completed charters. Users tap and nothing happens — should be disabled with a "coming soon" label or hidden. | `CharterDetailView.swift` |
| D4 | **No validation feedback on charter editor** — Save button is disabled when `!viewModel.isValid` (line 307) with reduced opacity, but no inline messages tell the user *what* to fix. | `CharterEditorView.swift` |
| D5 | **`Spacer()` in `ScrollView`** — `HomeView` line 34 uses a `Spacer()` inside a `ScrollView`'s `VStack`, which has undefined behavior (spacers expand infinitely in the scroll axis). | `HomeView.swift` |
| D6 | **Load more requires explicit button tap** — Charter discovery list (line 144) needs a "Load More" button. Infinite scroll with `.onAppear` on the last item would be more natural. | `CharterDiscoveryView.swift` |
| D7 | **Hardcoded English strings** — `CharterEditorView` lines 77-78 have `"Sign In to Share"` and `"Sign in to share your charter..."` bypassing `L10n`. | `CharterEditorView.swift` |
| D8 | **Emoji in code** — `HomeView` line 258 concatenates "📌" in a section header string. Should use the design system or localization layer. | `HomeView.swift` |
| D9 | **Double `NavigationStack`** — `ProfileView` wraps content in `NavigationStack` (line 21), but the parent tab already provides one via `AppView`. This creates double navigation bar behavior on certain routes. | `ProfileView.swift` |
| D10 | **Map stays mounted when hidden** — `CharterDiscoveryView` sets the map to `opacity(0)` instead of removing it from the hierarchy, consuming GPU/memory even in list mode. | `CharterDiscoveryView.swift` |

---

### 2.E — Tests & Reliability

| # | Issue | Location |
|---|-------|----------|
| E1 | **`ContentSyncServiceIntegrationTests` is 1602 lines** — a single test file covering too much surface. Should be split by operation type (publish, unpublish, update, retry). | `anyfleetTests/` |
| E2 | **`MockLocalRepository.fetchCharter(id:)` ignores the ID** — always returns the same pre-configured result. Tests needing per-ID behavior silently pass with wrong data. | `MockLocalRepository` |
| E3 | **`MockAuthService` has no call counters for most methods** — only `getAccessTokenCallCount` and `refreshCallCount` are tracked. `logout`, `deleteAccount`, `updateProfile` have no counters, limiting assertion capability. | `MockAuthService` |
| E4 | **Test-environment code in production `@main`** — `RESET_SWIPE_ONBOARDING` check and `UserDefaults` resets belong in a test helper or launch argument handler, not the production entry point. | `anyfleetApp.swift` |
| E5 | **No negative test for `pullMyCharters` when unauthenticated** — `CharterSyncServiceTests` tests push guards but not pull guards. | `CharterSyncServiceTests` |

---

## 3. Refactored Code

### 3.1 — Fix ViewModel Lifecycle in AppView (Critical — A3)

The most impactful single change. ViewModels are moved to `@State` so they survive re-renders.

```swift
// App/AppView.swift — full replacement

import SwiftUI

struct AppView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator
    @Bindable private var bindableCoordinator: AppCoordinator

    @State private var homeVM: HomeViewModel?
    @State private var charterListVM: CharterListViewModel?
    @State private var libraryListVM: LibraryListViewModel?
    @State private var discoverVM: DiscoverViewModel?
    @State private var charterDiscoveryVM: CharterDiscoveryViewModel?
    @State private var profileVM: ProfileViewModel?

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selectedTab) {
                homeTab.tag(AppTab.home)
                chartersTab.tag(AppTab.charters)
                libraryTab.tag(AppTab.library)
                discoverTab.tag(AppTab.discover)
                profileTab.tag(AppTab.profile)
            }

            if let toast = dependencies.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }

            FloatingTabBar(
                selectedTab: $coordinator.selectedTab,
                syncQueueService: dependencies.syncQueueService,
                charterSyncService: dependencies.charterSyncService
            )
        }
        .animation(.easeInOut(duration: 0.25), value: dependencies.toast != nil)
        .task { createViewModelsIfNeeded() }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var homeTab: some View {
        NavigationStack(path: $coordinator.homePath) {
            if let vm = homeVM {
                HomeView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var chartersTab: some View {
        NavigationStack(path: $coordinator.chartersPath) {
            if let vm = charterListVM {
                CharterListView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var libraryTab: some View {
        NavigationStack(path: $coordinator.libraryPath) {
            if let vm = libraryListVM {
                LibraryListView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var discoverTab: some View {
        NavigationStack(path: $coordinator.discoverPath) {
            if let dvm = discoverVM, let cdvm = charterDiscoveryVM {
                DiscoverView(viewModel: dvm, charterDiscoveryViewModel: cdvm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var profileTab: some View {
        NavigationStack(path: $coordinator.profilePath) {
            if let vm = profileVM {
                ProfileView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
    }

    // MARK: - ViewModel Factory

    private func createViewModelsIfNeeded() {
        if homeVM == nil {
            homeVM = HomeViewModel(
                charterStore: dependencies.charterStore,
                libraryStore: dependencies.libraryStore,
                coordinator: coordinator
            )
        }
        if charterListVM == nil {
            charterListVM = CharterListViewModel(
                charterStore: dependencies.charterStore,
                charterSyncService: dependencies.charterSyncService,
                coordinator: coordinator
            )
        }
        if libraryListVM == nil {
            libraryListVM = LibraryListViewModel(
                libraryStore: dependencies.libraryStore,
                syncService: dependencies.contentSyncService,
                coordinator: coordinator
            )
        }
        if discoverVM == nil {
            discoverVM = DiscoverViewModel(
                apiClient: dependencies.apiClient
            )
        }
        if charterDiscoveryVM == nil {
            charterDiscoveryVM = CharterDiscoveryViewModel(
                apiClient: dependencies.apiClient,
                locationProvider: dependencies.locationSearchService
            )
        }
        if profileVM == nil {
            profileVM = ProfileViewModel(
                authService: dependencies.authService,
                apiClient: dependencies.apiClient,
                charterStore: dependencies.charterStore,
                libraryStore: dependencies.libraryStore
            )
        }
    }
}
```

**Rationale:** `@State` ensures VMs are created once and survive `body` re-evaluation. The `@Bindable` wrapper on coordinator replaces manual `Binding(get:set:)` boilerplate. Tab contents are extracted into computed properties for readability.

---

### 3.2 — Extract ToastManager (A1)

```swift
// App/ToastManager.swift — new file

import Foundation
import Observation

@MainActor
@Observable
final class ToastManager {
    private(set) var toast: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, type: ToastType = .success, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()
        toast = ToastMessage(message: message, type: type)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        toast = nil
    }
}
```

Then remove `toast`, `showToast()`, and `toastDismissTask` from `AppDependencies` and inject `ToastManager` as a separate environment dependency.

**Rationale:** Single responsibility — the DI container should not own UI feedback state.

---

### 3.3 — Shared Charter Date Protocol (A6, B2)

```swift
// Core/Models/CharterDateComputing.swift — new file

import Foundation

protocol CharterDateComputing {
    var startDate: Date { get }
    var endDate: Date { get }
}

extension CharterDateComputing {
    func daysUntilStart(from now: Date = Date()) -> Int {
        Calendar.current.dateComponents([.day], from: now, to: startDate).day ?? 0
    }

    func durationDays() -> Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    func isUpcoming(from now: Date = Date()) -> Bool {
        startDate > now
    }

    func urgencyLevel(from now: Date = Date()) -> CharterUrgencyLevel {
        if endDate < now { return .past }
        if startDate <= now { return .ongoing }
        switch daysUntilStart(from: now) {
        case 0...7: return .imminent
        case 8...30: return .soon
        default: return .future
        }
    }

    static var sharedDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    func dateRange() -> String {
        let f = Self.sharedDateFormatter
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }
}
```

Then make both models conform:

```swift
extension CharterModel: CharterDateComputing {}
extension DiscoverableCharter: CharterDateComputing {}
```

Remove the duplicated computed properties from both types. The `now` parameter makes these testable.

**Rationale:** Eliminates divergent logic (the old `CharterModel` lacked `.ongoing`), makes date calculations injectable for testing, and shares the `DateFormatter` allocation.

---

### 3.4 — Static DateFormatters (B1)

Replace all inline `DateFormatter` allocations with static cached instances:

```swift
// Core/Utilities/Formatters.swift — new file

import Foundation

enum AppFormatters {
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    static let iso8601: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
```

Then in `CharterDetailView`, replace:

```swift
// Before (allocated every body evaluation)
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}

// After
// Use AppFormatters.mediumDate directly
```

And in `ProfileView.formatDate`, `HomeView.dateText`, `DiscoverableCharter.dateRange` — same pattern.

**Rationale:** `DateFormatter` is expensive to allocate (Apple's own docs warn about this). Static instances are allocated once and reused.

---

### 3.5 — Dynamic Type Support (D1)

Replace fixed font sizes with scalable alternatives:

```swift
// DesignSystem/DesignSystemTypography.swift — key changes

extension DesignSystem {
    enum Typography {
        // MARK: - Display

        static let display = Font.custom("Onder", size: 34, relativeTo: .largeTitle)
        static let largeTitle = Font.custom("Onder", size: 28, relativeTo: .title)

        // MARK: - Headings

        static let pageTitle = Font.system(.title2, weight: .bold)
        static let pageTitleRegular = Font.system(.title2)
        static let sectionTitle = Font.system(.headline)
        static let cardTitle = Font.system(.subheadline, weight: .semibold)

        // MARK: - Body

        static let body = Font.system(.body)
        static let bodyMedium = Font.system(.body, weight: .medium)
        static let bodySemibold = Font.system(.body, weight: .semibold)
        static let bodyBold = Font.system(.body, weight: .bold)

        // MARK: - Captions

        static let caption = Font.system(.caption)
        static let captionMedium = Font.system(.caption, weight: .medium)
        static let captionBold = Font.system(.caption, weight: .bold)
        static let caption2 = Font.system(.caption2)
        static let caption2Medium = Font.system(.caption2, weight: .medium)

        // MARK: - Labels

        static let label = Font.system(.footnote, weight: .medium)
        static let labelBold = Font.system(.footnote, weight: .bold)

        // MARK: - Symbols (use @ScaledMetric in views for frame sizes)

        static let symbolSM = Font.system(.footnote, weight: .medium)
        static let symbolMD = Font.system(.callout, weight: .semibold)
        static let symbolLG = Font.system(.title3, weight: .semibold)
        static let symbolXL = Font.system(.title2, weight: .semibold)
    }
}
```

For frame sizes that need to scale with Dynamic Type, use `@ScaledMetric` in views:

```swift
struct ProfileAvatarView: View {
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 44

    var body: some View {
        Circle()
            .frame(width: avatarSize, height: avatarSize)
    }
}
```

**Rationale:** Using `Font.system(.body)` and `.relativeTo:` makes all text respond to the user's preferred text size, a core iOS accessibility feature.

---

### 3.6 — Fix HomeView Accessibility (D2, D5)

```swift
// Features/Home/HomeView.swift — key changes to hero card

// Before:
// .onTapGesture { coordinator.push(...) }

// After:
Button {
    coordinator.push(.charterDetail(charterID: charter.id), tab: .home)
} label: {
    heroCardContent(charter: charter)
}
.buttonStyle(.plain)
.accessibilityLabel(Text("\(charter.name), \(charter.daysUntilStart) days away"))
.accessibilityHint(Text("Opens charter details"))
.accessibilityAddTraits(.isButton)

// Also: remove the Spacer() from inside ScrollView VStack.
// Replace with explicit padding or a fixed-height spacer:
// Before: Spacer()
// After: Color.clear.frame(height: 100) // tab bar clearance
```

**Rationale:** `Button` gives VoiceOver users proper `.isButton` trait, visual press feedback, and standard hit testing. `Spacer()` in a `ScrollView` has undefined layout behavior.

---

### 3.7 — Generic Paginated Response (B3, repeated wrapper pattern)

```swift
// Core/Models/API/PaginatedResponse.swift — new file

import Foundation

struct PaginatedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let total: Int
    let limit: Int
    let offset: Int
}

// Usage: replace CharterDiscoveryAPIResponse, CharterListAPIResponse,
// VirtualCaptainListResponse with:
//   typealias CharterDiscoveryAPIResponse = PaginatedResponse<CharterWithUserAPIResponse>
//   typealias CharterListAPIResponse = PaginatedResponse<CharterAPIResponse>
//   typealias VirtualCaptainListResponse = PaginatedResponse<VirtualCaptain>
```

**Rationale:** Eliminates 3 identical structs and prevents the pattern from proliferating as new endpoints are added.

---

### 3.8 — #if DEBUG Gate for Preview/Mock Data (B9)

Wrap all preview-only code in conditional compilation:

```swift
// CharterMapView.swift — wrap mock data section
#if DEBUG
// MARK: - Preview Data
struct PreviewCharterMapData { ... }

#Preview("Map – Clusters") { ... }
#Preview("Map – Empty") { ... }
#endif

// LibraryListView.swift — wrap PreviewLibraryRepository
#if DEBUG
final class PreviewLibraryRepository: LibraryRepository { ... }
#endif

// LibraryListViewModel.swift — wrap mockAuthorProfile
#if DEBUG
static let mockAuthorProfile = AuthorProfile(...)
#endif
```

**Rationale:** Preview and mock data should never ship in the production binary — it increases app size and can accidentally leak test data.

---

### 3.9 — Fix Charter Editor Progress Bug (C6)

```swift
// Features/Charter/CharterEditorViewModel.swift

// Before (line 341):
// if form.startDate != .now { progress += 0.2 }

// After:
private static let defaultStartDate = Date.distantFuture

func calculateProgress() -> Double {
    var progress = 0.0
    if !form.name.trimmingCharacters(in: .whitespaces).isEmpty { progress += 0.2 }
    if form.startDate != form.endDate { progress += 0.2 }
    if form.location?.isEmpty == false { progress += 0.2 }
    if form.boatName?.isEmpty == false { progress += 0.2 }
    if form.visibility != .private { progress += 0.2 }
    return min(progress, 1.0)
}
```

**Rationale:** `.now` creates a new `Date()` on every call, so `form.startDate != .now` is almost always true. The fix checks whether the user has meaningfully changed the date instead.

---

### 3.10 — Remove `@MainActor` from Error Descriptions (C5)

```swift
// Core/Errors/AppError.swift — remove @MainActor from localizedDescription

enum AppError: LocalizedError, Identifiable {
    // ...

    var id: String { localizedDescription ?? "unknown" }

    var errorDescription: String? {
        switch self {
        case .notFound(let entity, let id):
            return "\(entity) \(id.uuidString) not found"
        case .validationFailed(let field, let reason):
            return "Validation failed for \(field): \(reason)"
        case .databaseError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        case .networkError(let networkError):
            return networkError.errorDescription
        case .authenticationError(let authError):
            return authError.errorDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    // ... same for recoverySuggestion
}
```

For the localized strings, access `L10n` from the view layer (where you're already on `@MainActor`) rather than embedding `L10n` calls inside the error type. The error should produce a machine-readable key or plain English string; the view can map it to localized text.

**Rationale:** `@MainActor` on `errorDescription` prevents logging errors from background tasks and breaks the `LocalizedError` contract which expects nonisolated access.

---

### 3.11 — Replace `onTapGesture` with `Button` Pattern

Across all views that use `.onTapGesture` for interactive elements, replace with `Button` for proper semantics:

```swift
// General pattern — before:
SomeCard()
    .onTapGesture { action() }

// After:
Button(action: action) {
    SomeCard()
}
.buttonStyle(.plain)
```

Affected files: `HomeView` (hero card), `CharterDiscoveryRow`, `LibraryItemRow`.

**Rationale:** `Button` provides VoiceOver `.isButton` trait, visual feedback on press, and respects `.disabled()` state automatically.

---

### 3.12 — Infinite Scroll for Charter Discovery (D6)

```swift
// Features/Charter/Discovery/CharterDiscoveryView.swift — replace load more button

// Before:
Button(L10n.Charter.Discovery.loadMore) {
    Task { await viewModel.loadMore() }
}

// After — trigger on appearance of last item:
ForEach(viewModel.charters) { charter in
    CharterDiscoveryRow(charter: charter)
        .onAppear {
            if charter.id == viewModel.charters.last?.id {
                Task { await viewModel.loadMore() }
            }
        }
}

if viewModel.isLoadingMore {
    ProgressView()
        .frame(maxWidth: .infinity)
        .padding()
}
```

**Rationale:** Infinite scroll is the expected pattern for feed-style content on iOS. An explicit "Load More" button adds unnecessary friction.

---

## 4. Proposed High-Value Test Cases (section 2.E)

### Test 1 — ViewModel survives AppView re-render

```swift
@Test @MainActor
func viewModelIsNotReCreatedOnBodyEvaluation() async {
    let deps = try! AppDependencies.makeForTesting()
    let coordinator = AppCoordinator(dependencies: deps)
    let view = AppView()
        .environment(\.appDependencies, deps)
        .environment(\.appCoordinator, coordinator)

    // Force two body evaluations
    let host = UIHostingController(rootView: view)
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    // Assert the VM identity is stable (requires exposing a testable handle)
}
```

### Test 2 — Charter urgency level consistency

```swift
@Test
func charterAndDiscoverableCharterProduceSameUrgency() {
    let now = Date()
    let start = now.addingTimeInterval(3 * 86400) // 3 days from now
    let end = start.addingTimeInterval(7 * 86400)

    let local = CharterModel(id: UUID(), name: "Test", startDate: start, endDate: end, createdAt: now)
    let discoverable = DiscoverableCharter(
        id: UUID(), name: "Test", boatName: nil, destination: nil,
        startDate: start, endDate: end, latitude: nil, longitude: nil,
        distanceKm: nil, captain: .init(id: UUID(), username: nil, profileImageThumbnailURL: nil)
    )

    #expect(local.urgencyLevel(from: now) == discoverable.urgencyLevel(from: now))
}
```

### Test 3 — SyncQueueService handles auth-required state

```swift
@Test @MainActor
func syncQueueSetsNeedsAuthWhenUnauthenticated() async {
    let mockAuth = MockAuthService()
    mockAuth.isAuthenticated = false
    let service = SyncQueueService(repository: repo, apiClient: api, authService: mockAuth)

    let summary = await service.processQueue()

    #expect(service.needsAuthForSync == true)
    #expect(summary.attempted == 0)
}
```

### Test 4 — DateFormatter is not re-allocated

```swift
@Test
func appFormattersMediumDateReturnsSameInstance() {
    let f1 = AppFormatters.mediumDate
    let f2 = AppFormatters.mediumDate
    #expect(f1 === f2)
}
```

### Test 5 — pullMyCharters unauthenticated guard

```swift
@Test @MainActor
func pullMyChartersSkipsWhenUnauthenticated() async throws {
    let (service, mockAPI, _, _, mockAuth) = makeDependencies()
    mockAuth.isAuthenticated = false

    try await service.pullMyCharters()

    #expect(mockAPI.fetchMyChartersCallCount == 0)
}
```

---

## 5. App Store Readiness

### 5.A — Must Fix Before First Submission

These are items that will likely cause **App Review rejection** or **production crashes** if shipped as-is.

| # | Issue | Risk | Location | Effort |
|---|-------|------|----------|--------|
| S1 | **`fatalError` on database init failure** — `AppDatabase` line 421 crashes the app if the SQLite database can't be initialized (e.g. disk full, sandboxing issue). App Review often tests edge cases that trigger these. Must be replaced with a recoverable error UI (e.g. "Something went wrong — tap to retry" screen). | Crash → Rejection | `Data/Local/AppDatabase.swift` | Medium |
| S2 | **No-op "View Voyage Log" button** — `CharterDetailView` shows a prominent FAB that does nothing when tapped on completed charters. Apple rejects apps with buttons that don't function. Either hide it, disable with "Coming soon" label, or wire it to a placeholder screen. | Broken UI → Rejection | `Features/Charter/CharterDetailView.swift` | Small |
| S3 | **Flashcard deck route renders placeholder text** — `AppCoordinator.destination(for: .deckEditor)` returns `Text("Deck Editor - Coming Soon")`. If any UI path reaches this (and it can via the library create menu), it looks unfinished. Remove the route entirely or gate behind a feature flag. | Incomplete feature → Rejection | `App/AppModel.swift` line 263 | Small |
| S4 | **Test/mock data ships in production binary** — ~140 lines of mock charter data in `CharterMapView`, `PreviewLibraryRepository` in `LibraryListView`, `mockAuthorProfile` in `LibraryListViewModel`. Apple's review may flag this as test content visible to users, and it increases binary size needlessly. Wrap all preview code in `#if DEBUG`. | Test content → Possible rejection | Multiple files | Small |
| S5 | **`print()` statements in production** — 6 `print()` calls in `CharterMapView` and 1 in `LibraryStore`. These output user data to the console, which Apple views as a privacy concern during review. Replace with `AppLogger` or remove. | Privacy concern | `CharterMapView`, `LibraryStore` | Tiny |
| S6 | **ViewModel lifecycle bug** — ViewModels created in `body` (see section 3.1) cause visible state loss when the user switches tabs and returns. A reviewer trying the app for 5 minutes will notice list positions resetting and loading indicators re-appearing. | Poor UX during review | `App/AppView.swift` | Small |
| S7 | **Missing `NSPhotoLibraryUsageDescription`** — The app uses `PhotosUI` (`PhotosPicker`) for profile image upload. While `PHPickerViewController` (used by `PhotosPicker`) does not require a usage description on iOS 14+, the App Review team has historically flagged apps that access photos without one. Adding a description to `Info.plist` is a safety net. | Possible rejection | `Info.plist` | Tiny |
| S8 | **App Privacy "nutrition label"** — App Store Connect requires you to declare what data your app collects (location, user content, identifiers, etc.) before submission. Prepare the declaration based on: location (when in use), user content (charters, checklists), authentication (Apple ID, tokens), profile data (name, bio, photo). Not a code change, but blocks submission if not done. | Blocks submission | App Store Connect | Small |

### 5.B — Strongly Recommended Before v1.0

These won't cause rejection but significantly affect perceived quality during review and first user impressions.

| # | Issue | Why It Matters | Effort |
|---|-------|----------------|--------|
| R1 | **No first-time user experience (FTUE)** — The app drops users onto an empty Home screen with no guidance. Only swipe-action hints exist. A brief onboarding flow (2-3 screens explaining charter planning, library, and community discovery) would dramatically improve first-session retention and give reviewers context. | Review teams are more favorable to apps that explain their value proposition upfront. | Medium |
| R2 | **No crash reporting** — No Crashlytics, Sentry, or even `MXMetricManager` integration. Post-launch, you'll have zero visibility into crashes beyond TestFlight feedback. Add at minimum Apple's native `MetricKit` for crash diagnostics. | You can't fix what you can't see. Day-1 crashes with no telemetry lead to bad ratings. | Small |
| R3 | **No network reachability check** — `SyncQueueService.isNetworkReachable()` always returns `true`. The app silently fails when offline instead of showing a meaningful offline banner. Use `NWPathMonitor` for real connectivity awareness. | Offline-first apps that pretend to be online confuse users. | Medium |
| R4 | **No app rating prompt** — No `SKStoreReviewController.requestReview()` integration. Best practice is to prompt after a positive moment (e.g. first charter saved, checklist completed). | Early ratings heavily influence App Store ranking. Without prompts, only frustrated users leave reviews. | Tiny |
| R5 | **Hardcoded English strings** — `CharterEditorView` has "Sign In to Share" and "Sign in to share your charter..." outside `L10n`. Since the app supports Russian, these will appear in English on `ru` locale. | Broken localization looks unprofessional. | Tiny |
| R6 | **Dynamic Type** — No text in the app responds to the system text size setting. This is an Apple Human Interface Guidelines expectation and increasingly checked in review. See section 3.5 for the fix. | Accessibility compliance; Apple highlights this in HIG. | Medium |
| R7 | **Deep linking is stubbed** — `handleDeepLink` is a TODO. While not required for v1.0, if you add Universal Links or custom URL schemes to your entitlements, the handler must actually work. If you don't claim any URL schemes, this is safe to defer. | Only matters if you've configured Associated Domains. | Medium |
| R8 | **iPad layout** — No evidence of iPad-specific layout handling. If the app runs on iPad (default for iPhone apps via compatibility mode), verify it doesn't break. If you don't want iPad v1.0, set "Requires iPhone" in build settings. | Reviewers may test on iPad. A broken iPad layout leads to rejection. | Small–Large |

### 5.C — Post-Launch Improvement Roadmap

Items that can be deferred to subsequent releases, organized by recommended release cadence.

#### v1.1 — Quality & Architecture (2-4 weeks after launch)

| Item | Description |
|------|-------------|
| **Extract ToastManager** (section 3.2) | Decouple UI feedback from the DI container. Reduces `AppDependencies` from god object to clean composition root. |
| **Split `LibraryStore`** | Extract `ContentCacheService`, `PublishPayloadBuilder`, and `ForkService`. The 703-line store becomes 3-4 focused classes under 200 lines each. |
| **Split `APIClient`** | Move into `APIClient+Charters.swift`, `APIClient+Content.swift`, `APIClient+Profile.swift`. Eliminate duplicated request methods by extracting a shared `performRequest` core. |
| **Dead code cleanup** | Remove all commented-out flashcard deck code (~15 files), unused `CharterFormState` fields, `sortedByDate` in `CharterListViewModel`, and `FlashcardDeck` stub type. |
| **Consistent logging** | Fix `ContentSyncService` using `AppLogger.auth` instead of `.sync`. Remove `print()` remnants. Audit that every service uses the correct category. |

#### v1.2 — UX Polish (4-8 weeks)

| Item | Description |
|------|-------------|
| **Infinite scroll for discovery** (section 3.12) | Replace the "Load More" button with `.onAppear`-triggered pagination on the last item. |
| **Validation feedback on charter editor** (D4) | Show inline error messages below fields when `isValid` is false, telling users what needs fixing. |
| **Loading / empty / error states audit** | Ensure every list screen has polished loading skeleton, empty state with CTA, and error banner with retry. Currently some screens have these, others don't. |
| **Onboarding flow** | 2-3 screen walkthrough after first launch: "Plan your charter", "Build your library", "Discover the community". Store completion in UserDefaults. |
| **`Button` semantics everywhere** | Replace all `.onTapGesture` usages on interactive elements with proper `Button` wrappers for VoiceOver support and press feedback. |

#### v1.3 — Accessibility & Performance (8-12 weeks)

| Item | Description |
|------|-------------|
| **Full Dynamic Type support** (section 3.5) | Migrate all 50+ typography definitions from `Font.system(size:)` to `Font.system(.textStyle)`. Add `@ScaledMetric` for icon frames. |
| **VoiceOver audit** | Walk through every screen with VoiceOver enabled. Add `.accessibilityLabel`, `.accessibilityHint`, and `.accessibilityElement(children:)` where missing. Focus order should be logical. |
| **Color contrast check** | Verify all text/background combinations meet WCAG AA (4.5:1 for body, 3:1 for large text). The ocean-tinted dark mode surfaces need particular attention. |
| **Map clustering performance** | Move `buildClusters` off the main thread (`Task.detached` or `actor`). The current O(n*m) algorithm blocks the main thread during camera changes. |
| **Remove `@MainActor` from error types** (section 3.10) | Unblock background error handling and logging. |

#### v2.0 — Feature Completion

| Item | Description |
|------|-------------|
| **Voyage Log** | Wire the "View Voyage Log" button to actual functionality (photo timeline, notes, route tracking). |
| **Flashcard Decks** | Either implement the full feature (editor, reader, spaced repetition) or permanently remove all traces. The current half-state is technical debt. |
| **Deep Linking** | Implement `handleDeepLink` for shared charters, published content, and author profiles. Register Universal Links in Associated Domains. |
| **Export Data / Activity Log** | The `L10n` strings exist but the UI doesn't expose them. Implement GDPR-compliant data export and activity history. |
| **Nautical miles & regions** | `CaptainStats.nauticalMiles` and `regionsVisited` are placeholder Phase 3 fields. Implement GPS tracking during active charters. |
| **Offline sync resilience** | Replace the always-`true` `isNetworkReachable()` with `NWPathMonitor`. Show sync queue status when offline. Auto-retry on reconnection. |

---

## 6. Priority Execution Order

Pre-submission blockers first, then code quality, then post-launch improvements.

| Priority | Change | Effort | Impact |
|----------|--------|--------|--------|
| **P0 — Blocks submission** | Fix `fatalError` in AppDatabase (S1) | Medium | Prevents production crash |
| **P0 — Blocks submission** | Remove/disable no-op Voyage Log button (S2) | Small | Eliminates dead UI |
| **P0 — Blocks submission** | Remove flashcard deck placeholder route (S3) | Small | Eliminates unfinished feature |
| **P0 — Blocks submission** | `#if DEBUG` gates for mock data (S4, 3.8) | Small | Stops shipping test content |
| **P0 — Blocks submission** | Replace `print()` with `AppLogger` (S5) | Tiny | Privacy compliance |
| **P0 — Blocks submission** | Fix ViewModel lifecycle in AppView (S6, 3.1) | Small | Eliminates state loss reviewers will notice |
| **P0 — Blocks submission** | Prepare App Privacy nutrition label (S8) | Small | Required in App Store Connect |
| P1 | Static DateFormatters (3.4) | Small | Removes ~4 allocation-per-frame performance issues |
| P1 | Charter date protocol (3.3) | Small | Fixes the divergent urgency-level bug |
| P1 | Fix progress calculation bug (3.9) | Tiny | Fixes always-true comparison |
| P1 | Hardcoded English strings (R5) | Tiny | Fixes broken ru localization |
| P2 | Crash reporting integration (R2) | Small | Post-launch visibility into issues |
| P2 | Network reachability (R3) | Medium | Honest offline experience |
| P2 | App rating prompt (R4) | Tiny | Drives early App Store ratings |
| P2 | Dynamic Type support (3.5) | Medium | Accessibility compliance |
| P2 | Button semantics (3.6, 3.11) | Small | Fixes VoiceOver and interaction feedback |
| P3 | Extract ToastManager (3.2) | Medium | Improves SRP of AppDependencies |
| P3 | Onboarding flow (R1) | Medium | First-session retention |
| P3 | Infinite scroll (3.12) | Small | UX improvement for discovery feed |
| P3 | Generic PaginatedResponse (3.7) | Small | Reduces boilerplate for new endpoints |
| P3 | Remove `@MainActor` from errors (3.10) | Medium | Unblocks background error handling |
| P4 | Split LibraryStore, LocalRepository, APIClient | Large | Long-term maintainability |
| P4 | Dead code cleanup | Medium | Reduces cognitive load |
| P4 | iPad layout verification (R8) | Small–Large | Prevents iPad rejection |
