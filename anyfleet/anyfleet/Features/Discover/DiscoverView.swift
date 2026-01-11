import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    // Modal state
    @State private var selectedAuthorUsername: AuthorProfileItem?

    private struct AuthorProfileItem: Identifiable {
        let username: String
        var id: String { username }
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
            Group {
                if viewModel.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    contentList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.background.ignoresSafeArea())

            // Error Banner
            if viewModel.showErrorBanner, let error = viewModel.currentError {
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
        .sheet(item: $selectedAuthorUsername) { item in
            AuthorProfileModal(
                username: item.username,
                onDismiss: {
                    selectedAuthorUsername = nil
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
                        selectedAuthorUsername = AuthorProfileItem(username: username)
                        viewModel.onAuthorTapped(username)
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
