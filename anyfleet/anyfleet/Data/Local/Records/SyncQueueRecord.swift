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
    /// Earliest timestamp at which this operation may be retried.
    /// `nil` on the first attempt. Set to `now + retryDelay` on each failure.
    var nextRetryAt: Date?

    enum Columns: String, ColumnExpression {
        case id, contentID, operation, visibilityState
        case payload, createdAt, retryCount, lastError, syncedAt, nextRetryAt
    }

    // MARK: - Retry Backoff

    /// Exponential delay (seconds) before the nth retry attempt.
    /// Caps at 5 minutes to avoid stale items sitting forever.
    nonisolated static func retryDelay(for retryCount: Int) -> TimeInterval {
        let base = 1.0
        let maxDelay = 300.0
        return min(base * pow(2.0, Double(retryCount)), maxDelay)
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
        
        let record = SyncQueueRecord(
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
    
    /// Fetch pending operations (not synced, under max retries, past their backoff window).
    nonisolated static func fetchPending(maxRetries: Int, db: Database) throws -> [SyncQueueRecord] {
        let now = Date()
        return try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount < maxRetries)
            .filter(Columns.nextRetryAt == nil || Columns.nextRetryAt <= now)
            .order(Columns.createdAt.asc)
            .fetchAll(db)
    }
    
    /// Mark operation as synced
    nonisolated static func markSynced(id: Int64, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET syncedAt = ? WHERE id = ?",
            arguments: [Date(), id]
        )
    }

    /// Increment retry count, store the error message, and set the backoff window.
    nonisolated static func incrementRetry(id: Int64, error: String, nextRetryAt: Date, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET retryCount = retryCount + 1, lastError = ?, nextRetryAt = ? WHERE id = ?",
            arguments: [error, nextRetryAt, id]
        )
    }

    /// Jump retryCount straight to `maxRetries` so `fetchPending` never picks this
    /// record up again. Used for terminal errors (401, 403, 409 on publish, etc.)
    /// that can never succeed regardless of how many times they are retried.
    nonisolated static func exhaustRetries(id: Int64, maxRetries: Int, error: String, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET retryCount = ?, lastError = ?, nextRetryAt = NULL WHERE id = ?",
            arguments: [maxRetries, error, id]
        )
    }

    /// Reset all failed operations (retryCount >= maxRetries, not yet synced) back to
    /// retryCount = 0 so they re-enter the processing queue. Provides the user with
    /// an explicit "retry all failed" escape hatch.
    nonisolated static func resetFailed(maxRetries: Int, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET retryCount = 0, lastError = NULL, nextRetryAt = NULL WHERE syncedAt IS NULL AND retryCount >= ?",
            arguments: [maxRetries]
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
