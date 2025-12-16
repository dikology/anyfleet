//
//  LocalRepository.swift
//  anyfleet
//
//  Repository layer for local database CRUD operations
//

import Foundation
import GRDB

/// Repository providing type-safe database operations for all entities.
/// This is the main interface for stores to interact with the local SQLite database.
final class LocalRepository: Sendable {
    private let database: AppDatabase
    
    // MARK: - Initialization
    
    nonisolated init(database: AppDatabase = .shared) {
        self.database = database
    }
    
    // MARK: - Charter Operations
    
    /// Fetch all charters
    func fetchAllCharters() async throws -> [CharterModel] {
        try await database.dbWriter.read { db in
            try CharterRecord.fetchAll(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    /// Fetch active charters
    func fetchActiveCharters() async throws -> [CharterModel] {
        try await database.dbWriter.read { db in
            try CharterRecord.fetchActive(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    /// Fetch upcoming charters
    func fetchUpcomingCharters() async throws -> [CharterModel] {
        try await database.dbWriter.read { db in
            try CharterRecord.fetchUpcoming(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    /// Fetch past charters
    func fetchPastCharters() async throws -> [CharterModel] {
        try await database.dbWriter.read { db in
            try CharterRecord.fetchPast(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    /// Fetch charter by ID
    func fetchCharter(id: UUID) async throws -> CharterModel? {
        try await database.dbWriter.read { db in
            try CharterRecord
                .filter(CharterRecord.Columns.id == id.uuidString)
                .fetchOne(db)?
                .toDomainModel()
        }
    }
    
    /// Save or update charter
    func saveCharter(_ charter: CharterModel) async throws {
        AppLogger.repository.startOperation("Save Charter")
        defer { AppLogger.repository.completeOperation("Save Charter") }
        
        do {
            try await database.dbWriter.write { db in
                _ = try CharterRecord.saveCharter(charter, db: db)
            }
            AppLogger.repository.info("Charter saved successfully - ID: \(charter.id.uuidString)")
        } catch {
            AppLogger.repository.failOperation("Save Charter", error: error)
            throw error
        }
    }
    
    /// Create new charter
    func createCharter(_ charter: CharterModel) async throws {
        AppLogger.repository.startOperation("Create Charter")
        defer { AppLogger.repository.completeOperation("Create Charter") }
        
        AppLogger.repository.debug("Creating charter with ID: \(charter.id.uuidString), name: '\(charter.name)'")
        
        do {
            try await database.dbWriter.write { db in
                _ = try CharterRecord.saveCharter(charter, db: db)
            }
            AppLogger.repository.info("Charter created successfully - ID: \(charter.id.uuidString)")
        } catch {
            AppLogger.repository.failOperation("Create Charter", error: error)
            throw error
        }
    }
    
    /// Delete charter
    func deleteCharter(_ charterID: UUID) async throws {
        AppLogger.repository.startOperation("Delete Charter")
        defer { AppLogger.repository.completeOperation("Delete Charter") }
        
        do {
            try await database.dbWriter.write { db in
                try CharterRecord.delete(charterID, db: db)
            }
            AppLogger.repository.info("Charter deleted successfully - ID: \(charterID.uuidString)")
        } catch {
            AppLogger.repository.failOperation("Delete Charter", error: error)
            throw error
        }
    }
    
    /// Mark charters as synced
    func markChartersSynced(_ ids: [UUID]) async throws {
        AppLogger.repository.startOperation("Mark Charters Synced")
        defer { AppLogger.repository.completeOperation("Mark Charters Synced") }
        
        AppLogger.repository.debug("Marking \(ids.count) charters as synced")
        
        do {
            try await database.dbWriter.write { db in
                for id in ids {
                    try CharterRecord.markSynced(id, db: db)
                }
            }
            AppLogger.repository.info("Successfully marked \(ids.count) charters as synced")
        } catch {
            AppLogger.repository.failOperation("Mark Charters Synced", error: error)
            throw error
        }
    }
    
    // MARK: - Library Content Operations
    
    // MARK: - Metadata Queries
    
    /// Fetch all library content metadata
    func fetchUserLibrary() async throws -> [LibraryModel] {
        AppLogger.repository.startOperation("Fetch User Library")
        defer { AppLogger.repository.completeOperation("Fetch User Library") }
        
        return try await database.dbWriter.read { db in
            try LibraryModelRecord.fetchAll(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    // MARK: - Full Model Queries
    
    /// Fetch all full checklist models
    func fetchUserChecklists() async throws -> [Checklist] {
        AppLogger.repository.startOperation("Fetch User Checklists")
        defer { AppLogger.repository.completeOperation("Fetch User Checklists") }
        
        return try await database.dbWriter.read { db in
            try ChecklistRecord.fetchAll(db: db)
                .map { $0.toDomainModel() }
        }
    }
    
    /// Fetch all full practice guide models
    /// TODO: Implement when PracticeGuideRecord is created
    func fetchUserGuides() async throws -> [PracticeGuide] {
        AppLogger.repository.startOperation("Fetch User Guides")
        defer { AppLogger.repository.completeOperation("Fetch User Guides") }
        
        // TODO: Implement when PracticeGuideRecord is created
        // try await database.dbWriter.read { db in
        //     try PracticeGuideRecord.fetchAll(db: db)
        //         .map { $0.toDomainModel() }
        // }
        
        // Stub implementation - returns empty array until records are implemented
        AppLogger.repository.debug("Fetching guides")
        return []
    }
    
    /// Fetch all full flashcard deck models
    /// TODO: Implement when FlashcardDeckRecord is created
    func fetchUserDecks() async throws -> [FlashcardDeck] {
        AppLogger.repository.startOperation("Fetch User Decks")
        defer { AppLogger.repository.completeOperation("Fetch User Decks") }
        
        // TODO: Implement when FlashcardDeckRecord is created
        // try await database.dbWriter.read { db in
        //     try FlashcardDeckRecord.fetchAll(db: db)
        //         .map { $0.toDomainModel() }
        // }
        
        // Stub implementation - returns empty array until records are implemented
        AppLogger.repository.debug("Fetching decks")
        return []
    }
    
    /// Fetch a single checklist by ID
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist? {
        AppLogger.repository.startOperation("Fetch Checklist")
        defer { AppLogger.repository.completeOperation("Fetch Checklist") }
        
        return try await database.dbWriter.read { db in
            try ChecklistRecord.fetchOne(id: checklistID, db: db)?
                .toDomainModel()
        }
    }
    
    /// Fetch a single guide by ID
    /// TODO: Implement when PracticeGuideRecord is created
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? {
        AppLogger.repository.startOperation("Fetch Guide")
        defer { AppLogger.repository.completeOperation("Fetch Guide") }
        
        // TODO: Implement when PracticeGuideRecord is created
        // try await database.dbWriter.read { db in
        //     try PracticeGuideRecord
        //         .filter(PracticeGuideRecord.Columns.id == guideID.uuidString)
        //         .fetchOne(db)?
        //         .toDomainModel()
        // }
        
        // Stub implementation - returns nil until records are implemented
        AppLogger.repository.debug("Fetching guide: \(guideID.uuidString)")
        return nil
    }
    
    /// Fetch a single deck by ID
    /// TODO: Implement when FlashcardDeckRecord is created
    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck? {
        AppLogger.repository.startOperation("Fetch Deck")
        defer { AppLogger.repository.completeOperation("Fetch Deck") }
        
        // TODO: Implement when FlashcardDeckRecord is created
        // try await database.dbWriter.read { db in
        //     try FlashcardDeckRecord
        //         .filter(FlashcardDeckRecord.Columns.id == deckID.uuidString)
        //         .fetchOne(db)?
        //         .toDomainModel()
        // }
        
        // Stub implementation - returns nil until records are implemented
        AppLogger.repository.debug("Fetching deck: \(deckID.uuidString)")
        return nil
    }
    
    // MARK: - Creating Content
    
    /// Create a new checklist
    func createChecklist(_ checklist: Checklist) async throws {
        AppLogger.repository.startOperation("Create Checklist")
        defer { AppLogger.repository.completeOperation("Create Checklist") }
        
        try await database.dbWriter.write { db in
            // Save full checklist (using default creatorID for single-user device)
            _ = try ChecklistRecord.saveChecklist(checklist, db: db)
            
            // Create metadata entry
            let metadata = LibraryModel(
                id: checklist.id,
                title: checklist.title,
                description: checklist.description,
                type: .checklist,
                visibility: .private,
                creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), // Placeholder for single-user device
                tags: checklist.tags,
                createdAt: checklist.createdAt,
                updatedAt: checklist.updatedAt,
                syncStatus: checklist.syncStatus
            )
            _ = try LibraryModelRecord.saveMetadata(metadata, db: db)
            
            // TODO: Enqueue for sync if sync service is available
            // try SyncQueueRecord.enqueue(
            //     entityType: SyncEntityType.content.rawValue,
            //     entityID: checklist.id,
            //     operation: .create,
            //     db: db
            // )
        }
        
        AppLogger.repository.info("Checklist created successfully - ID: \(checklist.id.uuidString)")
    }
    
    /// Create a new practice guide
    /// TODO: Implement when PracticeGuideRecord is created
    func createGuide(_ guide: PracticeGuide) async throws {
        AppLogger.repository.startOperation("Create Guide")
        defer { AppLogger.repository.completeOperation("Create Guide") }
        
        // TODO: Implement when PracticeGuideRecord is created
        // try await database.dbWriter.write { db in
        //     var record = PracticeGuideRecord(from: guide, creatorID: creatorID)
        //     record.updatedAt = Date()
        //     try record.save(db)
        //     
        //     // Enqueue for sync if sync service is available
        //     // try SyncQueueRecord.enqueue(
        //     //     entityType: SyncEntityType.content.rawValue,
        //     //     entityID: guide.id,
        //     //     operation: .create,
        //     //     db: db
        //     // )
        // }
        
        // Stub implementation - logs until records are implemented
        AppLogger.repository.debug("Creating guide with ID: \(guide.id.uuidString)")
        AppLogger.repository.info("Guide created successfully - ID: \(guide.id.uuidString)")
    }
    
    /// Create a new flashcard deck
    /// TODO: Implement when FlashcardDeckRecord is created
    func createDeck(_ deck: FlashcardDeck) async throws {
        AppLogger.repository.startOperation("Create Deck")
        defer { AppLogger.repository.completeOperation("Create Deck") }
        
        // TODO: Implement when FlashcardDeckRecord is created
        // try await database.dbWriter.write { db in
        //     var record = FlashcardDeckRecord(from: deck, creatorID: creatorID)
        //     record.updatedAt = Date()
        //     try record.save(db)
        //     
        //     // Enqueue for sync if sync service is available
        //     // try SyncQueueRecord.enqueue(
        //     //     entityType: SyncEntityType.content.rawValue,
        //     //     entityID: deck.id,
        //     //     operation: .create,
        //     //     db: db
        //     // )
        // }
        
        // Stub implementation - logs until records are implemented
        AppLogger.repository.debug("Creating deck with ID: \(deck.id.uuidString)")
        AppLogger.repository.info("Deck created successfully - ID: \(deck.id.uuidString)")
    }
    
    // MARK: - Updating Content
    
    /// Save/update an existing checklist
    func saveChecklist(_ checklist: Checklist) async throws {
        AppLogger.repository.startOperation("Save Checklist")
        defer { AppLogger.repository.completeOperation("Save Checklist") }
        
        try await database.dbWriter.write { db in
            // Update full checklist
            _ = try ChecklistRecord.saveChecklist(checklist, db: db)
            
            // Update metadata entry
            let metadata = LibraryModel(
                id: checklist.id,
                title: checklist.title,
                description: checklist.description,
                type: .checklist,
                visibility: .private,
                creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), // Placeholder for single-user device
                tags: checklist.tags,
                createdAt: checklist.createdAt,
                updatedAt: checklist.updatedAt,
                syncStatus: checklist.syncStatus
            )
            _ = try LibraryModelRecord.saveMetadata(metadata, db: db)
            
            // TODO: Enqueue for sync if sync service is available
            // try SyncQueueRecord.enqueue(
            //     entityType: SyncEntityType.content.rawValue,
            //     entityID: checklist.id,
            //     operation: .update,
            //     db: db
            // )
        }
        
        AppLogger.repository.info("Checklist saved successfully - ID: \(checklist.id.uuidString)")
    }
    
    /// Save/update an existing practice guide
    /// TODO: Implement when PracticeGuideRecord is created
    func saveGuide(_ guide: PracticeGuide) async throws {
        AppLogger.repository.startOperation("Save Guide")
        defer { AppLogger.repository.completeOperation("Save Guide") }
        
        // TODO: Implement when PracticeGuideRecord is created
        // try await database.dbWriter.write { db in
        //     var record = PracticeGuideRecord(from: guide, creatorID: creatorID)
        //     record.updatedAt = Date()
        //     try record.save(db)
        //     
        //     // Enqueue for sync if sync service is available
        //     // try SyncQueueRecord.enqueue(
        //     //     entityType: SyncEntityType.content.rawValue,
        //     //     entityID: guide.id,
        //     //     operation: .update,
        //     //     db: db
        //     // )
        // }
        
        // Stub implementation - logs until records are implemented
        AppLogger.repository.debug("Saving guide with ID: \(guide.id.uuidString)")
        AppLogger.repository.info("Guide saved successfully - ID: \(guide.id.uuidString)")
    }
    
    // MARK: - Deleting Content
    
    /// Delete content by ID
    func deleteContent(_ contentID: UUID) async throws {
        AppLogger.repository.startOperation("Delete Content")
        defer { AppLogger.repository.completeOperation("Delete Content") }
        
        try await database.dbWriter.write { db in
            // Delete metadata
            try LibraryModelRecord.delete(contentID, db: db)
            
            // Delete full content (checklist, guide, or deck)
            // Try to delete from checklists table (will fail silently if not a checklist)
            try? ChecklistRecord.delete(contentID, db: db)
            
            // TODO: Delete from guides and decks tables when implemented
            
            // TODO: Enqueue for sync if sync service is available
            // try SyncQueueRecord.enqueue(
            //     entityType: SyncEntityType.content.rawValue,
            //     entityID: contentID,
            //     operation: .delete,
            //     db: db
            // )
        }
        
        AppLogger.repository.info("Content deleted successfully - ID: \(contentID.uuidString)")
    }
}
