import Foundation

// MARK: - Sync Operation Types
//
// Kept in a dedicated file so that these plain value types do NOT inherit
// the @MainActor isolation that Swift 6 can infer for declarations that
// share a file with an @MainActor-annotated type.

public enum SyncOperation: String, Codable, Sendable {
    case publish
    case unpublish
    case publish_update
}

public struct SyncQueueOperation: Sendable {
    let id: Int64
    let contentID: UUID
    let operation: SyncOperation
    let visibility: ContentVisibility
    let payload: Data?
    let retryCount: Int
    let lastError: String?
    let createdAt: Date
    /// Earliest timestamp at which this operation may be retried.
    /// `nil` until the first retryable failure.
    let nextRetryAt: Date?
}

enum SyncError: LocalizedError, Sendable {
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
