import Foundation

// MARK: - Social link (API wire format)

struct SocialLinkAPIItem: Codable, Sendable, Hashable {
    let id: String
    let platform: String
    let handle: String

    func toSocialLink() -> SocialLink? {
        guard let p = SocialPlatform(rawValue: platform) else { return nil }
        return SocialLink(id: UUID(uuidString: id) ?? UUID(), platform: p, handle: handle)
    }
}

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
    let virtualCaptainId: UUID?

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
        case virtualCaptainId = "virtual_captain_id"
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
            locationPlaceID: locationPlaceId,
            onBehalfOfVirtualCaptainID: virtualCaptainId
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
    let communityBadgeUrl: String?

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
        case communityBadgeUrl = "community_badge_url"
    }

    func toDiscoverableCharter() -> DiscoverableCharter {
        let badgeURL = communityBadgeUrl.flatMap { s -> URL? in
            guard let url = URL(string: s), url.scheme != nil else { return nil }
            return url
        }
        return DiscoverableCharter(
            id: id,
            name: name,
            boatName: boatName,
            destination: locationText,
            startDate: startDate,
            endDate: endDate,
            latitude: latitude,
            longitude: longitude,
            distanceKm: distanceKm,
            captain: user.toCaptainBasicInfo(),
            communityBadgeURL: badgeURL
        )
    }
}

// MARK: - User Basic API Response

struct UserBasicAPIResponse: Codable {
    let id: UUID
    let username: String?
    let profileImageThumbnailUrl: String?
    let avatarUrl: String?
    let isVirtualCaptain: Bool
    let socialLinks: [SocialLinkAPIItem]

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
        case avatarUrl = "avatar_url"
        case isVirtualCaptain = "is_virtual_captain"
        case socialLinks = "social_links"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        profileImageThumbnailUrl = try c.decodeIfPresent(String.self, forKey: .profileImageThumbnailUrl)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isVirtualCaptain = try c.decodeIfPresent(Bool.self, forKey: .isVirtualCaptain) ?? false
        socialLinks = try c.decodeIfPresent([SocialLinkAPIItem].self, forKey: .socialLinks) ?? []
    }

    /// Test / preview convenience (legacy payloads without `avatar_url` / virtual-captain fields).
    init(
        id: UUID,
        username: String?,
        profileImageThumbnailUrl: String?,
        avatarUrl: String? = nil,
        isVirtualCaptain: Bool = false,
        socialLinks: [SocialLinkAPIItem] = []
    ) {
        self.id = id
        self.username = username
        self.profileImageThumbnailUrl = profileImageThumbnailUrl
        self.avatarUrl = avatarUrl
        self.isVirtualCaptain = isVirtualCaptain
        self.socialLinks = socialLinks
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(username, forKey: .username)
        try c.encodeIfPresent(profileImageThumbnailUrl, forKey: .profileImageThumbnailUrl)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encode(isVirtualCaptain, forKey: .isVirtualCaptain)
        if !socialLinks.isEmpty {
            try c.encode(socialLinks, forKey: .socialLinks)
        }
    }

    func toCaptainBasicInfo() -> CaptainBasicInfo {
        let urlString = avatarUrl ?? profileImageThumbnailUrl
        let thumb = urlString.flatMap { s -> URL? in
            guard let url = URL(string: s), url.scheme != nil, url.host != nil else { return nil }
            return url
        }
        let links = socialLinks.compactMap { $0.toSocialLink() }
        return CaptainBasicInfo(
            id: id,
            username: username,
            profileImageThumbnailURL: thumb,
            isVirtualCaptain: isVirtualCaptain,
            socialLinks: links
        )
    }
}
