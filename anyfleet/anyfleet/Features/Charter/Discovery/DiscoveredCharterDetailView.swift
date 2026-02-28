import SwiftUI
import MapKit

/// Detail view for a charter discovered in the community feed.
/// Shows captain info, charter details, and a full map.
/// Privacy-safe: only shows destination, not exact captain location.
struct DiscoveredCharterDetailView: View {
    let charter: DiscoverableCharter
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                captainSection
                charterInfoSection
                if charter.hasLocation, let coordinate = charter.coordinate {
                    mapSection(coordinate: coordinate)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(charter.name)
                    .font(DesignSystem.Typography.headline)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Captain Section

    private var captainSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.sectionCaptain)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: DesignSystem.Spacing.md) {
                captainAvatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(charter.captain.username ?? L10n.Charter.Discovery.anonymousCaptain)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(L10n.Charter.Discovery.charterHost)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
    }

    private var captainAvatar: some View {
        Group {
            if let url = charter.captain.profileImageThumbnailURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderAvatar
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(DesignSystem.Colors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 24))
            )
    }

    // MARK: - Charter Info Section

    private var charterInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.sectionCharterDetails)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                infoRow(icon: "text.quote", label: L10n.Charter.Discovery.fieldName, value: charter.name)
                Divider().padding(.leading, 44)
                infoRow(icon: "calendar", label: L10n.Charter.Discovery.fieldDates, value: charter.dateRange)
                Divider().padding(.leading, 44)
                infoRow(icon: "clock", label: L10n.Charter.Discovery.fieldDuration,
                        value: L10n.Charter.Discovery.durationDays(charter.durationDays))

                if let boat = charter.boatName, !boat.isEmpty {
                    Divider().padding(.leading, 44)
                    infoRow(icon: "sailboat", label: L10n.Charter.Discovery.fieldVessel, value: boat)
                }

                if let destination = charter.destination, !destination.isEmpty {
                    Divider().padding(.leading, 44)
                    infoRow(icon: "mappin.and.ellipse", label: L10n.Charter.Discovery.fieldDestination, value: destination)
                }

                if let distanceKm = charter.distanceKm {
                    Divider().padding(.leading, 44)
                    infoRow(icon: "location.circle", label: L10n.Charter.Discovery.fieldDistance,
                            value: L10n.Charter.Discovery.kmAway(Int(distanceKm)))
                }
            }
            .background(DesignSystem.Colors.surface)
            .cornerRadius(12)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(value)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Map Section

    private func mapSection(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.sectionDestination)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textCase(.uppercase)

            MapPreviewThumbnail(
                coordinate: coordinate,
                height: 200,
                annotationTitle: charter.destination ?? charter.name
            )
        }
    }
}
