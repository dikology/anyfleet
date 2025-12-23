//
//  LocalRepositorySyncQueueIntegrationTests.swift
//  anyfleetTests
//
//  Integration tests for LocalRepository sync queue operations
//

import Foundation
import Testing
@testable import anyfleet

@Suite("LocalRepository Sync Queue Integration Tests")
struct LocalRepositorySyncQueueIntegrationTests {

    // Each test gets its own fresh in-memory database to avoid cross-test
    // contamination and ensure a clean state.
    private func makeRepository() throws -> LocalRepository {
        let database = try AppDatabase.makeEmpty()
        return LocalRepository(database: database)
    }

    @Test("Enqueue sync operation - publish success")
    func testEnqueueSyncOperation_Publish() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()
        let visibility = ContentVisibility.public
        let operation = SyncOperation.publish
        let testPayload = "test payload".data(using: .utf8)!

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Act
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: operation,
            visibility: visibility,
            payload: testPayload
        )

        // Assert - Verify operation was enqueued by fetching it back
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pending.count == 1)
        #expect(pending[0].contentID == contentID)
        #expect(pending[0].operation == operation)
        #expect(pending[0].visibility == visibility)
        #expect(pending[0].payload == testPayload)
        #expect(pending[0].retryCount == 0)
        #expect(pending[0].lastError == nil)
        #expect(pending[0].id > 0)
    }

    @Test("Basic smoke test - can create repository")
    func testBasicRepositoryCreation() async throws {
        // Arrange & Act
        let repository = try makeRepository()

        // Assert - Just verify we can create it and call a method
        let counts = try await repository.getSyncQueueCounts()
        #expect(counts.pending == 0)
        #expect(counts.failed == 0)
    }

    @Test("Enqueue sync operation - unpublish success")
    func testEnqueueSyncOperation_Unpublish() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()
        let visibility = ContentVisibility.private
        let operation = SyncOperation.unpublish

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Unpublish",
            description: "Test description",
            type: .checklist,
            visibility: .public, // Start as public so unpublish makes sense
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Act
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: operation,
            visibility: visibility,
            payload: nil
        )

        // Assert
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pending.count == 1)
        #expect(pending[0].contentID == contentID)
        #expect(pending[0].operation == operation)
        #expect(pending[0].visibility == visibility)
        #expect(pending[0].payload == nil)
    }

    @Test("Enqueue sync operation - multiple operations")
    func testEnqueueSyncOperation_MultipleOperations() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID1 = UUID()
        let contentID2 = UUID()

        // Create library content records first (required for foreign key constraint)
        let libraryModel1 = LibraryModel(
            id: contentID1,
            title: "Test Content 1",
            description: "Test description 1",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel2 = LibraryModel(
            id: contentID2,
            title: "Test Content 2",
            description: "Test description 2",
            type: .practiceGuide,
            visibility: .public,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel1)
        try await repository.updateLibraryMetadata(libraryModel2)

        // Act
        try await repository.enqueueSyncOperation(
            contentID: contentID1,
            operation: .publish,
            visibility: .public,
            payload: "payload1".data(using: .utf8)
        )

        try await repository.enqueueSyncOperation(
            contentID: contentID2,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )

        // Assert
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pending.count == 2)

        let publishOp = pending.first { $0.contentID == contentID1 }
        let unpublishOp = pending.first { $0.contentID == contentID2 }

        #expect(publishOp != nil)
        #expect(unpublishOp != nil)
        #expect(publishOp?.operation == .publish)
        #expect(unpublishOp?.operation == .unpublish)
    }

    @Test("Get pending sync operations - filters by retry count")
    func testGetPendingSyncOperations_FiltersByRetryCount() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Retry",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Enqueue operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        // Manually increment retry count to max (3)
        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(operations.count == 1)
        let operationID = operations[0].id

        // Increment retry count 3 times
        for _ in 0..<3 {
            try await repository.incrementSyncRetryCount(operationID, error: "Test error")
        }

        // Act - Should not return operations with max retries
        let pendingAfterRetries = try await repository.getPendingSyncOperations(maxRetries: 3)

        // Assert - Should be empty since operation exceeded max retries
        #expect(pendingAfterRetries.isEmpty)
    }

    @Test("Mark sync operation complete - success")
    func testMarkSyncOperationComplete_Success() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Complete",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Enqueue operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(operations.count == 1)
        let operationID = operations[0].id

        // Act
        try await repository.markSyncOperationComplete(operationID)

        // Assert - Should not appear in pending operations
        let pendingAfterComplete = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pendingAfterComplete.isEmpty)
    }

    @Test("Mark sync operation complete - non-existent operation")
    func testMarkSyncOperationComplete_NonExistent() async throws {
        // Arrange
        let repository = try makeRepository()

        // Act & Assert - Should not throw error for non-existent operation
        try await repository.markSyncOperationComplete(99999)
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pending.isEmpty)
    }

    @Test("Increment sync retry count - success")
    func testIncrementSyncRetryCount_Success() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()
        let errorMessage = "Network timeout"

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Retry Count",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Enqueue operation
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(operations.count == 1)
        #expect(operations[0].retryCount == 0)
        #expect(operations[0].lastError == nil)

        let operationID = operations[0].id

        // Act
        try await repository.incrementSyncRetryCount(operationID, error: errorMessage)

        // Assert
        let operationsAfterRetry = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(operationsAfterRetry.count == 1)
        #expect(operationsAfterRetry[0].retryCount == 1)
        #expect(operationsAfterRetry[0].lastError == errorMessage)
    }

    @Test("Increment sync retry count - multiple increments")
    func testIncrementSyncRetryCount_MultipleIncrements() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Multiple Retries",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        let operationID = operations[0].id

        // Act - Increment multiple times
        try await repository.incrementSyncRetryCount(operationID, error: "Error 1")
        try await repository.incrementSyncRetryCount(operationID, error: "Error 2")
        try await repository.incrementSyncRetryCount(operationID, error: "Error 3")

        // Assert - After 3 increments, retryCount = 3, so operation should not be returned (retryCount >= maxRetries)
        let operationsAfterRetries = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(operationsAfterRetries.count == 0) // Should be empty since operation exceeded max retries
    }

    @Test("Get sync queue counts - empty queue")
    func testGetSyncQueueCounts_EmptyQueue() async throws {
        // Arrange
        let repository = try makeRepository()

        // Act
        let counts = try await repository.getSyncQueueCounts()

        // Assert
        #expect(counts.pending == 0)
        #expect(counts.failed == 0)
    }

    @Test("Get sync queue counts - with operations")
    func testGetSyncQueueCounts_WithOperations() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID1 = UUID()
        let contentID2 = UUID()
        let contentID3 = UUID()

        // Create library content records first (required for foreign key constraint)
        let libraryModel1 = LibraryModel(
            id: contentID1,
            title: "Test Content 1",
            description: "Test description 1",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel2 = LibraryModel(
            id: contentID2,
            title: "Test Content 2",
            description: "Test description 2",
            type: .practiceGuide,
            visibility: .public,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel3 = LibraryModel(
            id: contentID3,
            title: "Test Content 3",
            description: "Test description 3",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel1)
        try await repository.updateLibraryMetadata(libraryModel2)
        try await repository.updateLibraryMetadata(libraryModel3)

        // Enqueue 2 pending operations
        try await repository.enqueueSyncOperation(
            contentID: contentID1,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        try await repository.enqueueSyncOperation(
            contentID: contentID2,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )

        // Create a failed operation (retry count >= 3)
        try await repository.enqueueSyncOperation(
            contentID: contentID3,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        // Make it failed by incrementing retries to max
        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        let failedOperationID = operations.first { $0.retryCount == 0 }!.id

        for _ in 0..<3 {
            try await repository.incrementSyncRetryCount(failedOperationID, error: "Test error")
        }

        // Act
        let counts = try await repository.getSyncQueueCounts()

        // Assert
        #expect(counts.pending == 2) // 2 operations still within retry limit
        #expect(counts.failed == 1) // 1 operation exceeded retry limit
    }

    @Test("Get sync queue counts - mixed states")
    func testGetSyncQueueCounts_MixedStates() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID1 = UUID()
        let contentID2 = UUID()

        // Create library content records first (required for foreign key constraint)
        let libraryModel1 = LibraryModel(
            id: contentID1,
            title: "Test Content for Mixed States 1",
            description: "Test description 1",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel2 = LibraryModel(
            id: contentID2,
            title: "Test Content for Mixed States 2",
            description: "Test description 2",
            type: .practiceGuide,
            visibility: .public,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel1)
        try await repository.updateLibraryMetadata(libraryModel2)

        // Enqueue operations
        try await repository.enqueueSyncOperation(
            contentID: contentID1,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        try await repository.enqueueSyncOperation(
            contentID: contentID2,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )

        let operations = try await repository.getPendingSyncOperations(maxRetries: 3)
        let operationID1 = operations[0].id
        let operationID2 = operations[1].id

        // Mark one as completed
        try await repository.markSyncOperationComplete(operationID1)

        // Make one failed
        for _ in 0..<3 {
            try await repository.incrementSyncRetryCount(operationID2, error: "Test error")
        }

        // Act
        let counts = try await repository.getSyncQueueCounts()

        // Assert
        #expect(counts.pending == 0) // None pending after marking complete and failing one
        #expect(counts.failed == 1) // One failed operation
    }

    @Test("Sync queue operations - FIFO order")
    func testSyncQueueOperations_FIFOOrder() async throws {
        // Arrange
        let repository = try makeRepository()

        // Enqueue operations in specific order
        let contentID1 = UUID()
        let contentID2 = UUID()
        let contentID3 = UUID()

        // Create library content records first (required for foreign key constraint)
        let libraryModel1 = LibraryModel(
            id: contentID1,
            title: "Test Content FIFO 1",
            description: "Test description 1",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel2 = LibraryModel(
            id: contentID2,
            title: "Test Content FIFO 2",
            description: "Test description 2",
            type: .practiceGuide,
            visibility: .public,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        let libraryModel3 = LibraryModel(
            id: contentID3,
            title: "Test Content FIFO 3",
            description: "Test description 3",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel1)
        try await repository.updateLibraryMetadata(libraryModel2)
        try await repository.updateLibraryMetadata(libraryModel3)

        try await repository.enqueueSyncOperation(
            contentID: contentID1,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        try await repository.enqueueSyncOperation(
            contentID: contentID2,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )

        try await repository.enqueueSyncOperation(
            contentID: contentID3,
            operation: .publish,
            visibility: .unlisted,
            payload: nil
        )

        // Act
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)

        // Assert - Should be returned in FIFO order (oldest first)
        #expect(pending.count == 3)
        #expect(pending[0].contentID == contentID1)
        #expect(pending[1].contentID == contentID2)
        #expect(pending[2].contentID == contentID3)
    }

    @Test("Sync queue operations - creation timestamps")
    func testSyncQueueOperations_CreationTimestamps() async throws {
        // Arrange
        let repository = try makeRepository()
        let contentID = UUID()
        let beforeEnqueue = Date()

        // Create a library content record first (required for foreign key constraint)
        let libraryModel = LibraryModel(
            id: contentID,
            title: "Test Content for Timestamps",
            description: "Test description",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: [],
            language: "en",
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        try await repository.updateLibraryMetadata(libraryModel)

        // Wait a tiny bit to ensure timestamp difference
        try await Task.sleep(for: .milliseconds(10))

        // Act
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: .public,
            payload: nil
        )

        try await Task.sleep(for: .milliseconds(10))
        let afterEnqueue = Date()

        // Assert
        let pending = try await repository.getPendingSyncOperations(maxRetries: 3)
        #expect(pending.count == 1)

        let operation = pending[0]
        #expect(operation.createdAt >= beforeEnqueue)
        #expect(operation.createdAt <= afterEnqueue)
    }
}
