import SwiftUI

/// A card displaying a discoverable charter in the discovery feed.
/// Shows captain info, charter details, dates, and an optional map thumbnail.
struct CharterDiscoveryRow: View {
    let charter: DiscoverableCharter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                captainHeader
                charterDetails
                if charter.hasLocation, let coordinate = charter.coordinate {
                    MapPreviewThumbnail(
                        coordinate: coordinate,
                        height: 120,
                        annotationTitle: charter.destination ?? ""
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var captainHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            CaptainAvatarView(captain: charter.captain)

            VStack(alignment: .leading, spacing: 2) {
                Text(charter.captain.username ?? L10n.Charter.Discovery.captainFallback)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let destination = charter.destination, !destination.isEmpty {
                    Text(destination)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                urgencyBadge
                if let distanceKm = charter.distanceKm {
                    Text(L10n.Charter.Discovery.kmAway(Int(distanceKm)))
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    private var charterDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(charter.name)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: DesignSystem.Spacing.md) {
                Label(charter.dateRange, systemImage: "calendar")
                if let boat = charter.boatName, !boat.isEmpty {
                    Label(boat, systemImage: "sailboat")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private var urgencyBadge: some View {
        Text(charter.urgencyLevel.badgeLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(charter.urgencyLevel.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(charter.urgencyLevel.color.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts = [charter.name]
        if let captain = charter.captain.username {
            parts.append("by \(captain)")
        }
        parts.append(charter.dateRange)
        if let dest = charter.destination {
            parts.append("in \(dest)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Captain Avatar

private struct CaptainAvatarView: View {
    let captain: CaptainBasicInfo

    var body: some View {
        Group {
            if let url = captain.profileImageThumbnailURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderAvatar
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(DesignSystem.Colors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 18))
            )
    }
}

// MARK: - Urgency Level Presentation

private extension CharterUrgencyLevel {
    var badgeLabel: String {
        switch self {
        case .past: return L10n.Charter.Discovery.Badge.past
        case .imminent: return L10n.Charter.Discovery.Badge.imminent
        case .soon: return L10n.Charter.Discovery.Badge.soon
        case .future: return L10n.Charter.Discovery.Badge.upcoming
        }
    }

    var color: Color {
        switch self {
        case .past: return .gray
        case .imminent: return .red
        case .soon: return .orange
        case .future: return DesignSystem.Colors.primary
        }
    }
}
