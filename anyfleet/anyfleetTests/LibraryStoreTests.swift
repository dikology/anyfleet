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
        private var checklistsResult: [Checklist] = []
        
        // Call counts
        private var fetchUserLibraryCallCount = 0
        private var fetchUserChecklistsCallCount = 0
        private var fetchChecklistCallCount = 0
        private var saveChecklistCallCount = 0
        
        // For fetchChecklist
        private var fetchChecklistResult: Checklist?
        
        // MARK: - Configuration Helpers
        
        func setLibraryResult(_ value: [LibraryModel]) {
            libraryResult = value
        }
        
        func setChecklistsResult(_ value: [Checklist]) {
            checklistsResult = value
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
            fetchUserChecklistsCallCount += 1
            return checklistsResult
        }
        
        func fetchUserGuides() async throws -> [PracticeGuide] {
            return []
        }
        
        func fetchUserDecks() async throws -> [FlashcardDeck] {
            return []
        }
        
        func fetchChecklist(_ checklistID: UUID) async throws -> Checklist? {
            fetchChecklistCallCount += 1
            return fetchChecklistResult
        }
        
        func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide? {
            return nil
        }
        
        func fetchDeck(_ deckID: UUID) async throws -> FlashcardDeck? {
            return nil
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
    
    @Test("saveChecklist updates in-memory collections and metadata without full reload")
    @MainActor
    func testSaveChecklistUpdatesInMemoryAndMetadata() async throws {
        // Arrange
        let baseChecklist = makeChecklist()
        let baseMetadata = makeLibraryModel(from: baseChecklist)
        
        let repository = MockLibraryRepository()
        await repository.setLibraryResult([baseMetadata])
        await repository.setChecklistsResult([baseChecklist])
        
        let store = LibraryStore(repository: repository)
        
        // Initial load to populate library + checklists
        await store.loadLibrary()
        #expect(store.library.count == 1)
        #expect(store.checklists.count == 1)
        
        // Prepare updated checklist
        var updatedChecklist = baseChecklist
        updatedChecklist.title = "Updated Title"
        updatedChecklist.description = "Updated Description"
        updatedChecklist.tags = ["tag2"]
        updatedChecklist.updatedAt = Date().addingTimeInterval(60)
        updatedChecklist.syncStatus = .synced
        
        // Act
        try await store.saveChecklist(updatedChecklist)
        
        // Assert: full models updated
        #expect(store.checklists.count == 1)
        #expect(store.checklists.first?.title == "Updated Title")
        #expect(store.checklists.first?.description == "Updated Description")
        #expect(store.checklists.first?.tags == ["tag2"])
        
        // Assert: metadata updated in place (no extra rows)
        #expect(store.library.count == 1)
        let metadata = store.library.first!
        #expect(metadata.title == "Updated Title")
        #expect(metadata.description == "Updated Description")
        #expect(metadata.tags == ["tag2"])
        #expect(metadata.syncStatus == .synced)
        
        // Assert: repository.saveChecklist called once
        #expect(await repository.getSaveChecklistCallCount() == 1)
        
        // Assert: fetchUserLibrary not called again after initial load (i.e. no full reload)
        #expect(await repository.getFetchUserLibraryCallCount() == 1)
    }
    
    @Test("fetchChecklist caches repository result and avoids repeated fetches")
    @MainActor
    func testFetchChecklistUsesCache() async throws {
        // Arrange
        let checklist = makeChecklist()
        let repository = MockLibraryRepository()
        await repository.setFetchChecklistResult(checklist)
        
        let store = LibraryStore(repository: repository)
        
        // Act: first fetch should hit repository
        let first = try await store.fetchChecklist(checklist.id)
        
        // Act: second fetch should be served from cache
        let second = try await store.fetchChecklist(checklist.id)
        
        // Assert: values are equal
        #expect(first?.id == checklist.id)
        #expect(second?.id == checklist.id)
        
        // Repository should have been called only once
        #expect(await repository.getFetchChecklistCallCount() == 1)
    }
    
    @Test("fetchChecklist uses in-memory collection before repository")
    @MainActor
    func testFetchChecklistUsesInMemoryBeforeRepository() async throws {
        // Arrange
        let checklist = makeChecklist()
        let metadata = makeLibraryModel(from: checklist)
        
        let repository = MockLibraryRepository()
        await repository.setLibraryResult([metadata])
        await repository.setChecklistsResult([checklist])
        await repository.setFetchChecklistResult(nil)
        
        let store = LibraryStore(repository: repository)
        
        // Populate in-memory collections via loadLibrary
        await store.loadLibrary()
        #expect(store.checklists.count == 1)
        
        // Act
        let fetched = try await store.fetchChecklist(checklist.id)
        
        // Assert: fetched from in-memory, not repository
        #expect(fetched?.id == checklist.id)
        #expect(await repository.getFetchChecklistCallCount() == 0)
    }
}


