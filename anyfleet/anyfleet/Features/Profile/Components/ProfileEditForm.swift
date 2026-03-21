import SwiftUI

// MARK: - Profile Edit Form

/// Extended edit form including text fields, social links, and community management.
/// Wraps the base `DesignSystem.Profile.EditForm` and appends the new sections.
struct ProfileEditForm: View {
    @Binding var username: String
    @Binding var bio: String
    @Binding var location: String
    @Binding var nationality: String
    @Binding var socialLinks: [SocialLink]
    @Binding var communities: [CommunityMembership]

    let onSave: () -> Void
    let onCancel: () -> Void
    let onAddCommunityTapped: () -> Void
    let isSaving: Bool

    private let bioCharacterLimit = 2000

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Text fields section (username, bio, location, nationality)
            textFieldsSection

            // Social links section
            SocialLinksSection(links: $socialLinks)

            // Community section
            CommunitiesSection(
                memberships: communities,
                isEditing: true,
                onSetPrimary: { id in
                    for i in communities.indices {
                        communities[i].isPrimary = (communities[i].id == id)
                    }
                },
                onLeave: { id in
                    communities.removeAll { $0.id == id }
                    if !communities.isEmpty, !communities.contains(where: \.isPrimary) {
                        communities[0].isPrimary = true
                    }
                },
                onAddTapped: onAddCommunityTapped
            )

            // Action buttons
            actionButtons
        }
    }

    // MARK: - Sections

    private var textFieldsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            fieldGroup(label: L10n.Profile.displayNameTitle, helper: nil) {
                TextField(L10n.Profile.displayNamePlaceholder, text: $username)
                    .formFieldStyle()
                    .textInputAutocapitalization(.words)
            }

            fieldGroup(label: L10n.Profile.Bio.title, helper: L10n.Profile.EditForm.bioCounter(bio.count, limit: bioCharacterLimit)) {
                TextEditor(text: $bio)
                    .font(DesignSystem.Typography.body)
                    .frame(minHeight: 80)
                    .padding(DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                fieldGroup(label: L10n.Profile.Location.title, helper: nil) {
                    TextField(L10n.Profile.Location.placeholder, text: $location)
                        .formFieldStyle()
                }
                fieldGroup(label: L10n.Profile.Nationality.title, helper: nil) {
                    TextField(L10n.Profile.Nationality.placeholder, text: $nationality)
                        .formFieldStyle()
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: onCancel) {
                Text(L10n.Profile.EditForm.cancel)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            .disabled(isSaving)

            Button(action: onSave) {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(DesignSystem.Colors.onPrimary)
                    } else {
                        Text(L10n.Profile.EditForm.save)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.onPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Gradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
            .disabled(isSaving || bio.count > bioCharacterLimit)
        }
    }

    // MARK: - Helpers

    private func fieldGroup<Content: View>(
        label: String,
        helper: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if let helper {
                    Spacer()
                    Text(helper)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(
                            bio.count > bioCharacterLimit
                                ? DesignSystem.Colors.error
                                : DesignSystem.Colors.textSecondary
                        )
                }
            }
            content()
        }
    }
}

#Preview {
    @Previewable @State var username = "Jane Sailor"
    @Previewable @State var bio = "Day skipper."
    @Previewable @State var location = "Oslo"
    @Previewable @State var nationality = "Norwegian"
    @Previewable @State var socialLinks: [SocialLink] = [
        SocialLink(platform: .instagram, handle: "jane_sails")
    ]
    @Previewable @State var communities: [CommunityMembership] = [
        CommunityMembership(id: "1", name: "Nordic Crew", iconURL: nil, role: .member, isPrimary: true)
    ]

    ProfileEditForm(
        username: $username,
        bio: $bio,
        location: $location,
        nationality: $nationality,
        socialLinks: $socialLinks,
        communities: $communities,
        onSave: {},
        onCancel: {},
        onAddCommunityTapped: {},
        isSaving: false
    )
    .padding()
    .background(DesignSystem.Colors.background)
}
