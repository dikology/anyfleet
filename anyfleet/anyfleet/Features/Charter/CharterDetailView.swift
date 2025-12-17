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
                    } else if let error = viewModel.loadError {
                        Text(error)
                            .foregroundColor(DesignSystem.Colors.error)
                            .padding()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Charter")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
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
        .heroCardStyle(elevation: .medium)
    }
    
    private func checkInChecklistSection(for charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                "Check-In Checklist",
                subtitle: "Run this before guests arrive to make sure the boat is truly ready."
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
                            Text("Pre-arrival check-in")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("Walk through the checklist step-by-step before guests step aboard.")
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
                    Text("No check-in checklist yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Create a checklist of type “Check-In” in your Library and it will automatically appear here for this charter.")
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


