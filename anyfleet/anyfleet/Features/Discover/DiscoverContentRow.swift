import SwiftUI

/// Redesigned discover content row with modern UX/UI best practices
/// - Clickable author avatar opening profile modal
/// - Fork action via swipe gesture
/// - Optimized information hierarchy
struct DiscoverContentRow: View {
    let content: DiscoverContent
    let onTap: () -> Void
    let onAuthorTapped: (String) -> Void  // NEW: Open author profile
    let onForkTapped: () -> Void  // NEW: Fork action
    
    @State private var isPressed = false
    @State private var showSwipeActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // SECTION 2: Content (Title + Description)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Icon + Title
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    contentTypeIcon
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(content.title)
                            .font(.system(size: 18, weight: .bold))
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
                    }
                }
                
                // Description
                if let description = content.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, 44) // Align with title
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.3))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // SECTION 3: Tags & Footer
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Tags
                if !content.tags.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(content.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.primary.opacity(0.08))
                                )
                        }
                        
                        if content.tags.count > 3 {
                            Text("+\(content.tags.count - 3)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Content Type Badge
                        contentTypeBadge
                        
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            Divider()
                .background(DesignSystem.Colors.border.opacity(0.3))
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // SECTION 3: Author & Fork
            HStack(spacing: DesignSystem.Spacing.md) {
                // Author Avatar - Clickable
                if let author = content.authorUsername {
                    Button(action: { onAuthorTapped(author) }) {
                        authorAvatarView(username: author)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                } else {
                    // Anonymous author fallback
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                        
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(width: 36, height: 36)
                }
                
                // Author Info
                VStack(alignment: .leading, spacing: 2) {
                    
                    Text(content.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Fork indicator
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("\(content.forkCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)

            
        }
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 1)
        )
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
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.12),
                            DesignSystem.Colors.primary.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: content.contentType.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .frame(width: 36, height: 36)
        //.flexibleFrame(alignment: .top)
    }
    
    private var contentTypeBadge: some View {
        Text(content.contentType.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.primary.opacity(0.12))
            )
    }
    
    private func authorAvatarView(username: String) -> some View {
        ZStack {
            // Avatar circle with gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            hashColor(username).opacity(0.7),
                            hashColor(username).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Initials or icon
            Text(username.prefix(1).uppercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 36, height: 36)
        .overlay(
            Circle()
                .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 1)
        )
    }
    
    /// Generate a consistent color based on username for avatar
    private func hashColor(_ username: String) -> Color {
        let colors: [Color] = [
            DesignSystem.Colors.primary,
            Color(red: 0.8, green: 0.5, blue: 0.3),
            Color(red: 0.3, green: 0.7, blue: 0.8),
            Color(red: 0.7, green: 0.3, blue: 0.6),
            Color(red: 0.5, green: 0.7, blue: 0.3)
        ]
        let hash = username.utf8.reduce(0) { $0 &+ Int($1) }
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Preview

#Preview("Redesigned Discover Content Row") {
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
