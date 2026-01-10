import Foundation
import SwiftUI

/// Protocol defining the interface for library store operations.
/// Used for dependency injection and testing.
protocol LibraryStoreProtocol: AnyObject {
    // MARK: - State
    var library: [LibraryModel] { get }
    var myChecklists: [LibraryModel] { get }
    var myGuides: [LibraryModel] { get }
    var myDecks: [LibraryModel] { get }

    // MARK: - Library Management
    func loadLibrary() async
    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel?

    // MARK: - Content Creation
    func createChecklist(_ checklist: Checklist) async throws
    func createGuide(_ guide: PracticeGuide) async throws
    func createDeck(_ deck: FlashcardDeck) async throws
    func forkContent(from sharedContent: SharedContentDetail) async throws

    // MARK: - Content Modification
    func saveChecklist(_ checklist: Checklist) async throws
    func saveGuide(_ guide: PracticeGuide) async throws
    func updateLibraryMetadata(_ item: LibraryModel) async throws

    // MARK: - Content Deletion
    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool) async throws

    // MARK: - Content Retrieval
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck

    /// Fetch full content model on-demand with caching
    func fetchFullContent<T>(_ id: UUID) async throws -> T?

    // MARK: - UI Actions
    func togglePin(for item: LibraryModel) async
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
@MainActor
@Observable
final class LibraryStore: LibraryStoreProtocol {
    // MARK: - Properties
    
    /// Unified content collection (metadata for all types)
    /// This is the single source of truth for library metadata
    private(set) var library: [LibraryModel] = []

    /// LRU caches for full content models loaded on-demand
    /// Separate caches for different content types to avoid type casting overhead
    private let checklistCache = ContentCache<UUID, Checklist>()
    private let guideCache = ContentCache<UUID, PracticeGuide>()
    
    // Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    private let repository: any LibraryRepository

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

    init(repository: any LibraryRepository, syncQueue: SyncQueueService) {
        self.repository = repository
        self.syncQueue = syncQueue
    }
    
    // MARK: - Loading Content

