import SwiftUI

struct AppView: View {
    @Environment(\.appDependencies) private var dependencies
    @EnvironmentObject private var coordinator: AppCoordinator

    enum Tab: Hashable {
        case home
        case library
        //case discover
        case charters
        case profile
    }
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Home Tab
            NavigationStack(path: $coordinator.homePath) {
                HomeView(
                    viewModel: HomeViewModel(
                        coordinator: coordinator,
                        charterStore: dependencies.charterStore,
                        libraryStore: dependencies.libraryStore
                    )
                )
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
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
                        coordinator.destination(for: route)
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
                        coordinator.destination(for: route)
                    }
            }
            .tabItem {
                Label(L10n.Library.myLibrary, systemImage: "book.fill")
            }
            .tag(Tab.library)
            
            // Profile Tab
            NavigationStack(path: $coordinator.profilePath) {
                ProfileView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
            }
            .tabItem {
                Label(L10n.ProfileTab, systemImage: "person.fill")
            }
            .tag(Tab.profile)
        }
    }
}

#Preview {
    let dependencies = AppDependencies()
    let coordinator = AppCoordinator(dependencies: dependencies)
    AppView()
        .environment(\.appDependencies, dependencies)
        .environmentObject(coordinator)
}
