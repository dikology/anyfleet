//
//  MockSyncService.swift
//  anyfleetTests
//
//  Mock sync service for unit testing
//

import Foundation
@testable import anyfleet

/// Mock sync service that implements ContentSyncServiceProtocol for testing
final class MockSyncService: ContentSyncServiceProtocol {
    // Track method calls
    var enqueuePublishCallCount = 0
    var enqueueUnpublishCallCount = 0
    var syncPendingCallCount = 0

    // Mock data
    var mockSyncSummary = SyncSummary(attempted: 1, succeeded: 1, failed: 0)
    var shouldFail = false

    // Track last called parameters
    var lastEnqueuePublishContentID: UUID?
    var lastEnqueuePublishVisibility: ContentVisibility?
    var lastEnqueuePublishPayload: Data?

    var lastEnqueueUnpublishContentID: UUID?
    var lastEnqueueUnpublishPublicID: String?

    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws -> SyncSummary {
        enqueuePublishCallCount += 1
        lastEnqueuePublishContentID = contentID
        lastEnqueuePublishVisibility = visibility
        lastEnqueuePublishPayload = payload

        if shouldFail {
            throw NSError(domain: "MockSyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock sync failure"])
        }

        return mockSyncSummary
    }

    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws -> SyncSummary {
        enqueueUnpublishCallCount += 1
        lastEnqueueUnpublishContentID = contentID
        lastEnqueueUnpublishPublicID = publicID

        if shouldFail {
            throw NSError(domain: "MockSyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock sync failure"])
        }

        return mockSyncSummary
    }

    func syncPending() async -> SyncSummary {
        syncPendingCallCount += 1
        return mockSyncSummary
    }
}