//
//  ChecklistReaderView.swift
//  anyfleet
//
//  Read-only view for checklists.
//

import SwiftUI

struct ChecklistReaderView: View {
    @State private var viewModel: ChecklistReaderViewModel
    
    init(viewModel: ChecklistReaderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            Group {
                if let checklist = viewModel.checklist {
                    contentView(for: checklist)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding()
                } else {
                    // Show loading state instead of empty view
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                        Text("Loading checklist...")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(viewModel.checklist?.title ?? "Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadChecklist()
        }
    }
    
    // MARK: - Content
    
    private func contentView(for checklist: Checklist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerView(for: checklist)
                
                // Sections
                ForEach(checklist.sections) { section in
                    sectionView(for: section)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Header
    
    private func headerView(for checklist: Checklist) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Title
            Text(checklist.title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            // Description
            if let description = checklist.description, !description.isEmpty {
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Metadata
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Type badge
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: checklist.checklistType.icon)
                        .font(.system(size: 12))
                    Text(checklist.checklistType.displayName)
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                )
                
                // Stats
                HStack(spacing: DesignSystem.Spacing.md) {
                    statBadge(
                        value: "\(checklist.sections.count)",
                        label: checklist.sections.count == 1 ? "Section" : "Sections"
                    )
                    statBadge(
                        value: "\(checklist.totalItems)",
                        label: checklist.totalItems == 1 ? "Item" : "Items"
                    )
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    private func statBadge(value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(DesignSystem.Typography.caption)
        }
        .foregroundColor(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.border.opacity(0.3))
        )
    }
    
    // MARK: - Section
    
    private func sectionView(for section: ChecklistSection) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = section.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 28, height: 28)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(section.title)
                        .font(DesignSystem.Typography.subheader)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if let description = section.description, !description.isEmpty {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xs)
            
            // Items
            if !section.items.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(section.items) { item in
                        itemView(for: item)
                    }
                }
                .padding(.leading, section.icon != nil ? 36 : 0)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Item
    
    private func itemView(for item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                // Unchecked checkbox indicator
                Circle()
                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            // Item metadata
            if item.isRequired || item.isOptional || item.estimatedMinutes != nil {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if item.isRequired {
                        Text("Required")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.error)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.error.opacity(0.1))
                            )
                    }
                    
                    if item.isOptional {
                        Text("Optional")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.border.opacity(0.3))
                            )
                    }
                    
                    if let minutes = item.estimatedMinutes {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(minutes) min")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.leading, 28)
            }
        }
    }
}

// MARK: - Preview

private func makePreviewView() -> some View {
    let dependencies = try! AppDependencies.makeForTesting()
    
    // Create a sample checklist
    let sampleChecklist = Checklist(
        title: "Pre-Departure Safety Checklist",
        description: "Essential safety checks before leaving port",
        sections: [
            ChecklistSection(
                title: "Engine & Systems",
                icon: "engine.combustion",
                items: [
                    ChecklistItem(title: "Check engine oil level"),
                    ChecklistItem(title: "Test bilge pump operation", isRequired: true),
                    ChecklistItem(title: "Verify fuel tank levels", estimatedMinutes: 5)
                ]
            ),
            ChecklistSection(
                title: "Safety Equipment",
                icon: "shield.checkered",
                description: "Verify all safety equipment is accessible and functional",
                items: [
                    ChecklistItem(title: "Life jackets accessible", isRequired: true),
                    ChecklistItem(title: "Fire extinguishers checked", isRequired: true),
                    ChecklistItem(title: "Flares and emergency kit ready", isOptional: true)
                ]
            ),
            ChecklistSection(
                title: "Navigation",
                icon: "compass",
                items: [
                    ChecklistItem(title: "GPS and chartplotter working", isRequired: true),
                    ChecklistItem(title: "VHF radio tested", isRequired: true)
                ]
            )
        ],
        checklistType: .preCharter
    )
    
    let viewModel = ChecklistReaderViewModel(
        libraryStore: dependencies.libraryStore,
        checklistID: sampleChecklist.id
    )
    // Set the checklist directly in the viewModel for preview
    viewModel.checklist = sampleChecklist
    
    return NavigationStack {
        ChecklistReaderView(viewModel: viewModel)
    }
    .environment(\.appDependencies, dependencies)
}

#Preview("Checklist Reader") {
    makePreviewView()
}

