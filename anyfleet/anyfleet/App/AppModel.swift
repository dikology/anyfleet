import SwiftUI
import Combine

enum AppRoute: Hashable {
    // Charters
    case createCharter
    case charterDetail(UUID)
    case checklistExecution(charterID: UUID, checklistID: UUID)
    
    // Library Content
    case checklistEditor(UUID?)
    case guideEditor(UUID?)
    case deckEditor(UUID?)
    case guideDetail(UUID)
    
    // TODO: Add more routes as features are implemented
    // case checklistDetail(UUID)
    // case deckDetail(UUID)
    // case guideDetail(UUID)
    // case profileUser(UUID)
    // case profileSettings
    // case search(String)
}

@MainActor
final class AppCoordinator: ObservableObject {
    private let dependencies: AppDependencies
    
    // Individual navigation paths per tab
    @Published var homePath: [AppRoute] = []
    @Published var libraryPath: [AppRoute] = []
    //@Published var discoverPath = NavigationPath()
    @Published var chartersPath: [AppRoute] = []
    //@Published var profilePath = NavigationPath()
    
    // Tab selection state
    @Published var selectedTab: AppView.Tab = .home
    
    // MARK: - Initialization
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }
    
    // MARK: - Tab-Specific Navigation
    
    func push(_ route: AppRoute, to tab: AppView.Tab) {
        switch tab {
        case .home:
            homePath.append(route)
        case .library:
            libraryPath.append(route)
        //case .discover:
            //discoverPath.append(route)
        case .charters:
            chartersPath.append(route)
        //case .profile:
            //profilePath.append(route)
        }
    }
    
    func pop(from tab: AppView.Tab) {
        switch tab {
        case .home:
            guard !homePath.isEmpty else { return }
            homePath.removeLast()
        case .library:
            guard !libraryPath.isEmpty else { return }
            libraryPath.removeLast()
        //case .discover:
            //guard !discoverPath.isEmpty else { return }
            //discoverPath.removeLast()
        case .charters:
            guard !chartersPath.isEmpty else { return }
            chartersPath.removeLast()
        //case .profile:
            //guard !profilePath.isEmpty else { return }
            //profilePath.removeLast()
        }
    }
    
    func popToRoot(from tab: AppView.Tab) {
        switch tab {
        case .home:
            homePath.removeLast(homePath.count)
        case .library:
            libraryPath.removeLast(libraryPath.count)
        //case .discover:
            //discoverPath.removeLast(discoverPath.count)
        case .charters:
            chartersPath.removeLast(chartersPath.count)
        //case .profile:
            //profilePath.removeLast(profilePath.count)
        }
    }
    
    // MARK: - Charter Navigation
    
    func createCharter() {
        chartersPath.append(.createCharter)
    }
    
    func viewCharter(_ id: UUID) {
        chartersPath.append(.charterDetail(id))
    }
    
    // MARK: - Library Navigation
    
    /// Navigate to checklist editor (create new or edit existing)
    /// - Parameter checklistID: Optional checklist ID. If nil, creates new checklist.
    func editChecklist(_ checklistID: UUID? = nil) {
        libraryPath.append(.checklistEditor(checklistID))
    }
    
    /// Navigate to guide editor (create new or edit existing)
    /// - Parameter guideID: Optional guide ID. If nil, creates new guide.
    func editGuide(_ guideID: UUID? = nil) {
        libraryPath.append(.guideEditor(guideID))
    }
    
    /// Navigate to deck editor (create new or edit existing)
    /// - Parameter deckID: Optional deck ID. If nil, creates new deck.
    func editDeck(_ deckID: UUID? = nil) {
        libraryPath.append(.deckEditor(deckID))
    }
    
    /// Navigate to guide reader view.
    /// - Parameter guideID: The ID of the guide to view.
    func viewGuide(_ guideID: UUID) {
        libraryPath.append(.guideDetail(guideID))
    }
    
    // MARK: - Cross-Tab Navigation
    
    /// Navigates to charter creation from any tab.
    ///
    /// Switches to the charters tab and pushes the create charter view.
    /// Used for cross-tab navigation (e.g., from Home tab).
    func navigateToCreateCharter() {
        selectedTab = .charters
        chartersPath = []
        chartersPath.append(.createCharter)
    }
    
    /// Navigates to a specific charter detail from any tab.
    ///
    /// Switches to the charters tab and pushes the charter detail view.
    /// Used for cross-tab navigation and deep linking.
    ///
    /// - Parameter id: The UUID of the charter to view
    func navigateToCharter(_ id: UUID) {
        selectedTab = .charters
        chartersPath = []
        chartersPath.append(.charterDetail(id))
    }
    
    // MARK: - Deep Linking (TODO: Implement when needed)
    
    func handleDeepLink(_ url: URL) {
        // TODO: Implement deep link handling
        // See PRD section "Deep Linking & URL Handling" for implementation details
    }
    
    // MARK: - Destination Building
    
    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .createCharter:
            CreateCharterView(
                viewModel: CreateCharterViewModel(
                    charterStore: dependencies.charterStore,
                    onDismiss: { self.pop(from: .charters) }
                )
            )
        case .charterDetail(let id):
            CharterDetailView(
                viewModel: CharterDetailViewModel(
                    charterID: id,
                    charterStore: dependencies.charterStore,
                    libraryStore: dependencies.libraryStore
                )
            )
        case .checklistEditor(let checklistID):
            ChecklistEditorView(
                viewModel: ChecklistEditorViewModel(
                    libraryStore: dependencies.libraryStore,
                    checklistID: checklistID,
                    onDismiss: { self.pop(from: .library) }
                )
            )
        case .guideEditor(let guideID):
            PracticeGuideEditorView(
                viewModel: PracticeGuideEditorViewModel(
                    libraryStore: dependencies.libraryStore,
                    guideID: guideID,
                    onDismiss: { self.pop(from: .library) }
                )
            )
        case .deckEditor(let deckID):
            // TODO: Implement DeckEditorView when ready
            // DeckEditorView(
            //     viewModel: DeckEditorViewModel(
            //         libraryStore: dependencies.libraryStore,
            //         deckID: deckID,
            //         onDismiss: { self.pop(from: .library) }
            //     )
            // )
            Text("Deck Editor: \(deckID?.uuidString ?? "New")")
                .navigationTitle("Deck")
        case .guideDetail(let guideID):
            PracticeGuideReaderView(
                viewModel: PracticeGuideReaderViewModel(
                    libraryStore: dependencies.libraryStore,
                    guideID: guideID
                )
            )
        case .checklistExecution(let charterID, let checklistID):
            ChecklistExecutionView(
                viewModel: ChecklistExecutionViewModel(
                    libraryStore: dependencies.libraryStore,
                    executionRepository: dependencies.executionRepository,
                    charterID: charterID,
                    checklistID: checklistID
                )
            )
        }
    }
}

// MARK: - Environment Key

private struct AppCoordinatorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: AppCoordinator = MainActor.assumeIsolated {
        AppCoordinator(dependencies: AppDependencies())
    }
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}

