import SwiftUI

extension DesignSystem {
    /// Horizontal stat groups: SF Symbol + bold value + caption label, pipe-separated (design system spec).
    struct StatsRow: View {
        struct Item: Identifiable {
            let id: String
            let systemImage: String
            let value: String
            let label: String
            let tint: Color
        }

        let items: [Item]

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Text("|")
                                .font(Typography.caption)
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal, Spacing.sm)
                        }
                        statGroup(item)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }

        private func statGroup(_ item: Item) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(item.tint)
                Text(item.value)
                    .font(Typography.subheader)
                    .foregroundColor(Colors.textPrimary)
                Text(item.label)
                    .font(Typography.caption)
                    .foregroundColor(Colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Stats row") {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
        DesignSystem.SectionLabel("Dashboard")
        DesignSystem.StatsRow(items: [
            .init(id: "a", systemImage: "sailboat", value: "12", label: "Charters", tint: DesignSystem.Colors.primary),
            .init(id: "b", systemImage: "map", value: "—", label: "Miles", tint: DesignSystem.Colors.info),
            .init(id: "c", systemImage: "sun.horizon", value: "34", label: "Days at sea", tint: DesignSystem.Colors.success),
            .init(id: "d", systemImage: "person.3", value: "2", label: "Communities", tint: DesignSystem.Colors.communityAccent)
        ])
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
