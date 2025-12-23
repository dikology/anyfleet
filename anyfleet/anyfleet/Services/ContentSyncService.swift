import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentSyncService {
    private let repository: LocalRepository
    // private let apiClient: APIClient?  // TODO: Implement in Phase 3
    private let libraryStore: LibraryStore
    
    // Configuration
    private let maxRetries = 3
    
    // State
    var isSyncing = false
    var pendingCount: Int = 0
    var failedCount: Int = 0
    
    init(
        repository: LocalRepository,
        // apiClient: APIClient?, // TODO: Add in Phase 3
        libraryStore: LibraryStore
    ) {
        self.repository = repository
        // self.apiClient = apiClient // TODO: Uncomment in Phase 3
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

        // TODO: Implement API client check in Phase 3
        // guard apiClient != nil else {
        //     AppLogger.auth.warning("API client not available, skipping sync")
        //     await updatePendingCounts()
        //     return SyncSummary()
        // }

        // For Phase 2: Skip network sync entirely
        AppLogger.auth.info("Network sync not yet implemented (Phase 3), skipping sync")
        await updatePendingCounts()
        return SyncSummary()
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