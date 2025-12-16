import SwiftUI

struct AppView: View {
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.appDependencies) private var dependencies

    enum Tab: Hashable {
        case home
        //case library
        //case discover
        case charters
        //case profile
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Home Tab
            NavigationStack(path: $coordinator.homePath) {
                HomeView(viewModel: HomeViewModel(coordinator: coordinator))
                    .navigationDestination(for: AppRoute.self) { route in
                        navigationDestination(route)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
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
                Label("Charters", systemImage: "sailboat.fill")
            }
            .tag(Tab.charters)
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
            // TODO: Implement CharterDetailView when ready
            Text("Charter Detail: \(id.uuidString)")
                .navigationTitle("Charter")
        }
    }
}

#Preview {
    AppView()
}
