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

    // ViewModels are stored in @State so they are created once and survive every
    // body re-evaluation. Optionals allow lazy init after environment values are
    // available; in practice they are filled during the first .task execution,
    // which runs before the first user-visible frame.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var homeVM: HomeViewModel?
    @State private var charterListVM: CharterListViewModel?
    @State private var libraryListVM: LibraryListViewModel?
    @State private var discoverVM: DiscoverViewModel?
    @State private var charterDiscoveryVM: CharterDiscoveryViewModel?
    @State private var profileVM: ProfileViewModel?

    init() {
        // Hide the native UIKit tab bar globally so the custom FloatingTabBar takes over.
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        @Bindable var coord = coordinator

        ZStack(alignment: .top) {
            TabView(selection: $coord.selectedTab) {
                homeTab
                chartersTab
                libraryTab
                discoverTab
                profileTab
            }

            if !dependencies.networkReachability.isPathSatisfied {
                offlineReachabilityBanner
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
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
        .animation(DesignSystem.Motion.standard, value: dependencies.networkReachability.isPathSatisfied)
        // Re-run when the coordinator identity changes (e.g. DB retry rebuilds deps).
        .task(id: ObjectIdentifier(coordinator)) {
            createViewModels()
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var offlineReachabilityBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
            Text(L10n.NetworkStatus.offlineBanner)
                .font(DesignSystem.Typography.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.textSecondary.opacity(0.12))
        .foregroundColor(DesignSystem.Colors.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall))
        .accessibilityIdentifier("banner.offline")
    }

    // MARK: - Tab Views

    @ViewBuilder
    private var homeTab: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.homePath) {
            if let vm = homeVM {
                HomeView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
        .floatingTabBarPadding()
        .tabItem { Label(L10n.Home, systemImage: "house.fill") }
        .tag(Tab.home)
        .accessibilityIdentifier("tab.home")
    }

    @ViewBuilder
    private var chartersTab: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.chartersPath) {
            if let vm = charterListVM {
                CharterListView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
        .floatingTabBarPadding()
        .tabItem { Label(L10n.Charters, systemImage: "sailboat.fill") }
        .tag(Tab.charters)
        .accessibilityIdentifier("tab.charters")
    }

    @ViewBuilder
    private var libraryTab: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.libraryPath) {
            if let vm = libraryListVM {
                LibraryListView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
        .floatingTabBarPadding()
        .tabItem { Label(L10n.Library.myLibrary, systemImage: "book.fill") }
        .tag(Tab.library)
        .accessibilityIdentifier("tab.library")
    }

    @ViewBuilder
    private var discoverTab: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.discoverPath) {
            if let dvm = discoverVM, let cdvm = charterDiscoveryVM {
                DiscoverView(viewModel: dvm, charterDiscoveryViewModel: cdvm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
        .floatingTabBarPadding()
        .tabItem { Label(L10n.Discover, systemImage: "globe") }
        .tag(Tab.discover)
        .accessibilityIdentifier("tab.discover")
    }

    @ViewBuilder
    private var profileTab: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.profilePath) {
            if let vm = profileVM {
                ProfileView(viewModel: vm)
                    .navigationDestination(for: AppRoute.self) { coordinator.destination(for: $0) }
            }
        }
        .floatingTabBarPadding()
        .tabItem { Label(L10n.ProfileTab, systemImage: "person.fill") }
        .tag(Tab.profile)
        .accessibilityIdentifier("tab.profile")
    }

    // MARK: - Onboarding

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { newValue in
                if !newValue { hasCompletedOnboarding = true }
            }
        )
    }

    // MARK: - ViewModel Factory

    /// Creates (or replaces) all per-tab view models from the current environment.
    /// Called once on first appearance and again whenever the coordinator identity
    /// changes (coordinator is recreated on DB-init retry).
    private func createViewModels() {
        homeVM = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        charterListVM = CharterListViewModel(
            charterStore: dependencies.charterStore,
            coordinator: coordinator
        )
        libraryListVM = LibraryListViewModel(
            libraryStore: dependencies.libraryStore,
            visibilityService: dependencies.visibilityService,
            authObserver: dependencies.authStateObserver,
            coordinator: coordinator,
            apiClient: dependencies.apiClient,
            presentToast: { message, variant in dependencies.showToast(message, variant: variant) }
        )
        discoverVM = DiscoverViewModel(
            apiClient: dependencies.apiClient,
            libraryStore: dependencies.libraryStore,
            coordinator: coordinator
        )
        charterDiscoveryVM = CharterDiscoveryViewModel(
            apiClient: dependencies.apiClient,
            locationProvider: dependencies.locationProvider
        )
        profileVM = ProfileViewModel(
            authService: dependencies.authService,
            authObserver: dependencies.authStateObserver,
            apiClient: dependencies.apiClient,
            clearLocalDataAfterAccountDeletion: {
                try await dependencies.clearAllLocalUserDataAfterAccountDeletion()
            },
            presentToast: { message, variant in dependencies.showToast(message, variant: variant) }
        )
    }
}

#if DEBUG
#Preview {
    MainActor.assumeIsolated {
        let deps = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: deps)
        return AppView()
            .environment(\.appDependencies, deps)
            .environment(\.appCoordinator, coordinator)
    }
}
#endif
