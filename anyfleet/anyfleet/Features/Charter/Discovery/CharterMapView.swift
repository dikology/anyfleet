import SwiftUI
import MapKit

// MARK: - Charter Cluster Model

struct CharterCluster: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let charters: [DiscoverableCharter]
    var isSingleton: Bool { charters.count == 1 }
}

// MARK: - Charter Map View

struct CharterMapView: View {
    let charters: [DiscoverableCharter]
    let onSelectCharter: (DiscoverableCharter) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedClusterID: UUID?
    @State private var clusters: [CharterCluster] = []
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)

    private var chartersWithLocation: [DiscoverableCharter] {
        charters.filter { $0.hasLocation }
    }

    private var selectedCluster: CharterCluster? {
        guard let id = selectedClusterID else { return nil }
        return clusters.first(where: { $0.id == id })
    }

    /// Standard map tiles follow the app `colorScheme`. `emphasis: .muted` in dark mode
    /// further subdues POI/road emphasis so teal/gold pins read clearly. (MapKit’s
    /// `MapStyle.standard` has no separate `colorScheme:` parameter in SwiftUI.)
    private var discoveryMapStyle: MapStyle {
        let excludedPOI = PointOfInterestCategories.excluding([.restaurant, .cafe, .hotel])
        switch colorScheme {
        case .dark:
            return .standard(
                emphasis: .muted,
                pointsOfInterest: excludedPOI,
                showsTraffic: false
            )
        case .light:
            return .standard(
                pointsOfInterest: excludedPOI,
                showsTraffic: false
            )
        @unknown default:
            return .standard(
                pointsOfInterest: excludedPOI,
                showsTraffic: false
            )
        }
    }

    var body: some View {
        ZStack {
            Map(position: $position, selection: $selectedClusterID) {
                ForEach(clusters) { cluster in
                    Annotation("", coordinate: cluster.coordinate, anchor: .bottom) {
                        if cluster.isSingleton {
                            UserAvatarPin(
                                charter: cluster.charters[0],
                                isSelected: selectedClusterID == cluster.id
                            ) {
                                print("[MapCluster] tapped singleton cluster=\(cluster.id.uuidString.prefix(8))")
                                withAnimation(DesignSystem.Motion.spring) {
                                    selectedClusterID = cluster.id
                                }
                            }
                        } else {
                            ClusterPin(
                                cluster: cluster,
                                isSelected: selectedClusterID == cluster.id
                            ) {
                                print("[MapCluster] tapped multi-cluster=\(cluster.id.uuidString.prefix(8)) count=\(cluster.charters.count)")
                                withAnimation(DesignSystem.Motion.spring) {
                                    selectedClusterID = cluster.id
                                }
                            }
                        }
                    }
                    .tag(cluster.id)
                }
            }
            .mapStyle(discoveryMapStyle)
            .ignoresSafeArea(edges: .top)
            .onMapCameraChange(frequency: .onEnd) { context in
                let newSpan = context.region.span
                guard newSpan.latitudeDelta > 0 else { return }
                // Mirror actual camera into the position binding so re-renders never snap back.
                position = .region(context.region)
                let relativeChange = abs(newSpan.latitudeDelta - mapSpan.latitudeDelta) / mapSpan.latitudeDelta
                print("[MapCluster] cameraChange span=\(String(format: "%.4f", newSpan.latitudeDelta))° relChange=\(String(format: "%.2f", relativeChange))")
                if relativeChange > 0.1 {
                    mapSpan = newSpan
                    rebuildClusters(reason: "cameraChange")
                }
            }
            .onAppear {
                fitMapToCharters()
                rebuildClusters(reason: "onAppear")
            }
            .onChange(of: charters.count) { _, _ in
                fitMapToCharters()
                rebuildClusters(reason: "chartersCountChanged(\(charters.count))")
            }
            .onChange(of: selectedClusterID) { old, new in
                let oldStr = old.map { String($0.uuidString.prefix(8)) } ?? "nil"
                let newStr = new.map { String($0.uuidString.prefix(8)) } ?? "nil"
                print("[MapCluster] selection \(oldStr) → \(newStr)")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let cluster = selectedCluster {
                    Group {
                        if cluster.isSingleton {
                            CharterMapCallout(charter: cluster.charters[0]) {
                                onSelectCharter(cluster.charters[0])
                            } onDismiss: {
                                withAnimation(DesignSystem.Motion.spring) { selectedClusterID = nil }
                            }
                        } else {
                            CharterClusterSheet(cluster: cluster) { charter in
                                onSelectCharter(charter)
                            } onDismiss: {
                                withAnimation(DesignSystem.Motion.spring) { selectedClusterID = nil }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    // Clear the app-level FloatingTabBar overlay (Map inset may not inherit floatingTabBarPadding).
                    .padding(.bottom, FloatingTabBar.safeAreaInset + DesignSystem.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            mapTopScrim

            if chartersWithLocation.isEmpty {
                mapEmptyOverlay
            }
        }
    }

    private func rebuildClusters(reason: String = "") {
        let raw = buildClusters(charters: chartersWithLocation, span: mapSpan)

        // Stabilise IDs: reuse an existing cluster's UUID when its charter membership
        // is identical to a new cluster. This prevents Map(selection:) from clearing
        // the selection whenever cluster objects are recreated with fresh UUIDs.
        let stabilised: [CharterCluster] = raw.map { newCluster in
            let newIDs = Set(newCluster.charters.map { $0.id })
            if let match = clusters.first(where: { Set($0.charters.map { $0.id }) == newIDs }) {
                return CharterCluster(id: match.id, coordinate: newCluster.coordinate, charters: newCluster.charters)
            }
            return newCluster
        }

        let selectionSurvives = selectedClusterID.map { id in stabilised.contains(where: { $0.id == id }) } ?? true
        print("[MapCluster] rebuildClusters(\(reason)) raw=\(raw.count) stabilised=\(stabilised.count) selectionSurvives=\(selectionSurvives)")

        if !selectionSurvives {
            print("[MapCluster] ⚠️ selection lost — cluster split or merged after rebuild")
            withAnimation(DesignSystem.Motion.spring) { selectedClusterID = nil }
        }
        clusters = stabilised
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

// MARK: - Client-side clustering

/// Groups charters whose lat/lon are within a dynamic threshold proportional to the
/// current map span. Clusters split naturally when the user zooms in.
private func buildClusters(
    charters: [DiscoverableCharter],
    span: MKCoordinateSpan
) -> [CharterCluster] {
    // Floor at 0.001° (~110 m) so fully-zoomed pins never merge when co-located.
    let threshold = max(span.latitudeDelta * 0.02, 0.001)
    var clusters: [CharterCluster] = []

    for charter in charters {
        guard let coord = charter.coordinate else { continue }
        if let i = clusters.firstIndex(where: {
            abs($0.coordinate.latitude - coord.latitude) < threshold &&
            abs($0.coordinate.longitude - coord.longitude) < threshold
        }) {
            // Merge into existing cluster, recomputing centroid incrementally.
            let existing = clusters[i]
            let count = Double(existing.charters.count)
            let centroid = CLLocationCoordinate2D(
                latitude: (existing.coordinate.latitude * count + coord.latitude) / (count + 1),
                longitude: (existing.coordinate.longitude * count + coord.longitude) / (count + 1)
            )
            clusters[i] = CharterCluster(
                id: existing.id,
                coordinate: centroid,
                charters: existing.charters + [charter]
            )
        } else {
            clusters.append(CharterCluster(id: UUID(), coordinate: coord, charters: [charter]))
        }
    }
    return clusters
}

// MARK: - User avatar pin (discovery map)

struct UserAvatarPin: View {
    let charter: DiscoverableCharter
    let isSelected: Bool
    let onTap: () -> Void

    /// Fixed layout size; selection uses `scaleEffect` (44 → 52 pt) to avoid layout thrashing.
    private let outerSize: CGFloat = 44
    private let avatarSize: CGFloat = 34
    private let communityBadgeSize: CGFloat = 28
    private var hasCommunity: Bool { charter.communityBadgeURL != nil }

    private var pinBackgroundColor: Color {
        hasCommunity
            ? DesignSystem.Colors.communityAccent.opacity(0.2)
            : DesignSystem.Colors.primary.opacity(0.15)
    }

    private var selectionScale: CGFloat { isSelected ? 52.0 / 44.0 : 1.0 }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(pinBackgroundColor)
                        .frame(width: outerSize, height: outerSize)
                        .overlay {
                            if hasCommunity {
                                Circle()
                                    .stroke(DesignSystem.Colors.communityAccent, lineWidth: 2.5)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            urgencyRingDot
                                .offset(x: 2, y: -2)
                        }

                    avatarContent
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                }
                .frame(width: outerSize, height: outerSize)

                if let badgeURL = charter.communityBadgeURL {
                    communityBadge(url: badgeURL)
                        .offset(x: 6, y: 6)
                }
            }
            .frame(width: outerSize, height: outerSize)
            .shadow(
                color: isSelected ? DesignSystem.Colors.primary.opacity(0.35) : .black.opacity(0.22),
                radius: isSelected ? 10 : 5,
                x: 0,
                y: isSelected ? 3 : 2
            )
            .scaleEffect(selectionScale)
            .animation(DesignSystem.Motion.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double tap to select")
    }

    /// Urgency encoded as a small dot on the outer ring (top-trailing), distinct from the community badge.
    private var urgencyRingDot: some View {
        Circle()
            .fill(charter.urgencyLevel.mapPinColor)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func communityBadge(url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
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
        .frame(width: communityBadgeSize, height: communityBadgeSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
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

    private var accessibilityLabelText: String {
        "Charter: \(charter.name), \(charter.urgencyLevel.mapPinAccessibilityLabel)"
    }
}

// MARK: - Cluster pin

struct ClusterPin: View {
    let cluster: CharterCluster
    let isSelected: Bool
    let onTap: () -> Void

    private let avatarDiam: CGFloat = 18
    private let avatarOffset: CGFloat = 11
    private var outerSize: CGFloat { isSelected ? 64 : 52 }

    /// Show a "+" indicator instead of a 3rd full avatar when there are more than 3 charters.
    private var showPlusIndicator: Bool { cluster.charters.count > 3 }

    private var visibleCharters: [DiscoverableCharter] {
        showPlusIndicator
            ? Array(cluster.charters.prefix(2))
            : Array(cluster.charters.prefix(3))
    }

    private var avatarStackWidth: CGFloat {
        let slots = visibleCharters.count + (showPlusIndicator ? 1 : 0)
        return avatarDiam + CGFloat(max(0, slots - 1)) * avatarOffset
    }

    /// Community accent when every charter in the cluster shares the same community; brand primary otherwise.
    private var ringColor: Color {
        let communityURLs = cluster.charters.compactMap { $0.communityBadgeURL?.absoluteString }
        let sharedCommunity = !communityURLs.isEmpty && Set(communityURLs).count == 1
        return sharedCommunity ? DesignSystem.Colors.communityAccent : DesignSystem.Colors.primary
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.surface)
                    Circle()
                        .stroke(ringColor, lineWidth: isSelected ? 3 : 2)
                    ZStack(alignment: .leading) {
                        ForEach(Array(visibleCharters.enumerated()), id: \.element.id) { idx, charter in
                            avatarCircle(for: charter)
                                .offset(x: CGFloat(idx) * avatarOffset)
                                .zIndex(Double(visibleCharters.count - idx))
                        }
                        if showPlusIndicator {
                            plusIndicator
                                .offset(x: CGFloat(visibleCharters.count) * avatarOffset)
                                .zIndex(0)
                        }
                    }
                    .frame(width: avatarStackWidth, height: avatarDiam)
                }
                .frame(width: outerSize, height: outerSize)

                countBadge
                    .offset(x: 5, y: -5)
            }
            .shadow(
                color: .black.opacity(isSelected ? 0.25 : 0.15),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(DesignSystem.Motion.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cluster.charters.count) charters in this area")
        .accessibilityHint("Double tap to see all")
    }

    private func avatarCircle(for charter: DiscoverableCharter) -> some View {
        CachedAsyncImage(url: charter.captain.profileImageThumbnailURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(DesignSystem.Colors.hashColor(for: charter.captain.id.uuidString))
                Text(avatarMonogram(for: charter.captain))
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: avatarDiam, height: avatarDiam)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
    }

    private var plusIndicator: some View {
        ZStack {
            Circle().fill(DesignSystem.Colors.surfaceAlt)
            Image(systemName: "plus")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(width: avatarDiam, height: avatarDiam)
        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
    }

    private var countBadge: some View {
        ZStack {
            Circle().fill(DesignSystem.Colors.gold)
            Text("\(cluster.charters.count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.75))
        }
        .frame(width: 18, height: 18)
        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
    }

    private func avatarMonogram(for captain: CaptainBasicInfo) -> String {
        let name = captain.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

// MARK: - Charter Cluster Sheet

private struct CharterClusterSheet: View {
    let cluster: CharterCluster
    let onSelectCharter: (DiscoverableCharter) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(DesignSystem.Colors.textSecondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, DesignSystem.Spacing.xs)
                .accessibilityHidden(true)

            HStack(alignment: .center) {
                Text(headerTitle)
                    .font(DesignSystem.Typography.subheader)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.title)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xs)

            Divider()
                .background(DesignSystem.Colors.border)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(cluster.charters) { charter in
                        CharterClusterSheetRow(charter: charter) {
                            onSelectCharter(charter)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        if charter.id != cluster.charters.last?.id {
                            Divider()
                                .background(DesignSystem.Colors.border)
                                // Indent to align with text, past the avatar column.
                                .padding(.leading, DesignSystem.Spacing.md + 36 + DesignSystem.Spacing.sm)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .frame(maxHeight: 260)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    if value.translation.height > 50 { onDismiss() }
                }
        )
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
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

    private var headerTitle: String {
        let count = cluster.charters.count
        return "\(count) charter\(count == 1 ? "" : "s") in \(areaName)"
    }

    /// Most frequently appearing destination among cluster members, or "this area" if none.
    private var areaName: String {
        let destinations = cluster.charters
            .compactMap { $0.destination?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !destinations.isEmpty else { return "this area" }
        let counts = Dictionary(grouping: destinations, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "this area"
    }
}

private struct CharterClusterSheetRow: View {
    let charter: DiscoverableCharter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                CharterMapCalloutAvatar(captain: charter.captain, ringColor: ringColor, diameter: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(charter.captain.username ?? L10n.Charter.Discovery.captainFallback)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let dest = charter.destination, !dest.isEmpty {
                            Text(dest).lineLimit(1)
                            Text("·")
                        }
                        Text(charter.dateRange).lineLimit(1)
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var ringColor: Color {
        charter.communityBadgeURL != nil
            ? DesignSystem.Colors.communityAccent
            : charter.urgencyLevel.mapPinColor
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = []
        if let name = charter.captain.username { parts.append(name) }
        parts.append(charter.dateRange)
        if let dest = charter.destination, !dest.isEmpty { parts.append("in \(dest)") }
        return parts.joined(separator: ", ")
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

    /// Localized urgency for map pin accessibility (matches discovery row badges).
    var mapPinAccessibilityLabel: String {
        switch self {
        case .past: return L10n.Charter.Discovery.Badge.past
        case .ongoing: return L10n.Charter.Discovery.Badge.ongoing
        case .imminent: return L10n.Charter.Discovery.Badge.imminent
        case .soon: return L10n.Charter.Discovery.Badge.soon
        case .future: return L10n.Charter.Discovery.Badge.upcoming
        }
    }
}

#if DEBUG
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

    /// Two extra charters near Split so the preview map shows a cluster pin.
    static var mockChartersWithCluster: [DiscoverableCharter] {
        let now = Date()
        let maria = DiscoverableCharter(
            id: uuid("44444444-4444-4444-4444-444444444444"),
            name: "Adriatic Escape",
            boatName: "Levantin",
            destination: "Split · Hvar",
            startDate: now.addingTimeInterval(86400 * 12),
            endDate: now.addingTimeInterval(86400 * 19),
            latitude: 43.515,
            longitude: 16.443,
            distanceKm: 46,
            captain: CaptainBasicInfo(
                id: uuid("55555555-5555-5555-5555-555555555555"),
                username: "Maria Kovac",
                profileImageThumbnailURL: URL(string: "https://picsum.photos/seed/captain-maria/80/80"),
                isVirtualCaptain: false
            ),
            communityBadgeURL: nil,
            communityName: nil
        )
        let tomaz = DiscoverableCharter(
            id: uuid("66666666-6666-6666-6666-666666666666"),
            name: "Blue Cave expedition",
            boatName: "Vjetar",
            destination: "Split · Hvar",
            startDate: now.addingTimeInterval(86400 * 16),
            endDate: now.addingTimeInterval(86400 * 23),
            latitude: 43.508,
            longitude: 16.447,
            distanceKm: 47,
            captain: CaptainBasicInfo(
                id: uuid("77777777-7777-7777-7777-777777777777"),
                username: "Tomaž Novak",
                profileImageThumbnailURL: nil,
                isVirtualCaptain: false
            ),
            communityBadgeURL: nil,
            communityName: nil
        )
        return mockCharters + [maria, tomaz]
    }

    /// A pre-built cluster for component previews.
    static var mockCluster: CharterCluster {
        let charters = Array(mockChartersWithCluster.filter { $0.destination == "Split · Hvar" })
        return CharterCluster(
            id: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: 43.511, longitude: 16.443),
            charters: charters
        )
    }
}

// MARK: - Previews

#Preview("Discovery map — scattered pins") {
    CharterMapView(charters: CharterMapPreviewData.mockCharters) { _ in }
        .frame(height: 520)
}

#Preview("Discovery map — with cluster") {
    CharterMapView(charters: CharterMapPreviewData.mockChartersWithCluster) { _ in }
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

#Preview("ClusterPin states") {
    let cluster = CharterMapPreviewData.mockCluster
    HStack(spacing: 32) {
        ClusterPin(cluster: cluster, isSelected: false) {}
        ClusterPin(cluster: cluster, isSelected: true) {}
    }
    .padding(40)
    .background(DesignSystem.Colors.background)
}

#Preview("CharterClusterSheet") {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.2).ignoresSafeArea()
        CharterClusterSheet(
            cluster: CharterMapPreviewData.mockCluster,
            onSelectCharter: { _ in },
            onDismiss: {}
        )
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}
#endif
