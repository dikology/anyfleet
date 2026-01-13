//
//  ChecklistExecutionRecord.swift
//  anyfleet
//
//  GRDB record type for ChecklistExecutionState persistence
//

import Foundation
@preconcurrency import GRDB

/// Database record for ChecklistExecutionState
nonisolated struct ChecklistExecutionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "checklistExecutionStates"
    
    var id: String
    var checklistID: String
    var charterID: String
    var itemStates: String  // JSON
    var progressPercentage: Double?
    var createdAt: Date
    var lastUpdated: Date
    var completedAt: Date?
    var syncStatus: String
    
    // MARK: - Column Definitions
    
    enum Columns: String, ColumnExpression {
        case id, checklistID, charterID, itemStates, progressPercentage
        case createdAt, lastUpdated, completedAt, syncStatus
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        checklistID: String,
        charterID: String,
        itemStates: String = "{}",
        progressPercentage: Double? = nil,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        completedAt: Date? = nil,
        syncStatus: String = "pending"
    ) {
        self.id = id
        self.checklistID = checklistID
        self.charterID = charterID
        self.itemStates = itemStates
        self.progressPercentage = progressPercentage
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.completedAt = completedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Conversion from Domain Model
    
    init(from domain: ChecklistExecutionState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Convert itemStates dictionary to JSON
        let itemStatesDictRaw = Dictionary(
            uniqueKeysWithValues: domain.itemStates.map { (key, value) in
                (key.uuidString, ItemStateJSON(checked: value.isChecked, checkedAt: value.checkedAt, notes: value.notes))
            }
        )
        
        let itemStatesData = try encoder.encode(itemStatesDictRaw)
        let itemStatesString = String(data: itemStatesData, encoding: .utf8) ?? "{}"
        
        self.id = domain.id.uuidString
        self.checklistID = domain.checklistID.uuidString
        self.charterID = domain.charterID.uuidString
        self.itemStates = itemStatesString
        self.progressPercentage = nil  // Calculated on query if needed
        self.createdAt = domain.createdAt
        self.lastUpdated = domain.lastUpdated
        self.completedAt = domain.completedAt
        self.syncStatus = domain.syncStatus.rawValue
    }
    
    // MARK: - Conversion to Domain Model
    
    nonisolated func toDomainModel() throws -> ChecklistExecutionState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Decode itemStates JSON
        guard let itemStatesData = itemStates.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert itemStates string to Data"
                )
            )
        }
        
        let itemStatesDictRaw = try decoder.decode(
            [String: ItemStateJSON].self,
            from: itemStatesData
        )
        
        // Convert to domain model format
        let itemStates = itemStatesDictRaw.reduce(into: [UUID: ChecklistItemState]()) { result, pair in
            guard let uuid = UUID(uuidString: pair.key) else { return }
            result[uuid] = ChecklistItemState(
                itemID: uuid,
                isChecked: pair.value.checked,
                checkedAt: pair.value.checkedAt,
                notes: pair.value.notes
            )
        }
        
        return ChecklistExecutionState(
            id: UUID(uuidString: id) ?? UUID(),
            checklistID: UUID(uuidString: checklistID) ?? UUID(),
            charterID: UUID(uuidString: charterID) ?? UUID(),
            itemStates: itemStates,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            completedAt: completedAt,
            syncStatus: SyncStatus(rawValue: syncStatus) ?? .pending
        )
    }
}

// MARK: - Helper Types

/// Helper struct for JSON encoding/decoding of item states
private struct ItemStateJSON: Codable {
    let checked: Bool
    let checkedAt: Date?
    let notes: String?
}

// MARK: - Database Operations

extension ChecklistExecutionRecord {
    /// Fetch execution state for a specific checklist in a charter
    nonisolated static func fetch(
        checklistID: UUID,
        charterID: UUID,
        db: Database
    ) throws -> ChecklistExecutionRecord? {
        try ChecklistExecutionRecord
            .filter(
                Columns.checklistID == checklistID.uuidString &&
                Columns.charterID == charterID.uuidString
            )
            .fetchOne(db)
    }
    
    /// Fetch all execution states for a charter
    nonisolated static func fetchForCharter(
        _ charterID: UUID,
        db: Database
    ) throws -> [ChecklistExecutionRecord] {
        try ChecklistExecutionRecord
            .filter(Columns.charterID == charterID.uuidString)
            .fetchAll(db)
    }
    
    /// Save or update execution state
    nonisolated static func saveState(
        _ state: ChecklistExecutionState,
        db: Database
    ) throws {
        let record = try ChecklistExecutionRecord(from: state)
        try record.save(db)
    }
    
    /// Delete execution state for a checklist in a charter
    nonisolated static func deleteState(
        checklistID: UUID,
        charterID: UUID,
        db: Database
    ) throws {
        try ChecklistExecutionRecord
            .filter(
                Columns.checklistID == checklistID.uuidString &&
                Columns.charterID == charterID.uuidString
            )
            .deleteAll(db)
    }
}

