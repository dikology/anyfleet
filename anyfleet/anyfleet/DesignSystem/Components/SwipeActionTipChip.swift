import SwiftUI

/// Compact chip labeling available list swipe actions; pairs with `swipeHint`.
struct SwipeActionTipChip: View {
    struct Action: Equatable {
        let icon: String
        let label: String
        let tint: Color
    }

    let actions: [Action]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "hand.point.left.fill")
                .font(DesignSystem.Typography.footnoteSemibold)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ForEach(actions.indices, id: \.self) { i in
                if i > 0 {
                    Text("·")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: actions[i].icon)
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(actions[i].tint)
                    Text(actions[i].label)
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text("Swipe")
                .font(DesignSystem.Typography.micro)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .glassPanel()
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("swipeOnboardingTipChip")
    }

    private var accessibilitySummary: String {
        let parts = actions.map { $0.label.lowercased() }
        return "Swipe actions available: " + parts.joined(separator: ", ")
    }
}
