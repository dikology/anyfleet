//
//  ItemEditorSheet.swift
//  anyfleet
//
//  Sheet for editing a checklist item
//

import SwiftUI

struct ItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var itemDescription: String
    @State private var isOptional: Bool
    @State private var isRequired: Bool
    @State private var estimatedMinutes: Int?
    
    private let existingItem: ChecklistItem?
    private let onSave: (ChecklistItem) -> Void
    private let onDelete: (() -> Void)?
    
    @State private var showingDeleteConfirm = false
    
    init(
        item: ChecklistItem?,
        onSave: @escaping (ChecklistItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existingItem = item
        self.onSave = onSave
        self.onDelete = onDelete
        
        _title = State(initialValue: item?.title ?? "")
        _itemDescription = State(initialValue: item?.itemDescription ?? "")
        _isOptional = State(initialValue: item?.isOptional ?? false)
        _isRequired = State(initialValue: item?.isRequired ?? false)
        _estimatedMinutes = State(initialValue: item?.estimatedMinutes)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Title
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(L10n.ItemEditor.itemTitle)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            TextField(L10n.ItemEditor.itemNamePlaceholder, text: $title)
                                .font(DesignSystem.Typography.body)
                                .formFieldStyle()
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text(L10n.ItemEditor.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text(L10n.ItemEditor.optional)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            TextField(L10n.ItemEditor.itemDescriptionPlaceholder, text: $itemDescription, axis: .vertical)
                                .font(DesignSystem.Typography.body)
                                .lineLimit(3...6)
                                .formFieldStyle()
                        }
                        
                        
                        // Delete button (if editing existing)
                        if let _ = existingItem, onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(L10n.ItemEditor.deleteItem)
                                }
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.error)
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle(existingItem == nil ? L10n.ItemEditor.newItem : L10n.ItemEditor.editItem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.ItemEditor.cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.ItemEditor.save) {
                        let item = ChecklistItem(
                            id: existingItem?.id ?? UUID(),
                            title: title,
                            itemDescription: itemDescription.isEmpty ? nil : itemDescription,
                            isOptional: isOptional,
                            isRequired: isRequired,
                            tags: existingItem?.tags ?? [],
                            estimatedMinutes: estimatedMinutes,
                            sortOrder: existingItem?.sortOrder ?? 0
                        )
                        onSave(item)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert(L10n.ItemEditor.deleteItemAlert, isPresented: $showingDeleteConfirm) {
                Button(L10n.ItemEditor.cancel, role: .cancel) { }
                Button(L10n.ItemEditor.delete, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(L10n.ItemEditor.deleteItemMessage)
            }
        }
    }
}

// MARK: - Preview

#Preview("New Item") {
    ItemEditorSheet(
        item: nil,
        onSave: { _ in }
    )
}

#Preview("Edit Item") {
    let sampleItem = ChecklistItem(
        title: "Check engine oil level",
        itemDescription: "Verify oil level is within acceptable range",
        isRequired: true,
        estimatedMinutes: 5
    )
    
    return ItemEditorSheet(
        item: sampleItem,
        onSave: { _ in },
        onDelete: {}
    )
}

#Preview("Edit Item - Optional") {
    let sampleItem = ChecklistItem(
        title: "Clean windows",
        itemDescription: "Optional cleaning task",
        isOptional: true,
        estimatedMinutes: 10
    )
    
    return ItemEditorSheet(
        item: sampleItem,
        onSave: { _ in },
        onDelete: {}
    )
}
