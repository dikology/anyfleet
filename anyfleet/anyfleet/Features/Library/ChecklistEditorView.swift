//
//  ChecklistEditorView.swift
//  anyfleet
//
//  Main checklist editor view for creating and editing checklists
//

import SwiftUI

struct ChecklistEditorView: View {
    @State private var viewModel: ChecklistEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSection = false
    @State private var showingPreview = false
    
    init(viewModel: ChecklistEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        mainContent
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddSection) {
                addSectionSheet
            }
            .sheet(item: $viewModel.editingSection) { section in
                editSectionSheet(section: section)
            }
            .sheet(item: editingItemBinding) { wrapper in
                editItemSheet(wrapper: wrapper)
            }
            .task {
                await viewModel.loadChecklist()
            }
            .alert(L10n.ChecklistEditor.error, isPresented: errorAlertBinding) {
                Button(L10n.ChecklistEditor.ok) { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    headerCard
                    statsRow
                    sectionsContent
                    addSectionButton
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
    }
    
    private var navigationTitle: String {
        viewModel.isNewChecklist ? L10n.ChecklistEditor.newChecklist : L10n.ChecklistEditor.editChecklist
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            saveButton
        }
    }
    
    private var saveButton: some View {
        Button(action: saveAction) {
            if viewModel.isSaving {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
            } else {
                Text(L10n.ChecklistEditor.save)
                    .fontWeight(.semibold)
            }
        }
        .disabled(viewModel.isSaving || viewModel.checklist.title.isEmpty)
        .foregroundColor(saveButtonColor)
    }
    
    private var saveButtonColor: Color {
        viewModel.checklist.title.isEmpty 
            ? DesignSystem.Colors.textSecondary 
            : DesignSystem.Colors.primary
    }
    
    private func saveAction() {
        Task {
            await viewModel.saveChecklist()
        }
    }
    
    // MARK: - Sheets
    
    private var addSectionSheet: some View {
        SectionEditorSheet(
            section: nil,
            onSave: { newSection in
                viewModel.addSection(newSection)
            }
        )
    }
    
    private func editSectionSheet(section: ChecklistSection) -> some View {
        SectionEditorSheet(
            section: section,
            onSave: { updatedSection in
                viewModel.updateSection(updatedSection)
            },
            onDelete: {
                viewModel.deleteSection(id: section.id)
            }
        )
    }
    
    private var editingItemBinding: Binding<EditingItemWrapper?> {
        Binding(
            get: {
                viewModel.editingItem.map { 
                    EditingItemWrapper(sectionID: $0.sectionID, item: $0.item) 
                }
            },
            set: { newValue in
                viewModel.editingItem = newValue.map { ($0.sectionID, $0.item) }
            }
        )
    }
    
    private func editItemSheet(wrapper: EditingItemWrapper) -> some View {
        ItemEditorSheet(
            item: wrapper.item,
            onSave: { updatedItem in
                viewModel.updateItem(updatedItem, inSection: wrapper.sectionID)
            },
            onDelete: {
                viewModel.deleteItem(wrapper.item.id, fromSection: wrapper.sectionID)
            }
        )
    }
    
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Focal Point: Title Section with subtle emphasis
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs + 2) {
                Text(L10n.ChecklistEditor.title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.3)
                
                TextField(L10n.ChecklistEditor.checklistNamePlaceholder, text: $viewModel.checklist.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.gold.opacity(0.15),
                        DesignSystem.Colors.gold.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            )
            
            // Supporting Element: Description with refined spacing
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs + 2) {
                Text(L10n.ChecklistEditor.description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.3)
                
                TextField(L10n.ChecklistEditor.descriptionPlaceholder, text: Binding(
                    get: { viewModel.checklist.description ?? "" },
                    set: { viewModel.checklist.description = $0.isEmpty ? nil : $0 }
                ))
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textFieldStyle(.plain)
                .lineLimit(2)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
            
            // Visual separator with intentional spacing
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Metadata: Checklist Type Selector
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.ChecklistEditor.checklistType)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.3)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                
                checklistTypeSelector
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .background(DesignSystem.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.border.opacity(0.6),
                            DesignSystem.Colors.border.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    /// Selector allowing the user to change the checklist type using DesignSystem styling.
    private var checklistTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(ChecklistType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.checklist.checklistType = type
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(type.displayName)
                                .font(DesignSystem.Typography.caption)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.checklist.checklistType == type
                                    ? DesignSystem.Colors.primary.opacity(0.12)
                                    : DesignSystem.Colors.surfaceAlt
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    viewModel.checklist.checklistType == type
                                    ? DesignSystem.Colors.primary
                                    : DesignSystem.Colors.border,
                                    lineWidth: viewModel.checklist.checklistType == type ? 1.5 : 1
                                )
                        )
                        .foregroundColor(
                            viewModel.checklist.checklistType == type
                            ? DesignSystem.Colors.primary
                            : DesignSystem.Colors.textSecondary
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, DesignSystem.Spacing.sm)
            }
        }
    }
    
    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(DesignSystem.Typography.caption)
        }
        .foregroundColor(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.surfaceAlt)
        .cornerRadius(8)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            statItem(value: "\(viewModel.checklist.sections.count)", label: L10n.ChecklistEditor.sections)
            statItem(value: "\(viewModel.checklist.totalItems)", label: L10n.ChecklistEditor.items)
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Sections Content
    
    private var sectionsContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(Array(viewModel.checklist.sections.enumerated()), id: \.element.id) { index, section in
                SectionCard(
                    section: section,
                    sectionIndex: index,
                    onEditSection: {
                        viewModel.editingSection = section
                    },
                    onAddItem: {
                        viewModel.addItem(to: section.id)
                    },
                    onEditItem: { item in
                        viewModel.editingItem = (section.id, item)
                    },
                    onDeleteItem: { itemID in
                        viewModel.deleteItem(itemID, fromSection: section.id)
                    },
                    onMoveItem: { from, to in
                        viewModel.moveItem(in: section.id, from: from, to: to)
                    }
                )
            }
            .onMove { source, destination in
                viewModel.checklist.sections.move(fromOffsets: source, toOffset: destination)
            }
        }
    }
    
    // MARK: - Add Section Button
    
    private var addSectionButton: some View {
        Button {
            showingAddSection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text(L10n.ChecklistEditor.addSection)
                    .font(DesignSystem.Typography.body)
            }
            .foregroundColor(DesignSystem.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignSystem.Colors.primary, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            )
        }
    }
}

