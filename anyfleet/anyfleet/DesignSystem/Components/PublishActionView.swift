//
//  PublishActionView.swift
//  anyfleet
//
//  Action button for publishing/unpublishing content
//

import SwiftUI

/// Action button for publishing or unpublishing content
struct PublishActionView: View {
    let item: LibraryModel
    let isSignedIn: Bool
    let onPublish: () -> Void
    let onUnpublish: () -> Void
    let onSignInRequired: () -> Void
    
    var body: some View {
        if item.visibility == .public {
            // Unpublish button - only show if signed in
            if isSignedIn {
                Button(action: onUnpublish) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 14, weight: .medium))
                        Text("Unpublish")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.surface)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show sign-in prompt for unpublish
                Button(action: onSignInRequired) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 14, weight: .medium))
                        Text("Sign In to Unpublish")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.border.opacity(0.3))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } else {
            // Publish button
            Button(action: {
                if isSignedIn {
                    onPublish()
                } else {
                    onSignInRequired()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                    Text("Publish")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(isSignedIn ? DesignSystem.Colors.primary : DesignSystem.Colors.border.opacity(0.3))
                .foregroundColor(isSignedIn ? .white : DesignSystem.Colors.textSecondary)
                .cornerRadius(8)
            }
            .opacity(isSignedIn ? 1.0 : 0.7)
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Preview

#Preview("Publish Actions") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // Signed in - can publish
        PublishActionView(
            item: LibraryModel(
                title: "Test",
                type: .checklist,
                visibility: .private,
                creatorID: UUID()
            ),
            isSignedIn: true,
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Not signed in - disabled
        PublishActionView(
            item: LibraryModel(
                title: "Test",
                type: .checklist,
                visibility: .private,
                creatorID: UUID()
            ),
            isSignedIn: false,
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
        
        // Published - can unpublish
        PublishActionView(
            item: LibraryModel(
                title: "Test",
                type: .checklist,
                visibility: .public,
                creatorID: UUID()
            ),
            isSignedIn: true,
            onPublish: {},
            onUnpublish: {},
            onSignInRequired: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

