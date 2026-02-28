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
        switch daysUntilStart {
        case ..<0: return .past
        case 0...7: return .imminent
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
}

// MARK: - Urgency Level

enum CharterUrgencyLevel {
    case past
    case imminent   // Within 7 days
    case soon       // Within 30 days
    case future     // More than 30 days away
}

// MARK: - API Response Models

struct CharterAPIResponse: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let boatName: String?
    let locationText: String?
    let startDate: Date
    let endDate: Date
    let latitude: Double?
    let longitude: Double?
    let locationPlaceId: String?
    let visibility: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case latitude
        case longitude
        case locationPlaceId = "location_place_id"
        case visibility
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toCharterModel() -> CharterModel {
        CharterModel(
            id: id,
            name: name,
            boatName: boatName,
            location: locationText,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            checkInChecklistID: nil,
            serverID: id,
            visibility: CharterVisibility(rawValue: visibility) ?? .private,
            needsSync: false,
            lastSyncedAt: updatedAt,
            latitude: latitude,
            longitude: longitude,
            locationPlaceID: locationPlaceId
        )
    }
}

struct CharterDiscoveryAPIResponse: Codable {
    let items: [CharterWithUserAPIResponse]
    let total: Int
    let limit: Int
    let offset: Int
}

struct CharterWithUserAPIResponse: Codable {
    let id: UUID
    let name: String
    let boatName: String?
    let locationText: String?
    let startDate: Date
    let endDate: Date
    let latitude: Double?
    let longitude: Double?
    let visibility: String
    let user: UserBasicAPIResponse
    let distanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case latitude
        case longitude
        case visibility
        case user
        case distanceKm = "distance_km"
    }

    func toDiscoverableCharter() -> DiscoverableCharter {
        DiscoverableCharter(
            id: id,
            name: name,
            boatName: boatName,
            destination: locationText,
            startDate: startDate,
            endDate: endDate,
            latitude: latitude,
            longitude: longitude,
            distanceKm: distanceKm,
            captain: user.toCaptainBasicInfo()
        )
    }
}

struct UserBasicAPIResponse: Codable {
    let id: UUID
    let username: String?
    let profileImageThumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
    }

    func toCaptainBasicInfo() -> CaptainBasicInfo {
        CaptainBasicInfo(
            id: id,
            username: username,
            profileImageThumbnailURL: profileImageThumbnailUrl.flatMap { urlString in
                // URL(string:) percent-encodes invalid strings rather than returning nil,
                // so validate that the result has a scheme and host before accepting it.
                guard let url = URL(string: urlString),
                      url.scheme != nil,
                      url.host != nil
                else { return nil }
                return url
            }
        )
    }
}

// MARK: - Create/Update Request Models

struct CharterCreateRequest: Encodable {
    let name: String
    let boatName: String?
    let locationText: String?
    let startDate: Date
    let endDate: Date
    let visibility: String
    let latitude: Double?
    let longitude: Double?
    let locationPlaceId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case visibility
        case latitude
        case longitude
        case locationPlaceId = "location_place_id"
    }
}

struct CharterUpdateRequest: Encodable {
    let name: String?
    let boatName: String?
    let locationText: String?
    let startDate: Date?
    let endDate: Date?
    let visibility: String?
    let latitude: Double?
    let longitude: Double?
    let locationPlaceId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case visibility
        case latitude
        case longitude
        case locationPlaceId = "location_place_id"
    }
}

struct CharterListAPIResponse: Codable {
    let items: [CharterAPIResponse]
    let total: Int
    let limit: Int
    let offset: Int
}
