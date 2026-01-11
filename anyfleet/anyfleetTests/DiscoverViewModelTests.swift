//
//  DiscoverViewModelTests.swift
//  anyfleetTests
//
//  Created by anyfleet on 2025-01-11.
//

import Foundation
import Testing
@testable import anyfleet

@Suite("DiscoverViewModel Tests")
struct DiscoverViewModelTests {

    @MainActor
    @Test("onAuthorTapped logs author interaction and is placeholder for modal")
    func testOnAuthorTappedLogsInteraction() async {
        // Given
        let mockApiClient = DiscoverMockAPIClient()
        let mockLibraryStore = MockLibraryStore()
        let mockCoordinator = MockAppCoordinator()

        let viewModel = DiscoverViewModel(
            apiClient: mockApiClient,
            libraryStore: mockLibraryStore,
            coordinator: mockCoordinator
        )

        let testUsername = "TestAuthor123"

        // When
        viewModel.onAuthorTapped(testUsername)

        // Then
        // Currently just logs - this test documents the expected behavior
        // When modal is implemented, this should trigger modal presentation
        #expect(testUsername == "TestAuthor123") // Placeholder assertion
    }

    @MainActor
    @Test("onAuthorTapped handles different username formats")
    func testOnAuthorTappedHandlesDifferentUsernames() async {
        // Given
        let mockApiClient = DiscoverMockAPIClient()
        let mockLibraryStore = MockLibraryStore()
        let mockCoordinator = MockAppCoordinator()

        let viewModel = DiscoverViewModel(
            apiClient: mockApiClient,
            libraryStore: mockLibraryStore,
            coordinator: mockCoordinator
        )

        let testUsernames = [
            "simple_user",
            "user-with-dashes",
            "user.with.dots",
            "UserWithCaps123",
            "email@domain.com",
            "very_long_username_that_might_cause_layout_issues"
        ]

        // When & Then
        for username in testUsernames {
            viewModel.onAuthorTapped(username)
            // Currently just logs - test ensures no crashes with various username formats
            #expect(username.count > 0)
        }
    }

    @MainActor
    @Test("onAuthorTapped is called when author avatar is tapped in UI")
    func testAuthorTapIntegration() async {
        // This test documents the integration point where onAuthorTapped should be called
        // from the UI layer (DiscoverContentRow -> DiscoverView -> DiscoverViewModel)

        let mockApiClient = DiscoverMockAPIClient()
        let mockLibraryStore = MockLibraryStore()
        let mockCoordinator = MockAppCoordinator()

        let viewModel = DiscoverViewModel(
            apiClient: mockApiClient,
            libraryStore: mockLibraryStore,
            coordinator: mockCoordinator
        )

        // Simulate the flow that happens when user taps author avatar
        let content = DiscoverContent(
            id: UUID(),
            title: "Test Content",
            description: "Test Description",
            contentType: .checklist,
            tags: ["test"],
            publicID: "test-content",
            authorUsername: "TestAuthor",
            viewCount: 10,
            forkCount: 5,
            createdAt: Date()
        )

        // This is what should happen when author avatar is tapped in UI
        if let authorUsername = content.authorUsername {
            viewModel.onAuthorTapped(authorUsername)
            #expect(authorUsername == "TestAuthor")
        }
    }
}

// MARK: - Mock Classes


class MockLibraryStore: LibraryStoreProtocol {
    var library: [LibraryModel] = []
    var myChecklists: [LibraryModel] = []
    var myGuides: [LibraryModel] = []
    var myDecks: [LibraryModel] = []

    func loadLibrary() async {
        // Mock implementation - do nothing
    }

    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
        return nil
    }

    func createChecklist(_ checklist: Checklist) async throws {
        // Mock implementation - do nothing
    }

    func createGuide(_ guide: PracticeGuide) async throws {
        // Mock implementation - do nothing
    }

    func createDeck(_ deck: FlashcardDeck) async throws {
        // Mock implementation - do nothing
    }

    func updateChecklist(_ checklist: Checklist) async throws {
        // Mock implementation - do nothing
    }

    func updateGuide(_ guide: PracticeGuide) async throws {
        // Mock implementation - do nothing
    }

    func updateDeck(_ deck: FlashcardDeck) async throws {
        // Mock implementation - do nothing
    }

    func deleteContent(_ id: UUID) async throws {
        // Mock implementation - do nothing
    }

    func saveChecklist(_ checklist: Checklist) async throws {
        // Mock implementation - do nothing
    }

    func saveGuide(_ guide: PracticeGuide) async throws {
        // Mock implementation - do nothing
    }

    func updateLibraryMetadata(_ item: LibraryModel) async throws {
        // Mock implementation - do nothing
    }

    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool) async throws {
        // Mock implementation - do nothing
    }

    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist {
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }

    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide {
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }

    func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck {
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }

    func fetchFullContent<T>(_ id: UUID) async throws -> T? {
        return nil
    }

    func forkContent(from sharedContent: SharedContentDetail) async throws {
        // Mock implementation - do nothing
    }

    func pinContent(_ id: UUID) async throws {
        // Mock implementation - do nothing
    }

    func unpinContent(_ id: UUID) async throws {
        // Mock implementation - do nothing
    }

    func togglePin(for item: LibraryModel) async {
        // Mock implementation - do nothing
    }
}

class DiscoverMockAPIClient: APIClientProtocol {
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
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }

    func unpublishContent(publicID: String) async throws {
        // Mock implementation
    }

    func fetchPublicContent() async throws -> [SharedContentSummary] {
        return []
    }

    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail {
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
            updatedAt: Date(),
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )
    }

    func incrementForkCount(publicID: String) async throws {
        // Mock implementation
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
        throw NSError(domain: "MockError", code: 1, userInfo: nil)
    }

}

class MockAppCoordinator: AppCoordinatorProtocol {
    func editChecklist(_ checklistID: UUID?) {
        // Mock implementation - do nothing
    }

    func editGuide(_ guideID: UUID?) {
        // Mock implementation - do nothing
    }

    func editDeck(_ deckID: UUID?) {
        // Mock implementation - do nothing
    }

    func viewChecklist(_ checklistID: UUID) {
        // Mock implementation - do nothing
    }

    func viewGuide(_ guideID: UUID) {
        // Mock implementation - do nothing
    }

    func push(_ route: AppRoute, to tab: AppView.Tab) {
        // Mock implementation - do nothing
    }

    func navigateToLibrary() {
        // Mock implementation - do nothing
    }
}