import SwiftUI

struct CharterListView: View {
    @State private var viewModel: CharterListViewModel
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.appCoordinator) private var coordinator

    @State private var showPast = false
    @State private var charterPendingDelete: CharterModel?

    @AppStorage("hasSeenCharterSwipeHint") private var hasSeenCharterSwipeHint = false
    @State private var playSwipeHint = false
    @State private var showSwipeTip = false

    @MainActor
    init(viewModel: CharterListViewModel) {
        _viewModel = State(initialValue: viewModel)
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
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                        Text(L10n.Charter.List.signInToSyncBanner)
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
            HapticEngine.impact(.light)
            await viewModel.refresh()
        }
        .sheet(item: $charterPendingDelete) { charter in
            CharterDeleteModal(
                charterName: charter.name,
                canUnpublish: dependencies.isAuthenticated && charter.serverID != nil,
                onUnpublishAndDelete: {
                    charterPendingDelete = nil
                    Task { try? await viewModel.deleteCharter(charter.id) }
                },
                onDeleteLocalOnly: {
                    charterPendingDelete = nil
                    Task {
                        try? await viewModel.deleteCharter(charter.id, unpublishFromDiscoveryIfNeeded: false)
                    }
                },
                onCancel: { charterPendingDelete = nil }
            )
        }
        .animation(DesignSystem.Motion.standard, value: charterPendingDelete?.id)
    }

    // MARK: - States

    private var emptyState: some View {
        DesignSystem.EmptyStateView(
            icon: "sailboat",
            title: L10n.Charter.List.EmptyState.title,
            message: L10n.Charter.List.EmptyState.message,
            actionTitle: L10n.Charter.List.EmptyState.action,
            action: { viewModel.onCreateCharterTapped() }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Charter.List.EmptyState.accessibilityLabel)
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

    private var sortedUpcomingCharters: [CharterModel] {
        viewModel.upcomingCharters.sorted { $0.startDate < $1.startDate }
    }

    private var charterSwipeTipActions: [SwipeActionTipChip.Action] {
        [
            .init(icon: "pencil", label: L10n.Charter.List.actionEdit, tint: .gray),
            .init(icon: "trash", label: L10n.Charter.List.actionDelete, tint: DesignSystem.Colors.error)
        ]
    }

    private var charterList: some View {
        List {
            // UPCOMING SECTION
            if !viewModel.upcomingCharters.isEmpty {
                Section {
                    ForEach(sortedUpcomingCharters) { charter in
                        CharterTimelineRow(charter: charter) {
                            coordinator.viewCharter(charter.id)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: DesignSystem.Spacing.lg, bottom: 4, trailing: DesignSystem.Spacing.lg))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeHint(isPlaying: Binding(
                            get: { playSwipeHint && charter.id == sortedUpcomingCharters.first?.id },
                            set: { playSwipeHint = $0 }
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Use role: .destructive only when deletion is immediate.
                            // For non-private charters a confirmation modal is shown first;
                            // using .destructive there causes SwiftUI to animate the row away
                            // before any data change, making the charter vanish on cancel.
                            if charter.visibility != .private {
                                Button {
                                    HapticEngine.impact(.light)
                                    charterPendingDelete = charter
                                } label: { Label(L10n.Charter.List.actionDelete, systemImage: "trash") }
                                .tint(.red)
                            } else {
                                Button(role: .destructive) {
                                    HapticEngine.impact(.light)
                                    Task { try? await viewModel.deleteCharter(charter.id) }
                                } label: { Label(L10n.Charter.List.actionDelete, systemImage: "trash") }
                            }

                            Button {
                                HapticEngine.impact(.light)
                                coordinator.editCharter(charter.id)
                            } label: {
                                Label(L10n.Charter.List.actionEdit, systemImage: "pencil")
                            }
                            .tint(.gray)
                        }
                    }
                } header: {
                    upcomingSectionHeader
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
                                if charter.visibility != .private {
                                    Button {
                                        HapticEngine.impact(.light)
                                        charterPendingDelete = charter
                                    } label: { Label(L10n.Charter.List.actionDelete, systemImage: "trash") }
                                    .tint(.red)
                                } else {
                                    Button(role: .destructive) {
                                        HapticEngine.impact(.light)
                                        Task { try? await viewModel.deleteCharter(charter.id) }
                                    } label: { Label(L10n.Charter.List.actionDelete, systemImage: "trash") }
                                }

                                Button {
                                    HapticEngine.impact(.light)
                                    coordinator.editCharter(charter.id)
                                } label: {
                                    Label(L10n.Charter.List.actionEdit, systemImage: "pencil")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(DesignSystem.Motion.spring) { showPast.toggle() }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            sectionLabel(L10n.Charter.List.sectionPastWithCount(viewModel.pastCharters.count))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(DesignSystem.Typography.micro)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .rotationEffect(.degrees(showPast ? 90 : 0))
                                .animation(DesignSystem.Motion.spring, value: showPast)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(showPast ? "Collapse past charters" : "Expand past charters")
                }
                .animation(DesignSystem.Motion.spring, value: showPast)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            DesignSystem.Gradients.subtleBackground
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            if showSwipeTip {
                SwipeActionTipChip(actions: charterSwipeTipActions)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Motion.standard, value: showSwipeTip)
        .task(id: viewModel.upcomingCharters.isEmpty) {
            await runCharterSwipeOnboardingIfNeeded()
        }
    }

    private func runCharterSwipeOnboardingIfNeeded() async {
        guard !viewModel.upcomingCharters.isEmpty, !hasSeenCharterSwipeHint else { return }
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showSwipeTip = true }
        playSwipeHint = true
        try? await Task.sleep(for: .seconds(2.5))
        guard !Task.isCancelled else { return }
        withAnimation(DesignSystem.Motion.standard) { showSwipeTip = false }
        playSwipeHint = false
        hasSeenCharterSwipeHint = true
    }

    private var createButton: some View {
        Button {
            viewModel.onCreateCharterTapped()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(DesignSystem.Typography.insetHeadline)
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }

    // MARK: - Section label

    private var upcomingSectionHeader: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "sailboat.fill")
                .font(DesignSystem.Typography.micro)
                .foregroundColor(DesignSystem.Colors.primary)
            sectionLabel(L10n.Charter.List.sectionUpcoming)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.primary.opacity(0.06))
        )
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

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
                .font(DesignSystem.Typography.dateDisplay)
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
                .font(DesignSystem.Typography.subheader)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
            if returnIsInDifferentMonth {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.right")
                        .font(DesignSystem.Typography.nano)
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
                    .font(DesignSystem.Typography.nano)
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
        let deps = try! AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: deps)
        return CharterListView(
            viewModel: CharterListViewModel(charterStore: deps.charterStore, coordinator: coordinator)
        )
        .environment(\.appDependencies, deps)
        .environment(\.appCoordinator, coordinator)
    }
}
