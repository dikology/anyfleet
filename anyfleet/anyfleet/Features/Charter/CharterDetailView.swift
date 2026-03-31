//
//  CharterDetailView.swift
//  anyfleet
//
//  Redesigned charter detail screen — a full voyage experience with a hero
//  header, inline stats row, polished BubbleCard sections, and a state-aware
//  FloatingActionButton as the single primary action.
//

import SwiftUI

struct CharterDetailView: View {
    @State private var viewModel: CharterDetailViewModel
    @State private var detailSkeletonAnimating = false

    init(viewModel: CharterDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var charterDetailDisplayKey: String {
        if viewModel.charter != nil { "content" }
        else if viewModel.isLoading { "loading" }
        else { "empty" }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.oceanDeep.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let charter = viewModel.charter {
                ScrollView {
                    VStack(spacing: 0) {
                        voyageHero(charter)

                        VStack(spacing: DesignSystem.Spacing.md) {
                            detailsCard(charter)
                            checkInChecklistCard(for: charter)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                        .padding(.top, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xxxl)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    floatingActionButton(for: charter)
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.background.opacity(0),
                                    DesignSystem.Colors.background.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .transition(.opacity)
            } else if viewModel.isLoading {
                charterDetailLoadingPlaceholder
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: charterDetailDisplayKey)
        .navigationTitle(L10n.Charter.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .overlay(alignment: .bottom) {
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                ErrorBanner(
                    error: error,
                    onDismiss: { viewModel.clearError() },
                    onRetry: { Task { await viewModel.load() } }
                )
                .padding(.horizontal)
                .padding(.bottom, FloatingTabBar.safeAreaInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Motion.standard, value: viewModel.showErrorBanner)
    }
}

// MARK: - Loading skeleton

private extension CharterDetailView {
    var charterDetailLoadingPlaceholder: some View {
        ScrollView {
            VStack(spacing: 0) {
                charterDetailHeroSkeleton
                VStack(spacing: DesignSystem.Spacing.md) {
                    charterDetailDetailsSkeleton
                    charterDetailChecklistSkeleton
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxxl)
            }
        }
        .onAppear {
            withAnimation(DesignSystem.Motion.skeleton) {
                detailSkeletonAnimating = true
            }
        }
    }

    var charterDetailHeroSkeleton: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Gradients.focalGoldRadial
                .frame(maxWidth: .infinity)
                .frame(height: 210)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Spacer()
                DesignSystem.SkeletonBlock(width: 52, height: 52, animating: detailSkeletonAnimating)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius))
                DesignSystem.SkeletonBlock(width: 72, height: 18, animating: detailSkeletonAnimating)
                DesignSystem.SkeletonBlock(width: 200, height: 28, animating: detailSkeletonAnimating)
                DesignSystem.SkeletonBlock(width: 120, height: 14, animating: detailSkeletonAnimating)
                DesignSystem.CharterDetailStatsRowSkeleton(animating: detailSkeletonAnimating)
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }

    var charterDetailDetailsSkeleton: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.SkeletonBlock(width: 100, height: 11, animating: detailSkeletonAnimating)
                DesignSystem.SkeletonBlock(height: 36, animating: detailSkeletonAnimating)
                DesignSystem.SkeletonBlock(height: 36, animating: detailSkeletonAnimating)
            }
        }
    }

    var charterDetailChecklistSkeleton: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.SkeletonBlock(width: 160, height: 11, animating: detailSkeletonAnimating)
                DesignSystem.SkeletonBlock(height: 56, animating: detailSkeletonAnimating)
            }
        }
    }
}

// MARK: - Hero Header

private extension CharterDetailView {

    func voyageHero(_ charter: CharterModel) -> some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Gradients.focalGoldRadial
                .frame(maxWidth: .infinity)
                .frame(height: 210)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Spacer()

                // Sailboat icon well
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                        .fill(DesignSystem.Colors.surface.opacity(0.5))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                                .stroke(DesignSystem.Colors.gold.opacity(0.3), lineWidth: 1)
                        )
                    Image(systemName: "sailboat.fill")
                        .font(DesignSystem.Typography.leadBold)
                        .foregroundColor(DesignSystem.Colors.gold)
                }

                // Status pill
                charterStatusPill(charter)

                // Charter name — Onder for emotional weight
                Text(charter.name)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)

                // Vessel
                if let boatName = charter.boatName, !boatName.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "helm")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.gold.opacity(0.7))
                        Text(boatName)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                // Stats row floats at the bottom of the hero
                statsRow(charter)
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }

    func charterStatusPill(_ charter: CharterModel) -> some View {
        let (label, color) = charterStatus(charter)
        return Text(label)
            .font(DesignSystem.Typography.microBold)
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
    }

    /// Returns a display label and accent color for the charter's lifecycle state.
    func charterStatus(_ charter: CharterModel) -> (String, Color) {
        let now = Date()
        if charter.endDate < now {
            return (L10n.Charter.Detail.Status.completed, DesignSystem.Colors.success)
        } else if charter.startDate <= now {
            return (L10n.Charter.Detail.Status.active, DesignSystem.Colors.gold)
        } else {
            return (L10n.Charter.Detail.Status.upcoming, DesignSystem.Colors.primary)
        }
    }
}

