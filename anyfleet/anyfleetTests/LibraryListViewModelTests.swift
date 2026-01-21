//
//  LibraryListViewModelTests.swift
//  anyfleetTests
//
//  Tests for LibraryListViewModel deletion scenarios
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Library List View Model Tests")
struct LibraryListViewModelTests {

    // MARK: - Mocks

@MainActor
class MockLibraryStore: LibraryStoreProtocol {
        // Track deletion calls
        private var deleteContentCalls: [(item: LibraryModel, shouldUnpublish: Bool)] = []

        // Track other calls
        private var togglePinCalls: [LibraryModel] = []
        private var loadLibraryCalls = 0

        // Mock data
        private var mockLibrary: [LibraryModel] = []

        // MARK: - Configuration

        func setLibrary(_ library: [LibraryModel]) {
            mockLibrary = library
        }

        func getDeleteContentCalls() -> [(item: LibraryModel, shouldUnpublish: Bool)] {
            deleteContentCalls
        }

        func getTogglePinCalls() -> [LibraryModel] {
            togglePinCalls
        }

        func getLoadLibraryCalls() -> Int {
            loadLibraryCalls
        }

        // MARK: - LibraryStore Protocol

        var library: [LibraryModel] {
            mockLibrary
        }

        var myChecklists: [LibraryModel] {
            mockLibrary.filter { $0.type == .checklist }
        }

        var myGuides: [LibraryModel] {
            mockLibrary.filter { $0.type == .practiceGuide }
        }

        var myDecks: [LibraryModel] {
            mockLibrary.filter { $0.type == .flashcardDeck }
        }

        func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
            mockLibrary.first { $0.id == id }
        }

        func loadLibrary() async {
            loadLibraryCalls += 1
        }

        func createChecklist(_ checklist: Checklist) async throws {}
        func createGuide(_ guide: PracticeGuide) async throws {}
        func createDeck(_ deck: FlashcardDeck) async throws {}

        func saveChecklist(_ checklist: Checklist) async throws {}
        func saveGuide(_ guide: PracticeGuide) async throws {}

        func updateLibraryMetadata(_ item: LibraryModel) async throws {}

        func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool = true) async throws {
            deleteContentCalls.append((item, shouldUnpublish))
            // Remove from mock library
            mockLibrary.removeAll { $0.id == item.id }
        }

        func togglePin(for item: LibraryModel) async {
            togglePinCalls.append(item)
        }

        func fetchFullContent<T>(_ id: UUID) async throws -> T? {
            // Mock implementation - return nil for simplicity in tests
            // Tests can override this behavior if needed
            return nil
        }

        func fetchChecklist(_ checklistID: UUID) async throws -> Checklist {
            // Mock implementation - throw not found for simplicity in tests
            throw LibraryError.notFound(checklistID)
        }

        func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide {
            // Mock implementation - throw not found for simplicity in tests
            throw LibraryError.notFound(guideID)
        }

        func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck {
            // Mock implementation - throw not found for simplicity in tests
            throw LibraryError.notFound(deckID)
        }

        func forkContent(from sharedContent: SharedContentDetail) async throws {
            // Convert content type string to enum
            let contentType: ContentType
            switch sharedContent.contentType {
            case "checklist": contentType = .checklist
            case "practice_guide": contentType = .practiceGuide
            case "flashcard_deck": contentType = .flashcardDeck
            default: contentType = .checklist // fallback
            }

            // Create forked LibraryModel
            let forkedItem = LibraryModel(
                id: UUID(),
                title: sharedContent.title,
                description: sharedContent.description,
                type: contentType,
                visibility: .private, // Forked content starts as private
                creatorID: UUID(), // Current user ID (mock)
                forkedFromID: sharedContent.id,
                originalAuthorUsername: sharedContent.authorUsername,
                originalContentPublicID: sharedContent.publicID,
                tags: sharedContent.tags,
                createdAt: Date(),
                updatedAt: Date(),
                syncStatus: .pending
            )

            // Add to mock library
            mockLibrary.append(forkedItem)
        }
    }

@MainActor
class MockVisibilityService: VisibilityServiceProtocol {
        private var publishCalls: [LibraryModel] = []
        private var unpublishCalls: [LibraryModel] = []
        private var retrySyncCalls: [LibraryModel] = []

        func getPublishCalls() -> [LibraryModel] { publishCalls }
        func getUnpublishCalls() -> [LibraryModel] { unpublishCalls }
        func getRetrySyncCalls() -> [LibraryModel] { retrySyncCalls }

        func publishContent(_ item: LibraryModel) async throws -> SyncSummary {
            publishCalls.append(item)
            return SyncSummary(succeeded: 1, failed: 0)
        }

