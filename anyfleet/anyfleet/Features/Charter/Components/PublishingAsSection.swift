import SwiftUI

struct PublishingAsSection: View {
    let currentUser: UserInfo?
    let selectedCaptain: VirtualCaptain?
    let community: ManagedCommunity?
    let onChangeTap: () -> Void

    var body: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.FieldLabelMicro(title: L10n.Charter.Editor.PublishingAs.title)

                Button(action: onChangeTap) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        avatarView
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(titleText)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            if let subtitle = subtitleText {
                                Text(subtitle)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(DesignSystem.Typography.captionSemibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Charter.Editor.PublishingAs.title)
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let vc = selectedCaptain {
            CachedAsyncImage(url: vc.avatarThumbnailURL ?? vc.avatarURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Colors.primary.opacity(0.5))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else if let thumb = currentUser?.profileImageThumbnailUrl.flatMap(URL.init(string:)) {
            CachedAsyncImage(url: thumb) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(DesignSystem.Typography.symbolPlateLGRegular)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private var titleText: String {
        selectedCaptain?.displayName ?? L10n.Charter.Editor.PublishingAs.yourself
    }

    private var subtitleText: String? {
        if let community, selectedCaptain != nil {
            return community.name
        }
        return nil
    }
}
