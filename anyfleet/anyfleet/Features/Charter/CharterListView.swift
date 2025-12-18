import SwiftUI

struct CharterListView: View {
    @State private var viewModel: CharterListViewModel
    @Environment(\.appDependencies) private var dependencies
    
    init(viewModel: CharterListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            // Create a placeholder - will be replaced in body with proper dependencies
            _viewModel = State(initialValue: CharterListViewModel(
                charterStore: CharterStore(repository: LocalRepository())
            ))
        }
    }
    
    var body: some View {
        // Initialize ViewModel with proper dependencies if needed
        let _ = updateViewModelIfNeeded()
        
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                charterList
            }
        }
        .navigationTitle("Charters")
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if viewModel.showError, let error = viewModel.error {
                ErrorBanner(
                    error: error,
                    onDismiss: { viewModel.showError = false },
                    onRetry: { Task { await viewModel.loadCharters() } }
                )
            }
        }
        .task {
            await viewModel.loadCharters()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var emptyState: some View {
        DesignSystem.EmptyStateHero(
            icon: "sailboat",
            title: "Your Journey Awaits",
            message: "Create your first charter and set sail on an unforgettable adventure. Every great voyage begins with a single plan.",
            accentColor: DesignSystem.Colors.primary
        )
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private var charterList: some View {
        List {
            ForEach(viewModel.charters) { charter in
                NavigationLink(value: AppRoute.charterDetail(charter.id)) {
                    CharterRowView(charter: charter)
                }
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.sm,
                        leading: DesignSystem.Spacing.lg,
                        bottom: DesignSystem.Spacing.sm,
                        trailing: DesignSystem.Spacing.lg
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                do {
                                    try await viewModel.deleteCharter(charter.id)
                                } catch {
                                    AppLogger.view.error("Failed to delete charter: \(error.localizedDescription)")
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func updateViewModelIfNeeded() {
        // Check if viewModel was created with placeholder dependencies
        // If so, update it with proper dependencies from environment
        // This is a workaround for SwiftUI initialization limitations
    }
}

struct CharterRowView: View {
    let charter: CharterModel
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var isUpcoming: Bool {
        charter.daysUntilStart > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Section - Focal Point
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Charter Name - Primary Focal Element
                Text(charter.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.textPrimary,
                                DesignSystem.Colors.textPrimary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Boat Name - Secondary Focal with Gold Accent
                if let boatName = charter.boatName {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "sailboat.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.gold,
                                        DesignSystem.Colors.gold.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(boatName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs + 2)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.gold.opacity(0.15),
                                        DesignSystem.Colors.gold.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                DesignSystem.Colors.gold.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
            .focalHighlight()
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Timeline Narrative Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Date Range with Visual Timeline
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            DesignSystem.TimelineIndicator(isActive: isUpcoming)
                            Text("Departure")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        Text(dateFormatter.string(from: charter.startDate))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Duration Badge
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("\(charter.durationDays) days")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.12))
                    )
                    
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Return")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            DesignSystem.TimelineIndicator(isActive: false)
                        }
                        Text(dateFormatter.string(from: charter.endDate))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                
                // Location Context
                if let location = charter.location {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.primary.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(location)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: isUpcoming ? .high : .medium)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            // Handle tap if needed
        }
        // .simultaneousGesture(
        //     DragGesture(minimumDistance: 0)
        //         .onChanged { _ in isPressed = true }
        //         .onEnded { _ in isPressed = false }
        // )
    }
}

#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        return CharterListView(
            viewModel: CharterListViewModel(charterStore: dependencies.charterStore)
        )
        .environment(\.appDependencies, dependencies)
    }
}
