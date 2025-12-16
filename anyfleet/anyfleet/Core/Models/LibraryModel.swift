import Foundation

// MARK: - Library Model

/// Metadata model for all library content types (checklists, guides, flashcard decks).
/// This serves as the lightweight representation used in library lists and filtering.
/// Full content structures (sections/items for checklists, markdown for guides, etc.)
/// are stored separately and loaded when needed for editing or execution.
nonisolated struct LibraryModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    
    var description: String?
    var type: ContentType
    var visibility: ContentVisibility
    var creatorID: UUID
    var forkedFromID: UUID?
    var forkCount: Int = 0
    var ratingAverage: Double?
    var ratingCount: Int = 0
    var tags: [String] = []
    var language: String = "en"
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: ContentSyncStatus = .pending
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        type: ContentType,
        visibility: ContentVisibility = .private,
        creatorID: UUID,
        forkedFromID: UUID? = nil,
        forkCount: Int = 0,
        ratingAverage: Double? = nil,
        ratingCount: Int = 0,
        tags: [String] = [],
        language: String = "en",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: ContentSyncStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.visibility = visibility
        self.creatorID = creatorID
        self.forkedFromID = forkedFromID
        self.forkCount = forkCount
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.tags = tags
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}

// MARK: - Content Type

/// Discriminator for different types of library content
enum ContentType: String, Codable, CaseIterable, Sendable, Hashable {
    case checklist = "checklist"
    case flashcardDeck = "flashcard_deck"
    case practiceGuide = "practice_guide"
    
    var displayName: String {
        switch self {
        case .checklist: return "Checklist"
        case .flashcardDeck: return "Flashcard Deck"
        case .practiceGuide: return "Practice Guide"
        }
    }
    
    var icon: String {
        switch self {
        case .checklist: return "checklist"
        case .flashcardDeck: return "rectangle.stack"
        case .practiceGuide: return "book"
        }
    }
}

// MARK: - Content Visibility

/// Visibility level for library content
enum ContentVisibility: String, Codable, CaseIterable, Sendable {
    case `private` = "private"
    case unlisted = "unlisted"
    case `public` = "public"
    
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .unlisted: return "Unlisted"
        case .public: return "Public"
        }
    }
    
    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .unlisted: return "link"
        case .public: return "globe"
        }
    }
    
    var description: String {
        switch self {
        case .private: return "Only you can see this"
        case .unlisted: return "Anyone with the link can see this"
        case .public: return "Discoverable in community library"
        }
    }
}

// MARK: - Sync Status

/// Sync status for offline-first content management
enum ContentSyncStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case queued
    case synced
    case failed
}