// MARK: - Stats Row

private extension CharterDetailView {

    func statsRow(_ charter: CharterModel) -> some View {
        let now = Date()
        let isActive = charter.startDate <= now && charter.endDate >= now
        let isCompleted = charter.endDate < now
        let hasLocation = !(charter.location ?? "").isEmpty

        return HStack(spacing: 0) {
            // Stat 1: Time context
            if isCompleted {
                statItem(
                    icon: "checkmark.circle.fill",
                    tint: DesignSystem.Colors.success,
                    value: L10n.Charter.Detail.Stats.done,
                    label: L10n.Charter.Detail.Stats.voyage
                )
            } else if isActive {
                let dayIn = (Calendar.current.dateComponents([.day], from: charter.startDate, to: now).day ?? 0) + 1
                statItem(
                    icon: "location.fill",
                    tint: DesignSystem.Colors.gold,
                    value: L10n.Charter.Detail.Stats.dayNumber(dayIn),
                    label: L10n.Charter.Detail.Stats.ofDays(charter.durationDays)
                )
            } else {
                let days = charter.daysUntilStart
                statItem(
                    icon: "calendar.badge.clock",
                    tint: DesignSystem.Colors.primary,
                    value: days > 0 ? "\(days)" : L10n.Charter.Detail.Stats.today,
                    label: days > 0 ? L10n.Charter.Detail.Stats.daysAway : L10n.Charter.Detail.Stats.departure
                )
            }

            statPipe()

            // Stat 2: Duration
            statItem(
                icon: "clock.fill",
                tint: DesignSystem.Colors.primary,
                value: "\(charter.durationDays)",
                label: charter.durationDays == 1 ? L10n.Charter.Detail.Stats.day : L10n.Charter.Detail.Stats.days
            )

            // Stat 3: Destination (if present)
            if hasLocation, let location = charter.location {
                statPipe()
                statItem(
                    icon: "mappin.circle.fill",
                    tint: DesignSystem.Colors.warning,
                    value: location,
                    label: L10n.Charter.Detail.Stats.destination,
                    valueLineLimit: 1
                )
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    func statItem(
        icon: String,
        tint: Color,
        value: String,
        label: String,
        valueLineLimit: Int? = nil
    ) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(valueLineLimit)
                Text(label)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func statPipe() -> some View {
        Rectangle()
            .fill(DesignSystem.Colors.border)
            .frame(width: 1, height: 28)
            .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

// MARK: - Details BubbleCard

private extension CharterDetailView {

    func detailsCard(_ charter: CharterModel) -> some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.FieldLabelMicro(title: L10n.Charter.Detail.voyageSectionLabel)

                // Dates row
                detailRow(
                    systemImage: "calendar.circle.fill",
                    tint: DesignSystem.Colors.primary,
                    title: L10n.Charter.Detail.rowDates,
                    value: "\(dateFormatter.string(from: charter.startDate)) – \(dateFormatter.string(from: charter.endDate))",
                    badge: L10n.Charter.Detail.durationBadge(days: charter.durationDays)
                )

                // Location row
                if let location = charter.location, !location.isEmpty {
                    Divider()
                        .background(DesignSystem.Colors.border.opacity(0.5))

                    detailRow(
                        systemImage: "mappin.circle.fill",
                        tint: DesignSystem.Colors.warning,
                        title: L10n.Charter.Detail.rowDestination,
                        value: location,
                        badge: nil
                    )
                }
            }
        }
    }

    func detailRow(
        systemImage: String,
        tint: Color,
        title: String,
        value: String,
        badge: String?
    ) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title.uppercased())
                    .font(DesignSystem.Typography.micro)
                    .tracking(0.6)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(value)
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundColor(DesignSystem.Colors.gold)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.gold.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DesignSystem.Colors.gold.opacity(0.20), lineWidth: 1))
            }
        }
    }
}

// MARK: - Check-in Checklist Card

private extension CharterDetailView {

