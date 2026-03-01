import SwiftUI

// MARK: - Skeleton block

extension DesignSystem {
    /// Animated shimmer placeholder block — use to build skeleton loading states.
    struct SkeletonBlock: View {
        var width: CGFloat? = nil
        var height: CGFloat

        @State private var animating = false

        var body: some View {
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.surface,
                            DesignSystem.Colors.surfaceAlt,
                            DesignSystem.Colors.surface
                        ],
                        startPoint: animating ? .leading : .trailing,
                        endPoint: animating ? .trailing : .leading
                    )
                )
                .frame(width: width, height: height)
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
        }
    }

    // MARK: - Skeleton row matching CharterTimelineRow shape

    /// Full-width skeleton placeholder that mirrors the shape of `CharterTimelineRow`.
    struct CharterSkeletonRow: View {
        var body: some View {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Date gutter
                VStack(spacing: DesignSystem.Spacing.xs) {
                    SkeletonBlock(width: 32, height: 32)
                    SkeletonBlock(width: 24, height: 11)
                }
                .frame(width: 48)
                .padding(.top, DesignSystem.Spacing.md)

                // Card body
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        SkeletonBlock(width: 72, height: 20)
                        Spacer()
                        SkeletonBlock(width: 56, height: 16)
                    }
                    SkeletonBlock(height: 18)
                    SkeletonBlock(width: 160, height: 14)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Rows") {
    VStack(spacing: 0) {
        DesignSystem.CharterSkeletonRow()
        DesignSystem.CharterSkeletonRow()
        DesignSystem.CharterSkeletonRow()
    }
    .padding(.horizontal, DesignSystem.Spacing.lg)
    .background(DesignSystem.Colors.background)
}
