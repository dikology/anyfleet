import SwiftUI

struct CharterListView: View {
    @State private var viewModel: CharterListViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    @State private var showPast = false

    @MainActor
    init(viewModel: CharterListViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            let deps = AppDependencies()
            _viewModel = State(initialValue: CharterListViewModel(
                charterStore: CharterStore(repository: LocalRepository()),
                coordinator: AppCoordinator(dependencies: deps)
            ))
        }
    }

    var body: some View {
        ZStack {
            Group {
                if viewModel.isLoading && viewModel.isEmpty {
                    skeletonList
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    charterList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.background.ignoresSafeArea())

            // Sync-pending banner
            if dependencies.charterSyncService.needsAuthForSync {
                VStack {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Sign in to sync your charters")
                            .font(DesignSystem.Typography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primary.opacity(0.12))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall))
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Error Banner
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                VStack {
                    Spacer()
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: { Task { await viewModel.loadCharters() } }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Charters)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            ToolbarItem(placement: .primaryAction) {
                createButton
            }
        }
        .task {
            await viewModel.loadCharters()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - States

    private var emptyState: some View {
        DesignSystem.EmptyStateView(
            icon: "sailboat",
            title: "No Charters Yet",
            message: "Create your first charter to start planning your sailing adventure. Track dates, vessels, and locations all in one place.",
            actionTitle: "Create Charter",
            action: { viewModel.onCreateCharterTapped() }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No charters. Create your first charter to start planning.")
    }

    private var skeletonList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    DesignSystem.CharterSkeletonRow()
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
    }

    private var charterList: some View {
        List {
            // UPCOMING SECTION
            if !viewModel.upcomingCharters.isEmpty {
                Section {
                    ForEach(viewModel.upcomingCharters.sorted { $0.startDate < $1.startDate }) { charter in
                        CharterTimelineRow(charter: charter) {
                            coordinator.viewCharter(charter.id)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: DesignSystem.Spacing.lg, bottom: 4, trailing: DesignSystem.Spacing.lg))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { try? await viewModel.deleteCharter(charter.id) }
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                coordinator.editCharter(charter.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.gray)
                        }
                    }
                } header: {
                    sectionLabel("Upcoming")
                }
            }

            // PAST SECTION — collapsed by default
            if !viewModel.pastCharters.isEmpty {
                Section {
                    if showPast {
                        ForEach(viewModel.pastCharters.sorted { $0.startDate > $1.startDate }) { charter in
                            CharterTimelineRow(charter: charter) {
                                coordinator.viewCharter(charter.id)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: DesignSystem.Spacing.lg, bottom: 4, trailing: DesignSystem.Spacing.lg))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { try? await viewModel.deleteCharter(charter.id) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.spring(response: 0.3)) { showPast.toggle() }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            sectionLabel("Past (\(viewModel.pastCharters.count))")
                            Spacer()
                            Image(systemName: showPast ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            DesignSystem.Gradients.subtleBackground
                .ignoresSafeArea()
        )
    }

    private var createButton: some View {
        Button {
            viewModel.onCreateCharterTapped()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.micro)
            .fontWeight(.semibold)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - CharterTimelineRow

struct CharterTimelineRow: View {
    let charter: CharterModel
    let onTap: () -> Void

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let returnFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                dateGutter
                    .frame(width: 48)
                compactCard
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details")
    }

    // MARK: - Date gutter

    private var dateGutter: some View {
        VStack(spacing: 2) {
            Text(Self.dayFormatter.string(from: charter.startDate))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(charter.isUpcoming
                    ? DesignSystem.Colors.textPrimary
                    : DesignSystem.Colors.textSecondary)
                .monospacedDigit()
            Text(Self.monthFormatter.string(from: charter.startDate).uppercased())
                .font(DesignSystem.Typography.micro)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .accessibilityHidden(true)
    }

    // MARK: - Card

    private var compactCard: some View {
        ZStack(alignment: .topLeading) {
            if charter.visibility != .private {
                RadialGradient(
                    colors: [charter.visibility.glowColor.opacity(0.22), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 130
                )
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius))
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                topRow
                nameRow
                metaRow
            }
            .padding(DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: charter.isUpcoming ? .medium : .low)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            DesignSystem.CharterVisibilityBadge(visibility: charter.visibility)
            Spacer()
            DesignSystem.SyncStatusBadge(status: charter.syncStatus)
        }
    }

    private var nameRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(charter.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
            if returnIsInDifferentMonth {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                    Text(Self.returnFormatter.string(from: charter.endDate))
                        .font(DesignSystem.Typography.micro)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("\(charter.durationDays)d")
                    .fontWeight(.semibold)
            }
            .font(DesignSystem.Typography.micro)
            .foregroundColor(DesignSystem.Colors.primary)

            if charter.boatName != nil || charter.location != nil {
                Text("·")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            if let boat = charter.boatName {
                Label(boat, systemImage: "sailboat.fill")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.vesselAccent)
                    .lineLimit(1)
            }

            if let location = charter.location {
                if charter.boatName != nil {
                    Text("·")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Label(location, systemImage: "mappin")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    private var returnIsInDifferentMonth: Bool {
        let cal = Calendar.current
        return cal.component(.month, from: charter.startDate)
            != cal.component(.month, from: charter.endDate)
    }

    private var accessibilityDescription: String {
        let day = Self.dayFormatter.string(from: charter.startDate)
        let month = Self.monthFormatter.string(from: charter.startDate)
        let vis = charter.visibility.displayName
        let sync = charter.syncStatus.label
        let dur = "\(charter.durationDays) days"
        return "\(charter.name). \(vis). \(sync). Starts \(day) \(month). \(dur)."
    }
}

// MARK: - Preview

#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        return CharterListView(
            viewModel: CharterListViewModel(charterStore: dependencies.charterStore, coordinator: coordinator)
        )
        .environment(\.appDependencies, dependencies)
    }
}
