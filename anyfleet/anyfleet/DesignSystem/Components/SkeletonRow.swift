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
                    withAnimation(DesignSystem.Motion.skeleton) {
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

    // MARK: - Skeleton row matching DiscoverContentRow shape

    /// Placeholder that mirrors `DiscoverContentRow` for the discover content tab.
    struct DiscoverContentSkeletonRow: View {
        var animating: Bool? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                    SkeletonBlock(width: 48, height: 48, animating: animating)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            SkeletonBlock(width: 160, height: 18, animating: animating)
                            Spacer(minLength: 0)
                            SkeletonBlock(width: 56, height: 14, animating: animating)
                        }
                        SkeletonBlock(height: 14, animating: animating)
                        SkeletonBlock(width: 200, height: 14, animating: animating)
                    }
                }
                .padding(DesignSystem.Spacing.lg)

                Divider()
                    .background(DesignSystem.Colors.border.opacity(0.3))
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    SkeletonBlock(width: 24, height: 24, animating: animating)
                        .clipShape(Circle())
                    SkeletonBlock(width: 72, height: 11, animating: animating)
                    Spacer()
                    SkeletonBlock(width: 36, height: 11, animating: animating)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                    .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 1)
            )
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

    // MARK: - Skeleton row matching Community Manager list row

    /// Placeholder that mirrors the community manager list row (thumbnail + title + subtitle in `cardStyle`).
    struct CommunitySkeletonRow: View {
        var animating: Bool? = nil

        var body: some View {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                SkeletonBlock(width: 40, height: 40, animating: animating)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusCompact, style: .continuous))

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    SkeletonBlock(width: 160, height: 20, animating: animating)
                    SkeletonBlock(width: 120, height: 14, animating: animating)
                }

                Spacer(minLength: 0)
            }
            .cardStyle()
        }
    }

    // MARK: - Stats row (profile `StatsRow` mirror)

    /// Horizontal stat groups with icon + value + label placeholders, matching `StatsRow` layout.
    struct StatsRowSkeleton: View {
        var groupCount: Int = 4
        var animating: Bool? = nil

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<groupCount, id: \.self) { index in
                        if index > 0 {
                            Text("|")
                                .font(Typography.caption)
                                .foregroundColor(Colors.textSecondary.opacity(0.25))
                                .padding(.horizontal, Spacing.sm)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            SkeletonBlock(width: 14, height: 14, animating: animating)
                            SkeletonBlock(width: 28, height: 18, animating: animating)
                            SkeletonBlock(width: 72, height: 14, animating: animating)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    // MARK: - Charter detail inline stats card

    /// Placeholder for the hero stats card on charter detail (three stat groups + pipes).
    struct CharterDetailStatsRowSkeleton: View {
        var animating: Bool? = nil

        var body: some View {
            HStack(spacing: 0) {
                statGroup
                pipe
                statGroup
                pipe
                statGroup
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
            .background(Colors.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                    .stroke(Colors.border, lineWidth: 1)
            )
        }

        private var statGroup: some View {
            HStack(spacing: Spacing.sm) {
                SkeletonBlock(width: 30, height: 30, animating: animating)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonBlock(width: 44, height: 14, animating: animating)
                    SkeletonBlock(width: 56, height: 10, animating: animating)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var pipe: some View {
            Rectangle()
                .fill(Colors.border)
                .frame(width: 1, height: 28)
                .padding(.horizontal, Spacing.sm)
        }
    }

    // MARK: - Virtual captain list row

    /// Circle avatar + title row, matching virtual captain rows in community detail.
    struct VirtualCaptainSkeletonRow: View {
        var animating: Bool? = nil

        var body: some View {
            HStack(spacing: Spacing.md) {
                SkeletonBlock(width: 36, height: 36, animating: animating)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SkeletonBlock(width: 140, height: 16, animating: animating)
                    SkeletonBlock(width: 88, height: 12, animating: animating)
                }
                Spacer(minLength: 0)
                SkeletonBlock(width: 10, height: 14, animating: animating)
            }
            .padding(.vertical, Spacing.xs)
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

#Preview("Community skeleton") {
    VStack(spacing: DesignSystem.Spacing.md) {
        DesignSystem.CommunitySkeletonRow()
        DesignSystem.CommunitySkeletonRow()
    }
    .padding(.horizontal, DesignSystem.Spacing.lg)
    .background(DesignSystem.Colors.background)
}
