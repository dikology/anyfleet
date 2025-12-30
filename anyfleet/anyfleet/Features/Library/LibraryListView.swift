import SwiftUI

struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    @State private var selectedFilter: ContentFilter = .all
    @State private var showingPublishConfirmation = false
    @State private var showingSignInModal = false

    // Deletion state
    @State private var pendingDeleteItem: LibraryModel?
    @State private var showPrivateDeleteConfirmation = false
    @State private var showPublishedDeleteConfirmation = false
    @State private var publishedDeleteModalItem: LibraryModel?
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator
    
    init(viewModel: LibraryListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Create a placeholder for previews and testing
            let deps = AppDependencies()
            _viewModel = State(initialValue: LibraryListViewModel(
                libraryStore: deps.libraryStore,
                visibilityService: deps.visibilityService,
                authObserver: deps.authStateObserver,
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
                        onRetry: { Task { await viewModel.loadLibrary() } }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Library.myLibrary)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            ToolbarItem(placement: .primaryAction) {
                createMenu
            }
        }
        .task {
            await viewModel.loadLibrary()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingPublishConfirmation) {
            if let item = viewModel.pendingPublishItem {
                PublishConfirmationModal(
                    item: item,
                    isLoading: viewModel.isLoading,
                    error: viewModel.publishError,
                    onConfirm: {
                        Task {
                            await viewModel.confirmPublish()
                            if viewModel.publishError == nil {
                                showingPublishConfirmation = false
                            }
                        }
                    },
                    onCancel: {
                        viewModel.cancelPublish()
                        showingPublishConfirmation = false
                    },
                    onRetry: {
                        Task {
                            await viewModel.confirmPublish()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingSignInModal) {
            SignInModalView(
                onSuccess: {
                    showingSignInModal = false
                },
                onDismiss: {
                    showingSignInModal = false
                }
            )
        }
        .sheet(isPresented: $showPrivateDeleteConfirmation) {
            if let item = pendingDeleteItem {
                DeleteConfirmationModal(
                    item: item,
                    isPublished: false,
                    onConfirm: {
                        Task {
                            do {
                                try await viewModel.deleteContent(item)
                                showPrivateDeleteConfirmation = false
                                pendingDeleteItem = nil
                            } catch {
                                AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                            }
                        }
                    },
                    onCancel: {
                        showPrivateDeleteConfirmation = false
                        pendingDeleteItem = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showPublishedDeleteConfirmation) {
            if let item = publishedDeleteModalItem {
                PublishedContentDeleteModal(
                    item: item,
                    onUnpublishAndDelete: {
                        AppLogger.view.info("User selected 'Unpublish & Delete' for item: \(item.id)")
                        Task {
                            do {
                                try await viewModel.deleteAndUnpublishContent(item)
                                showPublishedDeleteConfirmation = false
                                publishedDeleteModalItem = nil
                                pendingDeleteItem = nil
                            } catch {
                                AppLogger.view.error("Failed to unpublish and delete content: \(error.localizedDescription)")
                            }
                        }
                    },
                    onKeepPublished: {
                        AppLogger.view.info("User selected 'Keep Published' for item: \(item.id)")
                        Task {
                            do {
                                // For "Keep Published", delete local copy but keep content published on backend
                                try await viewModel.deleteLocalCopyKeepPublished(item)
                                showPublishedDeleteConfirmation = false
                                publishedDeleteModalItem = nil
                                pendingDeleteItem = nil
                            } catch {
                                AppLogger.view.error("Failed to delete local copy: \(error.localizedDescription)")
                            }
                        }
                    },
                    onCancel: {
                        AppLogger.view.info("User cancelled published content deletion")
                        showPublishedDeleteConfirmation = false
                        publishedDeleteModalItem = nil
                        pendingDeleteItem = nil
                    }
                )
            } else {
                // Fallback for debugging - show empty state if item is missing
                Text("No item selected")
                    .onAppear {
                        AppLogger.view.error("PublishedContentDeleteModal presented with nil publishedDeleteModalItem")
                        showPublishedDeleteConfirmation = false
                    }
            }
        }
        .onChange(of: viewModel.pendingPublishItem) { oldValue, newValue in
            showingPublishConfirmation = newValue != nil
        }
        .onChange(of: showPublishedDeleteConfirmation) { oldValue, newValue in
            if !newValue {
                // Sheet was dismissed, clean up state
                publishedDeleteModalItem = nil
                pendingDeleteItem = nil
            }
        }
    }
    
    
    // MARK: - Create Menu
    
    private var createMenu: some View {
        Menu {
            Button {
                viewModel.onCreateChecklistTapped()
            } label: {
                Label(L10n.Library.newChecklist, systemImage: "checklist")
            }
            
            Button {
                viewModel.onCreateDeckTapped()
            } label: {
                Label(L10n.Library.newFlashcardDeck, systemImage: "rectangle.stack")
            }
            
            Button {
                viewModel.onCreateGuideTapped()
            } label: {
                Label(L10n.Library.newPracticeGuide, systemImage: "book")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        DesignSystem.EmptyStateHero(
            icon: "book.fill",
            title: "Your Library Awaits",
            message: "Create checklists, guides, and flashcard decks to organize your sailing knowledge. Every great sailor builds their own library of resources.",
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
    
    private enum ContentFilter: String, CaseIterable, Identifiable {
        case all
        case checklists
        case guides
        case decks
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .all: return L10n.Library.filterAll
            case .checklists: return L10n.Library.filterChecklists
            case .guides: return L10n.Library.filterGuides
            case .decks: return L10n.Library.filterDecks
            }
        }
    }
    
    private var filteredItems: [LibraryModel] {
        switch selectedFilter {
        case .all:
            return viewModel.library
        case .checklists:
            return viewModel.checklists
        case .guides:
            return viewModel.guides
        case .decks:
            return viewModel.decks
        }
    }
    
    private var contentList: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Picker(L10n.Library.filterAccessibilityLabel, selection: $selectedFilter) {
                ForEach(ContentFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            List {
                ForEach(filteredItems) { item in
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
                            case .flashcardDeck:
                                // TODO: Implement deck reader when ready
                                break
                            }
                        },
                        onAuthorTapped: { username in
                            // TODO: Implement author profile navigation for forked content
                            print("Tapped original author: \(username)")
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
                            showingSignInModal = true
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteItem = item
                            AppLogger.view.info("Delete initiated for item: \(item.id), title: '\(item.title)', publicID: \(item.publicID ?? "nil")")
                            if viewModel.isPublishedContent(item) {
                                AppLogger.view.info("Showing published content delete modal")
                                publishedDeleteModalItem = item
                                showPublishedDeleteConfirmation = true
                            } else {
                                AppLogger.view.info("Showing private content delete modal")
                                showPrivateDeleteConfirmation = true
                            }
                        } label: {
                            Label(L10n.Library.actionDelete, systemImage: "trash")
                        }
                        
                        Button {
                            switch item.type {
                            case .checklist:
                                viewModel.onEditChecklistTapped(item.id)
                            case .practiceGuide:
                                viewModel.onEditGuideTapped(item.id)
                            case .flashcardDeck:
                                viewModel.onEditDeckTapped(item.id)
                            }
                        } label: {
                            Label(L10n.Library.actionEdit, systemImage: "pencil")
                        }
                        .tint(.gray)
                        
                        Button {
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
    }
}

// MARK: - Preview

#Preview {
    #if DEBUG
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
            type: .flashcardDeck,
            visibility: .unlisted,
            creatorID: UUID(),
            tags: ["colregs", "rules", "night"],
            createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3),
            updatedAt: Date().addingTimeInterval(-60 * 10)
        )
    ]

    let repository = PreviewLibraryRepository(sampleLibrary: sampleLibrary)
    let dependencies = AppDependencies()
    let libraryStore = LibraryStore(repository: repository)
    let coordinator = AppCoordinator(dependencies: dependencies)
    let viewModel = LibraryListViewModel(
        libraryStore: libraryStore,
        visibilityService: dependencies.visibilityService,
        authObserver: dependencies.authStateObserver,
        coordinator: coordinator
    )

    NavigationStack {
        LibraryListView(viewModel: viewModel)
    }
    .environment(\.appDependencies, dependencies)
    .environment(\.appCoordinator, coordinator)
    #else
    LibraryListView()
    #endif
}

#if DEBUG
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

    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist? { nil }
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? { nil }
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck? { nil }

    // MARK: - Mutating Operations (no‑ops for preview)
    func createChecklist(_ checklist: Checklist) async throws {}
    func createGuide(_ guide: PracticeGuide) async throws {}
    func createDeck(_ deck: FlashcardDeck) async throws {}

    func saveChecklist(_ checklist: Checklist) async throws {}
    func saveGuide(_ guide: PracticeGuide) async throws {}
    
    func updateLibraryMetadata(_ model: LibraryModel) async throws {}

    func deleteContent(_ contentID: UUID) async throws {}
}
#endif

