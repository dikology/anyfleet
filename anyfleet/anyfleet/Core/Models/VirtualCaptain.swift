import Foundation

// MARK: - Virtual Captain

struct VirtualCaptain: Decodable, Identifiable, Hashable, Sendable {
    let id: UUID
    let communityId: UUID
    let displayName: String
    let avatarURL: URL?
    let avatarThumbnailURL: URL?
    let socialLinks: [SocialLink]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case avatarThumbnailURL = "avatar_thumbnail_url"
        case socialLinks = "social_links"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        communityId = try c.decode(UUID.self, forKey: .communityId)
        displayName = try c.decode(String.self, forKey: .displayName)
        avatarURL = try Self.decodeURL(c, key: .avatarURL)
        avatarThumbnailURL = try Self.decodeURL(c, key: .avatarThumbnailURL)
        let linkItems = try c.decodeIfPresent([SocialLinkAPIItem].self, forKey: .socialLinks) ?? []
        socialLinks = linkItems.compactMap { $0.toSocialLink() }
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    private static func decodeURL(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> URL? {
        guard let s = try c.decodeIfPresent(String.self, forKey: key),
              let url = URL(string: s),
              url.scheme != nil,
              url.host != nil
        else { return nil }
        return url
    }

    /// Memberwise initializer for previews and tests (decoding remains the production path).
    init(
        id: UUID,
        communityId: UUID,
        displayName: String,
        avatarURL: URL?,
        avatarThumbnailURL: URL?,
        socialLinks: [SocialLink],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.communityId = communityId
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.avatarThumbnailURL = avatarThumbnailURL
        self.socialLinks = socialLinks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Managed Community

struct ManagedCommunity: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let slug: String
    let iconURL: URL?
    let memberCount: Int
    let virtualCaptainCount: Int
    let assignedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case iconURL = "icon_url"
        case memberCount = "member_count"
        case virtualCaptainCount = "virtual_captain_count"
        case assignedAt = "assigned_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        slug = try c.decode(String.self, forKey: .slug)
        if let s = try c.decodeIfPresent(String.self, forKey: .iconURL),
           let url = URL(string: s),
           url.scheme != nil {
            iconURL = url
        } else {
            iconURL = nil
        }
        memberCount = try c.decode(Int.self, forKey: .memberCount)
        virtualCaptainCount = try c.decode(Int.self, forKey: .virtualCaptainCount)
        assignedAt = try c.decode(Date.self, forKey: .assignedAt)
    }

    /// Memberwise initializer for previews and tests (decoding remains the production path).
    init(
        id: UUID,
        name: String,
        slug: String,
        iconURL: URL?,
        memberCount: Int,
        virtualCaptainCount: Int,
        assignedAt: Date
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.iconURL = iconURL
        self.memberCount = memberCount
        self.virtualCaptainCount = virtualCaptainCount
        self.assignedAt = assignedAt
    }
}

struct VirtualCaptainListResponse: Decodable, Sendable {
    let items: [VirtualCaptain]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Community API (icon upload response)

struct CommunityAPIResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let slug: String
    let description: String?
    let iconURL: URL?
    let communityType: String
    let memberCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case iconURL = "icon_url"
        case communityType = "community_type"
        case memberCount = "member_count"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        slug = try c.decode(String.self, forKey: .slug)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        communityType = try c.decode(String.self, forKey: .communityType)
        memberCount = try c.decode(Int.self, forKey: .memberCount)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        if let s = try c.decodeIfPresent(String.self, forKey: .iconURL),
           let url = URL(string: s),
           url.scheme != nil {
            iconURL = url
        } else {
            iconURL = nil
        }
    }

    init(
        id: UUID,
        name: String,
        slug: String,
        description: String?,
        iconURL: URL?,
        communityType: String,
        memberCount: Int,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.iconURL = iconURL
        self.communityType = communityType
        self.memberCount = memberCount
        self.createdAt = createdAt
    }
}
