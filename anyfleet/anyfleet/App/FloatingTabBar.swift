import SwiftUI

// MARK: - Shape

/// Bar background with an organic notch cut out for the active tab bubble.
/// The bar and the bubble are the same fill color, forming one connected piece.
/// `activePosition` (0…tabCount-1, CGFloat) is animatable so the notch slides smoothly.
private struct TabBarShape: Shape {

    // MARK: Layout constants

    /// Total component height (bar + the portion of the bubble above the bar top).
    static let totalHeight: CGFloat = 84
    /// Y of the bar's top edge within the component frame.
    static let barTopY: CGFloat = 26
    /// Depth of the notch below the bar top (= circle radius, so the curve wraps the circle bottom).
    static let notchDepth: CGFloat = 24

    var activePosition: CGFloat   // 0…(tabCount-1)
    let tabCount: Int

    // Animatable so SwiftUI interpolates the notch position between tab taps.
    var animatableData: CGFloat {
        get { activePosition }
        set { activePosition = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w   = rect.width
        let bt  = Self.barTopY
        let dep = Self.notchDepth
        let h   = Self.totalHeight

        // Notch half-width scales with bar width, derived from the SVG reference proportions.
        let hW  = 46.0 / 393.0 * w

        // Active tab center X
        let cx  = w / CGFloat(tabCount) * (activePosition + 0.5)
        let cL  = cx - hW
        let cR  = cx + hW

        // Cubic bezier control-point offsets (normalised from SVG reference).
        // Each offset is relative to (cx, bt).
        let c1x = 0.8079 * hW
        let c2x = 0.6595 * hW; let c2y = 0.255  * dep
        let p1x = 0.5617 * hW; let p1y = 0.5083 * dep
        let c3x = 0.4482 * hW; let c3y = 0.8027 * dep
        let c4x = 0.2391 * hW

        var p = Path()

        // ── Top-left — flat, no corner arc ───────────────────────────────
        // The view uses .clipped(), so any path overflow (edge tabs where
        // cL < 0 or cR > w) is clipped cleanly without needing special cases.
        p.move(to: CGPoint(x: 0, y: bt))

        // ── Top edge to notch left ───────────────────────────────────────
        p.addLine(to: CGPoint(x: cL, y: bt))

        // ── Notch left descent ───────────────────────────────────────────
        p.addCurve(
            to:       CGPoint(x: cx - p1x, y: bt + p1y),
            control1: CGPoint(x: cx - c1x, y: bt),
            control2: CGPoint(x: cx - c2x, y: bt + c2y)
        )
        p.addCurve(
            to:       CGPoint(x: cx, y: bt + dep),
            control1: CGPoint(x: cx - c3x, y: bt + c3y),
            control2: CGPoint(x: cx - c4x, y: bt + dep)
        )

        // ── Notch right ascent (mirror) ───────────────────────────────────
        p.addCurve(
            to:       CGPoint(x: cx + p1x, y: bt + p1y),
            control1: CGPoint(x: cx + c4x, y: bt + dep),
            control2: CGPoint(x: cx + c3x, y: bt + c3y)
        )
        p.addCurve(
            to:       CGPoint(x: cR, y: bt),
            control1: CGPoint(x: cx + c2x, y: bt + c2y),
            control2: CGPoint(x: cx + c1x, y: bt)
        )

        // ── Top-right — flat, no corner arc ──────────────────────────────
        p.addLine(to: CGPoint(x: w, y: bt))

        // ── Right edge straight down — no bottom corner arc ──────────────
        p.addLine(to: CGPoint(x: w, y: h))

        // ── Bottom edge ──────────────────────────────────────────────────
        p.addLine(to: CGPoint(x: 0, y: h))

        // ── Left edge up to start ─────────────────────────────────────────
        p.addLine(to: CGPoint(x: 0, y: bt))
        p.closeSubpath()
        return p
    }
}

// MARK: - View

struct FloatingTabBar: View {

    /// Total bottom safe-area inset the floating bar occupies above the home indicator.
    /// Used by AppView to set UITabBarController.additionalSafeAreaInsets.bottom.
    static let safeAreaInset: CGFloat = TabBarShape.totalHeight + 8  // 84 + 8 = 92

    @Binding var selectedTab: AppView.Tab
    @Environment(\.colorScheme) private var colorScheme

    /// Animated continuous position (0…tabCount-1) drives the notch location.
    @State private var animatedPosition: CGFloat = 0

    // MARK: Tab definitions

    private struct TabInfo: Identifiable {
        let id: AppView.Tab
        let icon: String
        let label: String
    }

