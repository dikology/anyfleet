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
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK") { viewModel.errorMessage = nil }
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
        viewModel.isNewChecklist ? "New Checklist" : "Edit Checklist"
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
                Text("Save")
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Title input
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Title")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField("Checklist name", text: $viewModel.checklist.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            
            // Description input
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Description")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                TextField("Brief description", text: Binding(
                    get: { viewModel.checklist.description ?? "" },
                    set: { viewModel.checklist.description = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(2...4)
            }
            
            Divider()
            
            // Metadata row
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Checklist type")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                checklistTypeSelector
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle()
    }
    
    /// Selector allowing the user to change the checklist type using DesignSystem styling.
    private var checklistTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(ChecklistType.allCases, id: \.self) { type in
                    Button {
                        viewModel.checklist.checklistType = type
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(type.displayName)
                                .font(DesignSystem.Typography.caption)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
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
            statItem(value: "\(viewModel.checklist.sections.count)", label: "Sections")
            statItem(value: "\(viewModel.checklist.totalItems)", label: "Items")
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.headline)
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
                Text("Add Section")
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
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("\(section.items.count) items")
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
                            Text("Add Item")
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
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

