//
//  ChecklistExecutionView.swift
//  anyfleet
//
//  View for executing a checklist with progress tracking scoped to a charter
//

import SwiftUI

struct ChecklistExecutionView: View {
    @State private var viewModel: ChecklistExecutionViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: ChecklistExecutionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            if let checklist = viewModel.checklist {
                ScrollView {
                    VStack(spacing: 0) {
                        headerView(checklist)
                        
                        ForEach(checklist.sections) { section in
                            sectionView(section)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.error)
                    Text("Failed to load checklist")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(error.localizedDescription)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(DesignSystem.Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.checklist?.checklistType.displayName ?? "Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .task {
            await viewModel.load()
        }
    }
    
    // MARK: - Header View
    
    private func headerView(_ checklist: Checklist) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Title
                Text(checklist.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Description
                if let description = checklist.description, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Metadata badge
                HStack(spacing: DesignSystem.Spacing.sm) {
                    metadataBadge(
                        icon: checklist.checklistType.icon,
                        text: checklist.checklistType.displayName
                    )
                }
            }
            
            // Progress bar
            progressView
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
        }
        .padding(DesignSystem.Spacing.screenPadding)
        .background(DesignSystem.Colors.surface)
    }
    
    private func metadataBadge(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.caption)
        }
        .foregroundColor(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.surfaceAlt)
        .cornerRadius(8)
    }
    
    private var progressView: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("\(viewModel.checkedCount) of \(viewModel.totalItems) completed")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(viewModel.progressPercentage * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.surfaceAlt)
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.gold
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.progressPercentage)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Section View
    
    private func sectionView(_ section: ChecklistSection) -> some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                viewModel.toggleSection(section.id)
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Section icon
                    if let icon = section.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 32, height: 32)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        let progress = viewModel.sectionProgress(section)
                        Text("\(progress.checked)/\(progress.total) items")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: viewModel.isSectionExpanded(section.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.Colors.surface)
            
            // Items
            if viewModel.isSectionExpanded(section.id) {
                VStack(spacing: 0) {
                    ForEach(section.items) { item in
                        itemRow(item)
                        
                        if item.id != section.items.last?.id {
                            Divider()
                                .background(DesignSystem.Colors.border.opacity(0.5))
                                .padding(.leading, DesignSystem.Spacing.lg + 32 + DesignSystem.Spacing.sm)
                        }
                    }
                }
                .background(DesignSystem.Colors.surface)
            }
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
        }
    }
    
    // MARK: - Item Row
    
    private func itemRow(_ item: ChecklistItem) -> some View {
        Button {
            viewModel.toggleItem(item.id)
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Checkbox
                ZStack {
                    if viewModel.isItemChecked(item.id) {
                        Circle()
                            .fill(DesignSystem.Colors.primary)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(
                                item.isRequired ? DesignSystem.Colors.error : DesignSystem.Colors.border,
                                lineWidth: 2
                            )
                    }
                }
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(item.title)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(
                                viewModel.isItemChecked(item.id)
                                ? DesignSystem.Colors.textSecondary
                                : DesignSystem.Colors.textPrimary
                            )
                            .strikethrough(viewModel.isItemChecked(item.id))
                            .lineLimit(2)
                        
                        if item.isRequired {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.error)
                        }
                    }
                    
                    if let description = item.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Time estimate
                if let minutes = item.estimatedMinutes {
                    Text("\(minutes)m")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let dependencies = try! AppDependencies.makeForTesting()
    
    NavigationStack {
        ChecklistExecutionView(
            viewModel: ChecklistExecutionViewModel(
                libraryStore: dependencies.libraryStore,
                executionRepository: dependencies.executionRepository,
                charterID: UUID(),
                checklistID: UUID()
            )
        )
    }
    .environment(\.appDependencies, dependencies)
}

