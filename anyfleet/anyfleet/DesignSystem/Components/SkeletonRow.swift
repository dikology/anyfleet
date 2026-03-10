import SwiftUI

// MARK: - Skeleton block

extension DesignSystem {
    /// Animated shimmer placeholder block — use to build skeleton loading states.
    ///
    /// Pass `animating` from a parent view to keep multiple blocks in sync.
    /// When `animating` is `nil` (default) the block manages its own animation timer.
    struct SkeletonBlock: View {
        var width: CGFloat? = nil
        var height: CGFloat
        /// External animation phase supplied by a parent for synchronized shimmer.
        var animating: Bool? = nil

        @State private var selfAnimating = false

        private var isAnimating: Bool { animating ?? selfAnimating }

        var body: some View {
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.surface,
                            DesignSystem.Colors.surfaceAlt,
                            DesignSystem.Colors.surface
                        ],
                        startPoint: isAnimating ? .leading : .trailing,
                        endPoint: isAnimating ? .trailing : .leading
                    )
                )
                .frame(width: width, height: height)
                .onAppear {
                    guard animating == nil else { return }
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        selfAnimating = true
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

    // MARK: - Skeleton row matching LibraryItemRow shape

    /// Full-width skeleton placeholder that mirrors the shape of `LibraryItemRow`.
    struct LibrarySkeletonRow: View {
        var animating: Bool? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    SkeletonBlock(width: 24, height: 24, animating: animating)
                    SkeletonBlock(width: 180, height: 18, animating: animating)
                    Spacer()
                    SkeletonBlock(width: 56, height: 16, animating: animating)
                }
                SkeletonBlock(height: 14, animating: animating)
                SkeletonBlock(width: 120, height: 12, animating: animating)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
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
