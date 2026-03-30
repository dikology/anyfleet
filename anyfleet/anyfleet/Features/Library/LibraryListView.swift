import SwiftUI

struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator
    
    @MainActor
    init(viewModel: LibraryListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            contentView
                .background(DesignSystem.Colors.background.ignoresSafeArea())

            if viewModel.showErrorBanner, let error = viewModel.currentError {
                ErrorBannerOverlay(
                    error: error,
                    onDismiss: { viewModel.clearError() },
                    onRetry: { Task { await viewModel.loadLibrary() } }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Library.myLibrary)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            ToolbarItem(placement: .primaryAction) {
                CreateContentMenu(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadLibrary()
        }
        .refreshable {
            HapticEngine.impact(.light)
            await viewModel.refresh()
        }
        .libraryModals(viewModel: viewModel)
    }

    private var libraryListDisplayPhase: Int {
        if viewModel.isLoading && viewModel.isEmpty { 0 }
        else if viewModel.isEmpty { 1 }
        else { 2 }
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading && viewModel.isEmpty {
                LibrarySkeletonListView()
                    .transition(.opacity)
            } else if viewModel.isEmpty {
                LibraryEmptyState(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                LibraryContentList(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: libraryListDisplayPhase)
    }
}

// MARK: - Preview

#Preview {
    MainActor.assumeIsolated {
        let sampleLibrary: [LibraryModel] = [
            LibraryModel(
                title: "Pre‑Departure Safety Checklist",
                description: "Run through this before every sail: weather, rigging, engine, and crew briefing.",
                type: .checklist,
                visibility: .private,
                creatorID: UUID(),
                tags: ["safety", "pre‑departure", "crew"],
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 7),
                updatedAt: Date().addingTimeInterval(-60 * 30)
            ),
            LibraryModel(
                title: "Heavy Weather Tactics",
                description: "Step‑by‑step guide for reefing, heaving‑to, and staying safe when the wind picks up.",
                type: .practiceGuide,
                visibility: .public,
                creatorID: UUID(),
                tags: ["heavy weather", "reefing", "safety"],
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 21),
                updatedAt: Date().addingTimeInterval(-60 * 60 * 2)
            ),
            LibraryModel(
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right‑of‑way rules and light patterns.",
                type: .practiceGuide,
                visibility: .unlisted,
                creatorID: UUID(),
                tags: ["colregs", "rules", "night"],
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3),
                updatedAt: Date().addingTimeInterval(-60 * 10)
            )
        ]

        let repository = PreviewLibraryRepository(sampleLibrary: sampleLibrary)
        let dependencies = AppDependencies()
        let libraryStore = LibraryStore(repository: repository, syncQueue: dependencies.syncQueueService)
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = LibraryListViewModel(
            libraryStore: libraryStore,
            visibilityService: dependencies.visibilityService,
            authObserver: dependencies.authStateObserver,
            coordinator: coordinator,
            apiClient: dependencies.apiClient
        )

        return NavigationStack {
            LibraryListView(viewModel: viewModel)
        }
        .environment(\.appDependencies, dependencies)
        .environment(\.appCoordinator, coordinator)
    }
}

// MARK: - Supporting Components

