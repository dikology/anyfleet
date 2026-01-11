import SwiftUI

struct AuthorProfileModal: View {
    let username: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    Spacer()

                    // Author Avatar and Info
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.primary.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }

                        // Username
                        Text(username)
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("author_username")

                        // Coming Soon Message
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text(L10n.AuthorProfile.comingSoonTitle)
                                .font(DesignSystem.Typography.title)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("coming_soon_title")

                            Text(L10n.AuthorProfile.comingSoonMessage)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                                .accessibilityIdentifier("coming_soon_message")
                        }
                    }

                    Spacer()

                    // Dismiss Button
                    Button(action: onDismiss) {
                        Text(L10n.Common.close)
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle(L10n.AuthorProfile.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthorProfileModal(
        username: "SailorMaria",
        onDismiss: {}
    )
}
