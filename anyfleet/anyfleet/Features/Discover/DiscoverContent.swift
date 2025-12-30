import Foundation

/// Model for content displayed in the Discover tab
/// Maps from the backend SharedContentSummary response
struct DiscoverContent: Identifiable, Hashable, Sendable {
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

    // Attribution fields
    let forkedFromID: UUID?
    let originalAuthorUsername: String?
    let originalContentPublicID: String?

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
        createdAt: Date,
        forkedFromID: UUID? = nil,
        originalAuthorUsername: String? = nil,
        originalContentPublicID: String? = nil
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
        self.forkedFromID = forkedFromID
        self.originalAuthorUsername = originalAuthorUsername
        self.originalContentPublicID = originalContentPublicID
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
        self.forkedFromID = response.forkedFromID
        self.originalAuthorUsername = response.originalAuthorUsername
        self.originalContentPublicID = response.originalContentPublicID
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

    // Attribution fields
    let forkedFromID: UUID?
    let originalAuthorUsername: String?
    let originalContentPublicID: String?

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
        case forkedFromID = "forked_from_id"
        case originalAuthorUsername = "original_author_username"
        case originalContentPublicID = "original_content_public_id"
    }
}

/// Response model for full content details from public endpoint
struct SharedContentDetail: Codable {
    let id: UUID
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let publicID: String
    let canFork: Bool
    let authorUsername: String?
    let viewCount: Int
    let forkCount: Int
    let createdAt: Date
    let updatedAt: Date

    // Attribution fields
    let forkedFromID: UUID?
    let originalAuthorUsername: String?
    let originalContentPublicID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case publicID = "public_id"
        case canFork = "can_fork"
        case authorUsername = "author_username"
        case viewCount = "view_count"
        case forkCount = "fork_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case forkedFromID = "forked_from_id"
        case originalAuthorUsername = "original_author_username"
        case originalContentPublicID = "original_content_public_id"
    }

    // MARK: - Memberwise Initializer

    init(
        id: UUID,
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        publicID: String,
        canFork: Bool,
        authorUsername: String?,
        viewCount: Int,
        forkCount: Int,
        createdAt: Date,
        updatedAt: Date,
        forkedFromID: UUID? = nil,
        originalAuthorUsername: String? = nil,
        originalContentPublicID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentData = contentData
        self.tags = tags
        self.publicID = publicID
        self.canFork = canFork
        self.authorUsername = authorUsername
        self.viewCount = viewCount
        self.forkCount = forkCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.forkedFromID = forkedFromID
        self.originalAuthorUsername = originalAuthorUsername
        self.originalContentPublicID = originalContentPublicID
    }

    // MARK: - Custom Decoding for contentData

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decode(String.self, forKey: .contentType)
        tags = try container.decode([String].self, forKey: .tags)
        publicID = try container.decode(String.self, forKey: .publicID)
        canFork = try container.decode(Bool.self, forKey: .canFork)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        forkCount = try container.decode(Int.self, forKey: .forkCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Decode contentData as nested JSON object
        let json = try container.decode(AnyCodable.self, forKey: .contentData)
        contentData = json.value as? [String: Any] ?? [:]

        // Decode attribution fields
        forkedFromID = try container.decodeIfPresent(UUID.self, forKey: .forkedFromID)
        originalAuthorUsername = try container.decodeIfPresent(String.self, forKey: .originalAuthorUsername)
        originalContentPublicID = try container.decodeIfPresent(String.self, forKey: .originalContentPublicID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(publicID, forKey: .publicID)
        try container.encode(canFork, forKey: .canFork)
        try container.encodeIfPresent(authorUsername, forKey: .authorUsername)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(forkCount, forKey: .forkCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)

        // Encode contentData as nested JSON object
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let jsonDecoder = JSONDecoder()
        let json = try jsonDecoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}
