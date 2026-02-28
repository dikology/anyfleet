import SwiftUI

struct AppView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    enum Tab: Hashable {
        case home
        case library
        case discover
        case charters
        case profile
    }
    
    var body: some View {
        TabView(selection: Binding<Tab>(get: { coordinator.selectedTab }, set: { coordinator.selectedTab = $0 })) {
            // Home Tab
            NavigationStack(path: Binding(get: { coordinator.homePath }, set: { coordinator.homePath = $0 })) {
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
            .accessibilityIdentifier("tab.home")
            
                // Charters Tab
                NavigationStack(path: Binding(get: { coordinator.chartersPath }, set: { coordinator.chartersPath = $0 })) {
                CharterListView(
                    viewModel: CharterListViewModel(charterStore: dependencies.charterStore, coordinator: coordinator)
                )
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
            }
            .tabItem {
                Label(L10n.Charters, systemImage: "sailboat.fill")
            }
            .tag(Tab.charters)
            .accessibilityIdentifier("tab.charters")

                // Library Tab
                NavigationStack(path: Binding(get: { coordinator.libraryPath }, set: { coordinator.libraryPath = $0 })) {
                LibraryListView(
                    viewModel: LibraryListViewModel(
                        libraryStore: dependencies.libraryStore,
                        visibilityService: dependencies.visibilityService,
                        authObserver: dependencies.authStateObserver,
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
            .accessibilityIdentifier("tab.library")

                // Discover Tab
                NavigationStack(path: Binding(get: { coordinator.discoverPath }, set: { coordinator.discoverPath = $0 })) {
                DiscoverView(
                    viewModel: DiscoverViewModel(
                        apiClient: dependencies.apiClient,
                        libraryStore: dependencies.libraryStore,
                        coordinator: coordinator
                    )
                )
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
            }
            .tabItem {
                Label(L10n.Discover, systemImage: "globe")
            }
            .tag(Tab.discover)
            .accessibilityIdentifier("tab.discover")

                // Profile Tab
                NavigationStack(path: Binding(get: { coordinator.profilePath }, set: { coordinator.profilePath = $0 })) {
                ProfileView(viewModel: ProfileViewModel(authService: dependencies.authService, authObserver: dependencies.authStateObserver))
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
            }
            .tabItem {
                Label(L10n.ProfileTab, systemImage: "person.fill")
            }
            .tag(Tab.profile)
            .accessibilityIdentifier("tab.profile")
        }
    }
}

#Preview {
    MainActor.assumeIsolated {
        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        return AppView()
            .environment(\.appDependencies, dependencies)
            .environment(coordinator)
    }
}
