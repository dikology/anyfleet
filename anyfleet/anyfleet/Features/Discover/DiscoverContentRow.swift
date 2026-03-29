import SwiftUI

/// discover content row
struct DiscoverContentRow: View {
    let content: DiscoverContent
    let onTap: () -> Void
    let onAuthorTapped: (String) -> Void
    let onForkTapped: () -> Void
    
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // SECTION 1: Icon + Title + Badge + Description (reference: flex gap-4)
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                contentTypeIcon

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Title row with type badge inline (reference: flex justify-between items-start)
                    HStack(alignment: .top) {
                        Text(content.title)
                            .font(DesignSystem.Typography.subheader)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: DesignSystem.Spacing.sm)

                        contentTypeBadge
                    }

                    if let description = content.description, !description.isEmpty {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            Divider()
                .background(DesignSystem.Colors.border.opacity(0.3))
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // SECTION 2: Attribution avatars + fork count (reference: border-t pt-3)
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    attributionAvatarStack

                    Text(content.createdAt.formatted(.relative(presentation: .named)))
                        .font(DesignSystem.Typography.micro)
                        .fontWeight(.regular)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("\(content.forkCount)")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .fontWeight(.medium)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: .medium)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        // Swipe actions for fork
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onForkTapped) {
                Label("Fork", systemImage: "arrow.triangle.branch.fill")
            }
            .tint(DesignSystem.Colors.primary)
        }
    }
    
    // MARK: - Subviews
    
    private var contentTypeIcon: some View {
        let (bgColor, iconColor) = content.contentType.iconColors
        return ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall)
                .fill(bgColor)

            Image(systemName: content.contentType.icon)
                .font(DesignSystem.Typography.title)
                .foregroundColor(iconColor)
        }
        .frame(width: 48, height: 48)
    }

    private var contentTypeBadge: some View {
        let (textColor, borderColor) = content.contentType.badgeColors
        return Text(content.contentType.displayName)
            .font(DesignSystem.Typography.nanoBold)
            .foregroundColor(textColor)
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    /// Stacked attribution avatars (reference: h-6 w-6 rounded-full, compact overlap).
    /// Avatars use 24pt size with -6pt overlap; touch target provided by parent padding.
    private var attributionAvatarStack: some View {
        HStack(spacing: -6) {
            // Original author avatar (if exists) - show first
            if let originalAuthor = content.originalAuthorUsername {
                Button(action: {
                    // TODO: Show timeline modal when implemented
                    print("Tapped original author: \(originalAuthor)")
                }) {
                    avatarCircle(username: originalAuthor, size: 24)
                }
                .accessibilityLabel("Original author \(originalAuthor)")
                .accessibilityHint("Tap to view attribution timeline")
                .buttonStyle(.plain)
            }

            // Current/main author avatar (always shown)
            if let currentAuthor = content.authorUsername {
                Button(action: {
                    onAuthorTapped(currentAuthor)
                }) {
                    avatarCircle(username: currentAuthor, size: 24)
                }
                .accessibilityLabel("Author \(currentAuthor)")
                .accessibilityHint("Tap to view author profile")
                .buttonStyle(.plain)
            } else {
                anonymousAvatarView(size: 24)
            }

            // Show "3+" indicator when the published attribution chain has 3+ distinct authors
            if content.chainDepth > 2 {
                Button(action: {
                    // TODO: Show timeline modal when implemented
                    print("Tapped attribution chain - show timeline modal")
                }) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.textSecondary.opacity(0.8))

                        Text("3+")
                            .font(DesignSystem.Typography.nanoSemibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.surface, lineWidth: 2)
                    )
                }
                .accessibilityLabel("Multiple contributors")
                .accessibilityHint("Tap to view attribution timeline")
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func avatarCircle(username: String, size: CGFloat) -> some View {
        let tint = DesignSystem.Colors.hashColor(for: username)
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.7),
                            tint.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(username.prefix(1).uppercased())
                .font(DesignSystem.Typography.avatarInitial(inCircleDiameter: size))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(DesignSystem.Colors.surface, lineWidth: 2)
        )
    }

    private func anonymousAvatarView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.primary.opacity(0.1))

            Image(systemName: "questionmark.circle.fill")
                .font(DesignSystem.Typography.avatarAnonymousGlyph(inCircleDiameter: size))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(DesignSystem.Colors.surface, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview("Discover Content Row with Avatar Stack") {
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
            onTap: {},
            onAuthorTapped: { username in
                print("Tapped author: \(username)")
            },
            onForkTapped: {
                print("Fork tapped")
            }
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
            onTap: {},
            onAuthorTapped: { username in
                print("Tapped author: \(username)")
            },
            onForkTapped: {
                print("Fork tapped")
            }
        )

        DiscoverContentRow(
            content: DiscoverContent(
                id: UUID(),
                title: "Storm Tactics (Fork)",
                description: "Enhanced version with additional safety measures and updated techniques.",
                contentType: .practiceGuide,
                tags: ["heavy weather", "reefing", "safety", "storm"],
                publicID: "storm-tactics-fork",
                authorUsername: "SailorMaria",
                viewCount: 89,
                forkCount: 5,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3),
                forkedFromID: UUID(),
                originalAuthorUsername: "CaptainJohn",
                originalContentPublicID: "heavy-weather-tactics"
            ),
            onTap: {},
            onAuthorTapped: { username in
                print("Tapped author: \(username)")
            },
            onForkTapped: {
                print("Fork tapped")
            }
        )
        
        DiscoverContentRow(
            content: DiscoverContent(
                id: UUID(),
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right-of-way rules and light patterns.",
                contentType: .practiceGuide,
                tags: ["colregs", "rules", "night"],
                publicID: "colregs-flashcards",
                authorUsername: nil,
                viewCount: 89,
                forkCount: 15,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3)
            ),
            onTap: {},
            onAuthorTapped: { username in
                print("Tapped author: \(username)")
            },
            onForkTapped: {
                print("Fork tapped")
            }
        )
        
        Spacer()
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
