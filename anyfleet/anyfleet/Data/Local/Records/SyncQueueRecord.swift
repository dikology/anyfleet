import Foundation
@preconcurrency import GRDB

/// Database record for sync queue operations
nonisolated struct SyncQueueRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sync_queue"
    
    var id: Int64?
    var contentID: String
    var operation: String // "publish" or "unpublish"
    var visibilityState: String
    var payload: String? // JSON
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    var syncedAt: Date?
    
    enum Columns: String, ColumnExpression {
        case id, contentID = "content_id", operation, visibilityState = "visibility_state"
        case payload, createdAt = "created_at", retryCount = "retry_count"
        case lastError = "last_error", syncedAt = "synced_at"
    }
}

// MARK: - Database Operations

extension SyncQueueRecord {
    /// Enqueue a new operation
    @discardableResult
    nonisolated static func enqueue(
        contentID: UUID,
        operation: SyncOperation,
        visibility: ContentVisibility,
        payload: Data?,
        db: Database
    ) throws -> SyncQueueRecord {
        let payloadString = payload.flatMap { String(data: $0, encoding: .utf8) }
        
        var record = SyncQueueRecord(
            id: nil,
            contentID: contentID.uuidString,
            operation: operation.rawValue,
            visibilityState: visibility.rawValue,
            payload: payloadString,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil,
            syncedAt: nil
        )
        
        try record.insert(db)
        return record
    }
    
    /// Fetch pending operations (not synced, under max retries)
    nonisolated static func fetchPending(maxRetries: Int, db: Database) throws -> [SyncQueueRecord] {
        try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount < maxRetries)
            .order(Columns.createdAt.asc)
            .fetchAll(db)
    }
    
    /// Mark operation as synced
    nonisolated static func markSynced(id: Int64, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET synced_at = ? WHERE id = ?",
            arguments: [Date(), id]
        )
    }
    
    /// Increment retry count and store error
    nonisolated static func incrementRetry(id: Int64, error: String, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?",
            arguments: [error, id]
        )
    }
    
    /// Get counts for UI display
    nonisolated static func getCounts(db: Database) throws -> (pending: Int, failed: Int) {
        let pending = try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount < 3)
            .fetchCount(db)
        
        let failed = try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount >= 3)
            .fetchCount(db)
        
        return (pending, failed)
    }
}