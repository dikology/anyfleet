//
//  LibraryModelRecord.swift
//  anyfleet
//
//  GRDB record type for LibraryModel (metadata) persistence
//

import Foundation
@preconcurrency import GRDB

/// Database record for LibraryModel (content metadata)
nonisolated struct LibraryModelRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "library_content"
    
    var id: String
    var title: String
    var description: String?
    var type: String
    var visibility: String
    var creatorID: String
    var forkedFromID: String?
    var originalAuthorUsername: String?
    var originalContentPublicID: String?
    var forkCount: Int
    var ratingAverage: Double?
    var ratingCount: Int
    var tags: String // JSON array of strings
    var language: String
    var isPinned: Bool
    var pinnedOrder: Int?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String
    var publishedAt: Date?
    var publicID: String?
    var publicMetadata: String? // JSON for PublicMetadata
    
    // MARK: - Column Definitions
    
    enum Columns: String, ColumnExpression {
        case id, title, description, type, visibility
        case creatorID, forkedFromID, originalAuthorUsername, originalContentPublicID, forkCount
        case ratingAverage, ratingCount, tags, language
        case isPinned, pinnedOrder
        case createdAt, updatedAt, syncStatus
        case publishedAt, publicID, publicMetadata
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        type: String,
        visibility: String,
        creatorID: String,
        forkedFromID: String? = nil,
        originalAuthorUsername: String? = nil,
        originalContentPublicID: String? = nil,
        forkCount: Int = 0,
        ratingAverage: Double? = nil,
        ratingCount: Int = 0,
        tags: String = "[]",
        language: String = "en",
        isPinned: Bool = false,
        pinnedOrder: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: String = "pending",
        publishedAt: Date? = nil,
        publicID: String? = nil,
        publicMetadata: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.visibility = visibility
        self.creatorID = creatorID
        self.forkedFromID = forkedFromID
        self.originalAuthorUsername = originalAuthorUsername
        self.originalContentPublicID = originalContentPublicID
        self.forkCount = forkCount
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.tags = tags
        self.language = language
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.publishedAt = publishedAt
        self.publicID = publicID
        self.publicMetadata = publicMetadata
    }
    
    // MARK: - Conversion from Domain Model
    
    init(from model: LibraryModel) {
        self.id = model.id.uuidString
        self.title = model.title
        self.description = model.description
        self.type = model.type.rawValue
        self.visibility = model.visibility.rawValue
        self.creatorID = model.creatorID.uuidString
        self.forkedFromID = model.forkedFromID?.uuidString
        self.originalAuthorUsername = model.originalAuthorUsername
        self.originalContentPublicID = model.originalContentPublicID
        self.forkCount = model.forkCount
        self.ratingAverage = model.ratingAverage
        self.ratingCount = model.ratingCount
        self.language = model.language
        self.isPinned = model.isPinned
        self.pinnedOrder = model.pinnedOrder
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.syncStatus = model.syncStatus.rawValue
        self.publishedAt = model.publishedAt
        self.publicID = model.publicID
        
        // Encode tags as JSON
        if let tagsData = try? JSONEncoder().encode(model.tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            self.tags = tagsString
        } else {
            self.tags = "[]"
        }
        
        // Encode publicMetadata as JSON
        if let metadata = model.publicMetadata {
            self.publicMetadata = Self.encodePublicMetadata(metadata)
        } else {
            self.publicMetadata = nil
        }
    }
    
    // MARK: - Conversion to Domain Model
    
    nonisolated func toDomainModel() -> LibraryModel {
        // Decode tags
        var decodedTags: [String] = []
        if let tagsData = tags.data(using: .utf8),
           let tags = try? JSONDecoder().decode([String].self, from: tagsData) {
            decodedTags = tags
        }
        
        // Decode enums
        let contentType = ContentType(rawValue: type) ?? .checklist
        let visibility = ContentVisibility(rawValue: self.visibility) ?? .private
        let syncStatus = ContentSyncStatus(rawValue: self.syncStatus) ?? .pending
        
        // Decode publicMetadata
        var decodedMetadata: PublicMetadata? = nil
        if let metadataString = publicMetadata,
           let metadataData = metadataString.data(using: .utf8) {
            // Decode in nonisolated context to avoid main actor isolation issues
            decodedMetadata = Self.decodePublicMetadata(from: metadataData)
        }
        
        return LibraryModel(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            description: description,
            type: contentType,
            visibility: visibility,
            creatorID: UUID(uuidString: creatorID) ?? UUID(),
            forkedFromID: forkedFromID.flatMap { UUID(uuidString: $0) },
            forkCount: forkCount,
            originalAuthorUsername: originalAuthorUsername,
            originalContentPublicID: originalContentPublicID,
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            tags: decodedTags,
            language: language,
            isPinned: isPinned,
            pinnedOrder: pinnedOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: syncStatus,
            publishedAt: publishedAt,
            publicID: publicID,
            publicMetadata: decodedMetadata
        )
    }
}

// MARK: - Database Operations

extension LibraryModelRecord {
    /// Encode PublicMetadata in a nonisolated context
    nonisolated private static func encodePublicMetadata(_ metadata: PublicMetadata) -> String? {
        guard let data = try? JSONEncoder().encode(metadata),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Decode PublicMetadata in a nonisolated context
    nonisolated private static func decodePublicMetadata(from data: Data) -> PublicMetadata? {
        try? JSONDecoder().decode(PublicMetadata.self, from: data)
    }
    /// Fetch all library content
    nonisolated static func fetchAll(db: Database) throws -> [LibraryModelRecord] {
        try LibraryModelRecord
            .order(Columns.updatedAt.desc)
            .fetchAll(db)
    }
    
    /// Fetch library content by type
    nonisolated static func fetchByType(_ type: ContentType, db: Database) throws -> [LibraryModelRecord] {
        try LibraryModelRecord
            .filter(Columns.type == type.rawValue)
            .order(Columns.updatedAt.desc)
            .fetchAll(db)
    }
    
    /// Save or update library metadata
    @discardableResult
    nonisolated static func saveMetadata(_ model: LibraryModel, db: Database) throws -> LibraryModelRecord {
        let record = LibraryModelRecord(from: model)
        let mutableRecord = record
        try mutableRecord.save(db)
        return mutableRecord
    }
    
    /// Delete library metadata
    nonisolated static func delete(_ contentID: UUID, db: Database) throws {
        try LibraryModelRecord
            .filter(Columns.id == contentID.uuidString)
            .deleteAll(db)
    }
}

