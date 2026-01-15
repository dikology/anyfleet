//
//  VisibilityService.swift
//  anyfleet
//
//  Service for managing content visibility and publishing
//

import Foundation
import Observation
import OSLog

/// Protocol defining the interface for visibility service operations.
/// Used for dependency injection and testing.
protocol VisibilityServiceProtocol: AnyObject {
    func publishContent(_ item: LibraryModel) async throws -> SyncSummary
    func unpublishContent(_ item: LibraryModel) async throws -> SyncSummary
    func retrySync(for item: LibraryModel) async
}

/// Validator for content publishing requirements
final class ContentValidator {
    func validate(_ item: LibraryModel) throws {
        try validateTitle(item.title)
        try validateDescription(item.description)
        try validateTags(item.tags)
    }

    private func validateTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VisibilityService.PublishError.validationError("Title cannot be empty")
        }
        guard trimmed.count >= 3 else {
            throw VisibilityService.PublishError.validationError("Title must be at least 3 characters")
        }
        guard trimmed.count <= 100 else {
            throw VisibilityService.PublishError.validationError("Title must be 100 characters or less")
        }
    }

    private func validateDescription(_ description: String?) throws {
        guard let desc = description, !desc.isEmpty else {
            throw VisibilityService.PublishError.validationError("Description is required for publishing")
        }
        guard desc.count <= 500 else {
            throw VisibilityService.PublishError.validationError("Description must be 500 characters or less")
        }
    }

    private func validateTags(_ tags: [String]) throws {
        // guard !tags.isEmpty else {
        //     throw VisibilityService.PublishError.validationError("At least one tag is required")
        // }
        guard tags.count <= 10 else {
            throw VisibilityService.PublishError.validationError("Maximum 10 tags allowed")
        }
    }
}

/// Protocol for content sync operations
protocol ContentSyncServiceProtocol {
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws -> SyncSummary

    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws -> SyncSummary

    func enqueuePublishUpdate(
        contentID: UUID,
        payload: Data
    ) async throws -> SyncSummary

    func syncPending() async -> SyncSummary
}

/// Service for managing content visibility and publishing operations
@MainActor
@Observable
final class VisibilityService: VisibilityServiceProtocol {
    private let libraryStore: LibraryStoreProtocol
    private let authService: AuthServiceProtocol
    private let syncService: ContentSyncServiceProtocol
    private let validator = ContentValidator()

    /// Errors that can occur during publishing operations
    enum PublishError: LocalizedError, Equatable {
        case notAuthenticated
        case networkError(Error)
        case validationError(String)

        static func == (lhs: PublishError, rhs: PublishError) -> Bool {
            switch (lhs, rhs) {
            case (.notAuthenticated, .notAuthenticated):
                return true
            case (.networkError(let lhsError), .networkError(let rhsError)):
                // Compare error descriptions for testing purposes
                return lhsError.localizedDescription == rhsError.localizedDescription
            case (.validationError(let lhsMessage), .validationError(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Sign in to publish content"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .validationError(let message):
                return message
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .notAuthenticated:
                return "Please sign in with your Apple ID to publish content."
            case .networkError:
                return "Check your internet connection and try again."
            case .validationError:
                return "Please fix the validation errors and try again."
            }
        }
    }

    /// Retry sync operations for a specific content item
    /// - Parameter item: The library item to retry sync for
    func retrySync(for item: LibraryModel) async {
        AppLogger.auth.info("Retrying sync for item: \(item.id)")

        // Find and retry any failed sync operations for this content
        // This will trigger the sync service to attempt pending operations again
        await syncService.syncPending()

        AppLogger.auth.info("Sync retry initiated for item: \(item.id)")
    }

    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStoreProtocol,
        authService: AuthServiceProtocol,
        syncService: ContentSyncServiceProtocol
    ) {
        self.libraryStore = libraryStore
        self.authService = authService
        self.syncService = syncService
        AppLogger.auth.debug("VisibilityService initialized")
    }
    
    // MARK: - Visibility Checks
    
    /// Check if user can perform visibility actions
    /// - Returns: `true` if user is authenticated, `false` otherwise
    func canToggleVisibility() -> Bool {
        let canToggle = authService.isAuthenticated
        AppLogger.auth.debug("canToggleVisibility: \(canToggle)")
        return canToggle
    }
    
    // MARK: - Validation
    
    
    /// Generate a URL-friendly slug from the title
    /// - Parameter title: The title to convert to a slug
    /// - Returns: A URL-friendly string
    private func generatePublicID(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        
        // Ensure it's not empty and add a random suffix for uniqueness
        let base = trimmed.isEmpty ? "content" : String(trimmed.prefix(50))
        let suffix = UUID().uuidString.prefix(8)
        return "\(base)-\(suffix)"
    }
    
    // MARK: - Publishing
    
