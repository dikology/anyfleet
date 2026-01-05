import Foundation
import SwiftUI
import OSLog

/// Service responsible for managing the sync queue operations.
///
/// `SyncQueueService` acts as the central coordinator for all content synchronization
/// operations. It handles enqueuing operations, processing the queue, and managing
/// sync state updates. Both `LibraryStore` and `ContentSyncService` depend on this
/// service to avoid circular dependencies.
///
/// This service owns the sync queue operations and provides a clean interface
/// for other components to interact with the sync system without tight coupling.
@MainActor
@Observable
final class SyncQueueService {
    private let repository: LocalRepository
    private let apiClient: APIClientProtocol

    // Configuration
    private let maxRetries = 3

    // State for UI observation
    var pendingCount: Int = 0
    var failedCount: Int = 0

    init(repository: LocalRepository, apiClient: APIClientProtocol) {
        self.repository = repository
        self.apiClient = apiClient
        AppLogger.services.info("SyncQueueService initialized")
    }

    // MARK: - Enqueue Operations

    /// Enqueue a publish operation for content
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws {
        AppLogger.services.info("Enqueuing publish operation for content: \(contentID)")

        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: visibility,
            payload: payload
        )

        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()

        // Trigger immediate sync processing
        Task { @MainActor in
            await processQueue()
        }
    }

    /// Enqueue an unpublish operation for content
    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws {
        AppLogger.services.info("Enqueuing unpublish operation for content: \(contentID)")

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

        // Trigger immediate sync processing
        Task { @MainActor in
            await processQueue()
        }
    }

    /// Enqueue a publish update operation for published content
    func enqueuePublishUpdate(
        contentID: UUID,
        payload: Data
    ) async throws {
        AppLogger.services.info("Enqueuing publish_update operation for content: \(contentID)")

        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish_update,
            visibility: .public, // Content is already public
            payload: payload
        )

        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()

        // Trigger immediate sync processing
        Task { @MainActor in
            await processQueue()
        }
    }

    // MARK: - Queue Processing

    /// Process all pending sync operations
    func processQueue() async -> SyncSummary {
        guard await canSync() else {
            return SyncSummary()
        }

        let operations = await fetchPendingOperations()
        return await processOperations(operations)
    }

    // MARK: - Private Helpers

    private var isProcessing = false

    private func canSync() async -> Bool {
        guard !isProcessing else {
            AppLogger.services.debug("Sync already in progress, skipping")
            return false
        }

        guard await isNetworkReachable() else {
            AppLogger.services.warning("Network unreachable, skipping sync")
            await updatePendingCounts()
            return false
        }

        isProcessing = true
        return true
    }

    private func fetchPendingOperations() async -> [SyncQueueOperation] {
        do {
            let operations = try await repository.getPendingSyncOperations(maxRetries: maxRetries)

            AppLogger.services.debug("Fetched \(operations.count) pending sync operations")
            guard !operations.isEmpty else {
                await updatePendingCounts()
                isProcessing = false
                return []
            }

            AppLogger.services.info("Processing \(operations.count) sync operations")
            return operations
        } catch {
            AppLogger.services.error("Failed to fetch pending sync operations: \(error.localizedDescription)")
            await updatePendingCounts()
            isProcessing = false
            return []
        }
    }

    private func processOperations(_ operations: [SyncQueueOperation]) async -> SyncSummary {
        var summary = SyncSummary()

        for operation in operations {
            await processOperation(operation, summary: &summary)
        }

        await updatePendingCounts()
        AppLogger.services.info("Sync complete: \(summary.succeeded) succeeded, \(summary.failed) failed")

        isProcessing = false
        return summary
    }

    private func processOperation(_ operation: SyncQueueOperation, summary: inout SyncSummary) async {
        summary.attempted += 1

        await updateSyncState(contentID: operation.contentID, status: .syncing)

        do {
            try await executeOperation(operation)
            summary.succeeded += 1

            // Mark as synced
            try await repository.markSyncOperationComplete(operation.id)
            await updateSyncState(contentID: operation.contentID, status: .synced)

            // Clean up any duplicate pending operations for this content
            try? await repository.cancelDuplicateOperations(for: operation.contentID, excluding: operation.id)

            AppLogger.services.info("Sync succeeded for content: \(operation.contentID)")

        } catch {
            summary.failed += 1
            AppLogger.services.error("Sync failed for content: \(operation.contentID), error: \(error)")

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

    private func executeOperation(_ operation: SyncQueueOperation) async throws {
        switch operation.operation {
        case .publish:
            try await handlePublish(operation)
        case .unpublish:
            try await handleUnpublish(operation)
        case .publish_update:
            try await handlePublishUpdate(operation)
        }
    }

    private func handlePublish(_ operation: SyncQueueOperation) async throws {
        guard let payload = operation.payload else {
            throw SyncError.invalidPayload
        }

        // Decode payload
        let decoder = JSONDecoder()
        let contentPayload: ContentPublishPayload
        do {
            contentPayload = try decoder.decode(ContentPublishPayload.self, from: payload)
        } catch {
            AppLogger.services.error("Failed to decode ContentPublishPayload: \(error)")
            throw error
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
        if var item = try await repository.fetchLibraryItem(operation.contentID) {
            item.publicMetadata = PublicMetadata(
                publishedAt: response.publishedAt,
                publicID: response.publicID,
                canFork: response.canFork,
                authorUsername: response.authorUsername ?? "Unknown"
            )
            item.syncStatus = .synced
            try await repository.updateLibraryMetadata(item)
        }

        // Update sync state to reflect successful publish
        await updateSyncState(contentID: operation.contentID, status: .synced)
    }

    private func handleUnpublish(_ operation: SyncQueueOperation) async throws {
        guard let payloadData = operation.payload else {
            throw SyncError.invalidPayload
        }

        let unpublishPayload = try JSONDecoder().decode(UnpublishPayload.self, from: payloadData)

        // Check if this content was ever successfully published
        let hasSuccessfulPublish = try? await repository.hasSuccessfulPublishOperation(for: operation.contentID)
        AppLogger.services.info("Unpublish operation for \(operation.contentID) - has successful publish: \(hasSuccessfulPublish ?? false)")

        // Also check if the content appears published in the database (has publicID and is public)
        let currentItem = try? await repository.fetchLibraryItem(operation.contentID)
        let appearsPublished = currentItem?.visibility == .public && currentItem?.publicID != nil
        AppLogger.services.info("Unpublish operation for \(operation.contentID) - appears published in DB: \(appearsPublished)")

        // If there's no record of successful publish AND the content doesn't appear published, skip the unpublish operation
        // This can happen when publish failed but unpublish was still enqueued
        guard hasSuccessfulPublish == true || appearsPublished == true else {
            AppLogger.services.warning("Skipping unpublish for \(operation.contentID) - no successful publish record and content doesn't appear published")
            return
        }

        // Use publicID from payload
        do {
            try await apiClient.unpublishContent(publicID: unpublishPayload.publicID)
        } catch APIError.notFound {
            // Content doesn't exist (404) - this means it's already unpublished
            // Treat this as successful
            AppLogger.services.info("Content \(unpublishPayload.publicID) not found during unpublish - treating as successful")
        }

        // Update local model - content is now unpublished (whether it existed or not)
        AppLogger.services.info("Unpublish: Updating local content \(operation.contentID)")
        if var updated = try await repository.fetchLibraryItem(operation.contentID) {
            AppLogger.services.info("Unpublish: Found item to update: \(updated.id), visibility: \(updated.visibility.rawValue)")
            updated.visibility = .private
            updated.publicID = nil
            updated.publishedAt = nil
            updated.syncStatus = .synced
            AppLogger.services.info("Unpublish: Updated item - visibility: \(updated.visibility.rawValue), publicID: \(updated.publicID ?? "nil")")
            try await repository.updateLibraryMetadata(updated)
            AppLogger.services.info("Unpublish: Successfully saved updated item")
        } else {
            AppLogger.services.warning("Unpublish: Could not find item \(operation.contentID) to update")
        }
    }

    private func handlePublishUpdate(_ operation: SyncQueueOperation) async throws {
        guard let payload = operation.payload else {
            throw SyncError.invalidPayload
        }

        // Decode the payload
        let decoder = JSONDecoder()
        let contentPayload: ContentPublishPayload
        do {
            contentPayload = try decoder.decode(ContentPublishPayload.self, from: payload)
        } catch {
            AppLogger.services.error("Failed to decode ContentPublishPayload for publish_update: \(error)")
            throw error
        }

        // Get the publicID for the published content
        let publicID = contentPayload.publicID

        // Call backend API to update existing published content
        let response = try await apiClient.updatePublishedContent(
            publicID: publicID,
            title: contentPayload.title,
            description: contentPayload.description,
            contentType: contentPayload.contentType,
            contentData: contentPayload.contentData,
            tags: contentPayload.tags,
            language: contentPayload.language
        )

        // Update local model with server response
        if var item = try await repository.fetchLibraryItem(operation.contentID) {
            item.updatedAt = response.updatedAt ?? Date()
            item.syncStatus = .synced
            try await repository.updateLibraryMetadata(item)
        }

        // Update sync state to reflect successful update
        await updateSyncState(contentID: operation.contentID, status: .synced)
    }

    private func isNetworkReachable() async -> Bool {
        // Basic check - in a real app you might use Network framework
        return true
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
                return operation != .unpublish
            case .conflict:
                // For publish operations, 409 means duplicate public_id
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

    private func updateSyncState(contentID: UUID, status: ContentSyncStatus) async {
        // This method updates the sync state in the repository
        // The actual UI updates will be handled by the stores that observe this service
        AppLogger.services.debug("Updated sync state for content \(contentID) to \(status.rawValue)")
    }

    private func updatePendingCounts() async {
        do {
            let counts = try await repository.getSyncQueueCounts()
            pendingCount = counts.pending
            failedCount = counts.failed
        } catch {
            AppLogger.services.error("Failed to get sync queue counts: \(error.localizedDescription)")
            pendingCount = 0
            failedCount = 0
        }
    }

    private func cancelPendingUnpublishOperations(for contentID: UUID) async {
        do {
            try await repository.cancelPendingOperations(
                contentID: contentID,
                operation: .unpublish
            )
            AppLogger.services.info("Cancelled pending unpublish operations for content: \(contentID)")
        } catch {
            AppLogger.services.error("Failed to cancel pending unpublish operations for \(contentID): \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Summary of sync operation results
public struct SyncSummary {
    var attempted: Int = 0
    var succeeded: Int = 0
    var failed: Int = 0
}

// MARK: - Logger Extension

extension AppLogger {
    /// Logger for sync queue service operations
    static let services = Logger(subsystem: "com.anyfleet.app", category: "Services")
}