        func unpublishContent(_ item: LibraryModel) async throws -> SyncSummary {
            unpublishCalls.append(item)
            return SyncSummary(succeeded: 1, failed: 0)
        }

        func retrySync(for item: LibraryModel) async {
            retrySyncCalls.append(item)
        }
    }

@MainActor
class MockAuthStateObserver: AuthStateObserverProtocol {
        let isSignedIn: Bool = true
        let currentUser: UserInfo? = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )
        let currentUserID: UUID? = UUID()
    }

@MainActor
class MockAppCoordinator: AppCoordinatorProtocol {
        private var editChecklistCalls: [UUID?] = []
        private var editGuideCalls: [UUID?] = []
        private var editDeckCalls: [UUID?] = []
        private var viewChecklistCalls: [UUID] = []
        private var viewGuideCalls: [UUID] = []

        func getEditChecklistCalls() -> [UUID?] { editChecklistCalls }
        func getEditGuideCalls() -> [UUID?] { editGuideCalls }
        func getEditDeckCalls() -> [UUID?] { editDeckCalls }
        func getViewChecklistCalls() -> [UUID] { viewChecklistCalls }
        func getViewGuideCalls() -> [UUID] { viewGuideCalls }

        func editChecklist(_ checklistID: UUID?) {
            editChecklistCalls.append(checklistID)
        }

        func editGuide(_ guideID: UUID?) {
            editGuideCalls.append(guideID)
        }

        func editDeck(_ deckID: UUID?) {
            editDeckCalls.append(deckID)
        }

        func viewChecklist(_ checklistID: UUID) {
            viewChecklistCalls.append(checklistID)
        }

        func viewGuide(_ guideID: UUID) {
            viewGuideCalls.append(guideID)
        }

        func viewDeck(_ deckID: UUID) {}
        func viewCharter(_ charterID: UUID) {}
        func editCharter(_ charterID: UUID?) {}
        func createCharter() {}
        func showSettings() {}
        func showProfile() {}
        func showDiscover() {}
        func showHome() {}
        func showLibrary() {}
        func showCharterList() {}
        func showCharterRecord() {}

        func push(_ route: AppRoute, to tab: AppView.Tab) {
            // Mock implementation - do nothing
        }

