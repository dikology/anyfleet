//
//  LibraryStoreTests.swift
//  anyfleetTests
//
//  Unit tests for LibraryStore performance and caching behavior
//

import Foundation
import Testing
@testable import anyfleet

@Suite("LibraryStore Tests")
struct LibraryStoreTests {
    
    // MARK: - Mocks
    
    actor MockLibraryRepository: LibraryRepository {
        // Stored test data
        private var libraryResult: [LibraryModel] = []

        // Call counts
        private var fetchUserLibraryCallCount = 0
        private var fetchChecklistCallCount = 0
        private var saveChecklistCallCount = 0

        // For fetchChecklist
        private var fetchChecklistResult: Checklist?

        // MARK: - Configuration Helpers

        func setLibraryResult(_ value: [LibraryModel]) {
            libraryResult = value
        }

        func setFetchChecklistResult(_ value: Checklist?) {
            fetchChecklistResult = value
        }
        
        func getFetchUserLibraryCallCount() -> Int {
            fetchUserLibraryCallCount
        }
        
        func getFetchChecklistCallCount() -> Int {
            fetchChecklistCallCount
        }
        
        func getSaveChecklistCallCount() -> Int {
            saveChecklistCallCount
        }
        
        // MARK: - LibraryRepository
        
        func fetchUserLibrary() async throws -> [LibraryModel] {
            fetchUserLibraryCallCount += 1
            return libraryResult
        }

        func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? {
            return libraryResult.first { $0.id == id }
        }
        
        func fetchUserChecklists() async throws -> [Checklist] {
            return []
        }
        
        func fetchUserGuides() async throws -> [PracticeGuide] {
            return []
        }
        
        func fetchUserDecks() async throws -> [FlashcardDeck] {
            return []
        }
        
        func fetchChecklist(_ checklistID: UUID) async throws -> Checklist {
            fetchChecklistCallCount += 1
            guard let result = fetchChecklistResult else {
                throw LibraryError.notFound(checklistID)
            }
            return result
        }
        
        func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide {
            throw LibraryError.notFound(guideID)
        }

        func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck {
            throw LibraryError.notFound(deckID)
        }
        
        func createChecklist(_ checklist: Checklist) async throws {}
        func createGuide(_ guide: PracticeGuide) async throws {}
        func createDeck(_ deck: FlashcardDeck) async throws {}
        
        func saveChecklist(_ checklist: Checklist) async throws {
            saveChecklistCallCount += 1
        }
        
        func saveGuide(_ guide: PracticeGuide) async throws {}
        
        func updateLibraryMetadata(_ model: LibraryModel) async throws {}
        
        func deleteContent(_ contentID: UUID) async throws {}
    }
    
    // MARK: - Helpers
    
