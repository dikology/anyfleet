//
//  LibraryItemRow.swift
//  anyfleet
//
//  Individual row component for library items with visibility controls
//

import SwiftUI

/// Row component for displaying library items with visibility badge and publish actions
struct LibraryItemRow: View {
    let item: LibraryModel
    let contentType: ContentType
    let isSignedIn: Bool
    let onTap: () -> Void
    let onPublish: () -> Void
    let onUnpublish: () -> Void
    let onSignInRequired: () -> Void
    
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
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
                        
                        Image(systemName: contentType.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(item.title)
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
                        
                        // Type Badge + Fork Attribution
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(contentType.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            // Fork attribution
                            if item.forkedFromID != nil {
                                Text("•")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)

                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)

                                Text("Forked")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
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
                if let description = item.description, !description.isEmpty {
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
            .focalHighlight()
            
            Divider()
                .background(DesignSystem.Colors.border.opacity(0.5))
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Metadata Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Updated Date
                    Text("\(L10n.Library.updatedPrefix) \(item.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            
            // Footer Section - Visibility Badge + Sync Status + Publish Action
            HStack(spacing: DesignSystem.Spacing.md) {
                VisibilityBadge(
                    visibility: item.visibility,
                    authorUsername: item.publicMetadata?.authorUsername
                )
                
                // Sync Status Indicator (only show for non-private items)
                if item.visibility != .private {
                    SyncStatusIndicator(syncStatus: item.syncStatus)
                }
                
                Spacer()
                
                PublishActionView(
                    item: item,
                    isSignedIn: isSignedIn,
                    onPublish: onPublish,
                    onUnpublish: onUnpublish,
                    onSignInRequired: onSignInRequired
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: .medium)
        .background(backgroundColor)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Styling
    
    /// Background color for published items
    private var backgroundColor: Color {
        if item.visibility == .public {
            return DesignSystem.Colors.success.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview("Library Item Row") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // Private item
        LibraryItemRow(
            item: LibraryModel(
                title: "Pre‑Departure Safety Checklist",
                description: "Run through this before every sail: weather, rigging, engine, and crew briefing.",
                type: .checklist,
                visibility: .private,
                creatorID: UUID()
            ),
            contentType: .checklist,
            isSignedIn: true,
            onTap: {},
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Public item (synced)
        LibraryItemRow(
            item: LibraryModel(
                title: "Heavy Weather Tactics",
                description: "Step‑by‑step guide for reefing, heaving‑to, and staying safe when the wind picks up.",
                type: .practiceGuide,
                visibility: .public,
                creatorID: UUID(),
                syncStatus: .synced,
                publicMetadata: PublicMetadata(
                    publishedAt: Date(),
                    publicID: "heavy-weather-tactics",
                    canFork: true,
                    authorUsername: "SailorMaria"
                )
            ),
            contentType: .practiceGuide,
            isSignedIn: true,
            onTap: {},
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Public item (pending sync)
        LibraryItemRow(
            item: LibraryModel(
                title: "Navigation Basics",
                description: "Essential navigation techniques for coastal sailing.",
                type: .practiceGuide,
                visibility: .public,
                creatorID: UUID(),
                syncStatus: .pending,
                publicMetadata: PublicMetadata(
                    publishedAt: Date(),
                    publicID: "navigation-basics",
                    canFork: true,
                    authorUsername: "CaptainJohn"
                )
            ),
            contentType: .practiceGuide,
            isSignedIn: true,
            onTap: {},
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Public item (failed sync)
        LibraryItemRow(
            item: LibraryModel(
                title: "Engine Troubleshooting",
                description: "Common engine issues and how to fix them.",
                type: .checklist,
                visibility: .public,
                creatorID: UUID(),
                syncStatus: .failed,
                publicMetadata: PublicMetadata(
                    publishedAt: Date(),
                    publicID: "engine-troubleshooting",
                    canFork: true,
                    authorUsername: "EngineerMike"
                )
            ),
            contentType: .checklist,
            isSignedIn: true,
            onTap: {},
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Not signed in
        LibraryItemRow(
            item: LibraryModel(
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right‑of‑way rules and light patterns.",
                type: .flashcardDeck,
                visibility: .private,
                creatorID: UUID()
            ),
            contentType: .flashcardDeck,
            isSignedIn: false,
            onTap: {},
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

