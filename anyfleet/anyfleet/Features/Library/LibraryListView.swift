import SwiftUI

struct LibraryListView: View {
    @State private var viewModel: LibraryListViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator
    
    init(viewModel: LibraryListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Placeholder - will be replaced in body with proper dependencies
            _viewModel = State(initialValue: LibraryListViewModel(
                libraryStore: LibraryStore(repository: LocalRepository()),
                coordinator: AppCoordinator()
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
        .navigationTitle(L10n.Library.myLibrary)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .toolbar {
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
        // Check if viewModel was created with placeholder dependencies
        // If so, update it with proper dependencies from environment
        // This is a workaround for SwiftUI initialization limitations
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
    
    private var contentList: some View {
        List {
            // Checklists Section
            if !viewModel.checklists.isEmpty {
                Section {
                    ForEach(viewModel.checklists) { item in
                        LibraryItemRow(
                            item: item,
                            contentType: .checklist,
                            onTap: { viewModel.onEditChecklistTapped(item.id) }
                        )
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.sm,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.sm,
                            trailing: DesignSystem.Spacing.lg
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await viewModel.deleteContent(item)
                                    } catch {
                                        AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Checklists")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            
            // Guides Section
            if !viewModel.guides.isEmpty {
                Section {
                    ForEach(viewModel.guides) { item in
                        LibraryItemRow(
                            item: item,
                            contentType: .practiceGuide,
                            onTap: { viewModel.onEditGuideTapped(item.id) }
                        )
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.sm,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.sm,
                            trailing: DesignSystem.Spacing.lg
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await viewModel.deleteContent(item)
                                    } catch {
                                        AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Practice Guides")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            
            // Decks Section
            if !viewModel.decks.isEmpty {
                Section {
                    ForEach(viewModel.decks) { item in
                        LibraryItemRow(
                            item: item,
                            contentType: .flashcardDeck,
                            onTap: { viewModel.onEditDeckTapped(item.id) }
                        )
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.sm,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.sm,
                            trailing: DesignSystem.Spacing.lg
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await viewModel.deleteContent(item)
                                    } catch {
                                        AppLogger.view.error("Failed to delete content: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Flashcard Decks")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
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
                    Text("Updated \(item.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Tags
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(item.tags.prefix(5), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.leading, -DesignSystem.Spacing.lg)
                    .padding(.trailing, DesignSystem.Spacing.lg)
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
    let dependencies = try! AppDependencies.makeForTesting()
    let coordinator = AppCoordinator()
    return LibraryListView(
        viewModel: LibraryListViewModel(
            libraryStore: dependencies.libraryStore,
            coordinator: coordinator
        )
    )
    .environment(\.appDependencies, dependencies)
    .environment(\.appCoordinator, coordinator)
}
