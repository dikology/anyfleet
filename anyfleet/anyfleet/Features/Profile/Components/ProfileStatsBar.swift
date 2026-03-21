import SwiftUI

// MARK: - Stats Bar

/// Captain stats as a horizontal `DesignSystem.StatsRow` (icon + value + label per group).
struct ProfileStatsBar: View {
    let stats: CaptainStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionLabel(L10n.Profile.Stats.dashboardLabel)
            DesignSystem.StatsRow(items: items)
        }
    }

    private var items: [DesignSystem.StatsRow.Item] {
        [
            .init(
                id: "charters",
                systemImage: "sailboat.fill",
                value: "\(stats.chartersCompleted)",
                label: singleLine(L10n.Profile.Stats.chartersCompleted),
                tint: DesignSystem.Colors.primary
            ),
            .init(
                id: "miles",
                systemImage: "map",
                value: "—",
                label: singleLine(L10n.Profile.Stats.nauticalMiles),
                tint: DesignSystem.Colors.info
            ),
            .init(
                id: "days",
                systemImage: "sun.horizon.fill",
                value: "\(stats.daysAtSea)",
                label: singleLine(L10n.Profile.Stats.daysAtSea),
                tint: DesignSystem.Colors.success
            ),
            .init(
                id: "communities",
                systemImage: "person.3.fill",
                value: "\(stats.communitiesJoined)",
                label: singleLine(L10n.Profile.Stats.communitiesJoined),
                tint: DesignSystem.Colors.communityAccent
            )
        ]
    }

    private func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}

// MARK: - Preview

#Preview("With data") {
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

#Preview("Zeros") {
    ProfileStatsBar(stats: CaptainStats(
        chartersCompleted: 0,
        nauticalMiles: 0,
        daysAtSea: 0,
        communitiesJoined: 0,
        regionsVisited: 0,
        contentPublished: 0
    ))
    .padding()
    .background(DesignSystem.Colors.background)
}
