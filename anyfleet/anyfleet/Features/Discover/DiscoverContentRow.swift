import SwiftUI

/// Row component for displaying discover content items
struct DiscoverContentRow: View {
    let content: DiscoverContent
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Section - Focal Point
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Content Title - Primary Focal Element
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    // Type Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary.opacity(0.15),
                                        DesignSystem.Colors.primary.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: content.contentType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(content.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.textPrimary,
                                        DesignSystem.Colors.textPrimary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Author and Type Badge
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if let author = content.authorUsername {
                                Text("by \(author)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }

                            Text(content.contentType.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                    }

                    Spacer()
                }

                // Description
                if let description = content.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, 56) // Align with title
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)

            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // Metadata Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Created Date
                    Text(content.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    // Tags
                    if !content.tags.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(content.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                                    )
                            }
                        }
                    }
                }

                // Stats Row
                HStack(spacing: DesignSystem.Spacing.md) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("\(content.viewCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("\(content.forkCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: .medium)
        .background(Color.clear)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

#Preview("Discover Content Row") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        DiscoverContentRow(
            content: DiscoverContent(
                id: UUID(),
                title: "Pre-Departure Safety Checklist",
                description: "Run through this before every sail: weather, rigging, engine, and crew briefing.",
                contentType: .checklist,
                tags: ["safety", "pre-departure", "crew"],
                publicID: "pre-departure-checklist",
                authorUsername: "SailorMaria",
                viewCount: 42,
                forkCount: 8,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 7)
            ),
            onTap: {}
        )

        DiscoverContentRow(
            content: DiscoverContent(
                id: UUID(),
                title: "Heavy Weather Tactics",
                description: "Step-by-step guide for reefing, heaving-to, and staying safe when the wind picks up.",
                contentType: .practiceGuide,
                tags: ["heavy weather", "reefing", "safety"],
                publicID: "heavy-weather-tactics",
                authorUsername: "CaptainJohn",
                viewCount: 127,
                forkCount: 23,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 14)
            ),
            onTap: {}
        )

        DiscoverContentRow(
            content: DiscoverContent(
                id: UUID(),
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right-of-way rules and light patterns.",
                contentType: .flashcardDeck,
                tags: ["colregs", "rules", "night"],
                publicID: "colregs-flashcards",
                authorUsername: nil,
                viewCount: 89,
                forkCount: 15,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3)
            ),
            onTap: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
