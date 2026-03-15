import Foundation

// MARK: - Charter API Response

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
            updatedAt: updatedAt,
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

// MARK: - Charter With User API Response

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

// MARK: - User Basic API Response

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
