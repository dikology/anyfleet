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
}
