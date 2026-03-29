import SwiftUI

/// Shared community badge — appears on profile chips, charter cards, and map pins.
/// Uses `DesignSystem.Colors.communityAccent` (gold) for border and text.
struct CommunityBadge: View {
    let name: String
    let iconURL: URL?
    var style: Style = .pill

    enum Style {
        /// Full pill with text label
        case pill
        /// Small square icon only (initials fallback)
        case icon
    }

    var body: some View {
        switch style {
        case .pill:
            pillView
        case .icon:
            iconView
        }
    }

    private var pillView: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            initialsView(size: 16)
            Text(name)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.communityAccent)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.communityAccent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.communityAccent.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private var iconView: some View {
        initialsView(size: 28)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.communityAccent.opacity(0.6), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func initialsView(size: CGFloat) -> some View {
        if let url = iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                default:
                    initialsPlaceholder(size: size)
                }
            }
            .frame(width: size, height: size)
        } else {
            initialsPlaceholder(size: size)
        }
    }

    private func initialsPlaceholder(size: CGFloat) -> some View {
        ZStack {
            DesignSystem.Colors.communityAccent.opacity(0.2)
            Text(String(name.prefix(1)).uppercased())
                .font(DesignSystem.Typography.communityBadgeInitial(forDiameter: size))
                .foregroundColor(DesignSystem.Colors.communityAccent)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 16) {
        CommunityBadge(name: "Med Sailors", iconURL: nil, style: .pill)
        CommunityBadge(name: "Racing Crew", iconURL: nil, style: .pill)
        CommunityBadge(name: "Med Sailors", iconURL: nil, style: .icon)
    }
    .padding()
}
