//
//  ContentSyncServiceIntegrationTests.swift
//  anyfleetTests
//
//  Integration tests for ContentSyncService with real payloads
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Content Sync Service Integration Tests")
struct ContentSyncServiceIntegrationTests {

    @MainActor
    private func makeTestDependencies() throws -> (
        repository: LocalRepository,
        apiClient: MockAPIClient,
        libraryStore: LibraryStore,
        syncService: ContentSyncService
    ) {
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let mockAuthService = MockAuthService()
        let apiClient = MockAPIClient()
        let libraryStore = LibraryStore(repository: repository)
        let syncService = ContentSyncService(
            repository: repository,
            apiClient: apiClient,
            libraryStore: libraryStore
        )

        return (repository, apiClient, libraryStore, syncService)
    }

    @Test("Publish operation - end-to-end with real payload")
    @MainActor
    func testPublishOperationEndToEnd() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Create a checklist in the library
        let checklist = Checklist(
            id: UUID(),
            title: "Integration Test Checklist",
            description: "Test checklist for sync integration",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Safety Checks",
                    items: [
                        ChecklistItem(
                            id: UUID(),
                            title: "Check brakes",
                            itemDescription: "Ensure brake pads are in good condition",
                            isOptional: false,
                            isRequired: true,
                            tags: ["safety"],
                            estimatedMinutes: 5,
                            sortOrder: 0
                        )
                    ]
                )
            ],
            checklistType: .general,
            tags: ["safety", "integration"],
            createdAt: Date(),
            updatedAt: Date()
        )

        try await repository.createChecklist(checklist)

        // Create library metadata
        let libraryModel = LibraryModel(
            id: checklist.id,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: checklist.tags,
            language: "en",
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt,
            syncStatus: .pending
        )

        try await repository.updateLibraryMetadata(libraryModel)

        // Act - Publish the checklist
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-12-24T10:00:00Z"
        )

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        try await visibilityService.publishContent(libraryModel)

        // Assert - Verify operation was enqueued with correct payload
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingOperations.count == 1)

        let operation = pendingOperations[0]
        #expect(operation.operation == .publish)
        #expect(operation.contentID == checklist.id)

        // Verify payload can be decoded as ContentPublishPayload
        #expect(operation.payload != nil)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ContentPublishPayload.self, from: operation.payload!)

        #expect(payload.title == "Integration Test Checklist")
        #expect(payload.contentType == "checklist")
        #expect(payload.publicID.hasPrefix("integration-test-checklist"))
        #expect(payload.tags == ["safety", "integration"])

        // Verify contentData is a proper dictionary
        let contentData = payload.contentData
        #expect(contentData["id"] as? String == checklist.id.uuidString)
        #expect(contentData["title"] as? String == checklist.title)
        #expect(contentData["checklistType"] as? String == "general")
    }

    @Test("Publish succeeds when isAuthenticated=true and ensureCurrentUserLoaded loads user")
    @MainActor
    func testPublishSucceedsWhenCurrentUserLoadedByEnsureMethod() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Create a mock auth service where isAuthenticated is true but currentUser starts as nil
        // The ensureCurrentUserLoaded method will set it
        let mockAuthService = MockAuthService()
        mockAuthService.mockIsAuthenticated = true
        mockAuthService.mockCurrentUser = nil // Simulate currentUser not loaded initially

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        // Create a test checklist
        let checklistID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "Test Checklist",
            description: "Test description",
            checklistType: .general,
            items: [],
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        let libraryModel = LibraryModel(
            id: checklistID,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt
        )

        // Save checklist to database
        try await libraryStore.saveChecklist(checklist)

        // Act - Should succeed (ensureCurrentUserLoaded will load the user)
        try await visibilityService.publishContent(libraryModel)

        // Assert - Verify operation was enqueued with correct payload
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingOperations.count == 1)

        let operation = pendingOperations[0]
        #expect(operation.operation == .publish)
        #expect(operation.contentID == checklist.id)

        // Verify payload can be decoded as ContentPublishPayload
        #expect(operation.payload != nil)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ContentPublishPayload.self, from: operation.payload!)

        #expect(payload.title == "Test Checklist")
        #expect(payload.contentType == "checklist")
        #expect(payload.publicID.hasPrefix("test-checklist"))
        #expect(payload.authorUsername == "mockuser") // Should use username from loaded currentUser
    }

    @Test("Publish succeeds when both isAuthenticated=true and currentUser is set")
    @MainActor
    func testPublishSucceedsWhenAuthenticatedAndCurrentUserLoaded() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Create a mock auth service with both authentication state set
        let mockAuthService = MockAuthService()
        mockAuthService.mockIsAuthenticated = true
        mockAuthService.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        // Create a test checklist
        let checklistID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "Test Checklist",
            description: "Test description",
            checklistType: .general,
            items: [],
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        let libraryModel = LibraryModel(
            id: checklistID,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt
        )

        // Save checklist to database
        try await libraryStore.saveChecklist(checklist)

        // Act - Should succeed without throwing
        try await visibilityService.publishContent(libraryModel)

        // Assert - Verify operation was enqueued with correct payload
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingOperations.count == 1)

        let operation = pendingOperations[0]
        #expect(operation.operation == .publish)
        #expect(operation.contentID == checklist.id)

        // Verify payload can be decoded as ContentPublishPayload
        #expect(operation.payload != nil)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ContentPublishPayload.self, from: operation.payload!)

        #expect(payload.title == "Test Checklist")
        #expect(payload.contentType == "checklist")
        #expect(payload.publicID.hasPrefix("test-checklist"))
        #expect(payload.authorUsername == "testuser") // Should use username from currentUser
    }

    @Test("Unpublish operation - stores publicID in payload")
    @MainActor
    func testUnpublishOperationStoresPublicID() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Create a checklist and mark it as published
        let checklistID = UUID()
        let publicID = "test-unpublish-checklist-123"

        let libraryModel = LibraryModel(
            id: checklistID,
            title: "Unpublish Test Checklist",
            description: "Test for unpublish operation",
            type: .checklist,
            visibility: .public,
            creatorID: UUID(),
            tags: ["test"],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced,
            publishedAt: Date(),
            publicID: publicID
        )

        try await repository.updateLibraryMetadata(libraryModel)

        // Act - Unpublish the checklist
        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: MockAuthService(),
            syncService: syncService
        )

        try await visibilityService.unpublishContent(libraryModel)

        // Assert - Verify unpublish operation was enqueued with publicID payload
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingOperations.count == 1)

        let operation = pendingOperations[0]
        #expect(operation.operation == .unpublish)
        #expect(operation.contentID == checklistID)

        // Verify payload contains the publicID
        #expect(operation.payload != nil)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(UnpublishPayload.self, from: operation.payload!)

        #expect(payload.publicID == publicID)
    }

    @Test("Sync queue payload - survives database round-trip")
    @MainActor
    func testSyncQueuePayloadPersistence() async throws {
        // Arrange
        let (repository, _, _, _) = try makeTestDependencies()

        let contentID = UUID()
        let originalPayload = ContentPublishPayload(
            title: "Persistence Test",
            description: "Test payload persistence",
            contentType: "checklist",
            contentData: [
                "id": "persistence-test-123",
                "title": "Persistence Test",
                "sections": [["id": "section-1", "title": "Test Section", "items": []]],
                "tags": ["persistence"],
                "checklistType": "general",
                "createdAt": "2024-12-24T10:00:00Z",
                "updatedAt": "2024-12-24T10:00:00Z",
                "syncStatus": "pending"
            ],
            tags: ["test", "persistence"],
            language: "en",
            publicID: "persistence-test-abc123"
        )

        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(originalPayload)

        // Create library content first
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Persistence Test",
            description: "Test payload persistence",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: ["test"],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Act - Enqueue the operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: payloadData
        )

        // Assert - Retrieve and verify payload is intact
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingOperations.count == 1)

        let retrievedOperation = pendingOperations[0]
        #expect(retrievedOperation.payload != nil)

        // Decode the retrieved payload
        let decoder = JSONDecoder()
        let retrievedPayload = try decoder.decode(ContentPublishPayload.self, from: retrievedOperation.payload!)

        // Verify all data is preserved
        #expect(retrievedPayload.title == originalPayload.title)
        #expect(retrievedPayload.description == originalPayload.description)
        #expect(retrievedPayload.contentType == originalPayload.contentType)
        #expect(retrievedPayload.tags == originalPayload.tags)
        #expect(retrievedPayload.language == originalPayload.language)
        #expect(retrievedPayload.publicID == originalPayload.publicID)

        // Verify complex contentData is preserved
        let contentData = retrievedPayload.contentData
        #expect(contentData["id"] as? String == "persistence-test-123")
        #expect(contentData["tags"] as? [String] == ["persistence"])
        #expect(contentData["sections"] as? [[String: Any]] != nil)
    }

    @Test("Sync operation retry logic")
    @MainActor
    func testSyncOperationRetryLogic() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Configure mock to always fail
        apiClient.shouldFail = true

        let contentID = UUID()
        let payload = ContentPublishPayload(
            title: "Retry Test",
            description: nil,
            contentType: "checklist",
            contentData: ["id": "retry-test-123", "title": "Retry Test"],
            tags: [],
            language: "en",
            publicID: "retry-test-456"
        )

        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)

        // Create library content
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Retry Test",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Enqueue operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: payloadData
        )

        // Act - Attempt sync (should fail and increment retry count)
        let summary = await syncService.syncPending()

        // Assert - Operation should be marked for retry
        #expect(summary.failed == 1)
        #expect(summary.succeeded == 0)

        // Verify retry count was incremented
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 5)
        #expect(pendingOperations.count == 1)
        #expect(pendingOperations[0].retryCount == 1)
        #expect(pendingOperations[0].lastError != nil)
    }

    @Test("Sync operation failure after max retries")
    @MainActor
    func testSyncOperationFailureAfterMaxRetries() async throws {
        // Arrange
        let (repository, apiClient, libraryStore, syncService) = try makeTestDependencies()

        // Configure mock to always fail
        apiClient.shouldFail = true

        let contentID = UUID()
        let payload = ContentPublishPayload(
            title: "Max Retry Test",
            description: nil,
            contentType: "checklist",
            contentData: ["id": "max-retry-test-123", "title": "Max Retry Test"],
            tags: [],
            language: "en",
            publicID: "max-retry-test-456"
        )

        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)

        // Create library content
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Max Retry Test",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Enqueue operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: payloadData
        )

        // Act - Attempt sync multiple times to exceed max retries
        for _ in 0..<4 { // maxRetries = 3, so this will exceed it
            let _ = await syncService.syncPending()
        }

        // Assert - Operation should be marked as failed
        let failedCounts = try await repository.getSyncQueueCounts()
        #expect(failedCounts.failed >= 1)

        // Verify operation has reached max retries and is still pending (but won't be retried)
        let pendingOperations = try await repository.getPendingSyncOperations(maxRetries: 10)
        #expect(pendingOperations.count == 1)
        #expect(pendingOperations[0].retryCount >= 3) // Should have reached max retries
    }
}

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    var shouldFail = false

    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool
    ) async throws -> PublishContentResponse {
        if shouldFail {
            throw APIError.serverError
        }

        // Return mock successful response
        return PublishContentResponse(
            id: UUID(),
            publicID: publicID,
            publishedAt: Date(),
            authorUsername: "mockuser",
            canFork: canFork
        )
    }

    func unpublishContent(publicID: String) async throws {
        // Mock implementation - do nothing for tests
    }

    func fetchPublicContent() async throws -> [SharedContentSummary] {
        // Mock implementation - return empty array for tests
        return []
    }

    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail {
        // Mock implementation - return mock content detail for tests
        return SharedContentDetail(
            id: UUID(),
            title: "Mock Content",
            description: "Mock description",
            contentType: "checklist",
            contentData: [:],
            tags: [],
            publicID: publicID,
            canFork: true,
            authorUsername: "mockauthor",
            viewCount: 0,
            forkCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func incrementForkCount(publicID: String) async throws {
        // Mock implementation - do nothing for tests
    }
}

// MARK: - Mock Auth Service
// MockAuthService is defined in MockAuthService.swift
