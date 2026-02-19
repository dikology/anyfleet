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
        syncQueue: SyncQueueService,
        libraryStore: LibraryStore,
        syncService: ContentSyncService
    ) {
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let apiClient = MockAPIClient()
        let syncQueue = SyncQueueService(
            repository: repository,
            apiClient: apiClient
        )
        let libraryStore = LibraryStore(repository: repository, syncQueue: syncQueue)
        let syncService = ContentSyncService(
            syncQueue: syncQueue,
            repository: repository
        )

        return (repository, apiClient, syncQueue, libraryStore, syncService)
    }

    @Test("Unpublish operation - end-to-end with real payload")
    @MainActor
    func testUnpublishOperationEndToEnd() async throws {
        // Arrange
        let (repository, apiClient, _, libraryStore, syncService) = try makeTestDependencies()

        // Create and publish a checklist first
        let checklist = Checklist(
            id: UUID(),
            title: "Integration Test Checklist for Unpublish",
            description: "Test checklist for unpublish integration",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Safety Checks",
                    items: [
                        ChecklistItem(
                            id: UUID(),
                            title: "Check weather conditions",
                            itemDescription: nil,
                            isOptional: false,
                            isRequired: true,
                            tags: [],
                            estimatedMinutes: nil,
                            sortOrder: 0
                        )
                    ]
                )
            ],
            checklistType: .general,
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )

        // Create library metadata for the checklist
        let libraryItem = LibraryModel(
            id: checklist.id,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .public,
            creatorID: UUID(),
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt,
            syncStatus: .synced,
            publishedAt: Date(),
            publicID: "pub-test-unpublish"
        )

        // Save to database
        try await repository.saveChecklist(checklist)
        try await repository.updateLibraryMetadata(libraryItem)

        // Verify initial state
        var loadedItem = try await repository.fetchLibraryItem(checklist.id)
        #expect(loadedItem?.visibility == .public)
        #expect(loadedItem?.publicID == "pub-test-unpublish")

        // Act: Unpublish the content
        try await syncService.enqueueUnpublish(
            contentID: checklist.id,
            publicID: "pub-test-unpublish"
        )

        // Process pending sync operations
        let _ = await syncService.syncPending()

        // Assert: Content should be marked as private locally
        loadedItem = try await repository.fetchLibraryItem(checklist.id)
        #expect(loadedItem?.visibility == .private)
        #expect(loadedItem?.publicID == nil)
        #expect(loadedItem?.publishedAt == nil)
        #expect(loadedItem?.syncStatus == .synced)
    }

    @Test("Publish operation - end-to-end with real payload")
    @MainActor
    func testPublishOperationEndToEnd() async throws {
        // Arrange
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

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
            createdAt: "2024-12-24T10:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        // Act & Assert - Publish should complete successfully and update the item
        let syncSummary = try await visibilityService.publishContent(libraryModel)

        // Verify sync completed successfully
        #expect(syncSummary.succeeded == 1)
        #expect(syncSummary.failed == 0)

        // Verify the library item was updated correctly
        let updatedItem = try await repository.fetchLibraryItem(checklist.id)
        #expect(updatedItem != nil)
        #expect(updatedItem!.visibility == .public)
        #expect(updatedItem!.publicID != nil)
        #expect(updatedItem!.syncStatus == .synced)
    }

    @Test("Publish operation payload structure is correct")
    @MainActor
    func testPublishOperationPayloadStructure() async throws {
        // Arrange
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // Create a checklist
        let checklist = Checklist(
            id: UUID(),
            title: "Payload Test Checklist",
            description: "A test checklist for payload structure testing",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Test Section",
                    items: [
                        ChecklistItem(id: UUID(), title: "Test item")
                    ]
                )
            ],
            checklistType: .general,
            tags: ["test", "payload"],
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
            syncStatus: .pending,
            publicID: "test-public-id-123"
        )

        try await repository.updateLibraryMetadata(libraryModel)

        // Create a mock auth service for encoding
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-12-24T10:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        // Create payload using the same method as publishContent
        let payloadData = try await visibilityService.encodeContentForSync(libraryModel)

        // Act - Enqueue operation without processing
        try await syncService.enqueuePublishOnly(
            contentID: libraryModel.id,
            visibility: .public,
            payload: payloadData
        )

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

        #expect(payload.title == "Payload Test Checklist")
        #expect(payload.contentType == "checklist")
        #expect(payload.publicID == "test-public-id-123")
        #expect(payload.tags == ["test", "payload"])

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
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

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
            sections: [],
            checklistType: .general,
            tags: ["test", "integration"],
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
        let syncSummary = try await visibilityService.publishContent(libraryModel)

        // Assert - Verify publish completed successfully
        #expect(syncSummary.succeeded == 1)
        #expect(syncSummary.failed == 0)

        // Verify the library item was updated correctly
        let updatedItem = try await repository.fetchLibraryItem(checklist.id)
        #expect(updatedItem != nil)
        #expect(updatedItem!.visibility == .public)
        #expect(updatedItem!.publicID != nil)
    }

    @Test("Publish succeeds when both isAuthenticated=true and currentUser is set")
    @MainActor
    func testPublishSucceedsWhenAuthenticatedAndCurrentUserLoaded() async throws {
        // Arrange
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // Create a mock auth service with both authentication state set
        let mockAuthService = MockAuthService()
        mockAuthService.mockIsAuthenticated = true
        mockAuthService.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
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
            sections: [],
            checklistType: .general,
            tags: ["test", "authenticated"],
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
        let syncSummary = try await visibilityService.publishContent(libraryModel)

        // Assert - Verify publish completed successfully
        #expect(syncSummary.succeeded == 1)
        #expect(syncSummary.failed == 0)

        // Verify the library item was updated correctly
        let updatedItem = try await repository.fetchLibraryItem(checklist.id)
        #expect(updatedItem != nil)
        #expect(updatedItem!.visibility == .public)
        #expect(updatedItem!.publicID != nil)
    }

    @Test("Unpublish operation - stores publicID in payload")
    @MainActor
    func testUnpublishOperationStoresPublicID() async throws {
        // Arrange
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

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
        let _ = VisibilityService(
            libraryStore: libraryStore,
            authService: MockAuthService(),
            syncService: syncService
        )

        // Create payload using the same method as unpublishContent
        let _ = try JSONEncoder().encode(UnpublishPayload(publicID: publicID))

        // Act - Enqueue operation without processing for payload inspection
        try await syncService.enqueueUnpublishOnly(
            contentID: checklistID,
            publicID: publicID
        )

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
        let (repository, _, _, _, _) = try makeTestDependencies()

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
        let (repository, apiClient, _, libraryStore, syncService) = try makeTestDependencies()

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
        let (repository, apiClient, _, libraryStore, syncService) = try makeTestDependencies()

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

    @Test("Publish-edit-publish cycle - published content should remain public after editing")
    @MainActor
    func testPublishEditPublishCycleMaintainsVisibility() async throws {
        // This test reproduces the bug described in edit-published.md
        // where published content becomes private after editing and saving

        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // 1. Create and save a checklist
        let checklistID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "Publish-Edit Cycle Test Checklist",
            description: "Test checklist for publish-edit cycle",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Test Section",
                    items: [
                        ChecklistItem(
                            id: UUID(),
                            title: "Test Item",
                            itemDescription: nil,
                            isOptional: false,
                            isRequired: true,
                            tags: [],
                            estimatedMinutes: nil,
                            sortOrder: 0
                        )
                    ]
                )
            ],
            checklistType: .general,
            tags: ["test", "publish-edit"],
            createdAt: Date(),
            updatedAt: Date()
        )

        try await repository.createChecklist(checklist)

        // Create library metadata (initially private)
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

        try await repository.updateLibraryMetadata(libraryModel)

        // 2. Publish the content
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-12-24T10:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        let visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: mockAuthService,
            syncService: syncService
        )

        // Publish the content
        let publishSummary = try await visibilityService.publishContent(libraryModel)
        #expect(publishSummary.succeeded == 1)
        #expect(publishSummary.failed == 0)

        // Verify content is now public after publishing
        var updatedItem = try await repository.fetchLibraryItem(checklistID)
        #expect(updatedItem?.visibility == .public, "Content should be public after publishing")
        #expect(updatedItem?.publicID != nil, "Content should have publicID after publishing")

        // 3. Simulate app restart by reloading from database
        // This simulates what happens when the app is restarted
        updatedItem = try await repository.fetchLibraryItem(checklistID)
        #expect(updatedItem?.visibility == .public, "Content should remain public after 'app restart'")

        // 4. Edit the content (simulate saving changes)
        // This is what triggers the bug - editing published content
        var editedChecklist = checklist
        editedChecklist.title = "Edited Publish-Edit Cycle Test Checklist"
        editedChecklist.updatedAt = Date()

        // Save the edited checklist (this should trigger publish_update)
        try await libraryStore.saveChecklist(editedChecklist)

        // The publish update should have been processed by enqueuePublishUpdate already
        // syncPending() should find no additional operations to process
        let finalSyncSummary = await syncService.syncPending()
        #expect(finalSyncSummary.attempted == 0, "No additional operations should be pending")

        // 5. Verify content is still public after editing
        let finalItem = try await repository.fetchLibraryItem(checklistID)

        // This assertion should pass, but currently fails due to the bug
        #expect(finalItem?.visibility == .public, "Content should remain public after editing")
        #expect(finalItem?.publicID != nil, "Content should retain publicID after editing")
        #expect(finalItem?.title == "Edited Publish-Edit Cycle Test Checklist", "Title should be updated")

        // Additional verification: check that no additional sync operations were needed
        #expect(finalSyncSummary.attempted == 0, "No additional sync operations should be pending")
    }

    @Test("Publish-edit-publish cycle preserves visibility through multiple edits")
    @MainActor
    func testPublishMultipleEditsMaintainsVisibility() async throws {
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // Create and publish content
        let checklistID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "Multiple Edits Test",
            description: "Test multiple edits maintain visibility",
            sections: [],
            checklistType: .general,
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date()
        )

        try await repository.createChecklist(checklist)
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
        try await repository.updateLibraryMetadata(libraryModel)

        // Publish
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(id: "user", email: "test@example.com", username: "testuser", createdAt: "2024-01-01T00:00:00Z", profileImageUrl: nil, profileImageThumbnailUrl: nil, bio: nil, location: nil, nationality: nil, profileVisibility: "public")
        let visibilityService = VisibilityService(libraryStore: libraryStore, authService: mockAuthService, syncService: syncService)
        let publishSummary = try await visibilityService.publishContent(libraryModel)
        #expect(publishSummary.succeeded == 1)

        // Verify published
        var item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public)

        // First edit
        var editedChecklist = checklist
        editedChecklist.title = "First Edit"
        editedChecklist.updatedAt = Date()
        try await libraryStore.saveChecklist(editedChecklist)
        let _ = await syncService.syncPending()

        item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public, "Should remain public after first edit")
        #expect(item?.title == "First Edit")

        // Second edit
        editedChecklist.title = "Second Edit"
        editedChecklist.updatedAt = Date()
        try await libraryStore.saveChecklist(editedChecklist)
        let _ = await syncService.syncPending()

        item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public, "Should remain public after second edit")
        #expect(item?.title == "Second Edit")
    }

    @Test("Publish operation correctly sets visibility in database")
    @MainActor
    func testPublishOperationDatabaseVisibility() async throws {
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // Create private content
        let checklistID = UUID()
        let checklist = Checklist(id: checklistID, title: "DB Visibility Test", description: "Test description for database visibility", sections: [], checklistType: .general, tags: [], createdAt: Date(), updatedAt: Date())
        try await repository.createChecklist(checklist)

        let libraryModel = LibraryModel(id: checklistID, title: checklist.title, description: checklist.description, type: .checklist, visibility: .private, creatorID: UUID(), tags: checklist.tags, createdAt: checklist.createdAt, updatedAt: checklist.updatedAt)
        try await repository.updateLibraryMetadata(libraryModel)

        // Verify initially private
        var item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .private)

        // Publish using VisibilityService (which uses SyncQueueService internally)
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(id: "test-user-id", email: "test@example.com", username: "testuser", createdAt: "2024-12-24T10:00:00Z", profileImageUrl: nil, profileImageThumbnailUrl: nil, bio: nil, location: nil, nationality: nil, profileVisibility: "public")
        let visibilityService = VisibilityService(libraryStore: libraryStore, authService: mockAuthService, syncService: syncService)

        let summary = try await visibilityService.publishContent(libraryModel)

        #expect(summary.succeeded == 1)

        // Verify database has correct visibility
        item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public, "Database should have public visibility after publish")
        #expect(item?.publicID != nil, "Content should have a generated publicID")
    }

    @Test("Publish update operation preserves visibility in database")
    @MainActor
    func testPublishUpdatePreservesVisibility() async throws {
        let (repository, _, _, libraryStore, syncService) = try makeTestDependencies()

        // Create and publish content using VisibilityService
        let checklistID = UUID()
        let checklist = Checklist(id: checklistID, title: "Update Visibility Test", description: "Test description for update visibility", sections: [], checklistType: .general, tags: [], createdAt: Date(), updatedAt: Date())
        try await repository.createChecklist(checklist)

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
        try await repository.updateLibraryMetadata(libraryModel)

        // Publish using VisibilityService
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(id: "test-user-id", email: "test@example.com", username: "testuser", createdAt: "2024-12-24T10:00:00Z", profileImageUrl: nil, profileImageThumbnailUrl: nil, bio: nil, location: nil, nationality: nil, profileVisibility: "public")
        let visibilityService = VisibilityService(libraryStore: libraryStore, authService: mockAuthService, syncService: syncService)

        let publishSummary = try await visibilityService.publishContent(libraryModel)
        #expect(publishSummary.succeeded == 1)

        // Get the published item to get the actual publicID
        var publishedItem = try await repository.fetchLibraryItem(checklistID)
        #expect(publishedItem?.publicID != nil)
        let actualPublicID = publishedItem!.publicID!

        // Verify initially public
        var item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public)

        // Update published content
        let payload = ContentPublishPayload(
            title: "Updated Title",
            description: nil,
            contentType: "checklist",
            contentData: ["id": checklistID.uuidString, "title": "Updated Title"],
            tags: [],
            language: "en",
            publicID: actualPublicID
        )
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)

        let summary = try await syncService.enqueuePublishUpdate(contentID: checklistID, payload: payloadData)

        #expect(summary.succeeded == 1)

        // Verify database still has public visibility
        item = try await repository.fetchLibraryItem(checklistID)
        #expect(item?.visibility == .public, "Database should preserve public visibility after publish update")
        #expect(item?.publicID == actualPublicID)
    }

    @Test("Publish-edit-publish cycle maintains JSON structure consistency")
    @MainActor
    func testPublishEditPublishMaintainsJSONStructure() async throws {
        // This test ensures JSON structures are consistent between initial publish and publish updates
        // and that discover parsing works correctly with the published data

        let (repository, apiClient, _, libraryStore, syncService) = try makeTestDependencies()

        // Create a checklist with all required fields including section properties
        let checklistID = UUID()
        let sectionID = UUID()
        let itemID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "JSON Structure Test Checklist",
            description: "Test checklist for JSON structure consistency",
            sections: [
                ChecklistSection(
                    id: sectionID,
                    title: "Test Section",
                    icon: "star",
                    description: "Section description",
                    items: [
                        ChecklistItem(
                            id: itemID,
                            title: "Test Item",
                            itemDescription: "Item description",
                            isOptional: false,
                            isRequired: true,
                            tags: ["test"],
                            estimatedMinutes: 30,
                            sortOrder: 0
                        )
                    ],
                    isExpandedByDefault: true,
                    sortOrder: 0
                )
            ],
            checklistType: .general,
            tags: ["test", "json-structure"],
            createdAt: Date(),
            updatedAt: Date()
        )

        try await repository.createChecklist(checklist)

        // Create library metadata
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
        try await repository.updateLibraryMetadata(libraryModel)

        // Publish using VisibilityService
        let mockAuthService = MockAuthService()
        mockAuthService.mockCurrentUser = UserInfo(id: "test-user", email: "test@example.com", username: "testuser", createdAt: "2024-01-01T00:00:00Z", profileImageUrl: nil, profileImageThumbnailUrl: nil, bio: nil, location: nil, nationality: nil, profileVisibility: "public")
        let visibilityService = VisibilityService(libraryStore: libraryStore, authService: mockAuthService, syncService: syncService)

        let publishSummary = try await visibilityService.publishContent(libraryModel)
        #expect(publishSummary.succeeded == 1)

        // Process the publish operation
        let _ = await syncService.syncPending()

        // Get published item
        var publishedItem = try await repository.fetchLibraryItem(checklistID)
        #expect(publishedItem?.publicID != nil)
        let publicID = publishedItem!.publicID!

        // Edit the checklist
        var editedChecklist = checklist
        editedChecklist.title = "Edited JSON Structure Test Checklist"
        editedChecklist.updatedAt = Date()
        try await libraryStore.saveChecklist(editedChecklist)

        // Trigger sync to process any pending operations
        let _ = await syncService.syncPending()

        // Verify the JSON structures are consistent by testing discover parsing
        // Create mock API response with the published content data
        let mockDetail = SharedContentDetail(
            id: checklistID,
            title: editedChecklist.title,
            description: editedChecklist.description,
            contentType: "checklist",
            contentData: [
                "id": editedChecklist.id.uuidString,
                "title": editedChecklist.title,
                "description": editedChecklist.description as Any,
                "sections": editedChecklist.sections.map { section in
                    [
                        "id": section.id.uuidString,
                        "title": section.title,
                        "icon": section.icon as Any,
                        "description": section.description as Any,
                        "isExpandedByDefault": section.isExpandedByDefault,
                        "sortOrder": section.sortOrder,
                        "items": section.items.map { item in
                            [
                                "id": item.id.uuidString,
                                "title": item.title,
                                "itemDescription": item.itemDescription as Any,
                                "isOptional": item.isOptional,
                                "isRequired": item.isRequired,
                                "tags": item.tags,
                                "estimatedMinutes": item.estimatedMinutes as Any,
                                "sortOrder": item.sortOrder
                            ]
                        }
                    ]
                },
                "checklistType": editedChecklist.checklistType.rawValue,
                "tags": editedChecklist.tags,
                "createdAt": editedChecklist.createdAt.ISO8601Format(),
                "updatedAt": editedChecklist.updatedAt.ISO8601Format(),
                "syncStatus": editedChecklist.syncStatus.rawValue
            ],
            tags: editedChecklist.tags,
            publicID: publicID,
            canFork: true,
            authorUsername: "testuser",
            viewCount: 0,
            forkCount: 0,
            createdAt: editedChecklist.createdAt,
            updatedAt: editedChecklist.updatedAt
        )

        // Test that DiscoverContentReaderViewModel can parse this data without errors
        let viewModel = DiscoverContentReaderViewModel(apiClient: apiClient, publicID: publicID)

        // Simulate successful API fetch by setting up the mock
        apiClient.mockPublicContentResponse = mockDetail

        // This should not throw an error now that we've fixed the date decoding and section properties
        try await viewModel.loadContent()

        #expect(viewModel.parsedContent != nil, "Should successfully parse published content")
        #expect(viewModel.currentError == nil, "Should not have any parsing errors")

        if case .checklist(let parsedChecklist) = viewModel.parsedContent {
            #expect(parsedChecklist.id == checklistID)
            #expect(parsedChecklist.title == editedChecklist.title)
            #expect(parsedChecklist.sections.count == 1)

            let parsedSection = parsedChecklist.sections[0]
            #expect(parsedSection.isExpandedByDefault == true, "Section should have isExpandedByDefault property")
            #expect(parsedSection.sortOrder == 0, "Section should have sortOrder property")
            #expect(parsedSection.icon == "star", "Section should have icon property")
            #expect(parsedSection.description == "Section description", "Section should have description property")
        } else {
            Issue.record("Parsed content should be a checklist")
        }
    }
}

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    var shouldFail = false
    var mockPublicContentResponse: SharedContentDetail?

    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool,
        forkedFromID: UUID?
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
        // Return mock response if set, otherwise default mock
        if let mockResponse = mockPublicContentResponse {
            return mockResponse
        }

        // Default mock implementation
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

    func updatePublishedContent(
        publicID: String,
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String
    ) async throws -> UpdateContentResponse {
        // Mock implementation - return a mock response
        return UpdateContentResponse(
            id: UUID(),
            publicID: publicID,
            updatedAt: Date()
        )
    }

    func fetchPublicProfile(username: String) async throws -> PublicProfileResponse {
        return PublicProfileResponse(
            id: UUID(),
            username: username,
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: "Mock bio",
            location: "Mock location",
            nationality: "Mock nationality",
            isVerified: false,
            verificationTier: nil,
            createdAt: Date(),
            stats: PublicProfileStatsResponse(
                totalContributions: 5,
                averageRating: nil,
                totalForks: 2
            )
        )
    }

    // MARK: Charter API

    var mockCreateCharterResponse: CharterAPIResponse?
    var mockFetchMyChartersResponse: CharterListAPIResponse?
    var mockDiscoverChartersResponse: CharterDiscoveryAPIResponse?
    var createCharterCallCount = 0
    var updateCharterCallCount = 0
    var discoverChartersCallCount = 0

    func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse {
        createCharterCallCount += 1
        if shouldFail { throw APIError.serverError }
        return mockCreateCharterResponse ?? CharterAPIResponse(
            id: UUID(),
            userId: UUID(),
            name: request.name,
            boatName: request.boatName,
            locationText: request.locationText,
            startDate: request.startDate,
            endDate: request.endDate,
            latitude: request.latitude,
            longitude: request.longitude,
            locationPlaceId: request.locationPlaceId,
            visibility: request.visibility,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func fetchMyCharters() async throws -> CharterListAPIResponse {
        if shouldFail { throw APIError.serverError }
        return mockFetchMyChartersResponse ?? CharterListAPIResponse(items: [], total: 0, limit: 20, offset: 0)
    }

    func fetchCharter(id: UUID) async throws -> CharterAPIResponse {
        if shouldFail { throw APIError.serverError }
        return CharterAPIResponse(
            id: id,
            userId: UUID(),
            name: "Mock Charter",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "private",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse {
        updateCharterCallCount += 1
        if shouldFail { throw APIError.serverError }
        return CharterAPIResponse(
            id: id,
            userId: UUID(),
            name: request.name ?? "Updated Charter",
            boatName: request.boatName,
            locationText: request.locationText,
            startDate: request.startDate ?? Date(),
            endDate: request.endDate ?? Date().addingTimeInterval(86400),
            latitude: request.latitude,
            longitude: request.longitude,
            locationPlaceId: request.locationPlaceId,
            visibility: request.visibility ?? "private",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func deleteCharter(id: UUID) async throws {
        if shouldFail { throw APIError.serverError }
    }

    func discoverCharters(
        dateFrom: Date?,
        dateTo: Date?,
        nearLat: Double?,
        nearLon: Double?,
        radiusKm: Double,
        limit: Int,
        offset: Int
    ) async throws -> CharterDiscoveryAPIResponse {
        discoverChartersCallCount += 1
        if shouldFail { throw APIError.serverError }
        return mockDiscoverChartersResponse ?? CharterDiscoveryAPIResponse(
            items: [],
            total: 0,
            limit: limit,
            offset: offset
        )
    }
}

// MARK: - Mock Auth Service
// MockAuthService is defined in MockAuthService.swift
