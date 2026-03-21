import Foundation

// MARK: - Social Links

struct SocialLink: Codable, Identifiable, Hashable {
    var id: UUID
    var platform: SocialPlatform
    var handle: String

    init(id: UUID = UUID(), platform: SocialPlatform, handle: String) {
        self.id = id
        self.platform = platform
        self.handle = handle
    }

    var url: URL? { platform.url(for: handle) }
}

enum SocialPlatform: String, Codable, CaseIterable {
    case instagram, telegram, other

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .telegram: "Telegram"
        case .other: "Other"
        }
    }

    var urlPrefix: String {
        switch self {
        case .instagram: "instagram.com/"
        case .telegram: "t.me/"
        case .other: ""
        }
    }

    /// SF Symbol name for the platform icon
    var icon: String {
        switch self {
        case .instagram: "camera"
        case .telegram: "paperplane"
        case .other: "link"
        }
    }

    func url(for handle: String) -> URL? {
        switch self {
        case .instagram: URL(string: "https://instagram.com/\(handle)")
        case .telegram: URL(string: "https://t.me/\(handle)")
        case .other: URL(string: handle.hasPrefix("http") ? handle : "https://\(handle)")
        }
    }
}

// MARK: - Community

struct CommunityMembership: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let role: CommunityRole
    var isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case iconURL = "icon_url"
        case isPrimary = "is_primary"
    }
}

enum CommunityRole: String, Codable {
    case member
    case moderator
    case founder
}

/// Response returned by POST /communities/create-and-join
struct CreateAndJoinCommunityResponse: Codable {
    let communityId: String
    let communityName: String
    let role: CommunityRole
    let message: String

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case communityName = "community_name"
        case role
        case message
    }
}

/// Lightweight model returned by community search / directory listing
struct CommunitySearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let memberCount: Int
    let isOpen: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case iconURL = "icon_url"
        case memberCount = "member_count"
        case isOpen = "is_open"
    }
}

// MARK: - Captain Stats

/// Aggregated sailing identity stats shown on the profile stats bar
struct CaptainStats {
    let chartersCompleted: Int
    /// Phase 3 — shown as "—" until distance_nm is available
    let nauticalMiles: Int
    let daysAtSea: Int
    let communitiesJoined: Int
    /// Phase 3 — shown as "—" until geocoding is available
    let regionsVisited: Int
    let contentPublished: Int
}
