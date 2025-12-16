//
//  ChecklistRecord.swift
//  anyfleet
//
//  GRDB record type for Checklist persistence
//

import Foundation
@preconcurrency import GRDB

/// Database record for Checklist
nonisolated struct ChecklistRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "checklists"
    
    var id: String
    var title: String
    var description: String?
    var checklistType: String
    var tags: String // JSON array of strings
    var content: String // JSON of sections and items
    var creatorID: String
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String
    
    // MARK: - Column Definitions
    
    enum Columns: String, ColumnExpression {
        case id, title, description, checklistType, tags, content
        case creatorID, createdAt, updatedAt, syncStatus
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        checklistType: String,
        tags: String = "[]",
        content: String = "[]",
        creatorID: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: String = "pending"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.checklistType = checklistType
        self.tags = tags
        self.content = content
        self.creatorID = creatorID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Conversion from Domain Model
    
    init(from checklist: Checklist) {
        self.id = checklist.id.uuidString
        self.title = checklist.title
        self.description = checklist.description
        self.checklistType = checklist.checklistType.rawValue
        self.creatorID = "00000000-0000-0000-0000-000000000000" // Placeholder for single-user device
        self.createdAt = checklist.createdAt
        self.updatedAt = checklist.updatedAt
        self.syncStatus = checklist.syncStatus.rawValue
        
        // Encode tags as JSON
        if let tagsData = try? JSONEncoder().encode(checklist.tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            self.tags = tagsString
        } else {
            self.tags = "[]"
        }
        
        // Encode sections/items as JSON
        if let contentData = try? JSONEncoder().encode(checklist.sections),
           let contentString = String(data: contentData, encoding: .utf8) {
            self.content = contentString
        } else {
            self.content = "[]"
        }
    }
    
    /// Create record from domain model, preserving existing metadata when updating
    nonisolated static func fromDomainModel(
        _ checklist: Checklist,
        existingRecord: ChecklistRecord? = nil
    ) -> ChecklistRecord {
        var record = ChecklistRecord(from: checklist)
        
        // Preserve metadata if updating existing record
        if let existing = existingRecord {
            record.createdAt = existing.createdAt
            record.creatorID = existing.creatorID // Preserve original creatorID
            // If already synced, mark as pending; otherwise preserve status
            record.syncStatus = existing.syncStatus == "synced" ? "pending" : existing.syncStatus
        }
        record.updatedAt = Date()  // Always update on save
        return record
    }
    
    // MARK: - Conversion to Domain Model
    
    nonisolated func toDomainModel() -> Checklist {
        // Decode tags
        var decodedTags: [String] = []
        if let tagsData = tags.data(using: .utf8),
           let tags = try? JSONDecoder().decode([String].self, from: tagsData) {
            decodedTags = tags
        }
        
        // Decode sections
        var decodedSections: [ChecklistSection] = []
        if let contentData = content.data(using: .utf8),
           let sections = try? JSONDecoder().decode([ChecklistSection].self, from: contentData) {
            decodedSections = sections
        }
        
        // Decode checklist type
        let type = ChecklistType(rawValue: checklistType) ?? .general
        
        // Decode sync status
        let syncStatus = ContentSyncStatus(rawValue: syncStatus) ?? .pending
        
        return Checklist(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            description: description,
            sections: decodedSections,
            checklistType: type,
            tags: decodedTags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }
}

// MARK: - Database Operations

extension ChecklistRecord {
    /// Fetch all checklists
    nonisolated static func fetchAll(db: Database) throws -> [ChecklistRecord] {
        try ChecklistRecord
            .order(Columns.updatedAt.desc)
            .fetchAll(db)
    }
    
    /// Fetch a single checklist by ID
    nonisolated static func fetchOne(id: UUID, db: Database) throws -> ChecklistRecord? {
        try ChecklistRecord
            .filter(Columns.id == id.uuidString)
            .fetchOne(db)
    }
    
    /// Save or update checklist
    /// Preserves existing metadata (createdAt, syncStatus) when updating
    @discardableResult
    nonisolated static func saveChecklist(_ checklist: Checklist, db: Database) throws -> ChecklistRecord {
        // Check if record exists
        let existing = try ChecklistRecord
            .filter(Columns.id == checklist.id.uuidString)
            .fetchOne(db)
        
        // Smart conversion preserving metadata
        let record = fromDomainModel(checklist, existingRecord: existing)
        
        // GRDB's save() is mutating, so we need var
        let mutableRecord = record
        try mutableRecord.save(db)
        return mutableRecord
    }
    
    /// Delete checklist
    nonisolated static func delete(_ checklistID: UUID, db: Database) throws {
        try ChecklistRecord
            .filter(Columns.id == checklistID.uuidString)
            .deleteAll(db)
    }
    
    /// Mark as synced
    nonisolated static func markSynced(_ checklistID: UUID, db: Database) throws {
        try ChecklistRecord
            .filter(Columns.id == checklistID.uuidString)
            .updateAll(db, Columns.syncStatus.set(to: "synced"))
    }
}

