import SwiftUI

struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    @State private var selectedFilter: ContentFilter = .all
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator
    
    init(viewModel: LibraryListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Placeholder - will be replaced in body with proper dependencies
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
        // Initialize ViewModel with proper dependencies if needed
        let _ = updateViewModelIfNeeded()
        
        Group {
            if viewModel.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                contentList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
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
    }
    
    // MARK: - ViewModel Update
    
    private func updateViewModelIfNeeded() {
        // ViewModel is initialized with proper dependencies in init or from AppView
        // This method is kept for potential future use if dynamic updates are needed
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
                            Task {
                                do {
                                    try await viewModel.deleteContent(item)
                                } catch {
                                    AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                                }
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

// MARK: - Library Item Row

struct LibraryItemRow: View {
    let item: LibraryModel
    let contentType: ContentType
    let onTap: () -> Void
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Section - Focal Point
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Content Title - Primary Focal Element
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    // Type Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary.opacity(0.15),
                                        DesignSystem.Colors.primary.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: contentType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(item.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.textPrimary,
                                        DesignSystem.Colors.textPrimary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Type Badge
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(contentType.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                }
                
                // Description
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, 56) // Align with title
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
            .focalHighlight()
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Metadata Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Visibility Badge
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: item.visibility.icon)
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(item.visibility.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.border.opacity(0.3))
                    )
                    
                    Spacer()
                    
                    // Updated Date
                    Text("\(L10n.Library.updatedPrefix) \(item.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: .medium)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            onTap()
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

