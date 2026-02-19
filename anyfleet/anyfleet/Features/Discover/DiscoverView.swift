import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    // Content type tab selection
    enum ContentTab: String, CaseIterable {
        case content = "Content"
        case charters = "Charters"
    }
    @State private var selectedTab: ContentTab = .content

    // Modal state
    @State private var selectedAuthor: AuthorProfileWrapper?

    private struct AuthorProfileWrapper: Identifiable {
        let profile: AuthorProfile
        var id: String { profile.username }
    }

    @MainActor
    init(viewModel: DiscoverViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Create a placeholder for previews and testing
            let deps = AppDependencies()
            _viewModel = State(initialValue: DiscoverViewModel(
                apiClient: deps.apiClient,
                libraryStore: deps.libraryStore,
                coordinator: AppCoordinator(dependencies: deps)
            ))
        }
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
                    .padding(.bottom, 20)
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
                Text(tab.rawValue).tag(tab)
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
        CharterDiscoveryView(
            viewModel: CharterDiscoveryViewModel(apiClient: dependencies.apiClient)
        )
    }

    // MARK: - Content Tab (Library Content Discovery)

    private var contentTabView: some View {
        ZStack {
            Group {
                if viewModel.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    contentList
                }
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
                contentType: .flashcardDeck,
                tags: ["colregs", "rules", "night"],
                publicID: "colregs-flashcards",
                authorUsername: nil,
                viewCount: 89,
                forkCount: 15,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3)
            )
        ]

        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = DiscoverViewModel(
            apiClient: dependencies.apiClient,
            libraryStore: dependencies.libraryStore,
            coordinator: coordinator
        )
        // For preview, inject sample data
        viewModel.content = sampleContent

        return NavigationStack {
            DiscoverView(viewModel: viewModel)
        }
        .environment(\.appDependencies, dependencies)
        .environment(\.appCoordinator, coordinator)
    }
}