struct LibraryModalsModifier: ViewModifier {
    @Bindable var viewModel: LibraryListViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.activeModal) { modal in
                modalContent(for: modal)
            }
            .animation(DesignSystem.Motion.standard, value: viewModel.activeModal?.id)
    }

    @ViewBuilder
    private func modalContent(for modal: LibraryModal) -> some View {
        switch modal {
        case .publishConfirmation(let item):
            PublishConfirmationModal(
                item: item,
                isLoading: viewModel.isLoading,
                error: viewModel.publishError,
                onConfirm: {
                    Task {
                        await viewModel.confirmPublish()
                        if viewModel.publishError == nil {
                            viewModel.dismissModal()
                        }
                    }
                },
                onCancel: {
                    viewModel.cancelPublish()
                },
                onRetry: {
                    Task {
                        await viewModel.confirmPublish()
                    }
                }
            )
        case .signIn:
            SignInModalView(
                onSuccess: {
                    viewModel.dismissModal()
                },
                onDismiss: {
                    viewModel.dismissModal()
                }
            )
        case .deletePrivate(let item):
            DeleteConfirmationModal(
                item: item,
                isPublished: false,
                onConfirm: {
                    Task {
                        do {
                            try await viewModel.deleteContent(item)
                            viewModel.dismissModal()
                        } catch {
                            AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                        }
                    }
                },
                onCancel: {
                    viewModel.dismissModal()
                }
            )
        case .deletePublished(let item):
            PublishedContentDeleteModal(
                item: item,
                onUnpublishAndDelete: {
                    AppLogger.view.info("User selected 'Unpublish & Delete' for item: \(item.id)")
                    Task {
                        do {
                            try await viewModel.deleteAndUnpublishContent(item)
                            viewModel.dismissModal()
                        } catch {
                            AppLogger.view.error("Failed to unpublish and delete content: \(error.localizedDescription)")
                        }
                    }
                },
                onKeepPublished: {
                    AppLogger.view.info("User selected 'Keep Published' for item: \(item.id)")
                    Task {
                        do {
                            try await viewModel.deleteLocalCopyKeepPublished(item)
                            viewModel.dismissModal()
                        } catch {
                            AppLogger.view.error("Failed to delete local copy: \(error.localizedDescription)")
                        }
                    }
                },
                onCancel: {
                    AppLogger.view.info("User cancelled published content deletion")
                    viewModel.dismissModal()
                }
            )
        case .authorProfile(let author):
            AuthorProfileModal(
                author: author,
                onDismiss: {
                    viewModel.dismissModal()
                }
            )
        }
    }
}

extension View {
    func libraryModals(viewModel: LibraryListViewModel) -> some View {
        modifier(LibraryModalsModifier(viewModel: viewModel))
    }
}

struct ContentFilterPicker: View {
    @Binding var selection: ContentFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(ContentFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Library.filterAccessibilityLabel)
    }

    private func filterChip(_ filter: ContentFilter) -> some View {
        let selected = selection == filter
        return Button {
            selection = filter
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(filter.title)
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(selected ? .semibold : .medium)
                    .foregroundColor(selected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                Capsule()
                    .fill(selected ? DesignSystem.Colors.primary : Color.clear)
                    .frame(height: 2)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.filterChip.\(filter.rawValue)")
    }
}

struct CreateContentMenu: View {
    let viewModel: LibraryListViewModel

    var body: some View {
        Menu {
            Button {
                viewModel.onCreateChecklistTapped()
            } label: {
                Label(L10n.Library.newChecklist, systemImage: "checklist")
            }

            // Flashcard deck item removed until feature ships

            Button {
                viewModel.onCreateGuideTapped()
            } label: {
                Label(L10n.Library.newPracticeGuide, systemImage: "book")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(DesignSystem.Typography.insetHeadline)
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }
}

struct LibrarySkeletonListView: View {
    @State private var animating = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    DesignSystem.LibrarySkeletonRow(animating: animating)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(DesignSystem.Motion.skeleton) {
                animating = true
            }
        }
    }
}

struct LibraryEmptyState: View {
    let viewModel: LibraryListViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.15),
                                DesignSystem.Colors.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "books.vertical.fill")
                    .font(DesignSystem.Typography.symbolPlateXL)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary,
                                DesignSystem.Colors.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Text(L10n.Library.emptyStateTitle)
                    .font(DesignSystem.Typography.emptyStateHeadline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.Library.emptyStateMessage)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            Menu {
                Button {
                    viewModel.onCreateChecklistTapped()
                } label: {
                    Label(L10n.Library.newChecklist, systemImage: "checklist")
                }
                Button {
                    viewModel.onCreateGuideTapped()
                } label: {
                    Label(L10n.Library.newPracticeGuide, systemImage: "book")
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.Library.emptyStatePrimaryAction)
                }
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusMedium)
                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Library.emptyStateAccessibilityLabel)
    }
}

struct LibraryContentList: View {
    let viewModel: LibraryListViewModel

    @AppStorage("hasSeenLibrarySwipeHint") private var hasSeenLibrarySwipeHint = false
    @State private var playSwipeHint = false
    @State private var showSwipeTip = false