    private let items: [TabInfo] = [
        TabInfo(id: .home,     icon: "house.fill",    label: L10n.Home),
        TabInfo(id: .charters, icon: "sailboat.fill", label: L10n.Charters),
        TabInfo(id: .library,  icon: "book.fill",     label: L10n.Library.myLibrary),
        TabInfo(id: .discover, icon: "globe",         label: L10n.Discover),
        TabInfo(id: .profile,  icon: "person.fill",   label: L10n.ProfileTab),
    ]

    // MARK: Colors

    /// Bar + active bubble color — both use the same fill so they read as one shape.
    private var barColor: Color {
        colorScheme == .dark
            ? Color(UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1))   // #111111
            : Color(UIColor.secondarySystemGroupedBackground)
    }

    /// Icon / label color for the active (highlighted) tab.
    private var activeAccentColor: Color {
        colorScheme == .dark
            ? Color(UIColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1))  // #EDEDED
            : DesignSystem.Colors.primary
    }

    /// Icon / label color for inactive tabs.
    private var inactiveColor: Color {
        colorScheme == .dark
            ? Color(UIColor(red: 0.392, green: 0.392, blue: 0.392, alpha: 1))  // #646464
            : DesignSystem.Colors.textSecondary
    }

    // MARK: Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                let isActive = selectedTab == item.id
                Button {
                    guard selectedTab != item.id else { return }
                    HapticEngine.selection()
                    withAnimation(DesignSystem.Motion.spring) {
                        selectedTab = item.id
                        animatedPosition = CGFloat(idx)
                    }
                } label: {
                    tabItemView(item: item, isActive: isActive)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .frame(height: TabBarShape.totalHeight)
        .background {
            TabBarShape(activePosition: animatedPosition, tabCount: items.count)
                .fill(barColor)
        }
        .clipped()
        .onAppear {
            if let idx = items.firstIndex(where: { $0.id == selectedTab }) {
                animatedPosition = CGFloat(idx)
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if let idx = items.firstIndex(where: { $0.id == newTab }) {
                withAnimation(DesignSystem.Motion.spring) {
                    animatedPosition = CGFloat(idx)
                }
            }
        }
    }

    // MARK: Tab item

    @ViewBuilder
    private func tabItemView(item: TabInfo, isActive: Bool) -> some View {
        // The total item frame matches the bar shape height exactly so layout
        // coordinates align with the shape geometry.
        let circleSize: CGFloat = 48
        let barTop = TabBarShape.barTopY

        ZStack {
            // ── Inactive state ────────────────────────────────────────────
            // Icon + label centered inside the visible bar area.
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(inactiveColor)
                Text(item.label)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(inactiveColor)
                    .lineLimit(1)
            }
            // Push icon+label into the bar (below barTopY) so they don't overlap the bubble zone.
            .frame(height: TabBarShape.totalHeight)
            .padding(.top, barTop + 8)
            .opacity(isActive ? 0 : 1)
            .scaleEffect(isActive ? 0.8 : 1, anchor: .center)

            // ── Active state ──────────────────────────────────────────────
            // Bubble sits at the top of the frame (protrudes above the bar top edge),
            // label inside the bar below it.
            VStack(spacing: 0) {
                // Circle — same barColor, so it blends seamlessly into the notch.
                ZStack {
                    Circle()
                        .fill(barColor)
                        .frame(width: circleSize, height: circleSize)
                    Image(systemName: item.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(activeAccentColor)
                }
                .frame(width: circleSize, height: circleSize)

                Spacer(minLength: 0)

                Text(item.label)
                    .font(DesignSystem.Typography.microBold)
                    .foregroundColor(activeAccentColor)
                    .lineLimit(1)

                Spacer(minLength: 6)
            }
            .frame(height: TabBarShape.totalHeight)
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.75, anchor: .top)
        }
        .animation(DesignSystem.Motion.spring, value: isActive)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("Floating Tab Bar — Light") {
    struct Wrapper: View {
        @State var tab: AppView.Tab = .home
        var body: some View {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                FloatingTabBar(selectedTab: $tab).padding(.bottom, 12)
            }
        }
    }
    return Wrapper().preferredColorScheme(.light)
}

#Preview("Floating Tab Bar — Dark") {
    struct Wrapper: View {
        @State var tab: AppView.Tab = .charters
        var body: some View {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                FloatingTabBar(selectedTab: $tab).padding(.bottom, 12)
            }
        }
    }
    return Wrapper().preferredColorScheme(.dark)
}