// MARK: - Wrapper for Identifiable sheet binding

private struct EditingItemWrapper: Identifiable {
    let id: UUID
    let sectionID: UUID
    let item: ChecklistItem
    
    init(sectionID: UUID, item: ChecklistItem) {
        self.id = item.id
        self.sectionID = sectionID
        self.item = item
    }
}

// MARK: - Section Card

private struct SectionCard: View {
    let section: ChecklistSection
    let sectionIndex: Int
    let onEditSection: () -> Void
    let onAddItem: () -> Void
    let onEditItem: (ChecklistItem) -> Void
    let onDeleteItem: (UUID) -> Void
    let onMoveItem: (Int, Int) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Section icon
                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 28, height: 28)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(DesignSystem.Typography.subheader)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("\(section.items.count) \(L10n.ChecklistEditor.items)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Edit button
                    Button {
                        onEditSection()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.trailing, DesignSystem.Spacing.sm)
                    
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
            }
            .buttonStyle(.plain)
            
            // Items list (collapsible)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        ItemRow(
                            item: item,
                            onTap: { onEditItem(item) },
                            onDelete: { onDeleteItem(item.id) }
                        )
                        
                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.leading, DesignSystem.Spacing.lg + 24 + DesignSystem.Spacing.sm)
                        }
                    }
                    
                    // Add item button
                    Button {
                        onAddItem()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                            Text(L10n.ChecklistEditor.addItem)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
                .background(DesignSystem.Colors.surface)
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onAppear {
            isExpanded = section.isExpandedByDefault
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: ChecklistItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Checkbox placeholder
                Circle()
                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.ChecklistEditor.delete, systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview("New Checklist") {
    let dependencies = try! AppDependencies.makeForTesting()
    let viewModel = ChecklistEditorViewModel(
        libraryStore: dependencies.libraryStore,
        checklistID: nil,
        onDismiss: {}
    )
    
    return NavigationStack {
        ChecklistEditorView(viewModel: viewModel)
    }
    .environment(\.appDependencies, dependencies)
}

#Preview("Existing Checklist") {
    let dependencies = try! AppDependencies.makeForTesting()
    
    // Create a sample checklist with sections and items
    var sampleChecklist = Checklist(
        title: "Pre-Departure Safety Checklist",
        description: "Essential safety checks before leaving port",
        sections: [
            ChecklistSection(
                title: "Engine & Systems",
                icon: "engine",
                items: [
                    ChecklistItem(title: "Check engine oil level"),
                    ChecklistItem(title: "Test bilge pump operation"),
                    ChecklistItem(title: "Verify fuel tank levels")
                ]
            ),
            ChecklistSection(
                title: "Safety Equipment",
                icon: "shield.checkered",
                items: [
                    ChecklistItem(title: "Life jackets accessible"),
                    ChecklistItem(title: "Fire extinguishers checked"),
                    ChecklistItem(title: "Flares and emergency kit ready")
                ]
            ),
            ChecklistSection(
                title: "Navigation",
                icon: "compass",
                items: [
                    ChecklistItem(title: "GPS and chartplotter working"),
                    ChecklistItem(title: "VHF radio tested")
                ]
            )
        ],
        checklistType: .preCharter
    )
    
    let viewModel = ChecklistEditorViewModel(
        libraryStore: dependencies.libraryStore,
        checklistID: sampleChecklist.id,
        onDismiss: {}
    )
    viewModel.checklist = sampleChecklist
    
    return NavigationStack {
        ChecklistEditorView(viewModel: viewModel)
    }
    .environment(\.appDependencies, dependencies)
}

