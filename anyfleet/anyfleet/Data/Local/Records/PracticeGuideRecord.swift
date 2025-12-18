//
//  PracticeGuideRecord.swift
//  anyfleet
//
//  GRDB record type for PracticeGuide persistence
//

import Foundation
@preconcurrency import GRDB

/// Database record for PracticeGuide
nonisolated struct PracticeGuideRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "practice_guides"
    
    var id: String
    var title: String
    var description: String?
    var markdown: String
    var tags: String // JSON array of strings
    var creatorID: String
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String
    
    // MARK: - Column Definitions
    
    enum Columns: String, ColumnExpression {
        case id, title, description, markdown, tags
        case creatorID, createdAt, updatedAt, syncStatus
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        markdown: String = "",
        tags: String = "[]",
        creatorID: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: String = "pending"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.markdown = markdown
        self.tags = tags
        self.creatorID = creatorID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Conversion from Domain Model
    
    init(from guide: PracticeGuide) {
        self.id = guide.id.uuidString
        self.title = guide.title
        self.description = guide.description
        self.markdown = guide.markdown
        self.creatorID = "00000000-0000-0000-0000-000000000000" // Placeholder for single-user device
        self.createdAt = guide.createdAt
        self.updatedAt = guide.updatedAt
        self.syncStatus = guide.syncStatus.rawValue
        
        // Encode tags as JSON
        if let tagsData = try? JSONEncoder().encode(guide.tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            self.tags = tagsString
        } else {
            self.tags = "[]"
        }
    }
    
    /// Create record from domain model, preserving existing metadata when updating
    nonisolated static func fromDomainModel(
        _ guide: PracticeGuide,
        existingRecord: PracticeGuideRecord? = nil
    ) -> PracticeGuideRecord {
        var record = PracticeGuideRecord(from: guide)
        
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
    
    nonisolated func toDomainModel() -> PracticeGuide {
        // Decode tags
        var decodedTags: [String] = []
        if let tagsData = tags.data(using: .utf8),
           let tags = try? JSONDecoder().decode([String].self, from: tagsData) {
            decodedTags = tags
        }
        
        // Decode sync status
        let syncStatus = ContentSyncStatus(rawValue: syncStatus) ?? .pending
        
        return PracticeGuide(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            description: description,
            markdown: markdown,
            tags: decodedTags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus
        )
    }
}

// MARK: - Database Operations

extension PracticeGuideRecord {
    /// Fetch all practice guides
    nonisolated static func fetchAll(db: Database) throws -> [PracticeGuideRecord] {
        try PracticeGuideRecord
            .order(Columns.updatedAt.desc)
            .fetchAll(db)
    }
    
    /// Fetch a single guide by ID
    nonisolated static func fetchOne(id: UUID, db: Database) throws -> PracticeGuideRecord? {
        try PracticeGuideRecord
            .filter(Columns.id == id.uuidString)
            .fetchOne(db)
    }
    
    /// Save or update guide
    /// Preserves existing metadata (createdAt, syncStatus) when updating
    @discardableResult
    nonisolated static func saveGuide(_ guide: PracticeGuide, db: Database) throws -> PracticeGuideRecord {
        // Check if record exists
        let existing = try PracticeGuideRecord
            .filter(Columns.id == guide.id.uuidString)
            .fetchOne(db)
        
        // Smart conversion preserving metadata
        let record = fromDomainModel(guide, existingRecord: existing)
        
        // GRDB's save() is mutating, so we need var
        let mutableRecord = record
        try mutableRecord.save(db)
        return mutableRecord
    }
    
    /// Delete guide
    nonisolated static func delete(_ guideID: UUID, db: Database) throws {
        try PracticeGuideRecord
            .filter(Columns.id == guideID.uuidString)
            .deleteAll(db)
    }
    
    /// Mark as synced
    nonisolated static func markSynced(_ guideID: UUID, db: Database) throws {
        try PracticeGuideRecord
            .filter(Columns.id == guideID.uuidString)
            .updateAll(db, Columns.syncStatus.set(to: "synced"))
    }
}