    func checkInChecklistCard(for charter: CharterModel) -> some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.FieldLabelMicro(title: L10n.Charter.CheckInChecklist.title)

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
                                                DesignSystem.Colors.primary.opacity(0.20),
                                                DesignSystem.Colors.primary.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                Image(systemName: ChecklistType.checkIn.icon)
                                    .font(DesignSystem.Typography.title)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(L10n.Charter.CheckInChecklist.Button.title)
                                    .font(DesignSystem.Typography.subheader)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text(L10n.Charter.CheckInChecklist.Button.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(DesignSystem.Typography.captionSemibold)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.border.opacity(0.6))
                                .frame(width: 40, height: 40)
                            Image(systemName: "checklist")
                                .font(DesignSystem.Typography.subheader)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(L10n.Charter.CheckInChecklist.Empty.title)
                                .font(DesignSystem.Typography.subheader)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(L10n.Charter.CheckInChecklist.Empty.description)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Floating Action Button

private extension CharterDetailView {

    /// The single primary action varies by charter lifecycle state.
    @ViewBuilder
    func floatingActionButton(for charter: CharterModel) -> some View {
        let now = Date()
        let isActive = charter.startDate <= now && charter.endDate >= now
        let isCompleted = charter.endDate < now

        if isCompleted {
            // Completed — ghost pill, no gradient pressure
            Button { } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "book.pages.fill")
                    Text(L10n.Charter.Detail.FAB.viewVoyageLog)
                        .font(DesignSystem.Typography.subheader)
                }
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1))
                .shadow(
                    color: DesignSystem.Colors.shadowStrong.opacity(0.12),
                    radius: 12, y: 4
                )
            }
            .buttonStyle(.plain)
        } else if isActive, let checklistID = viewModel.checkInChecklistID {
            NavigationLink(
                value: AppRoute.checklistExecution(
                    charterID: charter.id,
                    checklistID: checklistID
                )
            ) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checklist")
                    Text(L10n.Charter.Detail.FAB.openChecklist)
                        .font(DesignSystem.Typography.subheader)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignSystem.Gradients.primaryButton)
                .clipShape(Capsule())
                .shadow(
                    color: DesignSystem.Colors.primary.opacity(0.35),
                    radius: 12, y: 4
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: AppRoute.editCharter(charter.id)) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "pencil")
                    Text(L10n.Charter.Detail.FAB.editCharter)
                        .font(DesignSystem.Typography.subheader)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignSystem.Gradients.primaryButton)
                .clipShape(Capsule())
                .shadow(
                    color: DesignSystem.Colors.primary.opacity(0.35),
                    radius: 12, y: 4
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Previews

/// Seeds `CharterStore` via the real repository so `CharterDetailViewModel.load()` succeeds.
private struct CharterDetailPreviewHost: View {
    enum Scenario: String {
        case upcoming
        case active
        case completed
    }

    let scenario: Scenario

    @State private var viewModel: CharterDetailViewModel?
    @State private var dependencies: AppDependencies?

    var body: some View {
        Group {
            if let viewModel, let dependencies {
                NavigationStack {
                    CharterDetailView(viewModel: viewModel)
                }
                .environment(\.appDependencies, dependencies)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await seed()
        }
    }

    @MainActor
    private func seed() async {
        let deps = try! AppDependencies.makeForTesting()
        let calendar = Calendar.current
        let now = Date()
        let start: Date
        let end: Date
        switch scenario {
        case .upcoming:
            start = calendar.date(byAdding: .day, value: 12, to: now)!
            end = calendar.date(byAdding: .day, value: 19, to: now)!
        case .active:
            start = calendar.date(byAdding: .day, value: -2, to: now)!
            end = calendar.date(byAdding: .day, value: 5, to: now)!
        case .completed:
            start = calendar.date(byAdding: .day, value: -30, to: now)!
            end = calendar.date(byAdding: .day, value: -23, to: now)!
        }

        let charter = try! await deps.charterStore.createCharter(
            name: "Aegean Spring",
            boatName: "SV Horizon",
            location: "Paros, Greece",
            latitude: 37.0853,
            longitude: 25.1484,
            startDate: start,
            endDate: end
        )

        dependencies = deps
        viewModel = CharterDetailViewModel(
            charterID: charter.id,
            charterStore: deps.charterStore,
            libraryStore: deps.libraryStore
        )
    }
}

#Preview("Upcoming") {
    MainActor.assumeIsolated {
        CharterDetailPreviewHost(scenario: .upcoming)
    }
}

#Preview("Active") {
    MainActor.assumeIsolated {
        CharterDetailPreviewHost(scenario: .active)
    }
}

#Preview("Completed") {
    MainActor.assumeIsolated {
        CharterDetailPreviewHost(scenario: .completed)
    }
}