        func navigateToLibrary() {
            // Mock implementation - do nothing
        }
    }

    // MARK: - Helpers

    private func makeLibraryModel(
        id: UUID = UUID(),
        title: String = "Test Content",
        type: ContentType = .checklist,
        visibility: ContentVisibility = .private,
        publicID: String? = nil,
        creatorID: UUID = UUID()
    ) -> LibraryModel {
        LibraryModel(
            id: id,
            title: title,
            description: "Test description",
            type: type,
            visibility: visibility,
            creatorID: creatorID,
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced,
            publishedAt: publicID != nil ? Date() : nil,
            publicID: publicID
        )
    }

    @MainActor
    private func makeViewModel(
        library: [LibraryModel] = [],
        isSignedIn: Bool = true
    ) -> LibraryListViewModel {
        let libraryStore = MockLibraryStore()
        let visibilityService = MockVisibilityService()
        let authObserver = MockAuthStateObserver()
        let coordinator = MockAppCoordinator()

        libraryStore.setLibrary(library)

        return LibraryListViewModel(
            libraryStore: libraryStore,
            visibilityService: visibilityService,
            authObserver: authObserver,
            coordinator: coordinator
        )
    }

    // MARK: - Tests

    @Test("Delete private content calls deleteContent with shouldUnpublish=true")
    @MainActor
    func testDeletePrivateContent() async throws {
        // Arrange
        let privateContent = makeLibraryModel(title: "Private Checklist", visibility: .private)
        let viewModel = makeViewModel(library: [privateContent])
        let mockStore = await viewModel.libraryStore as! MockLibraryStore

        // Act
        try await viewModel.deleteContent(privateContent)

        // Assert
        let deleteCalls = await mockStore.getDeleteContentCalls()
        #expect(deleteCalls.count == 1)
        #expect(deleteCalls[0].item.id == privateContent.id)
        #expect(deleteCalls[0].shouldUnpublish == true) // Default behavior
    }

    @Test("Delete and unpublish published content calls deleteContent with shouldUnpublish=true")
    @MainActor
    func testDeleteAndUnpublishPublishedContent() async throws {
        // Arrange
        let publishedContent = makeLibraryModel(
            title: "Published Guide",
            visibility: .public,
            publicID: "pub-123"
        )
        let viewModel = makeViewModel(library: [publishedContent])
        let mockStore = await viewModel.libraryStore as! MockLibraryStore

        // Act
        try await viewModel.deleteAndUnpublishContent(publishedContent)

        // Assert
        let deleteCalls = await mockStore.getDeleteContentCalls()
        #expect(deleteCalls.count == 1)
        #expect(deleteCalls[0].item.id == publishedContent.id)
        #expect(deleteCalls[0].shouldUnpublish == true)
    }

    @Test("Delete local copy but keep published calls deleteContent with shouldUnpublish=false")
    @MainActor
    func testDeleteLocalCopyKeepPublished() async throws {
        // Arrange
        let publishedContent = makeLibraryModel(
            title: "Published Checklist",
            visibility: .public,
            publicID: "pub-456"
        )
        let viewModel = makeViewModel(library: [publishedContent])
        let mockStore = await viewModel.libraryStore as! MockLibraryStore

        // Act
        try await viewModel.deleteLocalCopyKeepPublished(publishedContent)

        // Assert
        let deleteCalls = await mockStore.getDeleteContentCalls()
        #expect(deleteCalls.count == 1)
        #expect(deleteCalls[0].item.id == publishedContent.id)
        #expect(deleteCalls[0].shouldUnpublish == false)
    }

    @Test("isPublishedContent returns true for content with publicID")
    @MainActor
    func testIsPublishedContent() {
        let viewModel = makeViewModel()

        let privateContent = makeLibraryModel(visibility: .private)
        let publishedContent = makeLibraryModel(visibility: .public, publicID: "pub-123")

        #expect(viewModel.isPublishedContent(privateContent) == false)
        #expect(viewModel.isPublishedContent(publishedContent) == true)
    }

    @Test("Computed properties filter content correctly")
    @MainActor
    func testComputedProperties() {
        let privateChecklist = makeLibraryModel(type: .checklist, visibility: .private)
        let publicGuide = makeLibraryModel(type: .practiceGuide, visibility: .public, publicID: "pub-1")
        let unlistedDeck = makeLibraryModel(type: .flashcardDeck, visibility: .unlisted)

        let viewModel = makeViewModel(library: [privateChecklist, publicGuide, unlistedDeck])

        // Test local content (private + unlisted)
        #expect(viewModel.localContent.count == 2)
        #expect(viewModel.localContent.contains(where: { $0.id == privateChecklist.id }))
        #expect(viewModel.localContent.contains(where: { $0.id == unlistedDeck.id }))

        // Test public content
        #expect(viewModel.publicContent.count == 1)
        #expect(viewModel.publicContent.first?.id == publicGuide.id)

        // Test helper properties
        #expect(viewModel.hasLocalContent == true)
        #expect(viewModel.hasPublicContent == true)
    }

    @Test("Self-forking preserves original creator attribution")
    @MainActor
    func testSelfForkingPreservesAttribution() async throws {
        // This test verifies that when a user forks their own deleted published content,
        // the original creator attribution is preserved in the metadata

        // Arrange: Create a shared content detail representing deleted published content
        let originalCreatorID = UUID()
        let sharedContent = SharedContentDetail(
            id: UUID(),
            title: "My Deleted Guide",
            description: "This was my published guide that I accidentally deleted",
            contentType: "practice_guide",
            contentData: [
                "id": UUID().uuidString,
                "title": "My Deleted Guide",
                "description": "This was my published guide that I accidentally deleted",
                "sections": [],
                "tags": ["test", "deleted"],
                "createdAt": Date().addingTimeInterval(-86400).ISO8601Format(),
                "updatedAt": Date().addingTimeInterval(-3600).ISO8601Format(),
                "syncStatus": "synced"
            ],
            tags: ["test", "deleted"],
            publicID: "pub-deleted-123",
            canFork: true,
            authorUsername: "testuser",
            viewCount: 42,
            forkCount: 0,
            createdAt: Date().addingTimeInterval(-86400), // 1 day ago
            updatedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )

        let viewModel = makeViewModel()
        let mockStore = await viewModel.libraryStore as! MockLibraryStore

        // Act: Fork the content (simulating user recovering their deleted content)
        try await mockStore.forkContent(from: sharedContent)

        // Assert: Verify that fork attribution is preserved
        let forkedItems = await mockStore.library
        #expect(forkedItems.count == 1)

        let forkedItem = forkedItems.first!
        #expect(forkedItem.title == "My Deleted Guide")
        #expect(forkedItem.type == .practiceGuide)
        #expect(forkedItem.forkedFromID == sharedContent.id)
        #expect(forkedItem.originalAuthorUsername == "testuser")
        #expect(forkedItem.originalContentPublicID == "pub-deleted-123")
        // Attribution is preserved through the original author fields
    }
}
