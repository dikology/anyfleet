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
                    .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignSystem.Colors.info)
                .frame(width: 22)

            // Prefix label or "https://"
            if !platform.urlPrefix.isEmpty {
                Text(platform.urlPrefix)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
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
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.info.opacity(0.8))
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceAlt)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
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

                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(activeLinks) { link in
                        if let url = link.url {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: link.platform.icon)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(localizedPlatformName(link.platform))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.Colors.info)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(DesignSystem.Colors.info.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(DesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
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
