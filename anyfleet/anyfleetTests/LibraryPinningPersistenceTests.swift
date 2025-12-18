//
//  LibraryPinningPersistenceTests.swift
//  anyfleetTests
//
//  Integration tests for pinning persistence of library metadata
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Library Pinning Persistence Tests")
struct LibraryPinningPersistenceTests {
    
    // Each test gets its own fresh in-memory database
    private func makeRepository() throws -> LocalRepository {
        let database = try AppDatabase.makeEmpty()
        return LocalRepository(database: database)
    }
    
    private func makeTestChecklist(title: String = "Pinned Test Checklist") -> Checklist {
        Checklist(
            id: UUID(),
            title: title,
            description: "Pinned persistence test",
            sections: [],
            checklistType: .general,
            tags: [],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
    }
    
    @Test("Pin state is persisted across LibraryStore instances and reloads")
    @MainActor
    func testPinnedStatePersistsAcrossReloads() async throws {
        // Arrange
        let repository = try makeRepository()
        let store1 = LibraryStore(repository: repository)
        let checklist = makeTestChecklist()
        
        // Create checklist -> creates library metadata row
        try await repository.createChecklist(checklist)
        
        // Load library into first store
        await store1.loadLibrary()
        #expect(store1.library.count == 1)
        guard var item = store1.library.first else {
            Issue.record("Expected one library item")
            return
        }
        
        // Act: pin item
        await store1.togglePin(for: item)
        
        // Assert: in-memory store sees it pinned
        item = store1.library.first!
        #expect(item.isPinned == true)
        #expect(item.pinnedOrder != nil)
        
        // Create a new store wired to same repository
        let store2 = LibraryStore(repository: repository)
        await store2.loadLibrary()
        
        // Assert: pin state persisted through DB
        #expect(store2.library.count == 1)
        let reloaded = store2.library.first!
        #expect(reloaded.isPinned == true)
        #expect(reloaded.pinnedOrder != nil)
    }
    
    @Test("Pinned order increments and is preserved after reload")
    @MainActor
    func testPinnedOrderPersistsAndIncrements() async throws {
        // Arrange
        let repository = try makeRepository()
        let store = LibraryStore(repository: repository)
        
        let checklist1 = makeTestChecklist(title: "First")
        let checklist2 = makeTestChecklist(title: "Second")
        
        try await repository.createChecklist(checklist1)
        try await repository.createChecklist(checklist2)
        
        await store.loadLibrary()
        #expect(store.library.count == 2)
        
        // Act: pin both items in order
        guard let first = store.library.first,
              let second = store.library.last else {
            Issue.record("Expected two library items")
            return
        }
        
        await store.togglePin(for: first)
        await store.togglePin(for: second)
        
        // Capture orders before reload
        let beforeOrders = store.library
            .filter { $0.isPinned }
            .sorted { ($0.pinnedOrder ?? 0) < ($1.pinnedOrder ?? 0) }
            .map { $0.pinnedOrder }
        
        #expect(beforeOrders.count == 2)
        #expect(beforeOrders[0]! < beforeOrders[1]!)
        
        // Reload via new store
        let storeReloaded = LibraryStore(repository: repository)
        await storeReloaded.loadLibrary()
        
        let reloadedPinned = storeReloaded.library
            .filter { $0.isPinned }
            .sorted { ($0.pinnedOrder ?? 0) < ($1.pinnedOrder ?? 0) }
        
        #expect(reloadedPinned.count == 2)
        #expect(reloadedPinned[0].pinnedOrder == beforeOrders[0])
        #expect(reloadedPinned[1].pinnedOrder == beforeOrders[1])
    }
    
    @Test("Unpin clears isPinned and pinnedOrder and persists")
    @MainActor
    func testUnpinPersists() async throws {
        // Arrange
        let repository = try makeRepository()
        let store = LibraryStore(repository: repository)
        let checklist = makeTestChecklist()
        
        try await repository.createChecklist(checklist)
        await store.loadLibrary()
        guard let item = store.library.first else {
            Issue.record("Expected one library item")
            return
        }
        
        // Pin then unpin
        await store.togglePin(for: item)
        guard let pinnedOnce = store.library.first else {
            Issue.record("Expected pinned item")
            return
        }
        #expect(pinnedOnce.isPinned == true)
        
        await store.togglePin(for: pinnedOnce)
        
        // Assert in-memory state
        guard let unpinned = store.library.first else {
            Issue.record("Expected unpinned item")
            return
        }
        #expect(unpinned.isPinned == false)
        #expect(unpinned.pinnedOrder == nil)
        
        // Reload via new store
        let storeReloaded = LibraryStore(repository: repository)
        await storeReloaded.loadLibrary()
        
        guard let reloaded = storeReloaded.library.first else {
            Issue.record("Expected reloaded item")
            return
        }
        #expect(reloaded.isPinned == false)
        #expect(reloaded.pinnedOrder == nil)
    }
}


