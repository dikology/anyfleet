//
//  DeleteConfirmationModal.swift
//  anyfleet
//
//  Modal for confirming content deletion
//

import SwiftUI

/// Modal for confirming private content deletion
struct DeleteConfirmationModal: View {
    let item: LibraryModel
    let isPublished: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Icon
                Image(systemName: "trash")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(DesignSystem.Colors.error)
                    .padding(.top, DesignSystem.Spacing.xl)

                // Title
                Text("Delete \"\(item.title)\"?")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Explanation
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("This content will be permanently removed from your library.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()

                // Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: onConfirm) {
                        Text("Delete")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.error)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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

#Preview("Delete Private Content") {
    DeleteConfirmationModal(
        item: LibraryModel(
            title: "My Racing Checklist",
            type: .checklist,
            creatorID: UUID()
        ),
        isPublished: false,
        onConfirm: {},
        onCancel: {}
    )
}
