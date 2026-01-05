import Foundation
import SwiftUI

/// Protocol defining the interface for library store operations.
/// Used for dependency injection and testing.
protocol LibraryStoreProtocol: AnyObject {
    var library: [LibraryModel] { get }
    var myChecklists: [LibraryModel] { get }
    var myGuides: [LibraryModel] { get }
    var myDecks: [LibraryModel] { get }

    func loadLibrary() async
    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool) async throws
    func togglePin(for item: LibraryModel) async

    /// Fetch full content model on-demand with caching
    func fetchFullContent<T>(_ id: UUID) async throws -> T?
}

/// Store managing library content state and operations across the application.
///
/// `LibraryStore` serves as the single source of truth for library content (checklists, guides, decks)
/// in the app. It maintains in-memory caches synchronized with the local database through
/// the repository layer.
///
/// This class uses Swift's modern `@Observable` macro for state observation,
/// providing automatic change tracking without the need for `@Published` properties.
///
/// ## Usage
///
/// Access the shared instance through the environment:
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.appDependencies) private var dependencies
///
///     var body: some View {
///         List(dependencies.libraryStore.myChecklists) { item in
///             Text(item.title)
///         }
///     }
/// }
/// ```
///
/// - Important: This class must be accessed from the main actor.
@Observable
final class LibraryStore: LibraryStoreProtocol {
    // MARK: - Properties
    
    /// Unified content collection (metadata for all types)
    /// This is the single source of truth for library metadata
    private(set) var library: [LibraryModel] = []

    /// LRU cache for full content models loaded on-demand
    /// Eliminates duplicate state and provides proper cache management
    private let fullContentCache = LRUCache<UUID, AnyContent>(maxSize: 50)
    
    // Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any LibraryRepository

    // Sync queue service for handling content synchronization
    private let syncQueue: SyncQueueService
    
    // MARK: - Computed Properties
    
    /// Filtered checklists from library metadata
    var myChecklists: [LibraryModel] {
        library.filter { $0.type == .checklist }
    }
    
    /// Filtered guides from library metadata
    var myGuides: [LibraryModel] {
        library.filter { $0.type == .practiceGuide }
    }
    
    /// Filtered flashcard decks from library metadata
    var myDecks: [LibraryModel] {
        library.filter { $0.type == .flashcardDeck }
    }
    
    // MARK: - Initialization

    nonisolated init(repository: any LibraryRepository, syncQueue: SyncQueueService) {
        self.repository = repository
        self.syncQueue = syncQueue
    }
    
    // MARK: - Loading Content

