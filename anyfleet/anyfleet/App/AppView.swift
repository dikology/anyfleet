import SwiftUI

struct AppView: View {
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.appDependencies) private var dependencies

    enum Tab: Hashable {
        case home
        case library
        //case discover
        case charters
        //case profile
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Home Tab
            NavigationStack(path: $coordinator.homePath) {
                HomeView(viewModel: HomeViewModel(coordinator: coordinator, 
                charterStore: dependencies.charterStore))
                    .navigationDestination(for: AppRoute.self) { route in
                        navigationDestination(route)
                    }
            }
            .tabItem {
                Label(L10n.Home, systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            // Charters Tab
            NavigationStack(path: $coordinator.chartersPath) {
                CharterListView(
                    viewModel: CharterListViewModel(charterStore: dependencies.charterStore)
                )
                    .navigationDestination(for: AppRoute.self) { route in
                        navigationDestination(route)
                    }
            }
            .tabItem {
                Label(L10n.Charters, systemImage: "sailboat.fill")
            }
            .tag(Tab.charters)

            // Library Tab
            NavigationStack(path: $coordinator.libraryPath) {
                LibraryListView(
                    viewModel: LibraryListViewModel(
                        libraryStore: dependencies.libraryStore,
                        coordinator: coordinator
                    )
                )
                    .navigationDestination(for: AppRoute.self) { route in
                        navigationDestination(route)
                    }
            }
            .tabItem {
                Label(L10n.Library.myLibrary, systemImage: "book.fill")
            }
            .tag(Tab.library)
        }
        .environment(\.appCoordinator, coordinator)
    }

    @ViewBuilder
    private func navigationDestination(_ route: AppRoute) -> some View {
        switch route {
        case .createCharter:
            CreateCharterView(
                viewModel: CreateCharterViewModel(
                    charterStore: dependencies.charterStore,
                    onDismiss: { coordinator.pop(from: .charters) }
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
                    onDismiss: { coordinator.pop(from: .library) }
                )
            )
        case .guideEditor(let guideID):
            // TODO: Implement GuideEditorView when ready
            // GuideEditorView(
            //     viewModel: GuideEditorViewModel(
            //         libraryStore: dependencies.libraryStore,
            //         guideID: guideID,
            //         onDismiss: { coordinator.pop(from: .library) }
            //     )
            // )
            Text("Guide Editor: \(guideID?.uuidString ?? "New")")
                .navigationTitle("Guide")
        case .deckEditor(let deckID):
            // TODO: Implement DeckEditorView when ready
            // DeckEditorView(
            //     viewModel: DeckEditorViewModel(
            //         libraryStore: dependencies.libraryStore,
            //         deckID: deckID,
            //         onDismiss: { coordinator.pop(from: .library) }
            //     )
            // )
            Text("Deck Editor: \(deckID?.uuidString ?? "New")")
                .navigationTitle("Deck")
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

#Preview {
    AppView()
}