    private var librarySwipeTipActions: [SwipeActionTipChip.Action] {
        [
            .init(icon: "pin", label: L10n.Library.actionPin, tint: DesignSystem.Colors.primary),
            .init(icon: "pencil", label: L10n.Library.actionEdit, tint: .gray),
            .init(icon: "trash", label: L10n.Library.actionDelete, tint: DesignSystem.Colors.error)
        ]
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if showSwipeTip {
                SwipeActionTipChip(actions: librarySwipeTipActions)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ContentFilterPicker(selection: Binding(
                get: { viewModel.selectedFilter },
                set: { viewModel.selectedFilter = $0 }
            ))

            List {
                ForEach(viewModel.filteredItems) { item in
                    LibraryItemRow(
                        item: item,
                        contentType: item.type,
                        isSignedIn: viewModel.isSignedIn,
                        onTap: {
                            switch item.type {
                            case .checklist:
                                viewModel.onReadChecklistTapped(item.id)
                            case .practiceGuide:
                                viewModel.onReadGuideTapped(item.id)
                            // TODO: Implement deck reader when ready

                            }
                        },
                        onAuthorTapped: { username, authorUserId in
                            Task {
                                await viewModel.fetchAndShowAuthorProfile(username: username, authorUserId: authorUserId)
                            }
                        },
                        onPublish: {
                            viewModel.initiatePublish(item)
                        },
                        onUnpublish: {
                            Task {
                                await viewModel.unpublish(item)
                            }
                        },
                        onSignInRequired: {
                            viewModel.showSignInModal()
                        },
                        onRetrySync: {
                            Task {
                                await viewModel.retrySync(for: item)
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
                        get: { playSwipeHint && item.id == viewModel.filteredItems.first?.id },
                        set: { playSwipeHint = $0 }
                    ))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            HapticEngine.impact(.light)
                            viewModel.initiateDelete(item)
                        } label: {
                            Label(L10n.Library.actionDelete, systemImage: "trash")
                        }

                        Button {
                            HapticEngine.impact(.light)
                            switch item.type {
                            case .checklist:
                                viewModel.onEditChecklistTapped(item.id)
                            case .practiceGuide:
                                viewModel.onEditGuideTapped(item.id)
//                            case .flashcardDeck:
//                                viewModel.onEditDeckTapped(item.id)
                            }
                        } label: {
                            Label(L10n.Library.actionEdit, systemImage: "pencil")
                        }
                        .tint(.gray)

                        Button {
                            HapticEngine.impact(.light)
                            Task {
                                await viewModel.togglePin(for: item)
                            }
                        } label: {
                            Label(
                                item.isPinned ? L10n.Library.actionUnpin : L10n.Library.actionPin,
                                systemImage: item.isPinned ? "pin.slash" : "pin"
                            )
                        }
                        .tint(DesignSystem.Colors.primary)
                    }
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
        .animation(DesignSystem.Motion.standard, value: showSwipeTip)
        .task(id: viewModel.filteredItems.isEmpty) {
            await runLibrarySwipeOnboardingIfNeeded()
        }
    }

    private func runLibrarySwipeOnboardingIfNeeded() async {
        guard !viewModel.filteredItems.isEmpty, !hasSeenLibrarySwipeHint else { return }
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showSwipeTip = true }
        playSwipeHint = true
        try? await Task.sleep(for: .seconds(2.5))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showSwipeTip = false }
        playSwipeHint = false
        hasSeenLibrarySwipeHint = true
    }
}

private struct PreviewLibraryRepository: LibraryRepository {
    let sampleLibrary: [LibraryModel]

    // MARK: - Metadata
    func fetchUserLibrary() async throws -> [LibraryModel] {
        sampleLibrary
    }

    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
        sampleLibrary.first { $0.id == id }
    }

    // MARK: - Full Models
    func fetchUserChecklists() async throws -> [Checklist] { [] }
    func fetchUserGuides() async throws -> [PracticeGuide] { [] }
    func fetchUserDecks() async throws -> [FlashcardDeck] { [] }

    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist { throw LibraryError.notFound(checklistID) }
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide { throw LibraryError.notFound(guideID) }
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck { throw LibraryError.notFound(deckID) }

    // MARK: - Mutating Operations (no‑ops for preview)
    func createChecklist(_ checklist: Checklist) async throws {}
    func createGuide(_ guide: PracticeGuide) async throws {}
    func createDeck(_ deck: FlashcardDeck) async throws {}

    func saveChecklist(_ checklist: Checklist) async throws {}
    func saveGuide(_ guide: PracticeGuide) async throws {}
    
    func updateLibraryMetadata(_ model: LibraryModel) async throws {}

    func deleteContent(_ contentID: UUID) async throws {}
}