    /// Publish content to make it publicly visible
    /// - Parameter item: The library item to publish
    /// - Throws: `PublishError` if publishing fails
    func publishContent(_ item: LibraryModel) async throws -> SyncSummary {
        AppLogger.auth.info("Publishing content: \(item.id)")

        // 1. Auth check
        try await ensureAuthenticated()

        // 2. Validation
        try validator.validate(item)

        // 3. Generate public metadata and update visibility
        let publicID = generatePublicID(from: item.title)
        let publishedAt = Date()
        let publicMetadata = PublicMetadata(
            publishedAt: publishedAt,
            publicID: publicID,
            canFork: true, // Default to allowing forks
            authorUsername: authService.currentUser?.username ?? "Anonymous User"
        )

        var updatedItem = item
        updatedItem.visibility = .public
        updatedItem.publishedAt = publishedAt
        updatedItem.publicID = publicID
        updatedItem.publicMetadata = publicMetadata
        updatedItem.syncStatus = .pending // Will be synced to backend later
        updatedItem.updatedAt = Date()

        // 4. Persist and sync
        try await libraryStore.updateLibraryMetadata(updatedItem)
        let payload = try await encodeContentForSync(updatedItem)
        let summary = try await syncService.enqueuePublish(
            contentID: updatedItem.id,
            visibility: .public,
            payload: payload
        )

        AppLogger.auth.info("Content published successfully: \(item.id)")
        return summary
    }

    private func ensureAuthenticated() async throws {
        guard authService.isAuthenticated else {
            AppLogger.auth.warning("Publish attempt without authentication")
            throw PublishError.notAuthenticated
        }
        try await authService.ensureCurrentUserLoaded()
    }

    /// Unpublish content (make it private)
    /// - Parameter item: The library item to unpublish
    /// - Throws: Error if unpublishing fails
    func unpublishContent(_ item: LibraryModel) async throws -> SyncSummary {
        AppLogger.auth.startOperation("Unpublish Content")

        // Check authentication and ensure user info is loaded
        guard authService.isAuthenticated else {
            AppLogger.auth.warning("Unpublish attempted without authentication")
            throw PublishError.notAuthenticated
        }

        // Ensure current user is loaded (this will load it if not already loaded)
        try await authService.ensureCurrentUserLoaded()
        
        // Capture publicID BEFORE clearing it
        guard let publicIDToUnpublish = item.publicID else {
            throw PublishError.validationError("Cannot unpublish content without publicID")
        }
        
        AppLogger.auth.info("Unpublishing content: \(item.id)")
        
        // Update item to private
        var updated = item
        updated.visibility = .private
        updated.publishedAt = nil
        updated.publicID = nil
        updated.publicMetadata = nil
        updated.syncStatus = .pending // Will sync unpublish to backend
        updated.updatedAt = Date()
        
        do {
            // Save to local database
            try await libraryStore.updateLibraryMetadata(updated)
            
            // Pass captured publicID
            let syncSummary = try await syncService.enqueueUnpublish(
                contentID: updated.id,
                publicID: publicIDToUnpublish
            )

            AppLogger.auth.completeOperation("Unpublish Content")
            AppLogger.auth.info("Content unpublished successfully: \(item.id)")
            return syncSummary
        } catch {
            AppLogger.auth.failOperation("Unpublish Content", error: error)
            throw PublishError.networkError(error)
        }
    }
    
    /// Change visibility to unlisted
    /// - Parameter item: The library item to make unlisted
    /// - Throws: Error if operation fails
    func makeUnlisted(_ item: LibraryModel) async throws {
        AppLogger.auth.startOperation("Make Unlisted")

        guard authService.isAuthenticated else {
            throw PublishError.notAuthenticated
        }

        // Ensure current user is loaded
        try await authService.ensureCurrentUserLoaded()
        
        var updated = item
        updated.visibility = .unlisted
        updated.updatedAt = Date()
        
        try await libraryStore.updateLibraryMetadata(updated)
        
        AppLogger.auth.completeOperation("Make Unlisted")
    }
    
    func encodeContentForSync(_ item: LibraryModel) async throws -> Data {
            let contentDict: [String: Any]
            
            switch item.type {
            case .checklist:
                guard let checklist: Checklist = try await libraryStore.fetchFullContent(item.id) else {
                    throw PublishError.validationError("Checklist not found")
                }
                contentDict = try encodeChecklist(checklist)
                
            case .practiceGuide:
                guard let guide: PracticeGuide = try await libraryStore.fetchFullContent(item.id) else {
                    throw PublishError.validationError("Guide not found")
                }
                contentDict = try encodeGuide(guide)
                
            case .flashcardDeck:
                throw PublishError.validationError("Flashcard decks not yet supported")
            }
            
            guard let publicID = item.publicID else {
                throw PublishError.validationError("Missing public ID")
            }
            
            let payload = ContentPublishPayload(
                title: item.title,
                description: item.description,
                contentType: item.type == .checklist ? "checklist" : "practice_guide",
                contentData: contentDict,
                tags: item.tags,
                language: item.language,
                publicID: publicID,
                forkedFromID: item.forkedFromID
            )
            
            // Encode with NO key strategy
            let encoder = JSONEncoder()
            return try encoder.encode(payload)
        }
        
        private func encodeChecklist(_ checklist: Checklist) throws -> [String: Any] {
            // Convert Checklist to JSON-serializable dict
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(checklist)
            let json = try JSONSerialization.jsonObject(with: data)
            guard let jsonDict = json as? [String: Any] else {
                throw PublishError.validationError("Failed to encode checklist as dictionary")
            }
            return jsonDict
        }
        
        private func encodeGuide(_ guide: PracticeGuide) throws -> [String: Any] {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(guide)
            let json = try JSONSerialization.jsonObject(with: data)
            guard let jsonDict = json as? [String: Any] else {
                throw PublishError.validationError("Failed to encode guide as dictionary")
            }
            return jsonDict
        }
}
