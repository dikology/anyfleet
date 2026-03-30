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
        ZStack {
            Map(position: $position, selection: $selectedCharterID) {
                ForEach(chartersWithLocation) { charter in
                    if let coordinate = charter.coordinate {
                        Annotation(charter.name, coordinate: coordinate, anchor: .bottom) {
                            UserAvatarPin(
                                charter: charter,
                                isSelected: selectedCharterID == charter.id
                            ) {
                                withAnimation(DesignSystem.Motion.spring) {
                                    selectedCharterID = charter.id
                                }
                            }
                        }
                        .tag(charter.id)
                    }
                }
            }
            .mapStyle(
                .standard(
                    pointsOfInterest: .excluding([.restaurant, .cafe, .hotel]),
                    showsTraffic: false
                )
            )
            .ignoresSafeArea(edges: .top)
            .onAppear { fitMapToCharters() }
            .onChange(of: charters.count) { _, _ in fitMapToCharters() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let id = selectedCharterID,
                   let charter = charters.first(where: { $0.id == id }) {
                    CharterMapCallout(charter: charter) {
                        onSelectCharter(charter)
                    } onDismiss: {
                        withAnimation(DesignSystem.Motion.spring) {
                            selectedCharterID = nil
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            mapTopScrim

            if chartersWithLocation.isEmpty {
                mapEmptyOverlay
            }
        }
    }

    /// Fades map content under the navigation header so tiles and POIs read less busy.
    private var mapTopScrim: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background.opacity(0.94),
                    DesignSystem.Colors.background.opacity(0.5),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    private var mapEmptyOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "map.fill")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.primary)

            Text(L10n.Charter.Discovery.mapEmptyTitle)
                .font(DesignSystem.Typography.subheader)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.Charter.Discovery.mapEmptySubtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: 320)
        .glassPanel()
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadiusLarge, style: .continuous))
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
        withAnimation(DesignSystem.Motion.spring) { position = .region(region) }
    }
}

// MARK: - Pin needle (map anchor)

private struct MapPinNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - User avatar pin (discovery map)

struct UserAvatarPin: View {
    let charter: DiscoverableCharter
    let isSelected: Bool
    let onTap: () -> Void

    private var outerRing: CGFloat { isSelected ? 60 : 48 }
    private var avatarSize: CGFloat { isSelected ? 52 : 40 }
    private var hasCommunity: Bool { charter.communityBadgeURL != nil }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    if hasCommunity {
                        Circle()
                            .stroke(DesignSystem.Colors.communityAccent, lineWidth: 3)
                            .frame(width: outerRing + 6, height: outerRing + 6)
                    }

                    Circle()
                        .fill(charter.urgencyLevel.mapPinColor)
                        .frame(width: outerRing, height: outerRing)

                    avatarContent
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())

                    if let badgeURL = charter.communityBadgeURL {
                        CachedAsyncImage(url: badgeURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.communityAccent.opacity(0.85))
                                Image(systemName: "sailboat.fill")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 5, y: 5)
                    }
                }

                MapPinNeedle()
                    .fill(charter.urgencyLevel.mapPinColor)
                    .frame(width: 6, height: 8)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .animation(DesignSystem.Motion.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Charter: \(charter.name)")
        .accessibilityHint("Double tap to select")
    }

    @ViewBuilder
    private var avatarContent: some View {
        CachedAsyncImage(url: charter.captain.profileImageThumbnailURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.hashColor(for: charter.captain.id.uuidString))
                Text(captainMonogram)
                    .font(DesignSystem.Typography.subheader)
                    .foregroundStyle(.white)
            }
        }
    }

    private var captainMonogram: String {
        let name = charter.captain.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }
}

// MARK: - Map Callout

private struct CharterMapCallout: View {
    let charter: DiscoverableCharter
    let onViewDetail: () -> Void
    let onDismiss: () -> Void

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var calloutRingColor: Color {
        if charter.communityBadgeURL != nil {
            return DesignSystem.Colors.communityAccent
        }
        return charter.urgencyLevel.mapPinColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Capsule()
                .fill(DesignSystem.Colors.textSecondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, DesignSystem.Spacing.xs)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                CharterMapCalloutAvatar(
                    captain: charter.captain,
                    ringColor: calloutRingColor,
                    diameter: 52
                )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(charter.captain.username ?? L10n.Charter.Discovery.captainFallback)
                        .font(DesignSystem.Typography.subheader)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if charter.communityBadgeURL != nil {
                        communityRow
                    }
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.title)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            Divider()
                .background(DesignSystem.Colors.border)

