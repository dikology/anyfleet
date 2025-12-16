//
//  SectionEditorSheet.swift
//  anyfleet
//
//  Sheet for editing a checklist section
//

import SwiftUI

struct SectionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var icon: String?
    @State private var description: String
    @State private var isExpandedByDefault: Bool
    
    private let existingSection: ChecklistSection?
    private let onSave: (ChecklistSection) -> Void
    private let onDelete: (() -> Void)?
    
    @State private var showingIconPicker = false
    @State private var showingDeleteConfirm = false
    
    // Common icons for sections
    private let sectionIcons = [
        "doc.text", "shield.checkered", "engine.combustion", "bolt",
        "drop", "fuelpump", "map", "anchor", "sailboat",
        "wrench.and.screwdriver", "lifepreserver", "cross.case",
        "sun.max", "moon.stars", "sunrise", "arrow.right.circle",
        "exclamationmark.triangle", "checkmark.shield", "cart",
        "bed.double", "cooktop", "sparkles", "antenna.radiowaves.left.and.right"
    ]
    
    init(
        section: ChecklistSection?,
        onSave: @escaping (ChecklistSection) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existingSection = section
        self.onSave = onSave
        self.onDelete = onDelete
        
        _title = State(initialValue: section?.title ?? "")
        _icon = State(initialValue: section?.icon)
        _description = State(initialValue: section?.description ?? "")
        _isExpandedByDefault = State(initialValue: section?.isExpandedByDefault ?? true)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Title section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Section Title")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            TextField("Section name", text: $title)
                                .font(DesignSystem.Typography.body)
                                .formFieldStyle()
                        }
                        
                        // Icon selection
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Icon")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text("Optional")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            Button {
                                showingIconPicker = true
                            } label: {
                                HStack {
                                    if let icon = icon {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(DesignSystem.Colors.primary)
                                            .frame(width: 32, height: 32)
                                            .background(DesignSystem.Colors.primary.opacity(0.1))
                                            .cornerRadius(8)
                                    } else {
                                        Image(systemName: "photo")
                                            .font(.system(size: 20))
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .frame(width: 32, height: 32)
                                            .background(DesignSystem.Colors.surfaceAlt)
                                            .cornerRadius(8)
                                    }
                                    
                                    Text(icon != nil ? "Change Icon" : "Choose Icon")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(10)
                            }
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
                            
                            TextField("Section description", text: $description, axis: .vertical)
                                .font(DesignSystem.Typography.body)
                                .lineLimit(2...4)
                                .formFieldStyle()
                        }
                        
                        // Options
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Options")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Toggle(isOn: $isExpandedByDefault) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Expanded by Default")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    Text("Show items when viewing checklist")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(10)
                        }
                        
                        // Delete button (if editing existing)
                        if let _ = existingSection, onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Section")
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
            .navigationTitle(existingSection == nil ? "New Section" : "Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        let section = ChecklistSection(
                            id: existingSection?.id ?? UUID(),
                            title: title,
                            icon: icon,
                            description: description.isEmpty ? nil : description,
                            items: existingSection?.items ?? [],
                            isExpandedByDefault: isExpandedByDefault,
                            sortOrder: existingSection?.sortOrder ?? 0
                        )
                        onSave(section)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $icon, icons: sectionIcons)
            }
            .alert("Delete Section", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this section? All items in this section will be deleted.")
            }
        }
    }
}

// MARK: - Icon Picker Sheet

private struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String?
    let icons: [String]
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                    // None option
                    Button {
                        selectedIcon = nil
                        dismiss()
                    } label: {
                        VStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("None")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(width: 60, height: 60)
                        .background(selectedIcon == nil ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.surface)
                        .cornerRadius(10)
                    }
                    
                    // Icon options
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .frame(width: 60, height: 60)
                            .background(selectedIcon == icon ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.surface)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