    /// Fetch a single library item by ID
    @MainActor
    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
        return try await repository.fetchLibraryItem(id)
    }

    /// Fetch full content model on-demand with caching
    /// - Parameter id: The content ID to fetch
    /// - Returns: The full content model, or nil if not found
    @MainActor
    func fetchFullContent<T>(_ id: UUID) async throws -> T? {
        // Check cache first
        if let cached = fullContentCache.get(id)?.as(T.self) {
            return cached
        }

        // Try to determine content type from metadata if available
        let contentType: ContentType?
        if let metadata = library.first(where: { $0.id == id }) {
            contentType = metadata.type
        } else {
            // If metadata isn't loaded, try to fetch from repository directly
            // This allows fetching content even when library metadata hasn't been loaded yet
            if let checklist = try await repository.fetchChecklist(id) {
                let content = AnyContent.checklist(checklist)
                fullContentCache.set(content, forKey: id)
                return content.as(T.self)
            }
            if let guide = try await repository.fetchGuide(id) {
                let content = AnyContent.practiceGuide(guide)
                fullContentCache.set(content, forKey: id)
                return content.as(T.self)
            }
            if let deck = try await repository.fetchDeck(id) {
                let content = AnyContent.flashcardDeck(deck)
                fullContentCache.set(content, forKey: id)
                return content.as(T.self)
            }
            return nil
        }

        // Fetch from repository based on known content type
        let content: AnyContent?
        switch contentType {
        case .checklist:
            if let checklist = try await repository.fetchChecklist(id) {
                content = .checklist(checklist)
            } else {
                content = nil
            }
        case .practiceGuide:
            if let guide = try await repository.fetchGuide(id) {
                content = .practiceGuide(guide)
            } else {
                content = nil
            }
        case .flashcardDeck:
            if let deck = try await repository.fetchDeck(id) {
                content = .flashcardDeck(deck)
            } else {
                content = nil
            }
        case nil:
            content = nil
        }

        // Cache the result if found
        if let content = content {
            fullContentCache.set(content, forKey: id)
            return content.as(T.self)
        }

        return nil
    }

    /// Load all library content metadata
    /// Full content models are loaded on-demand via fetchFullContent()
    @MainActor
    func loadLibrary() async {
        do {
            // Load only metadata - single source of truth
            library = try await repository.fetchUserLibrary()

            // Clear cache since metadata may have changed
            fullContentCache.removeAll()
        } catch {
            // On error, clear metadata collection
            library = []
            fullContentCache.removeAll()
            print("[LibraryStore] Failed to load library: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Creating Content
    
    /// Create a new checklist
    /// - Parameter checklist: The full checklist model to create
    @MainActor
    func createChecklist(_ checklist: Checklist) async throws {
        try await repository.createChecklist(checklist)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(checklist.id) {
            library.append(metadata)
            // Cache the full content
            fullContentCache.set(.checklist(checklist), forKey: checklist.id)
        }
    }
    
    /// Create a new practice guide
    /// - Parameter guide: The full guide model to create
    @MainActor
    func createGuide(_ guide: PracticeGuide) async throws {
        try await repository.createGuide(guide)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(guide.id) {
            library.append(metadata)
            // Cache the full content
            fullContentCache.set(.practiceGuide(guide), forKey: guide.id)
        }
    }

    /// Create a new flashcard deck
    /// - Parameter deck: The full deck model to create
    @MainActor
    func createDeck(_ deck: FlashcardDeck) async throws {
        try await repository.createDeck(deck)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(deck.id) {
            library.append(metadata)
            // Cache the full content
            fullContentCache.set(.flashcardDeck(deck), forKey: deck.id)
        }
    }

    /// Fork content from public shared content
    @MainActor
    func forkContent(from sharedContent: SharedContentDetail) async throws {
        let contentData = sharedContent.contentData

        switch sharedContent.contentType {
        case "checklist":
            AppLogger.store.info("Forking checklist: \(sharedContent.title)")
            let checklistData = try JSONSerialization.data(withJSONObject: contentData)
            AppLogger.store.debug("Checklist JSON data created, size: \(checklistData.count) bytes")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var checklist = try decoder.decode(Checklist.self, from: checklistData)
            AppLogger.store.debug("Checklist decoded successfully")

            // Update metadata for forked content
            checklist.title = sharedContent.title
            checklist.description = sharedContent.description
            checklist.tags = sharedContent.tags

            // Create the checklist (this will handle ID assignment and metadata)
            try await createChecklist(checklist)
            AppLogger.store.info("Checklist forked successfully")

            // Update the metadata to include fork attribution
            if let lastCreated = library.last, lastCreated.title == sharedContent.title {
                var updatedMetadata = lastCreated
                updatedMetadata.forkedFromID = sharedContent.id
                updatedMetadata.originalAuthorUsername = sharedContent.authorUsername
                updatedMetadata.originalContentPublicID = sharedContent.publicID
                try await repository.updateLibraryMetadata(updatedMetadata)

                // Update in-memory cache
                if let index = library.firstIndex(where: { $0.id == updatedMetadata.id }) {
                    library[index] = updatedMetadata
                }
            }

        case "practice_guide":
            AppLogger.store.info("Forking practice guide: \(sharedContent.title)")
            let guideData = try JSONSerialization.data(withJSONObject: contentData)
            AppLogger.store.debug("Guide JSON data created, size: \(guideData.count) bytes")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var guide = try decoder.decode(PracticeGuide.self, from: guideData)
            AppLogger.store.debug("Guide decoded successfully")

            // Update metadata for forked content
            guide.title = sharedContent.title
            guide.description = sharedContent.description
            guide.tags = sharedContent.tags

            // Create the guide (this will handle ID assignment and metadata)
            try await createGuide(guide)
            AppLogger.store.info("Guide forked successfully")

            // Update the metadata to include fork attribution
            if let lastCreated = library.last, lastCreated.title == sharedContent.title {
                var updatedMetadata = lastCreated
                updatedMetadata.forkedFromID = sharedContent.id
                updatedMetadata.originalAuthorUsername = sharedContent.authorUsername
                updatedMetadata.originalContentPublicID = sharedContent.publicID
                try await repository.updateLibraryMetadata(updatedMetadata)

                // Update in-memory cache
                if let index = library.firstIndex(where: { $0.id == updatedMetadata.id }) {
                    library[index] = updatedMetadata
                }
            }

        case "flashcard_deck":
            throw NSError(domain: "LibraryStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Flashcard deck forking not yet implemented"])

        default:
            throw NSError(domain: "LibraryStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown content type: \(sharedContent.contentType)"])
        }

        // Increment fork count on original content (best effort, don't fail fork if this fails)
        // TODO: Implement fork count increment when API client is available in dependencies
        AppLogger.view.info("Would increment fork count for original content: \(sharedContent.publicID)")
    }
    
    // MARK: - Updating Content
    
    /// Save/update an existing checklist
    /// - Parameter checklist: The updated checklist model
    @MainActor
    func saveChecklist(_ checklist: Checklist) async throws {
        try await repository.saveChecklist(checklist)

        // Update metadata only (avoid full reload)
        if let metadataIndex = library.firstIndex(where: { $0.id == checklist.id }) {
            var metadata = library[metadataIndex]
            metadata.title = checklist.title
            metadata.description = checklist.description
            metadata.tags = checklist.tags
            metadata.updatedAt = checklist.updatedAt
            metadata.syncStatus = checklist.syncStatus
            library[metadataIndex] = metadata

            // If this is published content, trigger automatic sync update
            if metadata.publicID != nil {
                await triggerPublishUpdate(for: metadata, checklist: checklist)
            }
        }

        // Update cache with full content
        fullContentCache.set(.checklist(checklist), forKey: checklist.id)
    }

    /// Trigger automatic sync update for published content
    private func triggerPublishUpdate(for metadata: LibraryModel, checklist: Checklist) async {
        do {
            // Create the full content data payload
            let contentData: [String: Any] = [
                "id": checklist.id.uuidString,
                "title": checklist.title,
                "description": checklist.description as Any,
                "sections": checklist.sections.map { section in
                    [
                        "id": section.id.uuidString,
                        "title": section.title,
                        "items": section.items.map { item in
                            [
                                "id": item.id.uuidString,
                                "title": item.title,
                                "itemDescription": item.itemDescription as Any,
                                "isOptional": item.isOptional,
                                "isRequired": item.isRequired,
                                "tags": item.tags,
                                "estimatedMinutes": item.estimatedMinutes as Any,
                                "sortOrder": item.sortOrder
                            ]
                        }
                    ]
                },
                "checklistType": checklist.checklistType.rawValue,
                "tags": checklist.tags,
                "createdAt": checklist.createdAt.ISO8601Format(),
                "updatedAt": checklist.updatedAt.ISO8601Format(),
                "syncStatus": checklist.syncStatus.rawValue
            ]

            let payload = ContentPublishPayload(
                title: checklist.title,
                description: checklist.description,
                contentType: "checklist",
                contentData: contentData,
                tags: checklist.tags,
                language: metadata.language,
                publicID: metadata.publicID!,
                forkedFromID: metadata.forkedFromID
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(payload)

            try await syncQueue.enqueuePublishUpdate(
                contentID: checklist.id,
                payload: payloadData
            )

            AppLogger.store.info("Triggered publish_update sync for checklist: \(checklist.id)")
        } catch {
            AppLogger.store.error("Failed to trigger publish_update sync for checklist: \(checklist.id)", error: error)
        }
    }

    /// Trigger automatic sync update for published practice guide
    private func triggerPublishUpdate(for metadata: LibraryModel, guide: PracticeGuide) async {
        do {
            // Create the full content data payload
            let contentData: [String: Any] = [
                "id": guide.id.uuidString,
                "title": guide.title,
                "description": guide.description as Any,
                "markdown": guide.markdown,
                "tags": guide.tags,
                "createdAt": guide.createdAt.ISO8601Format(),
                "updatedAt": guide.updatedAt.ISO8601Format(),
                "syncStatus": guide.syncStatus.rawValue
            ]

            let payload = ContentPublishPayload(
                title: guide.title,
                description: guide.description,
                contentType: "practice_guide",
                contentData: contentData,
                tags: guide.tags,
                language: metadata.language,
                publicID: metadata.publicID!,
                forkedFromID: metadata.forkedFromID
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(payload)

            try await syncQueue.enqueuePublishUpdate(
                contentID: guide.id,
                payload: payloadData
            )

            AppLogger.store.info("Triggered publish_update sync for guide: \(guide.id)")
        } catch {
            AppLogger.store.error("Failed to trigger publish_update sync for guide: \(guide.id)", error: error)
        }
    }
    
    /// Save/update an existing practice guide
    /// - Parameter guide: The updated guide model
    @MainActor
    func saveGuide(_ guide: PracticeGuide) async throws {
        try await repository.saveGuide(guide)

        // Update metadata and check for published content sync
        if let metadataIndex = library.firstIndex(where: { $0.id == guide.id }) {
            var metadata = library[metadataIndex]
            metadata.title = guide.title
            metadata.description = guide.description
            metadata.tags = guide.tags
            metadata.updatedAt = guide.updatedAt
            metadata.syncStatus = guide.syncStatus
            library[metadataIndex] = metadata

            // If this is published content, trigger automatic sync update
            if metadata.publicID != nil {
                await triggerPublishUpdate(for: metadata, guide: guide)
            }
        }

        // Update cache with full content
        fullContentCache.set(.practiceGuide(guide), forKey: guide.id)
    }
    
    // MARK: - Deleting Content

    /// Delete content from the library
    /// - Parameters:
    ///   - item: The library item to delete
    ///   - shouldUnpublish: Whether to unpublish from backend if content is published (default: true)
    ///                     Set to false for "keep published" deletion scenario
    @MainActor
    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool = true) async throws {
        // If content is published and should be unpublished, enqueue unpublish operation
        if shouldUnpublish, let publicID = item.publicID {
            AppLogger.store.info("Enqueuing unpublish operation for published content before deletion: \(item.id)")
            try await syncQueue.enqueueUnpublish(
                contentID: item.id,
                publicID: publicID
            )
        }

        // Delete from local database (after sync completes)
        try await repository.deleteContent(item.id)

        // Remove from metadata collection
        library.removeAll { $0.id == item.id }

        // Remove from cache
        fullContentCache.removeValue(forKey: item.id)
    }
    
    // MARK: - Metadata Updates
    
    /// Update library metadata (e.g., visibility, sync status)
    /// - Parameter item: The updated library item metadata
    /// - Throws: Error if update fails
    @MainActor
    func updateLibraryMetadata(_ item: LibraryModel) async throws {
        // Update in-memory collection
        if let index = library.firstIndex(where: { $0.id == item.id }) {
            library[index] = item
        } else {
            // If not found, add it
            library.append(item)
        }
        
        // Persist to database
        try await repository.updateLibraryMetadata(item)
    }
    
    // MARK: - Pinning
    
    /// Toggle pinned state for a library item and update its order.
    @MainActor
    func togglePin(for item: LibraryModel) async {
        guard let index = library.firstIndex(where: { $0.id == item.id }) else { return }
        
        var updated = library[index]
        updated.isPinned.toggle()
        
        if updated.isPinned {
            let maxOrder = library.compactMap { $0.pinnedOrder }.max() ?? 0
            updated.pinnedOrder = maxOrder + 1
        } else {
            updated.pinnedOrder = nil
        }
        
        library[index] = updated
        
        do {
            try await repository.updateLibraryMetadata(updated)
        } catch {
            AppLogger.repository.failOperation("Update Library Metadata", error: error)
        }
    }
    
    // MARK: - Fetching Full Models
    
    /// Fetch a full checklist model by ID
    /// - Parameter checklistID: The ID of the checklist to fetch
    /// - Returns: The full checklist model, or nil if not found
    @MainActor
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist? {
        return try await fetchFullContent(checklistID)
    }
    
    
    /// Fetch a full guide model by ID
    /// - Parameter guideID: The ID of the guide to fetch
    /// - Returns: The full guide model, or nil if not found
    @MainActor
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? {
        return try await fetchFullContent(guideID)
    }

    /// Fetch a full deck model by ID
    /// - Parameter deckID: The ID of the deck to fetch
    /// - Returns: The full deck model, or nil if not found
    @MainActor
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck? {
        return try await fetchFullContent(deckID)
    }
}

// MARK: - Content Models
// Note: Checklist, ChecklistSection, ChecklistItem, and ChecklistType are defined in Core/Models/Checklist.swift

/// Type-erased container for any library content type.
/// Used by the LRU cache to store different content models uniformly.
enum AnyContent: Hashable, Sendable {
    case checklist(Checklist)
    case practiceGuide(PracticeGuide)
    case flashcardDeck(FlashcardDeck)

    /// Extract the content as a specific type if it matches.
    func `as`<T>(_ type: T.Type) -> T? {
        switch (self, type) {
        case (.checklist(let content), _) where T.self == Checklist.self:
            return content as? T
        case (.practiceGuide(let content), _) where T.self == PracticeGuide.self:
            return content as? T
        case (.flashcardDeck(let content), _) where T.self == FlashcardDeck.self:
            return content as? T
        default:
            return nil
        }
    }

    /// The ID of the content, regardless of type.
    var id: UUID {
        switch self {
        case .checklist(let content): return content.id
        case .practiceGuide(let content): return content.id
        case .flashcardDeck(let content): return content.id
        }
    }

    /// The content type discriminator.
    var contentType: ContentType {
        switch self {
        case .checklist: return .checklist
        case .practiceGuide: return .practiceGuide
        case .flashcardDeck: return .flashcardDeck
        }
    }
}

/// Full practice guide model with markdown content.
///
/// This is the domain model for user-created practice guides. Metadata used for
/// listing and discovery (creator, visibility, rating, etc.) lives in
/// `LibraryModel`; this struct focuses on the actual document content.
nonisolated struct PracticeGuide: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var markdown: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: ContentSyncStatus
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        markdown: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: ContentSyncStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.markdown = markdown
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    /// Convenience factory for a new, empty guide.
    static func empty() -> PracticeGuide {
        PracticeGuide(title: "", markdown: "")
    }
}

/// Full flashcard deck model with cards
/// TODO: Replace with actual FlashcardDeck struct when implemented
/// This is a minimal placeholder that will be replaced with a full model
/// containing cards, categories, SRS data, etc.
struct FlashcardDeck: Identifiable, Hashable, Sendable {
    let id: UUID
    
    // TODO: Add full deck properties:
    // var title: String
    // var description: String?
    // var cards: [Flashcard]
    // etc.
}
