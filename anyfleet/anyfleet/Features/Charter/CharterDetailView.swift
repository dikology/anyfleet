//
//  CharterDetailView.swift
//  anyfleet
//
//  Detail view for a single charter, including a placeholder for the
//  charter-scoped check-in checklist.
//

import SwiftUI

struct CharterDetailView: View {
    @State private var viewModel: CharterDetailViewModel
    
    init(viewModel: CharterDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let charter = viewModel.charter {
                        charterHeader(charter)
                        checkInChecklistSection(for: charter)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.Charter.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }

        // Error Banner
        if viewModel.showErrorBanner, let error = viewModel.currentError {
            VStack {
                Spacer()
                ErrorBanner(
                    error: error,
                    onDismiss: { viewModel.clearError() },
                    onRetry: { Task { await viewModel.load() } }
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Sections
    
    private func charterHeader(_ charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Title & boat
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(charter.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if let boatName = charter.boatName, !boatName.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "sailboat.fill")
                            .foregroundColor(DesignSystem.Colors.gold)
                        Text(boatName)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
            
            // Dates & location
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                FormSummaryRow(
                    icon: "📅",
                    title: "Dates",
                    value: "\(dateFormatter.string(from: charter.startDate)) – \(dateFormatter.string(from: charter.endDate))",
                    detail: "\(charter.durationDays) days"
                )
                
                if let location = charter.location, !location.isEmpty {
                    FormSummaryRow(
                        icon: "📍",
                        title: "Destination",
                        value: location,
                        detail: nil
                    )
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .heroCardStyle(elevation: .medium)
    }
    
    private func checkInChecklistSection(for charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                L10n.Charter.CheckInChecklist.title,
                subtitle: L10n.Charter.CheckInChecklist.subtitle
            )
            
            if let checklistID = viewModel.checkInChecklistID {
                NavigationLink(
                    value: AppRoute.checklistExecution(
                        charterID: charter.id,
                        checklistID: checklistID
                    )
                ) {
                    HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.primary.opacity(0.18),
                                            DesignSystem.Colors.primary.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: ChecklistType.checkIn.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(L10n.Charter.CheckInChecklist.Button.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(L10n.Charter.CheckInChecklist.Button.description)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(L10n.Charter.CheckInChecklist.Empty.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(L10n.Charter.CheckInChecklist.Empty.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceAlt)
                .cornerRadius(12)
            }
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
}

#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        
        return NavigationStack {
            CharterDetailView(
                viewModel: CharterDetailViewModel(
                    charterID: UUID(),
                    charterStore: dependencies.charterStore,
                    libraryStore: dependencies.libraryStore
                )
            )
        }
        .environment(\.appDependencies, dependencies)
    }
}


