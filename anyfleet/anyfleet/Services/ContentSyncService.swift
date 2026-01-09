import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentSyncService: ContentSyncServiceProtocol {
    private let syncQueue: SyncQueueService
    private let repository: LocalRepository

    init(
        syncQueue: SyncQueueService,
        repository: LocalRepository
    ) {
        self.syncQueue = syncQueue
        self.repository = repository
        AppLogger.auth.info("ContentSyncService initialized")
    }
    
    // MARK: - Enqueue Operations
    
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws -> SyncSummary {
        AppLogger.auth.info("Enqueuing publish operation for content: \(contentID)")

        let summary = try await syncQueue.enqueuePublish(
            contentID: contentID,
            visibility: visibility,
            payload: payload
        )

        AppLogger.auth.info("Publish sync completed: \(summary.succeeded) succeeded, \(summary.failed) failed")
        return summary
    }
    
    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws -> SyncSummary {
        AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")

        let summary = try await syncQueue.enqueueUnpublish(
            contentID: contentID,
            publicID: publicID
        )

        AppLogger.auth.info("Unpublish sync completed: \(summary.succeeded) succeeded, \(summary.failed) failed")
        return summary
    }

    func enqueuePublishUpdate(
        contentID: UUID,
        payload: Data
    ) async throws {
        AppLogger.auth.info("Enqueuing publish_update operation for content: \(contentID)")

        let summary = try await syncQueue.enqueuePublishUpdate(
            contentID: contentID,
            payload: payload
        )

        AppLogger.auth.info("Publish update sync completed: \(summary.succeeded) succeeded, \(summary.failed) failed")
    }

    /// Enqueue a publish operation without immediately syncing (for testing)
    func enqueuePublishOnly(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws {
        AppLogger.auth.info("Enqueuing publish operation (no sync): \(contentID)")

        try await syncQueue.enqueuePublishOnly(
            contentID: contentID,
            visibility: visibility,
            payload: payload
        )
    }

    /// Enqueue an unpublish operation without immediately syncing (for testing)
    func enqueueUnpublishOnly(
        contentID: UUID,
        publicID: String
    ) async throws {
        AppLogger.auth.info("Enqueuing unpublish operation (no sync): \(contentID)")

        try await syncQueue.enqueueUnpublishOnly(
            contentID: contentID,
            publicID: publicID
        )
    }

    // MARK: - Sync Processing

    /// Trigger processing of pending sync operations
    func syncPending() async -> SyncSummary {
        return await syncQueue.processQueue()
    }

    
}

// MARK: - Supporting Types

// SyncSummary is now defined in SyncQueueService

public enum SyncOperation: String, Codable {
    case publish
    case unpublish
    case publish_update
}

public struct SyncQueueOperation {
    let id: Int64
    let contentID: UUID
    let operation: SyncOperation
    let visibility: ContentVisibility
    let payload: Data?
    let retryCount: Int
    let lastError: String?
    let createdAt: Date
}

enum SyncError: LocalizedError {
    case invalidPayload
    case missingPublicID
    case networkUnreachable
    
    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid sync payload"
        case .missingPublicID:
            return "Content missing public ID"
        case .networkUnreachable:
            return "Network unreachable"
        }
    }
}