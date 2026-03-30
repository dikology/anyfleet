import SwiftUI

/// Floating pill tab bar with a branded bubble that pops above the bar for the active tab.
/// Replaces the native UIKit tab bar; driven by the same `AppView.Tab` enum.
struct FloatingTabBar: View {
    @Binding var selectedTab: AppView.Tab
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout constants

    private enum Layout {
        static let barHeight: CGFloat = 60
        static let bubbleSize: CGFloat = 52
        /// How far the active bubble protrudes above the bar's top edge.
        static let bubbleOverhang: CGFloat = bubbleSize / 2 + 2   // 28 pt
        static let totalHeight: CGFloat = barHeight + bubbleOverhang // 88 pt
        static let cornerRadius: CGFloat = barHeight / 2            // full pill
    }

    // MARK: - Tab definitions

    private struct ItemInfo: Identifiable {
        let id: AppView.Tab
        let icon: String
        let label: String
    }

    private let items: [ItemInfo] = [
        ItemInfo(id: .home,     icon: "house.fill",    label: L10n.Home),
        ItemInfo(id: .charters, icon: "sailboat.fill", label: L10n.Charters),
        ItemInfo(id: .library,  icon: "book.fill",     label: L10n.Library.myLibrary),
        ItemInfo(id: .discover, icon: "globe",         label: L10n.Discover),
        ItemInfo(id: .profile,  icon: "person.fill",   label: L10n.ProfileTab),
    ]

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    guard selectedTab != item.id else { return }
                    HapticEngine.selection()
                    withAnimation(DesignSystem.Motion.spring) {
                        selectedTab = item.id
                    }
                } label: {
                    itemView(item)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(selectedTab == item.id ? [.isSelected] : [])
            }
        }
        .frame(height: Layout.totalHeight)
        // Bar pill sits at the bottom of the total-height frame so the bubble overflows above.
        .background(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(barFill)
                .frame(height: Layout.barHeight)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.45 : 0.13),
                    radius: colorScheme == .dark ? 18 : 24,
                    x: 0,
                    y: colorScheme == .dark ? 6 : 10
                )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Bar background

    private var barFill: AnyShapeStyle {
        if colorScheme == .dark {
            // Slightly darker + more opaque than surface so it reads as distinct chrome
            return AnyShapeStyle(
                Color(UIColor(red: 0.11, green: 0.14, blue: 0.16, alpha: 0.97))
            )
        } else {
            return AnyShapeStyle(.regularMaterial)
        }
    }

    // MARK: - Tab item

    @ViewBuilder
    private func itemView(_ item: ItemInfo) -> some View {
        let isActive = selectedTab == item.id

        ZStack {
            // ── Inactive state ────────────────────────────────────────────
            // Icon + label centered vertically inside the bar area
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(item.label)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(height: Layout.totalHeight)
            // Offset icon+label downward so they sit in the bar, not above it
            .padding(.top, Layout.bubbleOverhang + 10)
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? 0.85 : 1, anchor: .center)

            // ── Active state ──────────────────────────────────────────────
            // Bubble pops above the bar; label stays inside
            VStack(spacing: 0) {
                // Gradient circle — partially above the bar top edge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.oceanDeep,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: DesignSystem.Colors.primary.opacity(0.5),
                            radius: 10, x: 0, y: 4
                        )

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: Layout.bubbleSize, height: Layout.bubbleSize)

                // Flexible gap between bubble bottom and label
                Spacer(minLength: 0)

                Text(item.label)
                    .font(DesignSystem.Typography.microBold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .frame(height: Layout.totalHeight)
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.7, anchor: .top)
        }
        .animation(DesignSystem.Motion.spring, value: isActive)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("Floating Tab Bar") {
    struct PreviewWrapper: View {
        @State private var tab: AppView.Tab = .home

        var body: some View {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [DesignSystem.Colors.background, DesignSystem.Colors.oceanDeep.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                FloatingTabBar(selectedTab: $tab)
                    .padding(.bottom, 20)
            }
        }
    }
    return PreviewWrapper()
}
