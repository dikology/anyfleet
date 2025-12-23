//
//  VisibilityService.swift
//  anyfleet
//
//  Service for managing content visibility and publishing
//

import Foundation
import Observation
import OSLog

/// Service for managing content visibility and publishing operations
@MainActor
@Observable
final class VisibilityService {
    private let libraryStore: LibraryStore
    private let authService: AuthService

    private let syncService: ContentSyncService

    /// Errors that can occur during publishing operations
    enum PublishError: LocalizedError {
        case notAuthenticated
        case networkError(Error)
        case validationError(String)
        
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
    
    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStore,
        authService: AuthService,
        syncService: ContentSyncService
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
    
    /// Validate content before publishing
    /// - Parameter item: The library item to validate
    /// - Throws: `PublishError.validationError` if validation fails
    private func validateForPublishing(_ item: LibraryModel) throws {
        // Title validation
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.count >= 3 else {
            throw PublishError.validationError("Title must be at least 3 characters")
        }
        
        guard trimmedTitle.count <= 200 else {
            throw PublishError.validationError("Title must be no more than 200 characters")
        }
        
        // Description validation (optional but if provided, should be reasonable)
        if let description = item.description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedDescription.count <= 1000 else {
                throw PublishError.validationError("Description must be no more than 1000 characters")
            }
        }
        
        AppLogger.auth.debug("Content validation passed for item: \(item.id)")
    }
    
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
    func publishContent(_ item: LibraryModel) async throws {
        AppLogger.auth.startOperation("Publish Content")
        
        // Check authentication
        guard authService.isAuthenticated else {
            AppLogger.auth.warning("Publish attempted without authentication")
            throw PublishError.notAuthenticated
        }
        
        // Validate content
        try validateForPublishing(item)
        
        // Get current user info
        guard let currentUser = authService.currentUser else {
            AppLogger.auth.error("Current user not available")
            throw PublishError.notAuthenticated
        }
        
        // Generate public metadata
        let publicID = generatePublicID(from: item.title)
        let publishedAt = Date()
        let publicMetadata = PublicMetadata(
            publishedAt: publishedAt,
            publicID: publicID,
            canFork: true, // Default to allowing forks
            authorUsername: currentUser.username ?? currentUser.email
        )
        
        // Update item with public visibility
        var updated = item
        updated.visibility = .public
        updated.publishedAt = publishedAt
        updated.publicID = publicID
        updated.publicMetadata = publicMetadata
        updated.syncStatus = .pending // Will be synced to backend later
        updated.updatedAt = Date()
        
        AppLogger.auth.info("Publishing content: \(item.id), publicID: \(publicID)")
        
        do {
            // Save to local database
            try await libraryStore.updateLibraryMetadata(updated)
            
            let payload = try await encodeContentForSync(updated)
            try await syncService.enqueuePublish(
                contentID: updated.id,
                visibility: .public,
                payload: payload
            )
            AppLogger.auth.completeOperation("Publish Content")
            AppLogger.auth.info("Content published successfully: \(item.id)")
        } catch {
            AppLogger.auth.failOperation("Publish Content", error: error)
            
            // Update sync status to error
            var errorItem = updated
            errorItem.syncStatus = .failed
            try? await libraryStore.updateLibraryMetadata(errorItem)
            
            throw PublishError.networkError(error)
        }
    }
    
    /// Unpublish content (make it private)
    /// - Parameter item: The library item to unpublish
    /// - Throws: Error if unpublishing fails
    func unpublishContent(_ item: LibraryModel) async throws {
        AppLogger.auth.startOperation("Unpublish Content")
        
        // Check authentication
        guard authService.isAuthenticated else {
            AppLogger.auth.warning("Unpublish attempted without authentication")
            throw PublishError.notAuthenticated
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
            
            if let publicID = item.publicID {
                try await syncService.enqueueUnpublish(
                    contentID: updated.id,
                    publicID: publicID
                )
            }
            AppLogger.auth.completeOperation("Unpublish Content")
            AppLogger.auth.info("Content unpublished successfully: \(item.id)")
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
        
        var updated = item
        updated.visibility = .unlisted
        updated.updatedAt = Date()
        
        try await libraryStore.updateLibraryMetadata(updated)
        
        AppLogger.auth.completeOperation("Make Unlisted")
    }
    
    private func encodeContentForSync(_ item: LibraryModel) async throws -> Data {
            // Fetch full content based on type
            let payload: ContentPublishPayload
            
            switch item.type {
            case .checklist:
                guard let checklist = try await libraryStore.fetchChecklist(item.id) else {
                    throw PublishError.validationError("Checklist not found")
                }
                payload = ContentPublishPayload(
                    title: item.title,
                    description: item.description,
                    contentType: "checklist",
                    contentData: try encodeChecklist(checklist),
                    tags: item.tags,
                    language: item.language
                )
                
            case .practiceGuide:
                guard let guide = try await libraryStore.fetchGuide(item.id) else {
                    throw PublishError.validationError("Guide not found")
                }
                payload = ContentPublishPayload(
                    title: item.title,
                    description: item.description,
                    contentType: "practice_guide",
                    contentData: try encodeGuide(guide),
                    tags: item.tags,
                    language: item.language
                )
                
            case .flashcardDeck:
                throw PublishError.validationError("Flashcard decks not yet supported")
            }
            
            return try JSONEncoder().encode(payload)
        }
        
        private func encodeChecklist(_ checklist: Checklist) throws -> [String: Any] {
            // Convert Checklist to JSON-serializable dict
            let data = try JSONEncoder().encode(checklist)
            let json = try JSONSerialization.jsonObject(with: data)
            return json as! [String: Any]
        }
        
        private func encodeGuide(_ guide: PracticeGuide) throws -> [String: Any] {
            let data = try JSONEncoder().encode(guide)
            let json = try JSONSerialization.jsonObject(with: data)
            return json as! [String: Any]
        }
}

struct ContentPublishPayload: Encodable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case title, description, contentType = "content_type"
        case contentData = "content_data", tags, language
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        
        // Encode contentData as nested JSON
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try container.encode(jsonString, forKey: .contentData)
    }
}
