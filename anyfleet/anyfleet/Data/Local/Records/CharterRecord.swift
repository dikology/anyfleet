//
//  CharterRecord.swift
//  anyfleet
//
//  GRDB record type for Charter persistence
//

import Foundation
@preconcurrency import GRDB

/// Database record for Charter
nonisolated struct CharterRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "charters"
    
    var id: String
    var name: String
    var boatName: String?
    var location: String?
    var startDate: Date
    var endDate: Date
    var checkInChecklistID: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String
    
    // MARK: - Column Definitions
    
    enum Columns: String, ColumnExpression {
        case id, name, boatName, location, startDate, endDate
        case checkInChecklistID
        case createdAt, updatedAt, syncStatus
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        name: String,
        boatName: String? = nil,
        location: String? = nil,
        startDate: Date,
        endDate: Date,
        checkInChecklistID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: String = "pending"
    ) {
        self.id = id
        self.name = name
        self.boatName = boatName
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.checkInChecklistID = checkInChecklistID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Conversion from Domain Model
    
    init(from charter: CharterModel) {
        self.id = charter.id.uuidString
        self.name = charter.name
        self.boatName = charter.boatName
        self.location = charter.location
        self.startDate = charter.startDate
        self.endDate = charter.endDate
        self.checkInChecklistID = charter.checkInChecklistID?.uuidString
        self.createdAt = charter.createdAt
        self.updatedAt = Date()
        self.syncStatus = "pending"
    }
    
    /// Create record from domain model, preserving existing metadata when updating
    nonisolated static func fromDomainModel(
        _ charter: CharterModel,
        existingRecord: CharterRecord? = nil
    ) -> CharterRecord {
        var record = CharterRecord(from: charter)
        
        // Preserve metadata if updating existing record
        if let existing = existingRecord {
            record.createdAt = existing.createdAt
            // If already synced, mark as pending update; otherwise preserve status
            record.syncStatus = existing.syncStatus == "synced" ? "pending_update" : existing.syncStatus
        }
        record.updatedAt = Date()  // Always update on save
        return record
    }
    
    // MARK: - Conversion to Domain Model
    
    nonisolated func toDomainModel() -> CharterModel {
        CharterModel(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            boatName: boatName,
            location: location,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            checkInChecklistID: checkInChecklistID.flatMap { UUID(uuidString: $0) }
        )
    }
}

// MARK: - Database Operations

extension CharterRecord {
    /// Fetch all charters ordered by start date
    nonisolated static func fetchAll(db: Database) throws -> [CharterRecord] {
        try CharterRecord
            .order(Columns.startDate.desc)
            .fetchAll(db)
    }
    
    /// Fetch active charters (current date between start and end)
    nonisolated static func fetchActive(db: Database) throws -> [CharterRecord] {
        let now = Date()
        return try CharterRecord
            .filter(Columns.startDate <= now)
            .filter(Columns.endDate >= now)
            .fetchAll(db)
    }
    
    /// Fetch upcoming charters
    nonisolated static func fetchUpcoming(db: Database) throws -> [CharterRecord] {
        let now = Date()
        return try CharterRecord
            .filter(Columns.startDate > now)
            .order(Columns.startDate.asc)
            .fetchAll(db)
    }
    
    /// Fetch past charters
    nonisolated static func fetchPast(db: Database) throws -> [CharterRecord] {
        let now = Date()
        return try CharterRecord
            .filter(Columns.endDate < now)
            .order(Columns.endDate.desc)
            .fetchAll(db)
    }
    
    /// Fetch pending sync charters
    nonisolated static func fetchPendingSync(db: Database) throws -> [CharterRecord] {
        try CharterRecord
            .filter(Columns.syncStatus == "pending")
            .fetchAll(db)
    }
    
    /// Save or update charter
    /// Preserves existing metadata (createdAt, syncStatus) when updating
    @discardableResult
    nonisolated static func saveCharter(_ charter: CharterModel, db: Database) throws -> CharterRecord {
        // Check if record exists
        let existing = try CharterRecord
            .filter(Columns.id == charter.id.uuidString)
            .fetchOne(db)
        
        // Smart conversion preserving metadata
        let record = fromDomainModel(charter, existingRecord: existing)
        
        // GRDB's save() is mutating, so we need var
        // The compiler warning is a false positive - save() does mutate the record
        let mutableRecord = record
        try mutableRecord.save(db)
        return mutableRecord
    }
    
    /// Delete charter
    nonisolated static func delete(_ charterID: UUID, db: Database) throws {
        try CharterRecord
            .filter(Columns.id == charterID.uuidString)
            .deleteAll(db)
    }
    
    /// Mark as synced
    nonisolated static func markSynced(_ charterID: UUID, db: Database) throws {
        try CharterRecord
            .filter(Columns.id == charterID.uuidString)
            .updateAll(db, Columns.syncStatus.set(to: "synced"))
    }
}
