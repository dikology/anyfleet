import SwiftUI

// MARK: - Stats Bar

/// Captain stats as a horizontal `DesignSystem.StatsRow` (icon + value + label per group).
/// Only stats with non-zero values are shown; the section disappears entirely for new users.
struct ProfileStatsBar: View {
    let stats: CaptainStats

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.SectionLabel(L10n.Profile.Stats.dashboardLabel)
                DesignSystem.StatsRow(items: items)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
        }
    }

    private var items: [DesignSystem.StatsRow.Item] {
        var result: [DesignSystem.StatsRow.Item] = []
        if stats.chartersCompleted > 0 {
            result.append(.init(id: "charters", systemImage: "sailboat.fill",
                value: "\(stats.chartersCompleted)",
                label: L10n.Profile.Stats.chartersCompleted, tint: DesignSystem.Colors.primary))
        }
        if stats.daysAtSea > 0 {
            result.append(.init(id: "days", systemImage: "sun.horizon.fill",
                value: "\(stats.daysAtSea)",
                label: L10n.Profile.Stats.daysAtSea, tint: DesignSystem.Colors.success))
        }
        if stats.communitiesJoined > 0 {
            result.append(.init(id: "communities", systemImage: "person.3.fill",
                value: "\(stats.communitiesJoined)",
                label: L10n.Profile.Stats.communitiesJoined, tint: DesignSystem.Colors.communityAccent))
        }
        if stats.contentPublished > 0 {
            result.append(.init(id: "content", systemImage: "doc.text.fill",
                value: "\(stats.contentPublished)",
                label: L10n.Profile.Stats.contentPublished, tint: DesignSystem.Colors.info))
        }
        return result
    }
}

// MARK: - Loading

/// Shimmer placeholder for `ProfileStatsBar` (section label + stats row).
struct ProfileStatsBarSkeleton: View {
    @State private var animating = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SkeletonBlock(width: 140, height: 12, animating: animating)
            DesignSystem.StatsRowSkeleton(groupCount: 4, animating: animating)
        }
        .onAppear {
            withAnimation(DesignSystem.Motion.skeleton) {
                animating = true
            }
        }
    }
}

// MARK: - Preview

#Preview("All stats") {
    ProfileStatsBar(stats: CaptainStats(
        chartersCompleted: 12,
        nauticalMiles: 0,
        daysAtSea: 34,
        communitiesJoined: 3,
        regionsVisited: 0,
        contentPublished: 8
    ))
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Partial stats") {
    ProfileStatsBar(stats: CaptainStats(
        chartersCompleted: 5,
        nauticalMiles: 0,
        daysAtSea: 0,
        communitiesJoined: 2,
        regionsVisited: 0,
        contentPublished: 0
    ))
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("New user — section hidden") {
    VStack {
        Text("No stats bar below (all zeros)")
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
        ProfileStatsBar(stats: CaptainStats(
            chartersCompleted: 0,
            nauticalMiles: 0,
            daysAtSea: 0,
            communitiesJoined: 0,
            regionsVisited: 0,
            contentPublished: 0
        ))
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