    private func makeChecklist(
        id: UUID = UUID(),
        title: String = "Test Checklist",
        description: String? = "Description"
    ) -> Checklist {
        Checklist(
            id: id,
            title: title,
            description: description,
            sections: [],
            checklistType: .general,
            tags: ["tag1"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
    }
    
    private func makeLibraryModel(from checklist: Checklist) -> LibraryModel {
        LibraryModel(
            id: checklist.id,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt,
            syncStatus: checklist.syncStatus
        )
    }
    
    // MARK: - Tests
    
    @Test("saveChecklist updates metadata without full reload and caches full content")
    @MainActor
    func testSaveChecklistUpdatesMetadataAndCachesFullContent() async throws {
        // Arrange
        let baseChecklist = makeChecklist()
        let baseMetadata = makeLibraryModel(from: baseChecklist)

        let repository = MockLibraryRepository()
        await repository.setLibraryResult([baseMetadata])

        // Create sync queue service (uses a separate LocalRepository)
        let database = try AppDatabase.makeEmpty()
        let syncRepository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: syncRepository, apiClient: mockAPIClient)

        let store = LibraryStore(repository: repository, syncQueue: syncQueue)

        // Initial load to populate metadata only
        await store.loadLibrary()
        #expect(store.library.count == 1)
        #expect(store.myChecklists.count == 1)

        // Prepare updated checklist
        var updatedChecklist = baseChecklist
        updatedChecklist.title = "Updated Title"
        updatedChecklist.description = "Updated Description"
        updatedChecklist.tags = ["tag2"]
        updatedChecklist.updatedAt = Date().addingTimeInterval(60)
        updatedChecklist.syncStatus = .synced

        // Act
        try await store.saveChecklist(updatedChecklist)

        // Assert: metadata updated in place (no extra rows)
        #expect(store.library.count == 1)
        let metadata = store.library.first!
        #expect(metadata.title == "Updated Title")
        #expect(metadata.description == "Updated Description")
        #expect(metadata.tags == ["tag2"])
        #expect(metadata.syncStatus == .synced)

        // Assert: full content is cached and retrievable
        let cachedContent: Checklist? = try await store.fetchFullContent(baseChecklist.id)
        #expect(cachedContent?.title == "Updated Title")
        #expect(cachedContent?.description == "Updated Description")
        #expect(cachedContent?.tags == ["tag2"])

        // Assert: repository.saveChecklist called once
        #expect(await repository.getSaveChecklistCallCount() == 1)

        // Assert: fetchUserLibrary not called again after initial load (i.e. no full reload)
        #expect(await repository.getFetchUserLibraryCallCount() == 1)
    }
    
    @Test("fetchFullContent caches repository result and avoids repeated fetches")
    @MainActor
    func testFetchFullContentUsesCache() async throws {
        // Arrange
        let checklist = makeChecklist()
        let repository = MockLibraryRepository()
        await repository.setFetchChecklistResult(checklist)

        // Create sync queue service (uses a separate LocalRepository)
        let database = try AppDatabase.makeEmpty()
        let syncRepository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: syncRepository, apiClient: mockAPIClient)

        let store = LibraryStore(repository: repository, syncQueue: syncQueue)

        // Act: first fetch should hit repository
        let first: Checklist? = try await store.fetchFullContent(checklist.id)

        // Act: second fetch should be served from cache
        let second: Checklist? = try await store.fetchFullContent(checklist.id)

        // Assert: values are equal
        #expect(first?.id == checklist.id)
        #expect(second?.id == checklist.id)

        // Repository should have been called only once
        #expect(await repository.getFetchChecklistCallCount() == 1)
    }
    
    @Test("fetchFullContent caches content and serves subsequent requests from cache")
    @MainActor
    func testFetchFullContentCachesAndServesFromCache() async throws {
        // Arrange
        let checklist = makeChecklist()
        let metadata = makeLibraryModel(from: checklist)

        let repository = MockLibraryRepository()
        await repository.setLibraryResult([metadata])
        await repository.setFetchChecklistResult(checklist)

        // Create sync queue service (uses a separate LocalRepository)
        let database = try AppDatabase.makeEmpty()
        let syncRepository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: syncRepository, apiClient: mockAPIClient)

        let store = LibraryStore(repository: repository, syncQueue: syncQueue)

        // Load metadata
        await store.loadLibrary()
        #expect(store.library.count == 1)

        // Act: first fetch should hit repository and cache result
        let first: Checklist? = try await store.fetchFullContent(checklist.id)

        // Act: second fetch should be served from cache
        let second: Checklist? = try await store.fetchFullContent(checklist.id)

        // Assert: both fetches return the same content
        #expect(first?.id == checklist.id)
        #expect(second?.id == checklist.id)

