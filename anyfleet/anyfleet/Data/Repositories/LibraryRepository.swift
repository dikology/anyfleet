import Foundation

/// Protocol for repository operations to enable mocking and testing
protocol LibraryRepository: Sendable {
    // MARK: - Metadata Queries
    
    /// Fetch all library content metadata
    func fetchUserLibrary() async throws -> [LibraryModel]
    
    // MARK: - Full Model Queries
    
    /// Fetch all full checklist models
    func fetchUserChecklists() async throws -> [Checklist]
    
    /// Fetch all full practice guide models
    func fetchUserGuides() async throws -> [PracticeGuide]
    
    /// Fetch all full flashcard deck models
    func fetchUserDecks() async throws -> [FlashcardDeck]
    
    /// Fetch a single checklist by ID
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist?
    
    /// Fetch a single guide by ID
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide?
    
    /// Fetch a single deck by ID
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck?
    
    // MARK: - Creating Content
    
    /// Create a new checklist
    func createChecklist(_ checklist: Checklist) async throws
    
    /// Create a new practice guide
    func createGuide(_ guide: PracticeGuide) async throws
    
    /// Create a new flashcard deck
    func createDeck(_ deck: FlashcardDeck) async throws
    
    // MARK: - Updating Content
    
    /// Save/update an existing checklist
    func saveChecklist(_ checklist: Checklist) async throws
    
    /// Save/update an existing practice guide
    func saveGuide(_ guide: PracticeGuide) async throws
    
    /// Update metadata for a library item (e.g. pin state, title)
    func updateLibraryMetadata(_ model: LibraryModel) async throws
    
    // MARK: - Deleting Content
    
    /// Delete content by ID
    func deleteContent(_ contentID: UUID) async throws
}

/// Make LocalRepository conform to the protocol
extension LocalRepository: LibraryRepository {}
