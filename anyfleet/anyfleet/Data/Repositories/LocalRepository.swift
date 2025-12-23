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
    
    /// Update charter with new values
    func updateCharter(_ charterID: UUID, name: String, boatName: String?, location: String?, startDate: Date, endDate: Date, checkInChecklistID: UUID?) async throws -> CharterModel {
        AppLogger.repository.startOperation("Update Charter")
        defer { AppLogger.repository.completeOperation("Update Charter") }
        
        AppLogger.repository.debug("Updating charter with ID: \(charterID.uuidString)")
        
        do {
            // Fetch existing charter to preserve metadata
            guard let existingCharter = try await fetchCharter(id: charterID) else {
                throw AppError.notFound(entity: "Charter", id: charterID)
            }
            
            // Create updated charter model preserving existing metadata
            let updatedCharter = CharterModel(
                id: charterID,
                name: name,
                boatName: boatName,
                location: location,
                startDate: startDate,
                endDate: endDate,
                createdAt: existingCharter.createdAt,
                checkInChecklistID: checkInChecklistID
            )
            
            // Save the updated charter
            try await database.dbWriter.write { db in
                _ = try CharterRecord.saveCharter(updatedCharter, db: db)
            }
            
            AppLogger.repository.info("Charter updated successfully - ID: \(charterID.uuidString)")
            return updatedCharter
        } catch {
            AppLogger.repository.failOperation("Update Charter", error: error)
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
    func fetchUserGuides() async throws -> [PracticeGuide] {
        AppLogger.repository.startOperation("Fetch User Guides")
        defer { AppLogger.repository.completeOperation("Fetch User Guides") }
        
        return try await database.dbWriter.read { db in
            try PracticeGuideRecord.fetchAll(db: db)
                .map { $0.toDomainModel() }
        }
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
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? {
        AppLogger.repository.startOperation("Fetch Guide")
        defer { AppLogger.repository.completeOperation("Fetch Guide") }
        
        return try await database.dbWriter.read { db in
            try PracticeGuideRecord.fetchOne(id: guideID, db: db)?
                .toDomainModel()
        }
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
    func createGuide(_ guide: PracticeGuide) async throws {
        AppLogger.repository.startOperation("Create Guide")
        defer { AppLogger.repository.completeOperation("Create Guide") }
        
        try await database.dbWriter.write { db in
            // Save full guide
            _ = try PracticeGuideRecord.saveGuide(guide, db: db)
            
            // Create metadata entry
            let metadata = LibraryModel(
                id: guide.id,
                title: guide.title,
                description: guide.description,
                type: .practiceGuide,
                visibility: .private,
                creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), // Placeholder for single-user device
                tags: guide.tags,
                createdAt: guide.createdAt,
                updatedAt: guide.updatedAt,
                syncStatus: guide.syncStatus
            )
            _ = try LibraryModelRecord.saveMetadata(metadata, db: db)
            
            // TODO: Enqueue for sync if sync service is available
            // try SyncQueueRecord.enqueue(
            //     entityType: SyncEntityType.content.rawValue,
            //     entityID: guide.id,
            //     operation: .create,
            //     db: db
            // )
        }
        
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
    func saveGuide(_ guide: PracticeGuide) async throws {
        AppLogger.repository.startOperation("Save Guide")
        defer { AppLogger.repository.completeOperation("Save Guide") }
        
        try await database.dbWriter.write { db in
            // Update full guide
            _ = try PracticeGuideRecord.saveGuide(guide, db: db)
            
            // Update metadata entry
            let metadata = LibraryModel(
                id: guide.id,
                title: guide.title,
                description: guide.description,
                type: .practiceGuide,
                visibility: .private,
                creatorID: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), // Placeholder for single-user device
                tags: guide.tags,
                createdAt: guide.createdAt,
                updatedAt: guide.updatedAt,
                syncStatus: guide.syncStatus
            )
            _ = try LibraryModelRecord.saveMetadata(metadata, db: db)
            
            // TODO: Enqueue for sync if sync service is available
            // try SyncQueueRecord.enqueue(
            //     entityType: SyncEntityType.content.rawValue,
            //     entityID: guide.id,
            //     operation: .update,
            //     db: db
            // )
        }
        
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
            
            // Try to delete from guides table (will fail silently if not a guide)
            try? PracticeGuideRecord.delete(contentID, db: db)
            
            // TODO: Delete from decks table when implemented
            
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
    
    /// Update metadata for a library item (e.g. pin state, title)
    func updateLibraryMetadata(_ model: LibraryModel) async throws {
        AppLogger.repository.startOperation("Update Library Metadata")
        defer { AppLogger.repository.completeOperation("Update Library Metadata") }
        
        try await database.dbWriter.write { db in
            _ = try LibraryModelRecord.saveMetadata(model, db: db)
        }
        
        AppLogger.repository.info("Library metadata updated - ID: \(model.id.uuidString)")
    }
    
    // MARK: - Checklist Execution State Operations
}

// MARK: - ChecklistExecutionRepository Implementation

extension LocalRepository {
    
    func saveItemState(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        isChecked: Bool
    ) async throws {
        AppLogger.repository.startOperation("Save Execution Item State")
        defer { AppLogger.repository.completeOperation("Save Execution Item State") }
        
        try await database.dbWriter.write { db in
            // Load existing state or create new
            let existingRecord = try ChecklistExecutionRecord
                .fetch(checklistID: checklistID, charterID: charterID, db: db)
            
            if let record = existingRecord {
                // Update existing
                var state = try record.toDomainModel()
                state.itemStates[itemID] = ChecklistItemState(
                    itemID: itemID,
                    isChecked: isChecked,
                    checkedAt: isChecked ? Date() : nil
                )
                state.lastUpdated = Date()
                
                try ChecklistExecutionRecord.saveState(state, db: db)
            } else {
                // Create new
                let newState = ChecklistExecutionState(
                    id: UUID(),
                    checklistID: checklistID,
                    charterID: charterID,
                    itemStates: [itemID: ChecklistItemState(
                        itemID: itemID,
                        isChecked: isChecked,
                        checkedAt: isChecked ? Date() : nil
                    )],
                    createdAt: Date(),
                    lastUpdated: Date(),
                    completedAt: nil,
                    syncStatus: .pending
                )
                try ChecklistExecutionRecord.saveState(newState, db: db)
            }
        }
    }
    
    func loadExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws -> ChecklistExecutionState? {
        AppLogger.repository.startOperation("Load Execution State")
        defer { AppLogger.repository.completeOperation("Load Execution State") }
        
        return try await database.dbWriter.read { db in
            try ChecklistExecutionRecord
                .fetch(checklistID: checklistID, charterID: charterID, db: db)
                .map { try $0.toDomainModel() }
        }
    }
    
    func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState] {
        AppLogger.repository.startOperation("Load Charter Execution States")
        defer { AppLogger.repository.completeOperation("Load Charter Execution States") }
        
        return try await database.dbWriter.read { db in
            try ChecklistExecutionRecord.fetchForCharter(charterID, db: db)
                .map { try $0.toDomainModel() }
        }
    }
    
    func clearExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws {
        AppLogger.repository.startOperation("Clear Execution State")
        defer { AppLogger.repository.completeOperation("Clear Execution State") }
        
        try await database.dbWriter.write { db in
            try ChecklistExecutionRecord.deleteState(
                checklistID: checklistID,
                charterID: charterID,
                db: db
            )
        }
    }
}

// MARK: - Sync Queue Operations

extension LocalRepository {
    /// Enqueue a sync operation
    func enqueueSyncOperation(
        contentID: UUID,
        operation: SyncOperation,
        visibility: ContentVisibility,
        payload: Data?
    ) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.enqueue(
                contentID: contentID,
                operation: operation,
                visibility: visibility,
                payload: payload,
                db: db
            )
        }
    }
    
    /// Get pending sync operations
    func getPendingSyncOperations(maxRetries: Int) async throws -> [SyncQueueOperation] {
        try await database.dbWriter.read { db in
            let records = try SyncQueueRecord.fetchPending(maxRetries: maxRetries, db: db)
            return records.map { record in
                SyncQueueOperation(
                    id: record.id!,
                    contentID: UUID(uuidString: record.contentID)!,
                    operation: SyncOperation(rawValue: record.operation)!,
                    visibility: ContentVisibility(rawValue: record.visibilityState)!,
                    payload: record.payload?.data(using: .utf8),
                    retryCount: record.retryCount,
                    lastError: record.lastError,
                    createdAt: record.createdAt
                )
            }
        }
    }
    
    /// Mark operation as synced
    func markSyncOperationComplete(_ operationID: Int64) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.markSynced(id: operationID, db: db)
        }
    }
    
    /// Increment retry count
    func incrementSyncRetryCount(_ operationID: Int64, error: String) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.incrementRetry(id: operationID, error: error, db: db)
        }
    }
    
    /// Get sync queue counts
    func getSyncQueueCounts() async throws -> (pending: Int, failed: Int) {
        try await database.dbWriter.read { db in
            try SyncQueueRecord.getCounts(db: db)
        }
    }
}