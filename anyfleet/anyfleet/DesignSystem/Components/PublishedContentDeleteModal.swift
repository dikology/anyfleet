//
//  PublishedContentDeleteModal.swift
//  anyfleet
//
//  Modal for confirming published content deletion with recovery options
//

import SwiftUI

/// Modal for confirming published content deletion with multiple options
struct PublishedContentDeleteModal: View {
    let item: LibraryModel
    let onUnpublishAndDelete: () -> Void
    let onKeepPublished: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.error.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "globe")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                // Title
                Text("This content is published")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Explanation
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\"\(item.title)\" is available in the community library. Choose how you'd like to handle it:")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Options
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Option 1: Unpublish & Delete
                    Button(action: onUnpublishAndDelete) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.error.opacity(0.1))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.error)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unpublish & Delete")
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Text("Remove from community and delete locally")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Option 2: Keep Published
                    Button(action: onKeepPublished) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Keep Published")
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Text("Delete local copy, keep in community (can fork back later)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()

                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Delete Published Content") {
    PublishedContentDeleteModal(
        item: LibraryModel(
            title: "Racing Tips",
            type: .practiceGuide,
            creatorID: UUID(),
            publishedAt: Date(),
            publicID: "pub-123"
        ),
        onUnpublishAndDelete: {},
        onKeepPublished: {},
        onCancel: {}
    )
}