        // Repository should have been called only once (first fetch)
        #expect(await repository.getFetchChecklistCallCount() == 1)
    }
    
    // MARK: - Forking Tests
    
    @Test("forkChecklist successfully decodes ISO8601 dates from API response")
    @MainActor
    func testForkChecklistWithISO8601Dates() async throws {
        // Arrange - Create a real database and repository
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: repository, apiClient: mockAPIClient)
        let store = LibraryStore(repository: repository, syncQueue: syncQueue)
        
        // Create SharedContentDetail with ISO8601 formatted dates
        // This simulates what comes from the backend API
        let sharedContent = SharedContentDetail(
            id: UUID(),
            title: "Test Checklist",
            description: "Test Description",
            contentType: "checklist",
            contentData: [
                "id": UUID().uuidString,
                "title": "Test Checklist",
                "description": "Test Description",
                "sections": [
                    [
                        "id": UUID().uuidString,
                        "title": "Section 1",
                        "icon": "checkmark",
                        "description": "Section description",
                        "items": [
                            [
                                "id": UUID().uuidString,
                                "title": "Item 1",
                                "itemDescription": "Item description",
                                "isOptional": false,
                                "isRequired": true,
                                "tags": ["tag1"],
                                "estimatedMinutes": 5,
                                "sortOrder": 0
                            ]
                        ],
                        "isExpandedByDefault": true,
                        "sortOrder": 0
                    ]
                ],
                "checklistType": "general",
                "tags": ["test"],
                "createdAt": "2024-01-15T10:30:00Z",  // ISO8601 format
                "updatedAt": "2024-01-15T11:30:00Z",  // ISO8601 format
                "syncStatus": "pending"
            ],
            tags: ["test"],
            publicID: "test-checklist-123",
            canFork: true,
            authorUsername: "testuser",
            viewCount: 10,
            forkCount: 2,
            createdAt: Date(),
            updatedAt: Date(),
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )
        
        // Act - Fork the checklist
        try await store.forkContent(from: sharedContent)
        
        // Assert - Verify checklist was forked successfully
        await store.loadLibrary()
        #expect(store.library.count == 1)
        #expect(store.myChecklists.count == 1)
        
        let metadata = store.myChecklists.first!
        #expect(metadata.title == "Test Checklist")
        #expect(metadata.description == "Test Description")
        #expect(metadata.tags == ["test"])
        #expect(metadata.originalAuthorUsername == "testuser")
        #expect(metadata.originalContentPublicID == "test-checklist-123")
        
        // Verify full checklist can be loaded
        let checklist: Checklist? = try await store.fetchFullContent(metadata.id)
        #expect(checklist != nil)
        #expect(checklist?.sections.count == 1)
        #expect(checklist?.sections.first?.items.count == 1)
    }
    
    @Test("forkPracticeGuide successfully decodes ISO8601 dates from API response")
    @MainActor
    func testForkPracticeGuideWithISO8601Dates() async throws {
        // Arrange
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: repository, apiClient: mockAPIClient)
        let store = LibraryStore(repository: repository, syncQueue: syncQueue)
        
        // Create SharedContentDetail with ISO8601 formatted dates
        let sharedContent = SharedContentDetail(
            id: UUID(),
            title: "Test Guide",
            description: "Test Guide Description",
            contentType: "practice_guide",
            contentData: [
                "id": UUID().uuidString,
                "title": "Test Guide",
                "description": "Test Guide Description",
                "markdown": "# Test Guide\n\nThis is a test guide.",
                "tags": ["guide", "test"],
                "createdAt": "2024-01-15T10:30:00Z",
                "updatedAt": "2024-01-15T11:30:00Z",
                "syncStatus": "pending"
            ],
            tags: ["guide", "test"],
            publicID: "test-guide-123",
            canFork: true,
            authorUsername: "guideauthor",
            viewCount: 5,
            forkCount: 1,
            createdAt: Date(),
            updatedAt: Date(),
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )
        
        // Act
        try await store.forkContent(from: sharedContent)
        
        // Assert
        await store.loadLibrary()
        #expect(store.library.count == 1)
        #expect(store.myGuides.count == 1)
        
        let metadata = store.myGuides.first!
        #expect(metadata.title == "Test Guide")
        #expect(metadata.description == "Test Guide Description")
        #expect(metadata.tags == ["guide", "test"])
        #expect(metadata.originalAuthorUsername == "guideauthor")
        #expect(metadata.originalContentPublicID == "test-guide-123")
        
        // Verify full guide can be loaded
        let guide: PracticeGuide? = try await store.fetchFullContent(metadata.id)
        #expect(guide != nil)
        #expect(guide?.markdown == "# Test Guide\n\nThis is a test guide.")
    }
    
    @Test("forkChecklist handles complex nested structures")
    @MainActor
    func testForkChecklistWithComplexStructure() async throws {
        // Arrange
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: repository, apiClient: mockAPIClient)
        let store = LibraryStore(repository: repository, syncQueue: syncQueue)
        
        // Create a complex checklist with multiple sections and items
        let sharedContent = SharedContentDetail(
            id: UUID(),
            title: "Complex Checklist",
            description: "A checklist with multiple sections",
            contentType: "checklist",
            contentData: [
                "id": UUID().uuidString,
                "title": "Complex Checklist",
                "description": "A checklist with multiple sections",
                "sections": [
                    [
                        "id": UUID().uuidString,
                        "title": "Section 1",
                        "icon": "checkmark",
                        "description": "First section",
                        "items": [
                            [
                                "id": UUID().uuidString,
                                "title": "Item 1.1",
                                "itemDescription": "First item",
                                "isOptional": false,
                                "isRequired": true,
                                "tags": ["important"],
                                "estimatedMinutes": 5,
                                "sortOrder": 0
                            ],
                            [
                                "id": UUID().uuidString,
                                "title": "Item 1.2",
                                "itemDescription": "Second item",
                                "isOptional": true,
                                "isRequired": false,
                                "tags": ["optional"],
                                "estimatedMinutes": 10,
                                "sortOrder": 1
                            ]
                        ],
                        "isExpandedByDefault": true,
                        "sortOrder": 0
                    ],
                    [
                        "id": UUID().uuidString,
                        "title": "Section 2",
                        "icon": "star",
                        "description": "Second section",
                        "items": [
                            [
                                "id": UUID().uuidString,
                                "title": "Item 2.1",
                                "itemDescription": nil,
                                "isOptional": false,
                                "isRequired": false,
                                "tags": [],
                                "estimatedMinutes": nil,
                                "sortOrder": 0
                            ]
                        ],
                        "isExpandedByDefault": false,
                        "sortOrder": 1
                    ]
                ],
                "checklistType": "safety",
                "tags": ["safety", "complex"],
                "createdAt": "2024-01-15T10:30:00Z",
                "updatedAt": "2024-01-15T11:30:00Z",
                "syncStatus": "pending"
            ],
            tags: ["safety", "complex"],
            publicID: "complex-checklist-456",
            canFork: true,
            authorUsername: "complexuser",
            viewCount: 20,
            forkCount: 5,
            createdAt: Date(),
            updatedAt: Date(),
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )
        
        // Act
        try await store.forkContent(from: sharedContent)
        
        // Assert
        await store.loadLibrary()
        #expect(store.library.count == 1)
        
        let metadata = store.myChecklists.first!
        let checklist: Checklist? = try await store.fetchFullContent(metadata.id)
        
        #expect(checklist != nil)
        #expect(checklist?.sections.count == 2)
        #expect(checklist?.sections[0].items.count == 2)
        #expect(checklist?.sections[1].items.count == 1)
        #expect(checklist?.checklistType == .safety)
        #expect(checklist?.totalItems == 3)
    }
    
    @Test("forkContent handles unknown content type gracefully")
    @MainActor
    func testForkContentWithUnknownType() async throws {
        // Arrange
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        let mockAPIClient = MockAPIClient()
        let syncQueue = SyncQueueService(repository: repository, apiClient: mockAPIClient)
        let store = LibraryStore(repository: repository, syncQueue: syncQueue)
        
        let sharedContent = SharedContentDetail(
            id: UUID(),
            title: "Unknown Content",
            description: "Content of unknown type",
            contentType: "unknown_type",
            contentData: [:],
            tags: [],
            publicID: "unknown-123",
            canFork: true,
            authorUsername: "unknownuser",
            viewCount: 0,
            forkCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            forkedFromID: nil,
            originalAuthorUsername: nil,
            originalContentPublicID: nil
        )
        
        // Act & Assert
        do {
            try await store.forkContent(from: sharedContent)
            #expect(Bool(false), "Should have thrown an error for unknown content type")
        } catch {
            // Expected error
            #expect(error is NSError)
        }
    }
}


