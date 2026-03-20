import SwiftUI
import MapKit

// MARK: - Charter Map View

struct CharterMapView: View {
    let charters: [DiscoverableCharter]
    let onSelectCharter: (DiscoverableCharter) -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCharterID: UUID?

    private var chartersWithLocation: [DiscoverableCharter] {
        charters.filter { $0.hasLocation }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedCharterID) {
                ForEach(chartersWithLocation) { charter in
                    if let coordinate = charter.coordinate {
                        Annotation(charter.name, coordinate: coordinate, anchor: .bottom) {
                            UserAvatarPin(
                                charter: charter,
                                isSelected: selectedCharterID == charter.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCharterID = charter.id
                                }
                            }
                        }
                        .tag(charter.id)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear { fitMapToCharters() }
            .onChange(of: charters.count) { _, _ in fitMapToCharters() }

            if let id = selectedCharterID,
               let charter = charters.first(where: { $0.id == id }) {
                CharterMapCallout(charter: charter) {
                    onSelectCharter(charter)
                } onDismiss: {
                    withAnimation { selectedCharterID = nil }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func fitMapToCharters() {
        guard !chartersWithLocation.isEmpty else { return }
        let lats = chartersWithLocation.compactMap { $0.latitude }
        let lons = chartersWithLocation.compactMap { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.4, 1.0),
                longitudeDelta: max((maxLon - minLon) * 1.4, 1.0)
            )
        )
        withAnimation { position = .region(region) }
    }
}

// MARK: - User avatar pin (discovery map)

struct UserAvatarPin: View {
    let charter: DiscoverableCharter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(ringColor)
                    .frame(width: isSelected ? 52 : 44)

                CachedAsyncImage(url: charter.captain.profileImageThumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: isSelected ? 22 : 18))
                }
                .frame(width: isSelected ? 44 : 36)
                .clipShape(Circle())

                if let badgeURL = charter.communityBadgeURL {
                    CachedAsyncImage(url: badgeURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        EmptyView()
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Charter: \(charter.name)")
        .accessibilityHint("Double tap to select")
    }

    private var ringColor: Color {
        if charter.communityBadgeURL != nil {
            return DesignSystem.Colors.communityAccent
        }
        return charter.urgencyLevel.mapPinColor
    }
}

// MARK: - Map Callout

private struct CharterMapCallout: View {
    let charter: DiscoverableCharter
    let onViewDetail: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(charter.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: 4) {
                        Text(charter.captain.username ?? "Captain")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        if charter.captain.isVirtualCaptain {
                            Text("·")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(DesignSystem.Typography.caption)
                            Text(L10n.Charter.Discovery.virtualCaptainBadge)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.communityAccent)
                        }
                    }

                    Text("•")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.caption)

                    Text(charter.dateRange)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            Button("View") {
                onViewDetail()
            }
            .buttonStyle(DesignSystem.PrimaryButtonStyle())
            .accessibilityHint("View full charter details")
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8)
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .font(.system(size: 20))
            }
            .padding(DesignSystem.Spacing.xs)
            .accessibilityLabel("Dismiss")
        }
    }
}

// MARK: - Urgency Level Map Color

private extension CharterUrgencyLevel {
    var mapPinColor: Color {
        switch self {
        case .past: return .gray
        case .ongoing: return .green
        case .imminent: return .red
        case .soon: return .orange
        case .future: return DesignSystem.Colors.primary
        }
    }
}
