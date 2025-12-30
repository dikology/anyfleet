import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentSyncService {
    private let repository: LocalRepository
    private let apiClient: APIClientProtocol
    private let libraryStore: LibraryStore

    // Configuration
    private let maxRetries = 3

    // State
    var isSyncing = false
    var pendingCount: Int = 0
    var failedCount: Int = 0

    init(
        repository: LocalRepository,
        apiClient: APIClientProtocol,
        libraryStore: LibraryStore
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.libraryStore = libraryStore
        AppLogger.auth.info("ContentSyncService initialized")
    }
    
    // MARK: - Enqueue Operations
    
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws {
        AppLogger.auth.info("Enqueuing publish operation for content: \(contentID)")
        
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: visibility,
            payload: payload
        )
        
        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()
        
        // Trigger sync (will implement in next phase)
        Task {
            await syncPending()
        }
    }
    
    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws {
        AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")
        
        // Create payload with publicID
        let unpublishPayload = UnpublishPayload(publicID: publicID)
        let payloadData = try JSONEncoder().encode(unpublishPayload)
        
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .unpublish,
            visibility: .private,
            payload: payloadData
        )
        
        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()
        
        Task {
            await syncPending()
        }
    }
    
    // MARK: - Sync Processing (Stub for now)
    
    func syncPending() async -> SyncSummary {
        guard !isSyncing else {
            return SyncSummary()
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        var summary = SyncSummary()
        
        // Check network connectivity (basic check)
        guard await isNetworkReachable() else {
            AppLogger.auth.warning("Network unreachable, skipping sync")
            await updatePendingCounts()
            return summary
        }
        
        // Fetch pending operations
        let operations = try? await repository.getPendingSyncOperations(maxRetries: maxRetries)
        guard let operations = operations, !operations.isEmpty else {
            await updatePendingCounts()
            return summary
        }
        
        AppLogger.auth.info("Processing \(operations.count) sync operations")
        
        // Process each operation
        for operation in operations {
            summary.attempted += 1
            
            await updateSyncState(contentID: operation.contentID, status: .syncing)
            
            do {
                try await processOperation(operation, apiClient: apiClient)
                summary.succeeded += 1
                
                // Mark as synced
                try await repository.markSyncOperationComplete(operation.id)
                await updateSyncState(contentID: operation.contentID, status: .synced)

                // Clean up any duplicate pending operations for this content
                try? await repository.cancelDuplicateOperations(for: operation.contentID, excluding: operation.id)

                AppLogger.auth.info("Sync succeeded for content: \(operation.contentID)")
                
            } catch {
                summary.failed += 1
                AppLogger.auth.error("Sync failed for content: \(operation.contentID), error: \(error)")

                // Check if we should retry
                let shouldRetry = operation.retryCount < maxRetries && isRetryableError(error, operation: operation.operation)

                if shouldRetry {
                    // Increment retry count
                    try? await repository.incrementSyncRetryCount(
                        operation.id,
                        error: error.localizedDescription
                    )
                    await updateSyncState(contentID: operation.contentID, status: .pending)
                } else {
                    // Max retries exceeded or terminal error
                    await updateSyncState(contentID: operation.contentID, status: .failed)

                    // If this was a publish operation that failed permanently,
                    // cancel any pending unpublish operations for the same content
                    if operation.operation == .publish {
                        await cancelPendingUnpublishOperations(for: operation.contentID)
                    }
                }
            }
        }
        
        await updatePendingCounts()
        AppLogger.auth.info("Sync complete: \(summary.succeeded) succeeded, \(summary.failed) failed")
        return summary
    }

    private func processOperation(_ operation: SyncQueueOperation, apiClient: APIClientProtocol) async throws {
        switch operation.operation {
        case .publish:
            try await handlePublish(operation, apiClient: apiClient)
        case .unpublish:
            try await handleUnpublish(operation, apiClient: apiClient)
        }
    }

    private func handlePublish(_ operation: SyncQueueOperation, apiClient: APIClientProtocol) async throws {
        guard let payload = operation.payload else {
            throw SyncError.invalidPayload
        }

        // Debug: log the payload content
        if let payloadString = String(data: payload, encoding: .utf8) {
            AppLogger.auth.debug("Decoding payload for publish operation: \(payloadString)")
        }

        // Remove decoder strategy - use explicit CodingKeys
        let decoder = JSONDecoder()
        
        let contentPayload: ContentPublishPayload
        do {
            contentPayload = try decoder.decode(ContentPublishPayload.self, from: payload)
        } catch let decodingError as DecodingError {
            AppLogger.auth.error("Failed to decode ContentPublishPayload: \(decodingError)")
            // Log the payload content for debugging
            if let payloadString = String(data: payload, encoding: .utf8) {
                AppLogger.auth.error("Payload content: \(payloadString)")
            }
            throw decodingError
        } catch {
            AppLogger.auth.error("Unexpected error decoding payload: \(error)")
            throw error
        }

        // Get current item from repository (not in-memory cache which can be stale)
        guard var item = try await libraryStore.fetchLibraryItem(operation.contentID) else {
            throw SyncError.missingPublicID
        }
        
        // Call backend API
        let response = try await apiClient.publishContent(
            title: contentPayload.title,
            description: contentPayload.description,
            contentType: contentPayload.contentType,
            contentData: contentPayload.contentData,
            tags: contentPayload.tags,
            language: contentPayload.language,
            publicID: contentPayload.publicID,
            canFork: true,
            forkedFromID: contentPayload.forkedFromID
        )
        
        // Update local model with server response
        item.publicMetadata = PublicMetadata(
            publishedAt: response.publishedAt,
            publicID: response.publicID,
            canFork: response.canFork,
            authorUsername: response.authorUsername ?? "Unknown"
        )
        item.syncStatus = .synced
        try await libraryStore.updateLibraryMetadata(item)
    }

    private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClientProtocol) async throws {
        // Get publicID from payload, not from item
        guard let payloadData = operation.payload else {
            throw SyncError.invalidPayload
        }

        let unpublishPayload = try JSONDecoder().decode(UnpublishPayload.self, from: payloadData)

        // Check if this content was ever successfully published by looking for completed publish operations
        let hasSuccessfulPublish = try? await repository.hasSuccessfulPublishOperation(for: operation.contentID)

        // If there's no record of successful publish, skip the unpublish operation
        // This can happen when publish failed but unpublish was still enqueued
        guard hasSuccessfulPublish == true else {
            AppLogger.auth.info("Skipping unpublish for \(operation.contentID) - no successful publish found")
            return
        }

        // Use publicID from payload
        do {
            try await apiClient.unpublishContent(publicID: unpublishPayload.publicID)
        } catch APIError.notFound {
            // Content doesn't exist (404) - this means it's already unpublished
            // Treat this as successful
            AppLogger.auth.info("Content \(unpublishPayload.publicID) not found during unpublish - treating as successful (already unpublished)")
        }

        // Update local model - content is now unpublished (whether it existed or not)
        if var updated = libraryStore.library.first(where: { $0.id == operation.contentID }) {
            updated.syncStatus = .synced
            try await libraryStore.updateLibraryMetadata(updated)
        }
    }

    private func isNetworkReachable() async -> Bool {
        // Basic check: try to connect to backend
        // You can use Network framework for more sophisticated checks
        return true // For now, assume reachable
    }

    private func isRetryableError(_ error: Error, operation: SyncOperation) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError, .serverError:
                return true
            case .unauthorized, .forbidden:
                return false
            case .notFound:
                // For unpublish operations, 404 means the content was never published or already deleted
                // This is not retryable
                return operation != .unpublish
            case .conflict:
                // For publish operations, 409 means duplicate public_id - not retryable
                return operation != .publish
            case .clientError:
                return false
            case .invalidResponse:
                return true
            }
        }

        // Network errors from URLSession
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                return false
            }
        }

        return true // Unknown errors: retry once
    }
    
    // MARK: - Helper Methods
    
    private func updateSyncState(contentID: UUID, status: ContentSyncStatus) async {
        // Find the item in the library store's metadata collection
        if let index = libraryStore.library.firstIndex(where: { $0.id == contentID }) {
            var item = libraryStore.library[index]
            item.syncStatus = status
            try? await libraryStore.updateLibraryMetadata(item)
        }
    }
    
    private func updatePendingCounts() async {
        let counts = try? await repository.getSyncQueueCounts()
        pendingCount = counts?.pending ?? 0
        failedCount = counts?.failed ?? 0
    }

    private func cancelPendingUnpublishOperations(for contentID: UUID) async {
        do {
            try await repository.cancelPendingOperations(
                contentID: contentID,
                operation: .unpublish
            )
            AppLogger.auth.info("Cancelled pending unpublish operations for content: \(contentID)")
        } catch {
            AppLogger.auth.error("Failed to cancel pending unpublish operations for \(contentID): \(error)")
        }
    }
}

// MARK: - Supporting Types

public struct SyncSummary {
    var attempted: Int = 0
    var succeeded: Int = 0
    var failed: Int = 0
}

public enum SyncOperation: String, Codable {
    case publish
    case unpublish
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