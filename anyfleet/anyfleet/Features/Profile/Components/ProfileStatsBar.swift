import SwiftUI

// MARK: - Stats Bar

/// 4-circle stats row matching the captain profile reference UI.
/// Phase-3 stats (nauticalMiles, regionsVisited) render as "—" placeholders.
struct ProfileStatsBar: View {
    let stats: CaptainStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionLabel(L10n.Profile.Stats.dashboardLabel)
            HStack(spacing: DesignSystem.Spacing.sm) {
                StatCircle(
                value: "\(stats.chartersCompleted)",
                label: L10n.Profile.Stats.chartersCompleted,
                color: DesignSystem.Colors.primary,
                progress: progressCapped(stats.chartersCompleted, max: 50),
                isPlaceholder: false
            )
            StatCircle(
                value: "—",
                label: L10n.Profile.Stats.nauticalMiles,
                color: DesignSystem.Colors.info,
                progress: 0,
                isPlaceholder: true
            )
            StatCircle(
                value: "\(stats.daysAtSea)",
                label: L10n.Profile.Stats.daysAtSea,
                color: DesignSystem.Colors.success,
                progress: progressCapped(stats.daysAtSea, max: 100),
                isPlaceholder: false
            )
            StatCircle(
                value: "\(stats.communitiesJoined)",
                label: L10n.Profile.Stats.communitiesJoined,
                color: DesignSystem.Colors.communityAccent,
                progress: progressCapped(stats.communitiesJoined, max: 10),
                isPlaceholder: false
            )
            }
        }
    }

    private func progressCapped(_ value: Int, max: Int) -> Double {
        min(Double(value) / Double(max), 1.0)
    }
}

// MARK: - Stat Circle

struct StatCircle: View {
    let value: String
    let label: String
    let color: Color
    let progress: Double
    let isPlaceholder: Bool

    private let circleSize: CGFloat = 68
    private let lineWidth: CGFloat = 5

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: lineWidth)
                    .frame(width: circleSize, height: circleSize)

                // Progress ring
                if !isPlaceholder {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: progress)
                }

                // Value label
                Text(value)
                    .font(.system(size: isPlaceholder ? 18 : 17, weight: .bold, design: .rounded))
                    .foregroundColor(isPlaceholder ? DesignSystem.Colors.textSecondary : color)
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ProfileStatsBar(stats: CaptainStats(
        chartersCompleted: 12,
        nauticalMiles: 0,
        daysAtSea: 34,
        communitiesJoined: 3,
        regionsVisited: 0,
        contentPublished: 8
    ))
    .padding()
}