            calloutDetailRow(icon: "paperplane") {
                Text(charterDisplayDestination)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            calloutDetailRow(icon: "calendar") {
                HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                    Text(Self.shortDateFormatter.string(from: charter.startDate))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text(Self.shortDateFormatter.string(from: charter.endDate))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text(L10n.Charter.Discovery.durationDays(charter.durationDays))
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(DesignSystem.Colors.vesselAccent.opacity(0.22))
                        .clipShape(Capsule())
                }
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onViewDetail) {
                HStack {
                    Text(L10n.homeViewCharter)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(DesignSystem.PrimaryButtonStyle())
        }
        .accessibilityHint(L10n.Charter.Discovery.mapCalloutSwipeHint)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    if value.translation.height < -50 {
                        onViewDetail()
                    }
                }
        )
        .padding(DesignSystem.Spacing.md)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                DesignSystem.Colors.surface.opacity(0.55)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: DesignSystem.Spacing.cardCornerRadiusLarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DesignSystem.Spacing.cardCornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: DesignSystem.Spacing.cardCornerRadiusLarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DesignSystem.Spacing.cardCornerRadiusLarge,
                style: .continuous
            )
            .stroke(DesignSystem.Colors.border.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: -4)
    }

    @ViewBuilder
    private var communityRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let url = charter.communityBadgeURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.communityAccent.opacity(0.85))
                        Image(systemName: "sailboat.fill")
                            .font(DesignSystem.Typography.micro)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 18, height: 18)
                .clipShape(Circle())
            }

            HStack(spacing: 0) {
                Text(charter.communityName ?? L10n.Charter.Discovery.mapCommunityFallback)
                    .foregroundStyle(DesignSystem.Colors.communityAccent)
                if charter.captain.isVirtualCaptain {
                    Text(" · ")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text(L10n.Charter.Discovery.virtualCaptainBadge)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .font(DesignSystem.Typography.caption)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(2)
        }
    }

    private var charterDisplayDestination: String {
        if let d = charter.destination, !d.isEmpty { return d }
        return charter.name
    }

    @ViewBuilder
    private func calloutDetailRow<C: View>(icon: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 22, height: 22, alignment: .center)
            content()
        }
    }
}

// MARK: - Callout avatar

private struct CharterMapCalloutAvatar: View {
    let captain: CaptainBasicInfo
    var ringColor: Color = DesignSystem.Colors.primary
    var diameter: CGFloat = 52

    private var monogram: String {
        let name = captain.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let c = name.first else { return "?" }
        return String(c).uppercased()
    }

    var body: some View {
        CachedAsyncImage(url: captain.profileImageThumbnailURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.hashColor(for: captain.id.uuidString))
                Text(monogram)
                    .font(DesignSystem.Typography.subheader)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(ringColor, lineWidth: 2)
        )
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

// MARK: - Mock data (previews & design review)

enum CharterMapPreviewData {
    /// RFC-4122 strings must be `8-4-4-4-12` hex; a typo in the last group (e.g. 16 digits) makes `UUID(uuidString:)` nil and was crashing previews/runtime.
    private static func uuid(_ string: String) -> UUID {
        if let u = UUID(uuidString: string) { return u }
        assertionFailure("Invalid preview UUID literal: \(string)")
        return UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    }

    static let marcoID = uuid("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
    static let alexeyID = uuid("BBBBBBBB-BBBB-BCCC-BDDD-BBBBBBBBBBBB")
    static let soloID = uuid("CCCCCCCC-DDDD-EEEE-FFFF-000000000001")

    static var mockCharters: [DiscoverableCharter] {
        let cal = Calendar.current
        let now = Date()
        let may1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 1)) ?? now
        let may8 = cal.date(from: DateComponents(year: 2026, month: 5, day: 8)) ?? now.addingTimeInterval(86400 * 7)

        let communityBadge = URL(string: "https://picsum.photos/seed/anyfleet-badge/64/64")

        let marco = DiscoverableCharter(
            id: uuid("11111111-1111-1111-1111-111111111111"),
            name: "Spring Racing Week",
            boatName: "Zephyr",
            destination: "Seychelles",
            startDate: may1,
            endDate: may8,
            latitude: -4.62,
            longitude: 55.45,
            distanceKm: 120,
            captain: CaptainBasicInfo(
                id: marcoID,
                username: "Marco Rossi",
                profileImageThumbnailURL: nil,
                isVirtualCaptain: true
            ),
            communityBadgeURL: communityBadge,
            communityName: "RBYC Racing School"
        )

        let alexey = DiscoverableCharter(
            id: uuid("22222222-2222-2222-2222-222222222222"),
            name: "Croatia island hop",
            boatName: "Bora",
            destination: "Split · Hvar",
            startDate: now.addingTimeInterval(86400 * 14),
            endDate: now.addingTimeInterval(86400 * 21),
            latitude: 43.51,
            longitude: 16.44,
            distanceKm: 45,
            captain: CaptainBasicInfo(
                id: alexeyID,
                username: "Рунов Алексей",
                profileImageThumbnailURL: nil,
                isVirtualCaptain: false
            ),
            communityBadgeURL: nil,
            communityName: nil
        )

        let solo = DiscoverableCharter(
            id: uuid("33333333-3333-3333-3333-333333333333"),
            name: "Weekend sail",
            boatName: "Dawn Treader",
            destination: "Barcelona",
            startDate: now.addingTimeInterval(86400 * 3),
            endDate: now.addingTimeInterval(86400 * 5),
            latitude: 41.39,
            longitude: 2.16,
            distanceKm: 8,
            captain: CaptainBasicInfo(
                id: soloID,
                username: "nina.sails",
                profileImageThumbnailURL: URL(string: "https://picsum.photos/seed/captain-nina/80/80"),
                isVirtualCaptain: false
            ),
            communityBadgeURL: nil,
            communityName: nil
        )

        return [marco, alexey, solo]
    }
}

// MARK: - Previews

#Preview("Discovery map — mock charters") {
    CharterMapView(charters: CharterMapPreviewData.mockCharters) { _ in }
        .frame(height: 520)
}

#Preview("Map callout card") {
    CharterMapView(charters: [CharterMapPreviewData.mockCharters[0]]) { _ in }
        .frame(height: 400)
}

#Preview("UserAvatarPin states") {
    HStack(spacing: 32) {
        UserAvatarPin(charter: CharterMapPreviewData.mockCharters[0], isSelected: false) {}
        UserAvatarPin(charter: CharterMapPreviewData.mockCharters[0], isSelected: true) {}
        UserAvatarPin(charter: CharterMapPreviewData.mockCharters[2], isSelected: false) {}
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
