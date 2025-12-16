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
                            Text("Item Title")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            TextField("Item name", text: $title)
                                .font(DesignSystem.Typography.body)
                                .formFieldStyle()
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Description")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text("Optional")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            TextField("Item description", text: $itemDescription, axis: .vertical)
                                .font(DesignSystem.Typography.body)
                                .lineLimit(3...6)
                                .formFieldStyle()
                        }
                        
                        // Importance toggles
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Importance")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            VStack(spacing: 0) {
                                // Required toggle
                                Toggle(isOn: $isRequired) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(DesignSystem.Colors.error)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Required")
                                                .font(DesignSystem.Typography.body)
                                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                            Text("Safety-critical item")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                    }
                                }
                                .tint(DesignSystem.Colors.error)
                                .padding(DesignSystem.Spacing.md)
                                .onChange(of: isRequired) { _, newValue in
                                    if newValue { isOptional = false }
                                }
                                
                                Divider()
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                
                                // Optional toggle
                                Toggle(isOn: $isOptional) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "circle.dashed")
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Optional")
                                                .font(DesignSystem.Typography.body)
                                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                            Text("Can be skipped")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                    }
                                }
                                .tint(DesignSystem.Colors.primary)
                                .padding(DesignSystem.Spacing.md)
                                .onChange(of: isOptional) { _, newValue in
                                    if newValue { isRequired = false }
                                }
                            }
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(10)
                        }
                        
                        // Estimated time
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Estimated Time (minutes)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            TextField("Minutes", value: $estimatedMinutes, format: .number)
                                .font(DesignSystem.Typography.body)
                                .formFieldStyle()
                                .keyboardType(.numberPad)
                        }
                        
                        // Delete button (if editing existing)
                        if let _ = existingItem, onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Item")
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
            .navigationTitle(existingItem == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
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
            .alert("Delete Item", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this item?")
            }
        }
    }
}

