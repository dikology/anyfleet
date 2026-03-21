import Foundation
import CoreLocation

// MARK: - Discoverable Charter (from API discovery endpoint)

/// A charter shared publicly and returned from the discovery API.
/// Distinct from the local `CharterModel` — this is a read-only view of
/// another user's public charter, enriched with captain info and distance.
struct DiscoverableCharter: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let boatName: String?
    let destination: String?
    let startDate: Date
    let endDate: Date
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let captain: CaptainBasicInfo
    let communityBadgeURL: URL?
    /// Display name for the managing community when `communityBadgeURL` is set (optional until API provides it).
    let communityName: String?

    init(
        id: UUID,
        name: String,
        boatName: String?,
        destination: String?,
        startDate: Date,
        endDate: Date,
        latitude: Double?,
        longitude: Double?,
        distanceKm: Double?,
        captain: CaptainBasicInfo,
        communityBadgeURL: URL? = nil,
        communityName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.boatName = boatName
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.latitude = latitude
        self.longitude = longitude
        self.distanceKm = distanceKm
        self.captain = captain
        self.communityBadgeURL = communityBadgeURL
        self.communityName = communityName
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var daysUntilStart: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }

    var urgencyLevel: CharterUrgencyLevel {
        let now = Date()
        // Past = charter has already finished
        if endDate < now { return .past }
        // Ongoing = started but not finished
        if startDate <= now { return .ongoing }
        // Future = not yet started
        switch daysUntilStart {
        case 0...7: return .imminent   // Starts this week
        case 8...30: return .soon
        default: return .future
        }
    }

    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

// MARK: - Captain Basic Info

struct CaptainBasicInfo: Hashable, Sendable {
    let id: UUID
    let username: String?
    let profileImageThumbnailURL: URL?
    let isVirtualCaptain: Bool
    let socialLinks: [SocialLink]

    init(
        id: UUID,
        username: String?,
        profileImageThumbnailURL: URL?,
        isVirtualCaptain: Bool = false,
        socialLinks: [SocialLink] = []
    ) {
        self.id = id
        self.username = username
        self.profileImageThumbnailURL = profileImageThumbnailURL
        self.isVirtualCaptain = isVirtualCaptain
        self.socialLinks = socialLinks
    }
}

// MARK: - Urgency Level

enum CharterUrgencyLevel {
    case past
    case ongoing    // Started but not finished
    case imminent   // Starts within 7 days
    case soon       // Starts within 30 days
    case future     // More than 30 days away
}