    /// Fetch a single library item by ID
    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
        return try await repository.fetchLibraryItem(id)
    }

    /// Fetch full content model on-demand with caching
    /// - Parameter id: The content ID to fetch
    /// - Returns: The full content model, or nil if not found
    func fetchFullContent<T>(_ id: UUID) async throws -> T? {
        // Check cache first based on content type
        if T.self == Checklist.self {
            if let cached = checklistCache.get(id) as? T {
                AppLogger.store.debug("Cache hit for checklist: \(id)")
                return cached
            }
        } else if T.self == PracticeGuide.self {
            if let cached = guideCache.get(id) as? T {
                AppLogger.store.debug("Cache hit for guide: \(id)")
                return cached
            }
        }

        // Fetch from repository based on requested type
        let content: T?
        if T.self == Checklist.self {
            do {
                let checklist = try await repository.fetchChecklist(id)
                checklistCache.set(id, value: checklist)
                content = checklist as? T
            } catch let error as LibraryError where error == .notFound(id) {
                content = nil
            } catch {
                throw error
            }
        } else if T.self == PracticeGuide.self {
            do {
                let guide = try await repository.fetchGuide(id)
                guideCache.set(id, value: guide)
                content = guide as? T
            } catch let error as LibraryError where error == .notFound(id) {
                content = nil
            } catch {
                throw error
            }
        } else {
            fatalError("Unsupported content type for caching")
        }

        return content
    }

    /// Load all library content metadata
    /// Full content models are loaded on-demand via fetchFullContent()
    func loadLibrary() async {
        do {
            // Load only metadata - single source of truth
            library = try await repository.fetchUserLibrary()

            // Clear cache since metadata may have changed
            checklistCache.clear()
            guideCache.clear()
        } catch {
            // On error, clear metadata collection
            library = []
            checklistCache.clear()
            guideCache.clear()
            print("[LibraryStore] Failed to load library: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Creating Content
    
    /// Create a new checklist
    /// - Parameter checklist: The full checklist model to create
    func createChecklist(_ checklist: Checklist) async throws {
        try await repository.createChecklist(checklist)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(checklist.id) {
            library.append(metadata)
            // Cache the full content
            checklistCache.set(checklist.id, value: checklist)
        }
    }
    
    /// Create a new practice guide
    /// - Parameter guide: The full guide model to create
    func createGuide(_ guide: PracticeGuide) async throws {
        try await repository.createGuide(guide)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(guide.id) {
            library.append(metadata)
            // Cache the full content
            guideCache.set(guide.id, value: guide)
        }
    }

    /// Create a new flashcard deck
    /// - Parameter deck: The full deck model to create
    func createDeck(_ deck: FlashcardDeck) async throws {
        try await repository.createDeck(deck)

        // Add to metadata collection directly (no full reload needed)
        if let metadata = try await repository.fetchLibraryItem(deck.id) {
            library.append(metadata)
            // Decks are not cached since they're not frequently accessed
        }
    }

    /// Fork content from public shared content
    func forkContent(from sharedContent: SharedContentDetail) async throws {
        switch sharedContent.contentType {
        case "checklist":
            try await forkChecklist(from: sharedContent)
        case "practice_guide":
            try await forkPracticeGuide(from: sharedContent)
        case "flashcard_deck":
            try await forkFlashcardDeck(from: sharedContent)
        default:
            throw NSError(domain: "LibraryStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown content type: \(sharedContent.contentType)"])
        }

        // Increment fork count on original content (best effort, don't fail fork if this fails)
        // TODO: Implement fork count increment when API client is available in dependencies
        AppLogger.view.info("Would increment fork count for original content: \(sharedContent.publicID)")
    }

    private func forkChecklist(from sharedContent: SharedContentDetail) async throws {
        AppLogger.store.info("Forking checklist: \(sharedContent.title)")
        let checklistData = try JSONSerialization.data(withJSONObject: sharedContent.contentData)
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
        await updateForkAttribution(for: sharedContent)
    }

    private func forkPracticeGuide(from sharedContent: SharedContentDetail) async throws {
        AppLogger.store.info("Forking practice guide: \(sharedContent.title)")
        let guideData = try JSONSerialization.data(withJSONObject: sharedContent.contentData)
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
        await updateForkAttribution(for: sharedContent)
    }

    private func forkFlashcardDeck(from sharedContent: SharedContentDetail) async throws {
        throw NSError(domain: "LibraryStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Flashcard deck forking not yet implemented"])
    }

    private func updateForkAttribution(for sharedContent: SharedContentDetail) async {
        guard let lastCreated = library.last, lastCreated.title == sharedContent.title else {
            return
        }

        var updatedMetadata = lastCreated
        updatedMetadata.forkedFromID = sharedContent.id
        updatedMetadata.originalAuthorUsername = sharedContent.authorUsername
        updatedMetadata.originalContentPublicID = sharedContent.publicID

        do {
            try await repository.updateLibraryMetadata(updatedMetadata)

            // Update in-memory cache
            if let index = library.firstIndex(where: { $0.id == updatedMetadata.id }) {
                library[index] = updatedMetadata
            }
        } catch {
            AppLogger.store.error("Failed to update fork attribution metadata: \(error)")
        }
    }

    // MARK: - Updating Content
    
    /// Save/update an existing checklist
    /// - Parameter checklist: The updated checklist model
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
        checklistCache.set(checklist.id, value: checklist)
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

            let summary = try await syncQueue.enqueuePublishUpdate(
                contentID: checklist.id,
                payload: payloadData
            )

            AppLogger.store.info("Publish update sync completed for checklist: \(checklist.id) - \(summary.succeeded) succeeded, \(summary.failed) failed")
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

            let summary = try await syncQueue.enqueuePublishUpdate(
                contentID: guide.id,
                payload: payloadData
            )

            AppLogger.store.info("Publish update sync completed for guide: \(guide.id) - \(summary.succeeded) succeeded, \(summary.failed) failed")
        } catch {
            AppLogger.store.error("Failed to trigger publish_update sync for guide: \(guide.id)", error: error)
        }
    }
    
    /// Save/update an existing practice guide
    /// - Parameter guide: The updated guide model
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
        guideCache.set(guide.id, value: guide)
    }
    
    // MARK: - Deleting Content

    /// Delete content from the library
    /// - Parameters:
    ///   - item: The library item to delete
    ///   - shouldUnpublish: Whether to unpublish from backend if content is published (default: true)
    ///                     Set to false for "keep published" deletion scenario
    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool = true) async throws {
        // If content is published and should be unpublished, enqueue unpublish operation
        if shouldUnpublish, let publicID = item.publicID {
            AppLogger.store.info("Enqueuing unpublish operation for published content before deletion: \(item.id)")
            let summary = try await syncQueue.enqueueUnpublish(
                contentID: item.id,
                publicID: publicID
            )
            AppLogger.store.info("Unpublish sync completed for deletion: \(item.id) - \(summary.succeeded) succeeded, \(summary.failed) failed")
        }

        // Delete from local database (after sync completes)
        try await repository.deleteContent(item.id)

        // Remove from metadata collection
        library.removeAll { $0.id == item.id }

        // Remove from cache
        invalidateCache(for: item.id)
    }
    
    // MARK: - Metadata Updates
    
    /// Update library metadata (e.g., visibility, sync status)
    /// - Parameter item: The updated library item metadata
    /// - Throws: Error if update fails
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
    /// - Returns: The full checklist model
    /// - Throws: LibraryError.notFound if the checklist is not found
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist {
        guard let checklist = try await fetchFullContent(checklistID) as Checklist? else {
            throw LibraryError.notFound(checklistID)
        }
        return checklist
    }
    
    
    /// Fetch a full guide model by ID
    /// - Parameter guideID: The ID of the guide to fetch
    /// - Returns: The full guide model
    /// - Throws: LibraryError.notFound if the guide is not found
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide {
        guard let guide = try await fetchFullContent(guideID) as PracticeGuide? else {
            throw LibraryError.notFound(guideID)
        }
        return guide
    }

    /// Fetch a full deck model by ID
    /// - Parameter deckID: The ID of the deck to fetch
    /// - Returns: The full deck model
    /// - Throws: LibraryError.notFound if the deck is not found
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck {
        guard let deck = try await fetchFullContent(deckID) as FlashcardDeck? else {
            throw LibraryError.notFound(deckID)
        }
        return deck
    }

    /// Invalidate cache entries for a specific content ID
    /// - Parameter contentID: The content ID to remove from caches
    func invalidateCache(for contentID: UUID) {
        checklistCache.remove(contentID)
        guideCache.remove(contentID)
    }
}

// MARK: - Content Models
// Note: Checklist, ChecklistSection, ChecklistItem, and ChecklistType are defined in Core/Models/Checklist.swift

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
