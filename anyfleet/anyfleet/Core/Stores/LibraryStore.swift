import Foundation
import SwiftUI

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
final class LibraryStore {
    // MARK: - Properties
    
    /// Unified content collection (metadata for all types)
    private(set) var library: [LibraryModel] = []
    
    /// Type-specific collections (full models for editing)
    /// These are loaded separately when needed for editing or execution
    private(set) var checklists: [Checklist] = []
    private(set) var guides: [PracticeGuide] = []
    private(set) var decks: [FlashcardDeck] = []
    
    /// In-memory cache for frequently accessed checklists
    private var checklistsCache: [UUID: Checklist] = [:]
    private let maxChecklistCacheSize = 50
    
    // Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any LibraryRepository
    
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

    nonisolated init(repository: any LibraryRepository) {
        self.repository = repository
    }
    
    // MARK: - Loading Content
    
    /// Load all library content
    @MainActor
    func loadLibrary() async {
        do {
            // Load metadata for all content types in parallel
            async let metadataTask = repository.fetchUserLibrary()
            async let checklistsTask = repository.fetchUserChecklists()
            async let guidesTask = repository.fetchUserGuides()
            async let decksTask = repository.fetchUserDecks()
            
            // Wait for all tasks to complete
            library = try await metadataTask
            checklists = try await checklistsTask
            guides = try await guidesTask
            decks = try await decksTask
        } catch {
            // On error, clear all collections
            library = []
            checklists = []
            guides = []
            decks = []
            print("[LibraryStore] Failed to load library: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Creating Content
    
    /// Create a new checklist
    /// - Parameter checklist: The full checklist model to create
    @MainActor
    func createChecklist(_ checklist: Checklist) async throws {
        try await repository.createChecklist(checklist)
        // Reload library to reflect the new content
        await loadLibrary()
    }
    
    /// Create a new practice guide
    /// - Parameter guide: The full guide model to create
    @MainActor
    func createGuide(_ guide: PracticeGuide) async throws {
        try await repository.createGuide(guide)
        // Reload library to reflect the new content
        await loadLibrary()
    }
    
    /// Create a new flashcard deck
    /// - Parameter deck: The full deck model to create
    @MainActor
    func createDeck(_ deck: FlashcardDeck) async throws {
        try await repository.createDeck(deck)
        // Reload library to reflect the new content
        await loadLibrary()
    }
    
    // MARK: - Updating Content
    
    /// Save/update an existing checklist
    /// - Parameter checklist: The updated checklist model
    @MainActor
    func saveChecklist(_ checklist: Checklist) async throws {
        try await repository.saveChecklist(checklist)
        
        // Update in-memory full-model cache
        if let index = checklists.firstIndex(where: { $0.id == checklist.id }) {
            checklists[index] = checklist
        }
        
        // Update metadata only (avoid full reload)
        if let metadataIndex = library.firstIndex(where: { $0.id == checklist.id }) {
            var metadata = library[metadataIndex]
            metadata.title = checklist.title
            metadata.description = checklist.description
            metadata.tags = checklist.tags
            metadata.updatedAt = checklist.updatedAt
            metadata.syncStatus = checklist.syncStatus
            library[metadataIndex] = metadata
        }
        
        // Update cache
        checklistsCache[checklist.id] = checklist
        enforceChecklistCacheLimit()
    }
    
    /// Save/update an existing practice guide
    /// - Parameter guide: The updated guide model
    @MainActor
    func saveGuide(_ guide: PracticeGuide) async throws {
        try await repository.saveGuide(guide)
        // Update in-memory cache
        if let index = guides.firstIndex(where: { $0.id == guide.id }) {
            guides[index] = guide
        }
        // Reload metadata to ensure sync status is updated
        await loadLibrary()
    }
    
    // MARK: - Deleting Content
    
    /// Delete content from the library
    /// - Parameter item: The library item to delete
    @MainActor
    func deleteContent(_ item: LibraryModel) async throws {
        try await repository.deleteContent(item.id)
        
        // Remove from in-memory collections
        library.removeAll { $0.id == item.id }
        
        // Remove from type-specific collections
        switch item.type {
        case .checklist:
            checklists.removeAll { $0.id == item.id }
        case .practiceGuide:
            guides.removeAll { $0.id == item.id }
        case .flashcardDeck:
            decks.removeAll { $0.id == item.id }
        }
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
        // Check cache first
        if let cached = checklistsCache[checklistID] {
            return cached
        }
        
        // Then check in-memory collection
        if let checklist = checklists.first(where: { $0.id == checklistID }) {
            // Populate cache for future fast access
            checklistsCache[checklistID] = checklist
            enforceChecklistCacheLimit()
            return checklist
        }
        
        // Finally, fetch from repository
        guard let checklist = try await repository.fetchChecklist(checklistID) else {
            return nil
        }
        
        // Add to cache with size-based eviction
        checklistsCache[checklistID] = checklist
        enforceChecklistCacheLimit()
        return checklist
    }
    
    // MARK: - Cache Management
    
    private func enforceChecklistCacheLimit() {
        guard checklistsCache.count > maxChecklistCacheSize else { return }
        // Simple eviction: remove oldest key in dictionary order
        let overflow = checklistsCache.count - maxChecklistCacheSize
        let keysToRemove = Array(checklistsCache.keys.prefix(overflow))
        for key in keysToRemove {
            checklistsCache.removeValue(forKey: key)
        }
    }
    
    /// Fetch a full guide model by ID
    /// - Parameter guideID: The ID of the guide to fetch
    /// - Returns: The full guide model, or nil if not found
    @MainActor
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? {
        // First check in-memory cache
        if let guide = guides.first(where: { $0.id == guideID }) {
            return guide
        }
        
        // If not in cache, fetch from repository
        return try await repository.fetchGuide(guideID)
    }
    
    /// Fetch a full deck model by ID
    /// - Parameter deckID: The ID of the deck to fetch
    /// - Returns: The full deck model, or nil if not found
    @MainActor
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck? {
        // First check in-memory cache
        if let deck = decks.first(where: { $0.id == deckID }) {
            return deck
        }
        
        // If not in cache, fetch from repository
        return try await repository.fetchDeck(deckID)
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