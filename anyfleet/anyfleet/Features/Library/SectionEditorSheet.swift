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
                            Text(L10n.SectionEditor.sectionTitle)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            TextField(L10n.SectionEditor.sectionNamePlaceholder, text: $title)
                                .font(DesignSystem.Typography.body)
                                .formFieldStyle()
                        }
                        
                        // Icon selection
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text(L10n.SectionEditor.icon)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text(L10n.SectionEditor.optional)
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
                                    
                                    Text(icon != nil ? L10n.SectionEditor.changeIcon : L10n.SectionEditor.chooseIcon)
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
                                Text(L10n.SectionEditor.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text(L10n.SectionEditor.optional)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            TextField(L10n.SectionEditor.sectionDescriptionPlaceholder, text: $description, axis: .vertical)
                                .font(DesignSystem.Typography.body)
                                .lineLimit(2...4)
                                .formFieldStyle()
                        }
                        
                        // Options
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(L10n.SectionEditor.options)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Toggle(isOn: $isExpandedByDefault) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.SectionEditor.expandedByDefault)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    Text(L10n.SectionEditor.expandedByDefaultDescription)
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
                                    Text(L10n.SectionEditor.deleteSection)
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
            .navigationTitle(existingSection == nil ? L10n.SectionEditor.newSection : L10n.SectionEditor.editSection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.SectionEditor.cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.SectionEditor.save) {
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
            .alert(L10n.SectionEditor.deleteSectionAlert, isPresented: $showingDeleteConfirm) {
                Button(L10n.SectionEditor.cancel, role: .cancel) { }
                Button(L10n.SectionEditor.delete, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(L10n.SectionEditor.deleteSectionMessage)
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
                            Text(L10n.SectionEditor.none)
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
            .navigationTitle(L10n.SectionEditor.chooseIconTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.SectionEditor.done) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("New Section") {
    SectionEditorSheet(
        section: nil,
        onSave: { _ in }
    )
}

#Preview("Edit Section") {
    let sampleSection = ChecklistSection(
        title: "Engine & Systems",
        icon: "engine.combustion",
        description: "Essential engine and mechanical system checks",
        items: [
            ChecklistItem(title: "Check engine oil level"),
            ChecklistItem(title: "Test bilge pump operation")
        ],
        isExpandedByDefault: true
    )
    
    return SectionEditorSheet(
        section: sampleSection,
        onSave: { _ in },
        onDelete: {}
    )
}

#Preview("Edit Section - No Icon") {
    let sampleSection = ChecklistSection(
        title: "Safety Equipment",
        description: "Safety equipment verification",
        items: [
            ChecklistItem(title: "Life jackets accessible")
        ],
        isExpandedByDefault: false
    )
    
    return SectionEditorSheet(
        section: sampleSection,
        onSave: { _ in },
        onDelete: {}
    )
}
