# Sailaway Navigation Architecture PRD
## iOS App Navigation System

**Version:** 1.0  
**Status:** Design Phase  
**Last Updated:** December 2025  

---

## TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Navigation Goals & Principles](#navigation-goals--principles)
3. [App Structure Overview](#app-structure-overview)
4. [Navigation Hierarchy](#navigation-hierarchy)
5. [Core Navigation Flows](#core-navigation-flows)
6. [SwiftUI Implementation Architecture](#swiftui-implementation-architecture)
7. [Navigation Coordinator Pattern](#navigation-coordinator-pattern)
8. [Tab Navigation Strategy](#tab-navigation-strategy)
9. [Deep Linking & URL Handling](#deep-linking--url-handling)
10. [Error Handling & Edge Cases](#error-handling--edge-cases)
11. [Accessibility & Navigation](#accessibility--navigation)
12. [Performance Considerations](#performance-considerations)
13. [Testing Navigation Flows](#testing-navigation-flows)

---

## EXECUTIVE SUMMARY

The Sailaway iOS app requires a **hybrid navigation architecture** combining:

1. **Tab-based primary navigation** (Home, Library, Discover, Profile, Charters)
2. **Independent NavigationStack per tab** (preserves per-tab history)
3. **Global coordinator** (manages state, routing, deep linking)
4. **Custom URL scheme support** (for deep links and sharing)

**Key Decision:** Each tab maintains its own NavigationStack with isolated navigation history. A global coordinator orchestrates routing while tabs remain independent—this is the iOS standard (matching Apple Mail, Messages, Notes).

---

## NAVIGATION GOALS & PRINCIPLES

### Primary Goals

1. **Preserve Tab State** — Users expect switching tabs to preserve their position
2. **Clear Back Navigation** — Users know how to get back
3. **Deep Linking Support** — Links from web/email open correct screen
4. **Offline Navigation** — Works completely without network
5. **Performance** — No jank, smooth transitions
6. **Accessibility** — VoiceOver and keyboard navigation work

### Core Principles

**Principle 1: Tabs Are Independent**  
Each tab is its own self-contained app. Switching tabs doesn't affect other tabs' navigation stacks.

**Principle 2: Navigation State Lives in ViewModel**  
Never in the view. Views are derived from state.

**Principle 3: Coordinator Orchestrates Global Routing**  
Cross-tab navigation (home → charter → create checklist on different tab) flows through coordinator.

**Principle 4: Back Button Behavior is Predictable**  
Back button pops current stack. Switching tabs doesn't add to back stack.

**Principle 5: No Synchronization Across Tabs**  
If user creates content in one tab, it's immediately visible when switching tabs (because it's in database), but the **navigation state** stays isolated.

---

## APP STRUCTURE OVERVIEW

### Tab Architecture

```
AppView (root)
├─ @StateObject AppCoordinator (global state, routing)
├─ TabView (native tab bar)
│  │
│  ├─ Tab: Home
│  │  └─ NavigationStack(path: $coordinator.homePath)
│  │     └─ HomeView → (browse, create, etc.)
│  │
│  ├─ Tab: My Library
│  │  └─ NavigationStack(path: $coordinator.libraryPath)
│  │     └─ LibraryView → (created, forked, contributed)
│  │
│  ├─ Tab: Discover
│  │  └─ NavigationStack(path: $coordinator.discoverPath)
│  │     └─ DiscoverView → (trending, recommendations)
│  │
│  ├─ Tab: Charters
│  │  └─ NavigationStack(path: $coordinator.chartersPath)
│  │     └─ CharterListView → (create, detail, checklist)
│  │
│  └─ Tab: Profile
│     └─ NavigationStack(path: $coordinator.profilePath)
│        └─ ProfileView → (settings, followers, etc.)
│
└─ Environment(\.appCoordinator, coordinator) (pass to all views)
```

---

## NAVIGATION HIERARCHY

### Content Type Routes

```
Content Item (Checklist, Flashcard Deck, Guide)
├─ Browse (read-only, public library)
│  └─ Content Detail
│     └─ Optional: Ratings/reviews tab
│
└─ Library (user's own + forked)
   ├─ Edit Mode
   │  └─ Editor (checklist/deck/guide specific)
   │
   ├─ Fork Creation
   │  └─ Rename/customize fork → Save to library
   │
   └─ During Charter
      └─ Checklist Execution (interactive, checkable)
```

### Charter Routes

```
Charter
├─ Create Charter
│  ├─ Basic info (name, dates, crew)
│  └─ Select checklists (pre-charter, daily, post)
│
├─ Charter List (home/archive tabs)
│
└─ Charter Detail
   ├─ Open Check-in Checklist
   ├─ Open Daily Checklist
   ├─ Open Post-charter Checklist
   ├─ Edit crew list
   └─ Archive charter
```

### User Profile Routes

```
Profile
├─ Own Profile
│  ├─ Edit profile
│  ├─ Followers list
│  ├─ Following list
│  ├─ Settings
│  │  ├─ Account settings
│  │  ├─ Sync status
│  │  ├─ Privacy
│  │  ├─ Notifications
│  │  └─ About
│  │
│  └─ Data management
│     ├─ Export data
│     ├─ Clear cache
│     └─ Delete account
│
└─ Other User's Profile
   ├─ Content (checklists, decks, guides)
   ├─ Followers list
   ├─ Following list
   └─ [Follow] button
```

### Search & Discovery Routes

```
Search Results
├─ Filter/refine
├─ Select result → Content Detail
└─ Empty state / No results

Trending/Recommended
├─ Tap item → Content Detail
└─ "See all" → Search with preset filters
```

---

## CORE NAVIGATION FLOWS

### Flow 1: Create Checklist (In Home Tab)

```
Home
  ↓
[Tap "Create Checklist" FAB]
  ↓
Checklist Type Selection
  ├─ Create blank
  ├─ Fork existing
  └─ Import file
  ↓
[Choose "Create blank"]
  ↓
Checklist Editor
  ├─ Add sections
  ├─ Add items
  ├─ Preview
  └─ [Save]
  ↓
Saved locally, appears in My Library
  ↓
[Publish]
  ↓
Visibility selector (private/unlisted/public)
  ↓
Content published, appears in Discover
```

**Navigation Code:**
```swift
struct AppCoordinator {
    @Published var homePath: [ChecklistRoute] = []
    
    func createChecklist() {
        homePath.append(.checklistEditor(id: UUID(), mode: .create))
    }
}

// In HomeView:
NavigationStack(path: $coordinator.homePath) {
    HomeView()
        .navigationDestination(for: ChecklistRoute.self) { route in
            switch route {
            case .checklistEditor(let id, let mode):
                ChecklistEditorView(checklistID: id, mode: mode)
            }
        }
}
```

### Flow 2: Fork & Customize (Cross-Tab)

```
User in Discover Tab
  ↓
[Browse library]
  ↓
[Tap checklist card]
  ↓
Content Detail View (read-only)
  ↓
[Fork button]
  ↓
Fork created in My Library
  ↓
Switch to Library Tab
  ↓
[See forked checklist]
  ↓
[Edit button]
  ↓
Checklist Editor (editable copy)
```

**Key Point:** Switching tabs doesn't lose the content. Both Discover and Library tabs can show the same content (different modes: read-only vs. editable).

### Flow 3: Charter Execution (Long-Lived State)

```
Charters Tab → Create Charter
  ↓
Input boat, dates, crew
  ↓
Select check-in checklist
  ↓
Charter created, detail view shown
  ↓
[Open Check-in Checklist]
  ↓
Checklist Execution View (interactive)
  ├─ Tap items to check
  ├─ Add notes
  └─ Progress tracked locally
  ↓
[Back] → Charter Detail
  ↓
Progress saved in database
  ↓
Switch to Home Tab, do other things
  ↓
Switch back to Charters Tab
  ↓
[Open same charter]
  ↓
Progress is still there (persisted in database)
```

**State Persistence:** Charter state is in database, not view state. Switching tabs doesn't lose progress.

### Flow 4: Deep Link (From Email)

```
User receives email: "Check out this checklist: [link]"
  ↓
Taps link
  ↓
App opens (handles URL in AppDelegate)
  ↓
Coordinator.handleDeepLink(url)
  ↓
Parses URL → contentID
  ↓
Shows appropriate tab
  ↓
Navigates to content detail
  ↓
User sees checklist (can fork/rate/etc.)
```

**Example URL:**
```
sailaway://content/checklist/550e8400-e29b-41d4-a716-446655440000
sailaway://user/550e8400-e29b-41d4-a716-446655440001
sailaway://charter/550e8400-e29b-41d4-a716-446655440002
```

---

## SWIFTUI IMPLEMENTATION ARCHITECTURE

### AppView (Root Container)

```swift
@main
struct SailawayApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @State private var selectedTab: Tab = .home
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                // Tab content
                TabView(selection: $selectedTab) {
                    // Home Tab
                    NavigationStack(path: $coordinator.homePath) {
                        HomeView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(for: route, tab: .home)
                            }
                    }
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(Tab.home)
                    
                    // Library Tab
                    NavigationStack(path: $coordinator.libraryPath) {
                        LibraryView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(for: route, tab: .library)
                            }
                    }
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                    .tag(Tab.library)
                    
                    // Discover Tab
                    NavigationStack(path: $coordinator.discoverPath) {
                        DiscoverView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(for: route, tab: .discover)
                            }
                    }
                    .tabItem {
                        Label("Discover", systemImage: "sparkles")
                    }
                    .tag(Tab.discover)
                    
                    // Charters Tab
                    NavigationStack(path: $coordinator.chartersPath) {
                        CharterListView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(for: route, tab: .charters)
                            }
                    }
                    .tabItem {
                        Label("Charters", systemImage: "sailboat.fill")
                    }
                    .tag(Tab.charters)
                    
                    // Profile Tab
                    NavigationStack(path: $coordinator.profilePath) {
                        ProfileView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(for: route, tab: .profile)
                            }
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(Tab.profile)
                }
            }
            .environment(\.appCoordinator, coordinator)
            .onChange(of: selectedTab) { oldTab, newTab in
                // No action needed - tabs are independent
                // Switching tabs doesn't affect navigation stack
            }
        }
    }
    
    @ViewBuilder
    private func routeDestination(for route: AppRoute, tab: Tab) -> some View {
        switch route {
        case .checklistDetail(let id):
            ChecklistDetailView(checklistID: id)
        case .checklistEditor(let id):
            ChecklistEditorView(checklistID: id)
        case .checklistExecution(let charterID, let checklistID):
            ChecklistExecutionView(charterID: charterID, checklistID: checklistID)
        case .deckDetail(let id):
            FlashcardDeckDetailView(deckID: id)
        case .deckEditor(let id):
            FlashcardDeckEditorView(deckID: id)
        case .guideDetail(let id):
            PracticeGuideDetailView(guideID: id)
        case .guideEditor(let id):
            PracticeGuideEditorView(guideID: id)
        case .charterCreate:
            CharterCreateView()
        case .charterDetail(let id):
            CharterDetailView(charterID: id)
        case .profileUser(let userID):
            PublicProfileView(userID: userID)
        case .profileSettings:
            SettingsView()
        case .search(let query):
            SearchResultsView(query: query)
        }
    }
}

enum Tab: Hashable {
    case home
    case library
    case discover
    case charters
    case profile
}

enum AppRoute: Hashable {
    case checklistDetail(UUID)
    case checklistEditor(UUID)
    case checklistExecution(charterID: UUID, checklistID: UUID)
    case deckDetail(UUID)
    case deckEditor(UUID)
    case guideDetail(UUID)
    case guideEditor(UUID)
    case charterCreate
    case charterDetail(UUID)
    case profileUser(UUID)
    case profileSettings
    case search(String)
}
```

### HomeView (First Tab)

```swift
struct HomeView: View {
    @Environment(\.appCoordinator) var coordinator
    @StateObject private var viewModel: HomeViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hello, \(viewModel.userName)")
                        .font(.title2)
                        .bold()
                    Text("What would you like to do?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                
                // Quick actions
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "checkmark.circle",
                        label: "Create\nChecklist",
                        action: { coordinator.createChecklist(in: .home) }
                    )
                    ActionButton(
                        icon: "square.grid.2x2",
                        label: "New Deck",
                        action: { coordinator.createDeck(in: .home) }
                    )
                    ActionButton(
                        icon: "doc.text",
                        label: "New Guide",
                        action: { coordinator.createGuide(in: .home) }
                    )
                }
                .padding(16)
                
                // Recent activity / content
                ScrollView {
                    VStack(spacing: 16) {
                        // ... Recent charters, suggested content, etc.
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Home")
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .foregroundColor(.primary)
    }
}
```

### Coordinator Implementation

```swift
@MainActor
class AppCoordinator: ObservableObject {
    // Individual navigation paths per tab
    @Published var homePath: [AppRoute] = []
    @Published var libraryPath: [AppRoute] = []
    @Published var discoverPath: [AppRoute] = []
    @Published var chartersPath: [AppRoute] = []
    @Published var profilePath: [AppRoute] = []
    
    // Cross-tab state (if needed for modal presentations)
    @Published var presentedSheet: SheetDestination? = nil
    @Published var selectedTab: Tab = .home
    
    // MARK: - Home Tab Navigation
    
    func createChecklist(in tab: Tab) {
        let checklistID = UUID()
        let route: AppRoute = .checklistEditor(checklistID)
        
        switch tab {
        case .home:
            homePath.append(route)
        case .library:
            libraryPath.append(route)
        case .discover:
            discoverPath.append(route)
        case .charters:
            chartersPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }
    
    func viewChecklistDetail(_ id: UUID, in tab: Tab) {
        let route: AppRoute = .checklistDetail(id)
        
        switch tab {
        case .home:
            homePath.append(route)
        case .library:
            libraryPath.append(route)
        case .discover:
            discoverPath.append(route)
        case .charters:
            chartersPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }
    
    // MARK: - Charter Navigation
    
    func createCharter() {
        chartersPath.append(.charterCreate)
    }
    
    func viewCharter(_ id: UUID) {
        chartersPath.append(.charterDetail(id))
    }
    
    func executeChecklist(charterID: UUID, checklistID: UUID) {
        chartersPath.append(.checklistExecution(charterID: charterID, checklistID: checklistID))
    }
    
    // MARK: - Cross-Tab Navigation
    
    func navigateToProfile(_ userID: UUID) {
        // Switch to profile tab and show user profile
        selectedTab = .profile
        profilePath = [.profileUser(userID)]
    }
    
    func goToSettings() {
        selectedTab = .profile
        profilePath = [.profileSettings]
    }
    
    // MARK: - Deep Linking
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        switch components.host {
        case "content":
            if let type = components.queryItems?.first(where: { $0.name == "type" })?.value,
               let idString = components.path.split(separator: "/").last,
               let id = UUID(uuidString: String(idString)) {
                navigateToContent(type: type, id: id)
            }
        
        case "user":
            if let idString = components.path.split(separator: "/").last,
               let id = UUID(uuidString: String(idString)) {
                navigateToProfile(id)
            }
        
        case "charter":
            if let idString = components.path.split(separator: "/").last,
               let id = UUID(uuidString: String(idString)) {
                selectedTab = .charters
                chartersPath = [.charterDetail(id)]
            }
        
        default:
            break
        }
    }
    
    private func navigateToContent(type: String, id: UUID) {
        let route: AppRoute
        
        switch type {
        case "checklist":
            route = .checklistDetail(id)
            selectedTab = .discover
            discoverPath = [route]
        case "deck":
            route = .deckDetail(id)
            selectedTab = .discover
            discoverPath = [route]
        case "guide":
            route = .guideDetail(id)
            selectedTab = .discover
            discoverPath = [route]
        default:
            return
        }
    }
}

enum SheetDestination: Hashable {
    case rateContent(UUID)
    case shareContent(UUID)
    case reportContent(UUID)
}
```

---

## NAVIGATION COORDINATOR PATTERN

### Coordinator Responsibilities

The `AppCoordinator` is responsible for:

1. **Path Management** — One path per tab
2. **Route Validation** — Only valid routes are added
3. **State Synchronization** — Ensures database state matches UI state
4. **Deep Linking** — Parse URLs and navigate
5. **Cross-Tab Communication** — When needed (usually just switching tabs)

### Coordinator Principles

**Principle 1: Coordinator Does Not Own Views**  
Views ask the coordinator to navigate; coordinator doesn't create views.

**Principle 2: One Path Per Tab**  
Each tab has its own independent `[AppRoute]` path array.

**Principle 3: No Global Navigation State**  
Only the selected tab switches globally; each tab manages its own stack.

**Principle 4: Coordinator is Observable**  
`@StateObject` on AppView level, passed as `@Environment` to all views.

### Environment Injection

```swift
// In AppView (root)
.environment(\.appCoordinator, coordinator)

// In any child view
@Environment(\.appCoordinator) var coordinator

// Custom environment key
struct AppCoordinatorKey: EnvironmentKey {
    static let defaultValue: AppCoordinator = AppCoordinator()
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}
```

---

## TAB NAVIGATION STRATEGY

### Tab Selection Behavior

**Tapping Current Tab**
- Does NOT pop to root
- Does NOT reset navigation stack
- (Unlike some apps like Instagram)

**Why:** Users expect to quickly access deep content. If I'm editing a checklist in the Library tab and accidentally tap Library again, I should stay where I am.

### Alternative: Popstack on Double-Tap

**Future Enhancement (Post-Launch):**

If users request the ability to quickly return to tab root:

```swift
@State private var lastTabTap: Date?

TabView(selection: $selectedTab) {
    // ...
}
.onChange(of: selectedTab) { oldTab, newTab in
    if oldTab == newTab && Date().timeIntervalSince(lastTabTap ?? Date.distantPast) < 0.3 {
        // Double-tap detected
        popTabToRoot(newTab)
    }
    lastTabTap = Date()
}
```

### Per-Tab State Preservation

```
Home Tab navigation stack:
├─ HomeView
├─ ContentDetailView (checklist)
└─ RatingsView

Switch to Library Tab
├─ LibraryView
├─ ChecklistEditorView
└─ PreviewView

Switch back to Home Tab
├─ HomeView ← Back to exact state
├─ ContentDetailView (same content)
└─ RatingsView

PRESERVED: Exactly where I was
```

---

## DEEP LINKING & URL HANDLING

### Supported URL Schemes

```
sailaway://content/checklist/{checklistID}
sailaway://content/deck/{deckID}
sailaway://content/guide/{guideID}
sailaway://user/{userID}
sailaway://charter/{charterID}
sailaway://search?q={query}

Examples:
sailaway://content/checklist/550e8400-e29b-41d4-a716-446655440000
sailaway://user/550e8400-e29b-41d4-a716-446655440001
sailaway://charter/550e8400-e29b-41d4-a716-446655440002
sailaway://search?q=mediterranean+sailing
```

### Deep Link Handling

```swift
// In AppDelegate
func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    coordinator.handleDeepLink(url)
    return true
}

// In SceneDelegate (for iOS 13+)
func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
) {
    for context in URLContexts {
        coordinator.handleDeepLink(context.url)
    }
}
```

### URL Parsing

```swift
extension AppCoordinator {
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        guard let host = components.host else {
            return
        }
        
        switch host {
        case "content":
            handleContentLink(components)
        case "user":
            handleUserLink(components)
        case "charter":
            handleCharterLink(components)
        case "search":
            handleSearchLink(components)
        default:
            break
        }
    }
    
    private func handleContentLink(_ components: URLComponents) {
        // Path: /checklist/{id}, /deck/{id}, /guide/{id}
        let pathParts = components.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 2 else { return }
        
        let type = pathParts[0]
        let idString = pathParts[1]
        
        guard let id = UUID(uuidString: idString) else { return }
        
        selectedTab = .discover
        
        let route: AppRoute
        switch type {
        case "checklist":
            route = .checklistDetail(id)
        case "deck":
            route = .deckDetail(id)
        case "guide":
            route = .guideDetail(id)
        default:
            return
        }
        
        discoverPath = [route]
    }
    
    private func handleUserLink(_ components: URLComponents) {
        let pathParts = components.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 1,
              let id = UUID(uuidString: pathParts[0]) else {
            return
        }
        
        selectedTab = .profile
        profilePath = [.profileUser(id)]
    }
    
    private func handleCharterLink(_ components: URLComponents) {
        let pathParts = components.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 1,
              let id = UUID(uuidString: pathParts[0]) else {
            return
        }
        
        selectedTab = .charters
        chartersPath = [.charterDetail(id)]
    }
    
    private func handleSearchLink(_ components: URLComponents) {
        guard let query = components.queryItems?.first(where: { $0.name == "q" })?.value else {
            return
        }
        
        selectedTab = .discover
        discoverPath = [.search(query)]
    }
}
```

### Sharing Content

```swift
struct ShareButton: View {
    let contentID: UUID
    let contentType: String
    
    var body: some View {
        ShareLink(
            item: deepLinkURL(),
            subject: Text("Check out this template"),
            message: Text("I found this useful sailing template")
        ) {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    private func deepLinkURL() -> URL {
        var components = URLComponents()
        components.scheme = "sailaway"
        components.host = "content"
        components.path = "/\(contentType)/\(contentID)"
        return components.url ?? URL(fileURLWithPath: "")
    }
}
```

---

## ERROR HANDLING & EDGE CASES

### Invalid Route Navigation

```swift
struct ChecklistDetailView: View {
    let checklistID: UUID
    @State private var checklistNotFound = false
    
    var body: some View {
        ZStack {
            if checklistNotFound {
                ErrorView(
                    title: "Not Found",
                    message: "This checklist was deleted or you don't have access.",
                    action: { /* pop back */ }
                )
            } else {
                // Normal checklist detail
            }
        }
        .task {
            do {
                _ = try await viewModel.loadChecklist(id: checklistID)
            } catch {
                checklistNotFound = true
            }
        }
    }
}
```

### Offline Navigation

All navigation works offline since:
- Routes are local enums (no network needed)
- Local content is always available
- Only real issue: loading content that doesn't exist locally yet

**Solution:** Show placeholder during load, graceful error if not found

### Network Recovery

```swift
@MainActor
class AppCoordinator: ObservableObject {
    @Published var isOffline = false
    @Published var pendingSync: [AppRoute] = []
    
    func handleNetworkRecovery() {
        // Retry any failed syncs
        for route in pendingSync {
            // Attempt to sync content related to route
        }
        pendingSync.removeAll()
    }
}
```

### Rapid Tab Switching

No special handling needed. Each tab is independent, so rapid switching just updates which tab's view is visible.

### Memory Management

```swift
// Each tab keeps its own views in memory
// SwiftUI handles view lifecycle based on NavigationStack

// To clear memory when switching away from tab:
// (Usually not necessary, but option exists)
.onDisappear {
    // Optional: cleanup resources
}
```

---

## ACCESSIBILITY & NAVIGATION

### VoiceOver Support

```swift
struct ChecklistItemRow: View {
    let item: ChecklistItem
    
    var body: some View {
        HStack {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
            Text(item.title)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checklist item: \(item.title)")
        .accessibilityValue(item.isChecked ? "Checked" : "Unchecked")
        .accessibilityAction(named: "Toggle") {
            viewModel.toggleItem(item)
        }
    }
}
```

### Keyboard Navigation

TabView supports native keyboard navigation:
- Tab key: Cycle through tabs
- Shift+Tab: Reverse cycle
- Arrow keys: Navigate within tab

### Focus Management

```swift
struct SearchView: View {
    @FocusState private var searchFieldFocused: Bool
    
    var body: some View {
        TextField("Search", text: $searchText)
            .focused($searchFieldFocused)
            .onAppear {
                searchFieldFocused = true  // Auto-focus search field
            }
    }
}
```

### Large Text Support

All text uses dynamic type:
```swift
.font(.body)  // Respects user's preferred size
.font(.headline) // Adapts automatically
```

---

## PERFORMANCE CONSIDERATIONS

### NavigationStack Performance

```swift
// Each NavigationStack maintains only visible + one view in memory
// Popped views are deallocated
// No memory leak from deep stacks

// Optimization: Lazy loading for content
struct ContentDetailView: View {
    @State private var content: ContentItem?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let content {
                // Render
            }
        }
        .task {
            content = await loadContent()
            isLoading = false
        }
    }
}
```

### Tab View Memory Usage

Each tab's views remain in memory when not visible. This is acceptable because:
- Only 5 tabs total
- Views are lightweight (GRDB queries fast)
- User benefits from preserved state

If memory becomes issue in future:
- Lazy load tab content
- Clear old navigation stacks periodically

### Database Query Optimization

```swift
// Bad: Fetches all content
let allChecklists = try await db.readChecklist()

// Good: Fetches only what's visible
let recentChecklists = try await db.readChecklist()
    .limit(20)
    .order(by: "updatedAt DESC")
```

---

## TESTING NAVIGATION FLOWS

### Navigation Test Template

```swift
class NavigationTests: XCTestCase {
    func testChecklistCreationFlow() {
        let coordinator = AppCoordinator()
        
        // Start at home
        XCTAssertEqual(coordinator.homePath.count, 0)
        
        // Create checklist
        coordinator.createChecklist(in: .home)
        XCTAssertEqual(coordinator.homePath.count, 1)
        XCTAssertEqual(coordinator.homePath[0], .checklistEditor(checklistID))
        
        // Back button (pop)
        coordinator.homePath.removeLast()
        XCTAssertEqual(coordinator.homePath.count, 0)
    }
    
    func testTabPreservation() {
        let coordinator = AppCoordinator()
        
        // Navigate in home tab
        coordinator.createChecklist(in: .home)
        let homePathBefore = coordinator.homePath
        
        // Switch to library tab
        coordinator.selectedTab = .library
        
        // Home tab state should be preserved
        XCTAssertEqual(coordinator.homePath, homePathBefore)
    }
    
    func testDeepLinking() {
        let coordinator = AppCoordinator()
        
        let url = URL(string: "sailaway://content/checklist/550e8400-e29b-41d4-a716-446655440000")!
        coordinator.handleDeepLink(url)
        
        XCTAssertEqual(coordinator.selectedTab, .discover)
        XCTAssertEqual(coordinator.discoverPath.count, 1)
    }
}
```

### Manual Testing Checklist

- [ ] Create checklist in Home, navigate back works
- [ ] Switch tabs, navigation state preserved
- [ ] Fork content from Discover, can edit in Library
- [ ] Create charter, open checklist, close, reopen → state preserved
- [ ] Deep link from Notes app opens correct screen
- [ ] Back button works at every level
- [ ] VoiceOver can navigate all tabs
- [ ] Offline: create content → switch tabs → still there
- [ ] Network recovers → content syncs
- [ ] Rapid tab switching doesn't crash

---

## APPENDIX: Route Enum Definition

```swift
enum AppRoute: Hashable {
    // Checklists
    case checklistDetail(UUID)
    case checklistEditor(UUID)
    case checklistExecution(charterID: UUID, checklistID: UUID)
    
    // Flashcard Decks
    case deckDetail(UUID)
    case deckEditor(UUID)
    case reviewSession(UUID)
    
    // Guides
    case guideDetail(UUID)
    case guideEditor(UUID)
    
    // Charters
    case charterCreate
    case charterDetail(UUID)
    case charterEdit(UUID)
    
    // User Profiles
    case profileOwn
    case profileUser(UUID)
    case followers(UUID)
    case following(UUID)
    
    // Settings & Meta
    case settings
    case aboutApp
    
    // Search & Discovery
    case searchResults(query: String)
    case browseLibrary(type: ContentType, filters: SearchFilters)
    
    enum ContentType: String, Hashable {
        case checklist
        case deck
        case guide
    }
}
```

---

## APPENDIX: Full AppView Implementation

```swift
@main
struct SailawayApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @State private var selectedTab: Tab = .home
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                // Home Tab
                NavigationStack(path: $coordinator.homePath) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            navigationDestination(route)
                        }
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
                
                // Library Tab
                NavigationStack(path: $coordinator.libraryPath) {
                    LibraryView()
                        .navigationDestination(for: AppRoute.self) { route in
                            navigationDestination(route)
                        }
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(Tab.library)
                
                // Discover Tab
                NavigationStack(path: $coordinator.discoverPath) {
                    DiscoverView()
                        .navigationDestination(for: AppRoute.self) { route in
                            navigationDestination(route)
                        }
                }
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(Tab.discover)
                
                // Charters Tab
                NavigationStack(path: $coordinator.chartersPath) {
                    CharterListView()
                        .navigationDestination(for: AppRoute.self) { route in
                            navigationDestination(route)
                        }
                }
                .tabItem {
                    Label("Charters", systemImage: "sailboat.fill")
                }
                .tag(Tab.charters)
                
                // Profile Tab
                NavigationStack(path: $coordinator.profilePath) {
                    ProfileView()
                        .navigationDestination(for: AppRoute.self) { route in
                            navigationDestination(route)
                        }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
            }
            .environment(\.appCoordinator, coordinator)
        }
    }
    
    @ViewBuilder
    private func navigationDestination(_ route: AppRoute) -> some View {
        switch route {
        case .checklistDetail(let id):
            ChecklistDetailView(checklistID: id)
        case .checklistEditor(let id):
            ChecklistEditorView(checklistID: id)
        case .checklistExecution(let charterID, let checklistID):
            ChecklistExecutionView(charterID: charterID, checklistID: checklistID)
        case .deckDetail(let id):
            FlashcardDeckDetailView(deckID: id)
        case .deckEditor(let id):
            FlashcardDeckEditorView(deckID: id)
        case .reviewSession(let id):
            ReviewSessionView(deckID: id)
        case .guideDetail(let id):
            PracticeGuideDetailView(guideID: id)
        case .guideEditor(let id):
            PracticeGuideEditorView(guideID: id)
        case .charterCreate:
            CharterCreateView()
        case .charterDetail(let id):
            CharterDetailView(charterID: id)
        case .charterEdit(let id):
            CharterEditView(charterID: id)
        case .profileOwn:
            MyProfileView()
        case .profileUser(let id):
            PublicProfileView(userID: id)
        case .followers(let id):
            FollowersView(userID: id)
        case .following(let id):
            FollowingView(userID: id)
        case .settings:
            SettingsView()
        case .aboutApp:
            AboutAppView()
        case .searchResults(let query):
            SearchResultsView(query: query)
        case .browseLibrary(let type, let filters):
            BrowseLibraryView(contentType: type, filters: filters)
        }
    }
}

enum Tab: Hashable {
    case home
    case library
    case discover
    case charters
    case profile
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | December 2025 | Initial Navigation PRD |

---

**END OF NAVIGATION PRD**

*For questions or clarifications, refer to Sailaway main PRD or contact team.*