import Foundation

/// Model for content displayed in the Discover tab
/// Maps from the backend SharedContentSummary response
nonisolated struct DiscoverContent: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let description: String?
    let contentType: ContentType
    let tags: [String]
    let publicID: String
    let authorUsername: String?
    let viewCount: Int
    let forkCount: Int
    let createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID,
        title: String,
        description: String?,
        contentType: ContentType,
        tags: [String],
        publicID: String,
        authorUsername: String?,
        viewCount: Int,
        forkCount: Int,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.contentType = contentType
        self.tags = tags
        self.publicID = publicID
        self.authorUsername = authorUsername
        self.viewCount = viewCount
        self.forkCount = forkCount
        self.createdAt = createdAt
    }

    // MARK: - Mapping from API Response

    /// Initialize from backend SharedContentSummary response
    init(from response: SharedContentSummary) {
        self.id = response.id
        self.title = response.title
        self.description = response.description
        self.contentType = ContentType(rawValue: response.contentType) ?? .checklist
        self.tags = response.tags
        self.publicID = response.publicID
        self.authorUsername = response.authorUsername
        self.viewCount = response.viewCount
        self.forkCount = response.forkCount
        self.createdAt = response.createdAt
    }
}

// MARK: - API Response Models

/// Response model for individual content item from public endpoint
struct SharedContentSummary: Codable {
    let id: UUID
    let title: String
    let description: String?
    let contentType: String
    let tags: [String]
    let publicID: String
    let authorUsername: String?
    let viewCount: Int
    let forkCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case contentType = "content_type"
        case tags
        case publicID = "public_id"
        case authorUsername = "author_username"
        case viewCount = "view_count"
        case forkCount = "fork_count"
        case createdAt = "created_at"
    }
}
