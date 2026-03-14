import SwiftUI

/// Confirmation sheet for deleting a charter that is visible in the community or public
/// discovery feed. Gives the user the option to unpublish (remove from discovery) or to
/// delete only the local copy while leaving the server record in place.
///
/// - Parameter canUnpublish: Pass `false` when the user is not signed in; the
///   "Unpublish & Delete" option will be shown disabled with an explanation.
struct CharterDeleteModal: View {
    let charterName: String
    let canUnpublish: Bool
    let onUnpublishAndDelete: () -> Void
    let onDeleteLocalOnly: () -> Void
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
                Text(L10n.Charter.DeleteModal.title)
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Explanation
                Text(L10n.Charter.DeleteModal.explanation(charterName))
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                // Options
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: canUnpublish ? onUnpublishAndDelete : {}) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.error.opacity(canUnpublish ? 0.1 : 0.05))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(canUnpublish
                                        ? DesignSystem.Colors.error
                                        : DesignSystem.Colors.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Charter.DeleteModal.unpublishAndDeleteTitle)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(canUnpublish
                                        ? DesignSystem.Colors.textPrimary
                                        : DesignSystem.Colors.textSecondary)

                                Text(canUnpublish
                                    ? L10n.Charter.DeleteModal.unpublishAndDeleteSubtitle
                                    : L10n.Charter.DeleteModal.unpublishRequiresSignIn)
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
                    .disabled(!canUnpublish)

                    Button(action: onDeleteLocalOnly) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "iphone.slash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Charter.DeleteModal.deleteLocalOnlyTitle)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Text(L10n.Charter.DeleteModal.deleteLocalOnlySubtitle)
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

                Button(action: onCancel) {
                    Text(L10n.Common.cancel)
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

#Preview("Delete Published Charter — signed in") {
    CharterDeleteModal(
        charterName: "Greek Islands Adventure",
        canUnpublish: true,
        onUnpublishAndDelete: {},
        onDeleteLocalOnly: {},
        onCancel: {}
    )
}

#Preview("Delete Published Charter — not signed in") {
    CharterDeleteModal(
        charterName: "Greek Islands Adventure",
        canUnpublish: false,
        onUnpublishAndDelete: {},
        onDeleteLocalOnly: {},
        onCancel: {}
    )
}
