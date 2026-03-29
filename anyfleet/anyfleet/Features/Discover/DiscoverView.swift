import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    /// Persisted across tab switches so the in-memory cache survives when the user
    /// temporarily leaves the charters sub-tab. Creating a new VM on every render
    /// was the root cause of the "shows nothing on return" bug.
    @State private var charterDiscoveryViewModel: CharterDiscoveryViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    // Content type tab selection
    enum ContentTab: String, CaseIterable {
        case content
        case charters

        var localizedTitle: String {
            switch self {
            case .content: return L10n.DiscoverView.tabContent
            case .charters: return L10n.DiscoverView.tabCharters
            }
        }
    }
    @State private var selectedTab: ContentTab = .content
    @State private var discoverSkeletonAnimating = false

    @AppStorage("hasSeenDiscoverSwipeHint") private var hasSeenDiscoverSwipeHint = false
    @State private var playDiscoverSwipeHint = false
    @State private var showDiscoverSwipeTip = false

    // Modal state
    @State private var selectedAuthor: AuthorProfileWrapper?

    private struct AuthorProfileWrapper: Identifiable {
        let profile: AuthorProfile
        var id: String { profile.username }
    }

    @MainActor
    init(
        viewModel: DiscoverViewModel,
        charterDiscoveryViewModel: CharterDiscoveryViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        _charterDiscoveryViewModel = State(initialValue: charterDiscoveryViewModel)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                contentTabPicker
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.background)

                tabContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.background.ignoresSafeArea())

            // Error Banner (only for content tab)
            if selectedTab == .content, viewModel.showErrorBanner, let error = viewModel.currentError {
                VStack {
                    Spacer()
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: { Task { await viewModel.loadContent() } }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedAuthor) { item in
            AuthorProfileModal(
                author: item.profile,
                onDismiss: {
                    selectedAuthor = nil
                }
            )
        }
        .animation(DesignSystem.Motion.standard, value: selectedAuthor?.id)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Discover)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
        .task {
            await viewModel.loadContent()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Tab Picker

    private var contentTabPicker: some View {
        Picker("Content Type", selection: $selectedTab) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                Text(tab.localizedTitle).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Content type selector")
        .accessibilityHint("Switch between community content and charter discovery")
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .content:
            contentTabView
        case .charters:
            charterDiscoveryTabView
        }
    }

    private var charterDiscoveryTabView: some View {
        CharterDiscoveryView(viewModel: charterDiscoveryViewModel)
    }

    // MARK: - Content Tab (Library Content Discovery)

    private var contentTabView: some View {
        ZStack {
            Group {
                if viewModel.isLoading && viewModel.content.isEmpty {
                    discoverContentSkeletonList
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    contentList
                }
            }
        }
    }

    private var discoverContentSkeletonList: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    DesignSystem.DiscoverContentSkeletonRow(animating: discoverSkeletonAnimating)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(DesignSystem.Motion.skeleton) {
                discoverSkeletonAnimating = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        DesignSystem.EmptyStateHero(
            icon: "globe",
            title: L10n.DiscoverView.emptyStateTitle,
            message: L10n.DiscoverView.emptyStateMessage,
            accentColor: DesignSystem.Colors.primary
        )
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var discoverSwipeTipActions: [SwipeActionTipChip.Action] {
        [
            .init(icon: "arrow.triangle.branch.fill", label: "Fork", tint: DesignSystem.Colors.primary)
        ]
    }

    /// Drives swipe onboarding when the content tab list is shown with items.
    private var discoverSwipeOnboardingTaskActive: Bool {
        selectedTab == .content && !viewModel.content.isEmpty
    }

    // MARK: - Content List

    private var contentList: some View {
        List {
            ForEach(viewModel.content) { content in
                DiscoverContentRow(
                    content: content,
                    onTap: {
                        viewModel.onContentTapped(content)
                    },
                    onAuthorTapped: { username in
                        // Fetch full profile data from backend
                        Task {
                            await viewModel.fetchAndShowAuthorProfile(
                                username: username,
                                onProfileFetched: { profile in
                                    selectedAuthor = AuthorProfileWrapper(profile: profile)
                                }
                            )
                        }
                    },
                    onForkTapped: {
                        Task {
                            await viewModel.onForkTapped(content)
                        }
                    }
                )
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spacing.sm,
                    leading: DesignSystem.Spacing.lg,
                    bottom: DesignSystem.Spacing.sm,
                    trailing: DesignSystem.Spacing.lg
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeHint(isPlaying: Binding(
                    get: { playDiscoverSwipeHint && content.id == viewModel.content.first?.id },
                    set: { playDiscoverSwipeHint = $0 }
                ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            if showDiscoverSwipeTip {
                SwipeActionTipChip(actions: discoverSwipeTipActions)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Motion.standard, value: showDiscoverSwipeTip)
        .task(id: discoverSwipeOnboardingTaskActive) {
            await runDiscoverSwipeOnboardingIfNeeded()
        }
    }

    private func runDiscoverSwipeOnboardingIfNeeded() async {
        guard selectedTab == .content else { return }
        guard !viewModel.content.isEmpty, !hasSeenDiscoverSwipeHint else { return }
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showDiscoverSwipeTip = true }
        playDiscoverSwipeHint = true
        try? await Task.sleep(for: .seconds(2.5))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showDiscoverSwipeTip = false }
        playDiscoverSwipeHint = false
        hasSeenDiscoverSwipeHint = true
    }
}

// MARK: - Preview

#Preview {
    MainActor.assumeIsolated {
        let sampleContent: [DiscoverContent] = [
            DiscoverContent(
                id: UUID(),
                title: "Pre-Departure Safety Checklist",
                description: "Run through this before every sail: weather, rigging, engine, and crew briefing.",
                contentType: .checklist,
                tags: ["safety", "pre-departure", "crew"],
                publicID: "pre-departure-checklist",
                authorUsername: "SailorMaria",
                viewCount: 42,
                forkCount: 8,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 7)
            ),
            DiscoverContent(
                id: UUID(),
                title: "Heavy Weather Tactics",
                description: "Step-by-step guide for reefing, heaving-to, and staying safe when the wind picks up.",
                contentType: .practiceGuide,
                tags: ["heavy weather", "reefing", "safety"],
                publicID: "heavy-weather-tactics",
                authorUsername: "CaptainJohn",
                viewCount: 127,
                forkCount: 23,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 14)
            ),
            DiscoverContent(
                id: UUID(),
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right-of-way rules and light patterns.",
                contentType: .practiceGuide,
                tags: ["colregs", "rules", "night"],
                publicID: "colregs-flashcards",
                authorUsername: nil,
                viewCount: 89,
                forkCount: 15,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3)
            )
        ]

        let deps = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: deps)
        let viewModel = DiscoverViewModel(
            apiClient: deps.apiClient,
            libraryStore: deps.libraryStore,
            coordinator: coordinator
        )
        // For preview, inject sample data
        viewModel.content = sampleContent

        return NavigationStack {
            DiscoverView(
                viewModel: viewModel,
                charterDiscoveryViewModel: CharterDiscoveryViewModel(
                    apiClient: deps.apiClient,
                    locationProvider: deps.locationProvider
                )
            )
        }
        .environment(\.appDependencies, deps)
        .environment(\.appCoordinator, coordinator)
    }
}
