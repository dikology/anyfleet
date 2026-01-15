//
//  VisibilityServiceTests.swift
//  anyfleetTests
//
//  Unit tests for VisibilityService using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("VisibilityService Tests")
struct VisibilityServiceTests {

// MARK: - Mock Library Store for VisibilityService tests

@MainActor
final class MockLibraryStoreForVisibility: LibraryStoreProtocol {
        var lastUpdatedItem: LibraryModel?

        // Mock data
        private var mockLibrary: [LibraryModel] = []
        private var mockFullContent: [UUID: Any] = [:]

        var library: [LibraryModel] { mockLibrary }
        var myChecklists: [LibraryModel] { mockLibrary.filter { $0.type == .checklist } }
        var myGuides: [LibraryModel] { mockLibrary.filter { $0.type == .practiceGuide } }
        var myDecks: [LibraryModel] { mockLibrary.filter { $0.type == .flashcardDeck } }

        func loadLibrary() async {}
        func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? { nil }
        func createChecklist(_ checklist: Checklist) async throws {}
        func createGuide(_ guide: PracticeGuide) async throws {}
        func createDeck(_ deck: FlashcardDeck) async throws {}
        func forkContent(from sharedContent: SharedContentDetail) async throws {}
        func saveChecklist(_ checklist: Checklist) async throws {}
        func saveGuide(_ guide: PracticeGuide) async throws {}

        func updateLibraryMetadata(_ item: LibraryModel) async throws {
            lastUpdatedItem = item
        }

        func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool) async throws {}
        func fetchChecklist(_ checklistID: UUID) async throws -> Checklist { throw LibraryError.notFound(checklistID) }
        func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide { throw LibraryError.notFound(guideID) }
        func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck { throw LibraryError.notFound(deckID) }

        func fetchFullContent<T>(_ id: UUID) async throws -> T? {
            return mockFullContent[id] as? T
        }

        func togglePin(for item: LibraryModel) async {}

        // Helper method to set mock content for testing
        func setMockChecklist(_ checklist: Checklist, for id: UUID) {
            mockFullContent[id] = checklist
        }
}

    @Test("Publish requires authentication")
    @MainActor
    func publishRequiresAuth() async throws {
        // Given
        let mockAuth = MockAuthService()
        mockAuth.mockIsAuthenticated = false
        let mockStore = MockLibraryStoreForVisibility()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )

        let item = LibraryModel(
            title: "Test Content",
            description: "Test description",
            type: .checklist,
            creatorID: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        // When/Then
        await #expect(throws: VisibilityService.PublishError.notAuthenticated) {
            try await service.publishContent(item)
        }
    }

    @Test("Publish validates content before submission")
    @MainActor
    func publishValidatesContent() async throws {
        // Given
        let mockAuth = MockAuthService()
        mockAuth.mockIsAuthenticated = true
        let mockStore = MockLibraryStoreForVisibility()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )

        let item = LibraryModel(
            title: "AB", // Too short
            description: "Test description",
            type: .checklist,
            creatorID: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        // When/Then
        await #expect(throws: VisibilityService.PublishError.self) {
            try await service.publishContent(item)
        }
    }

    @Test("Publish updates visibility and triggers sync")
    @MainActor
    func publishUpdatesVisibility() async throws {
        // Given
        let mockAuth = MockAuthService()
        mockAuth.mockIsAuthenticated = true
        mockAuth.mockCurrentUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-01-01T00:00:00Z"
        )
        let mockStore = MockLibraryStoreForVisibility()
        let mockSync = MockSyncService()
        let service = VisibilityService(
            libraryStore: mockStore,
            authService: mockAuth,
            syncService: mockSync
        )

        let itemID = UUID()
        let mockChecklist = Checklist(
            id: itemID,
            title: "Valid Content Title",
            description: "Test description with enough content",
            sections: [],
            checklistType: .general,
            tags: ["test"]
        )
        mockStore.setMockChecklist(mockChecklist, for: itemID)

        let item = LibraryModel(
            id: itemID,
            title: "Valid Content Title",
            description: "Test description with enough content",
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date()
        )

        // When
        _ = try await service.publishContent(item)

        // Then
        #expect(mockStore.lastUpdatedItem?.visibility == .public)
        #expect(mockSync.enqueuePublishCallCount == 1)
    }

    @Test("Date encoding strategy produces ISO 8601 dates that can be decoded correctly")
    @MainActor
    func testDateEncodingStrategyCompatibility() async throws {
        // Given: Create a checklist with specific dates
        let testDate = Date(timeIntervalSince1970: 1700000000) // Fixed date for testing
        let checklist = Checklist(
            id: UUID(),
            title: "Date Encoding Test",
            description: "Testing date encoding/decoding compatibility",
            sections: [
                ChecklistSection(
                    title: "Test Section",
                    items: [
                        ChecklistItem(title: "Test Item")
                    ]
                )
            ],
            checklistType: .general,
            tags: ["test"],
            createdAt: testDate,
            updatedAt: testDate,
            syncStatus: .pending
        )

        // When: Encode the checklist using the same method as VisibilityService
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedData = try encoder.encode(checklist)

        // Convert to dictionary (simulating what encodeChecklist does)
        let json = try JSONSerialization.jsonObject(with: encodedData)
        guard let jsonDict = json as? [String: Any] else {
            Issue.record("Failed to convert encoded data to dictionary")
            return
        }

        // Now decode it using the same method as DiscoverContentReaderViewModel
        let checklistData = try JSONSerialization.data(withJSONObject: jsonDict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedChecklist = try decoder.decode(Checklist.self, from: checklistData)

        // Then: Verify dates are preserved correctly
        #expect(decodedChecklist.createdAt == testDate)
        #expect(decodedChecklist.updatedAt == testDate)
        #expect(decodedChecklist.title == "Date Encoding Test")
        #expect(decodedChecklist.description == "Testing date encoding/decoding compatibility")
    }
}
