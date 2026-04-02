import SwiftUI
import SafariServices

// MARK: - Social Links Section (Edit Mode)

/// Edit-mode form showing one text field per platform.
/// Empty handles are not saved. Tapping a saved link opens it in Safari.
struct SocialLinksSection: View {
    @Binding var links: [SocialLink]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "link")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.info)
                Text(L10n.Profile.SocialLinks.title)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(SocialPlatform.allCases, id: \.self) { platform in
                    platformRow(platform)
                }
            }
        }
    }

    private func platformRow(_ platform: SocialPlatform) -> some View {
        let binding = handleBinding(for: platform)
        let handle = binding.wrappedValue

        return HStack(spacing: DesignSystem.Spacing.sm) {
            // Platform icon
            Image(systemName: platform.icon)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.info)
                .frame(width: 22)

            // Prefix label or "https://"
            if !platform.urlPrefix.isEmpty {
                Text(platform.urlPrefix)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.regular)
                    .monospaced()
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }

            // Handle input
            TextField(platform == .other ? L10n.Profile.SocialLinks.urlPlaceholder : L10n.Profile.SocialLinks.usernamePlaceholder, text: binding)
                .font(DesignSystem.Typography.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(platform == .other ? .URL : .default)

            // Open link button (only shown when handle is non-empty)
            if !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let url = platform.url(for: handle.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.info.opacity(0.8))
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
    }

    /// Returns a Binding<String> for the handle of a given platform,
    /// creating a SocialLink entry if one doesn't exist yet.
    private func handleBinding(for platform: SocialPlatform) -> Binding<String> {
        Binding(
            get: {
                links.first(where: { $0.platform == platform })?.handle ?? ""
            },
            set: { newHandle in
                if let index = links.firstIndex(where: { $0.platform == platform }) {
                    links[index].handle = newHandle
                } else {
                    links.append(SocialLink(platform: platform, handle: newHandle))
                }
            }
        )
    }
}

// MARK: - Social Links Display (View Mode)

/// Read-only display of social links on the profile. Tapping opens the URL.
struct SocialLinksDisplaySection: View {
    let links: [SocialLink]

    private var activeLinks: [SocialLink] {
        links.filter { !$0.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        if !activeLinks.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                DesignSystem.SectionLabel(L10n.Profile.SocialLinks.title)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(activeLinks) { link in
                        if let url = link.url {
                            Link(destination: url) {
                                ZStack {
                                    Circle()
                                        .fill(link.platform.brandColor.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle().stroke(link.platform.brandColor.opacity(0.25), lineWidth: 1)
                                        )
                                    Image(systemName: link.platform.icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(link.platform.brandColor)
                                }
                            }
                            .accessibilityLabel(localizedPlatformName(link.platform))
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private func localizedPlatformName(_ platform: SocialPlatform) -> String {
        switch platform {
        case .instagram: return L10n.Profile.SocialLinks.Platform.instagram
        case .telegram: return L10n.Profile.SocialLinks.Platform.telegram
        case .other: return L10n.Profile.SocialLinks.Platform.other
        }
    }
}

// MARK: - Preview

#Preview("Edit Mode") {
    @State var links: [SocialLink] = [
        SocialLink(platform: .instagram, handle: "john_sailor"),
        SocialLink(platform: .telegram, handle: "")
    ]
    return SocialLinksSection(links: $links)
        .padding()
}

#Preview("Display Mode") {
    SocialLinksDisplaySection(links: [
        SocialLink(platform: .instagram, handle: "john_sailor"),
        SocialLink(platform: .telegram, handle: "j_sailor")
    ])
    .padding()
}
