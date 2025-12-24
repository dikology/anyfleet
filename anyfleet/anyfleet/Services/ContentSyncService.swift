import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentSyncService {
    private let repository: LocalRepository
    private let apiClient: APIClient
    private let libraryStore: LibraryStore
    
    // Configuration
    private let maxRetries = 3
    
    // State
    var isSyncing = false
    var pendingCount: Int = 0
    var failedCount: Int = 0
    
    init(
        repository: LocalRepository,
        apiClient: APIClient,
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
        
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .unpublish,
            visibility: .private,
            payload: nil
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
                
                AppLogger.auth.info("Sync succeeded for content: \(operation.contentID)")
                
            } catch {
                summary.failed += 1
                AppLogger.auth.error("Sync failed for content: \(operation.contentID), error: \(error)")
                
                // Check if we should retry
                let shouldRetry = operation.retryCount < maxRetries && isRetryableError(error)
                
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
                }
            }
        }
        
        await updatePendingCounts()
        AppLogger.auth.info("Sync complete: \(summary.succeeded) succeeded, \(summary.failed) failed")
        return summary
    }

    private func processOperation(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
        switch operation.operation {
        case .publish:
            try await handlePublish(operation, apiClient: apiClient)
        case .unpublish:
            try await handleUnpublish(operation, apiClient: apiClient)
        }
    }

    private func handlePublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
        guard let payload = operation.payload else {
            throw SyncError.invalidPayload
        }
        
        let contentPayload = try JSONDecoder().decode(ContentPublishPayload.self, from: payload)
        
        // Get current item to ensure we have latest publicID
        guard var item = libraryStore.library.first(where: { $0.id == operation.contentID }),
            let publicID = item.publicID else {
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
            publicID: publicID,
            canFork: true
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

    private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
        guard let item = libraryStore.library.first(where: { $0.id == operation.contentID }),
            let publicID = item.publicID else {
            throw SyncError.missingPublicID
        }
        
        // Call backend API
        try await apiClient.unpublishContent(publicID: publicID)
        
        // Update local model
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

    private func isRetryableError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError, .serverError:
                return true
            case .unauthorized, .forbidden, .notFound, .conflict, .clientError:
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