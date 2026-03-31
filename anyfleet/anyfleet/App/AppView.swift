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

    init() {
        // Hide the native UIKit tab bar globally so the custom FloatingTabBar takes over.
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: Binding<Tab>(
                get: { coordinator.selectedTab },
                set: { coordinator.selectedTab = $0 }
            )) {
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
                .floatingTabBarPadding()
                .tabItem { Label(L10n.Home, systemImage: "house.fill") }
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
                .floatingTabBarPadding()
                .tabItem { Label(L10n.Charters, systemImage: "sailboat.fill") }
                .tag(Tab.charters)
                .accessibilityIdentifier("tab.charters")

                // Library Tab
                NavigationStack(path: Binding(get: { coordinator.libraryPath }, set: { coordinator.libraryPath = $0 })) {
                    LibraryListView(
                        viewModel: LibraryListViewModel(
                            libraryStore: dependencies.libraryStore,
                            visibilityService: dependencies.visibilityService,
                            authObserver: dependencies.authStateObserver,
                            coordinator: coordinator,
                            apiClient: dependencies.apiClient,
                            presentToast: { message, variant in dependencies.showToast(message, variant: variant) }
                        )
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
                }
                .floatingTabBarPadding()
                .tabItem { Label(L10n.Library.myLibrary, systemImage: "book.fill") }
                .tag(Tab.library)
                .accessibilityIdentifier("tab.library")

                // Discover Tab
                NavigationStack(path: Binding(get: { coordinator.discoverPath }, set: { coordinator.discoverPath = $0 })) {
                    DiscoverView(
                        viewModel: DiscoverViewModel(
                            apiClient: dependencies.apiClient,
                            libraryStore: dependencies.libraryStore,
                            coordinator: coordinator
                        ),
                        charterDiscoveryViewModel: CharterDiscoveryViewModel(
                            apiClient: dependencies.apiClient,
                            locationProvider: dependencies.locationProvider
                        )
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
                }
                .floatingTabBarPadding()
                .tabItem { Label(L10n.Discover, systemImage: "globe") }
                .tag(Tab.discover)
                .accessibilityIdentifier("tab.discover")

                // Profile Tab
                NavigationStack(path: Binding(get: { coordinator.profilePath }, set: { coordinator.profilePath = $0 })) {
                    ProfileView(viewModel: ProfileViewModel(
                        authService: dependencies.authService,
                        authObserver: dependencies.authStateObserver,
                        apiClient: dependencies.apiClient,
                        clearLocalDataAfterAccountDeletion: {
                            try await dependencies.clearAllLocalUserDataAfterAccountDeletion()
                        },
                        presentToast: { message, variant in dependencies.showToast(message, variant: variant) }
                    ))
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.destination(for: route)
                    }
                }
                .floatingTabBarPadding()
                .tabItem { Label(L10n.ProfileTab, systemImage: "person.fill") }
                .tag(Tab.profile)
                .accessibilityIdentifier("tab.profile")
            }

            if let toast = dependencies.toast {
                ToastView(message: toast.message, variant: toast.variant)
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(1000)
            }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(
                selectedTab: Binding(
                    get: { coordinator.selectedTab },
                    set: { newTab in
                        HapticEngine.selection()
                        coordinator.selectedTab = newTab
                    }
                )
            )
            .padding(.bottom, 8)
            .ignoresSafeArea(.keyboard)
        }
        .animation(DesignSystem.Motion.spring, value: dependencies.toast?.id)
    }
}

#Preview {
    MainActor.assumeIsolated {
        let deps = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: deps)
        return AppView()
            .environment(\.appDependencies, deps)
            .environment(\.appCoordinator, coordinator)
    }
}
