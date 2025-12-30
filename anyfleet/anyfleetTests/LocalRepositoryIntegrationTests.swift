//
//  LocalRepositoryIntegrationTests.swift
//  anyfleetTests
//
//  Integration tests for LocalRepository using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("LocalRepository Integration Tests")
struct LocalRepositoryIntegrationTests {
    
    // Each test gets its own fresh in-memory database to avoid cross-test
    // contamination and ensure a clean state.
    private func makeRepository() throws -> LocalRepository {
        let database = try AppDatabase.makeEmpty()
        return LocalRepository(database: database)
    }
    
    @Test("Create and fetch charter - full flow")
    func testCreateAndFetchCharter() async throws {
        // Arrange
        let repository = try makeRepository()
        // Arrange
        let charter = CharterModel(
            id: UUID(),
            name: "Integration Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(charter)
        let fetched = try await repository.fetchCharter(id: charter.id)
        
        // Assert
        #expect(fetched != nil)
        #expect(fetched?.id == charter.id)
        #expect(fetched?.name == charter.name)
        #expect(fetched?.boatName == charter.boatName)
        #expect(fetched?.location == charter.location)
    }
    
    @Test("Fork attribution is preserved when saving edited checklist")
    @MainActor
    func testForkAttributionPreservedWhenSavingEditedChecklist() async throws {
        // Arrange
        let repository = try makeRepository()

        // Create a forked checklist with attribution
        let originalID = UUID()
        let checklistID = UUID()
        let checklist = Checklist(
            id: checklistID,
            title: "Forked Test Checklist",
            description: "Originally created by someone else",
            sections: [],
            checklistType: .general,
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )

        // Create metadata with fork attribution
        let metadata = LibraryModel(
            id: checklistID,
            title: checklist.title,
            description: checklist.description,
            type: .checklist,
            visibility: .private,
            creatorID: UUID(),
            forkedFromID: originalID,
            originalAuthorUsername: "OriginalAuthor",
            originalContentPublicID: "original-checklist-123",
            tags: checklist.tags,
            createdAt: checklist.createdAt,
            updatedAt: checklist.updatedAt,
            syncStatus: checklist.syncStatus
        )

        // Save initial checklist and metadata
        try await repository.saveChecklist(checklist)
        try await repository.updateLibraryMetadata(metadata)

        // Verify initial state
        let initialLibrary = try await repository.fetchUserLibrary()
        #expect(initialLibrary.count == 1)
        let initialItem = initialLibrary.first!
        #expect(initialItem.forkedFromID == originalID)
        #expect(initialItem.originalAuthorUsername == "OriginalAuthor")
        #expect(initialItem.originalContentPublicID == "original-checklist-123")

        // Act: Edit and save the checklist (simulating user editing)
        var editedChecklist = checklist
        editedChecklist.title = "Edited Forked Checklist"
        editedChecklist.description = "Modified by current user"
        editedChecklist.tags = ["edited", "forked"]
        editedChecklist.updatedAt = Date()

        try await repository.saveChecklist(editedChecklist)

        // Assert: Fork attribution should be preserved
        let updatedLibrary = try await repository.fetchUserLibrary()
        #expect(updatedLibrary.count == 1)
        let updatedItem = updatedLibrary.first!
        #expect(updatedItem.id == checklistID)
        #expect(updatedItem.title == "Edited Forked Checklist")
        #expect(updatedItem.description == "Modified by current user")
        #expect(updatedItem.tags == ["edited", "forked"])
        #expect(updatedItem.forkedFromID == originalID) // Should be preserved
        #expect(updatedItem.originalAuthorUsername == "OriginalAuthor") // Should be preserved
        #expect(updatedItem.originalContentPublicID == "original-checklist-123") // Should be preserved
    }

    @Test("Fork attribution is preserved when saving edited practice guide")
    @MainActor
    func testForkAttributionPreservedWhenSavingEditedGuide() async throws {
        // Arrange
        let repository = try makeRepository()

        // Create a forked guide with attribution
        let originalID = UUID()
        let guideID = UUID()
        let guide = PracticeGuide(
            id: guideID,
            title: "Forked Test Guide",
            description: "Originally created by someone else",
            markdown: "# Test Guide\n\nSome content.",
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )

        // Create metadata with fork attribution
        let metadata = LibraryModel(
            id: guideID,
            title: guide.title,
            description: guide.description,
            type: .practiceGuide,
            visibility: .private,
            creatorID: UUID(),
            forkedFromID: originalID,
            originalAuthorUsername: "GuideAuthor",
            originalContentPublicID: "original-guide-456",
            tags: guide.tags,
            createdAt: guide.createdAt,
            updatedAt: guide.updatedAt,
            syncStatus: guide.syncStatus
        )

        // Save initial guide and metadata
        try await repository.saveGuide(guide)
        try await repository.updateLibraryMetadata(metadata)

        // Verify initial state
        let initialLibrary = try await repository.fetchUserLibrary()
        #expect(initialLibrary.count == 1)
        let initialItem = initialLibrary.first!
        #expect(initialItem.forkedFromID == originalID)
        #expect(initialItem.originalAuthorUsername == "GuideAuthor")
        #expect(initialItem.originalContentPublicID == "original-guide-456")

        // Act: Edit and save the guide (simulating user editing)
        var editedGuide = guide
        editedGuide.title = "Edited Forked Guide"
        editedGuide.description = "Modified by current user"
        editedGuide.markdown = "# Edited Guide\n\nModified content."
        editedGuide.tags = ["edited", "guide"]
        editedGuide.updatedAt = Date()

        try await repository.saveGuide(editedGuide)

        // Assert: Fork attribution should be preserved
        let updatedLibrary = try await repository.fetchUserLibrary()
        #expect(updatedLibrary.count == 1)
        let updatedItem = updatedLibrary.first!
        #expect(updatedItem.id == guideID)
        #expect(updatedItem.title == "Edited Forked Guide")
        #expect(updatedItem.description == "Modified by current user")
        #expect(updatedItem.tags == ["edited", "guide"])
        #expect(updatedItem.forkedFromID == originalID) // Should be preserved
        #expect(updatedItem.originalAuthorUsername == "GuideAuthor") // Should be preserved
        #expect(updatedItem.originalContentPublicID == "original-guide-456") // Should be preserved
    }

    @Test("Fetch charters by status - active")
    func testFetchChartersByStatus_Active() async throws {
        // Arrange
        let repository = try makeRepository()
        let now = Date()
        let activeCharter = CharterModel(
            id: UUID(),
            name: "Active Charter",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        let upcomingCharter = CharterModel(
            id: UUID(),
            name: "Upcoming Charter",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: 17, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(activeCharter)
        try await repository.createCharter(upcomingCharter)
        
        let active = try await repository.fetchActiveCharters()
        
        // Assert
        #expect(active.count == 1)
        #expect(active.first?.id == activeCharter.id)
        #expect(active.first?.name == "Active Charter")
    }
    
    @Test("Fetch charters by status - upcoming")
    func testFetchChartersByStatus_Upcoming() async throws {
        // Arrange
        let repository = try makeRepository()
        let now = Date()
        let upcomingCharter = CharterModel(
            id: UUID(),
            name: "Upcoming Charter",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: 17, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(upcomingCharter)
        let upcoming = try await repository.fetchUpcomingCharters()
        
        // Assert
        #expect(upcoming.count == 1)
        #expect(upcoming.contains { $0.id == upcomingCharter.id })
    }
    
    @Test("Fetch charters by status - past")
    func testFetchChartersByStatus_Past() async throws {
        // Arrange
        let repository = try makeRepository()
        let now = Date()
        let pastCharter = CharterModel(
            id: UUID(),
            name: "Past Charter",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: -20, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(pastCharter)
        let past = try await repository.fetchPastCharters()
        
        // Assert
        #expect(past.count == 1)
        #expect(past.contains { $0.id == pastCharter.id })
    }
    
    @Test("Mark charter as synced")
    func testMarkCharterSynced() async throws {
        // Arrange
        let repository = try makeRepository()
        let charter = CharterModel(
            id: UUID(),
            name: "Sync Test Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(charter)
        try await repository.markChartersSynced([charter.id])
        
        // Verify by fetching and checking sync status in record
        // Note: This requires direct database access to check syncStatus
        // For now, we just verify the operation completes without error
        let fetched = try await repository.fetchCharter(id: charter.id)
        
        // Assert
        #expect(fetched != nil)
        #expect(fetched?.id == charter.id)
    }
    
    @Test("Delete charter")
    func testDeleteCharter() async throws {
        // Arrange
        let repository = try makeRepository()
        let charter = CharterModel(
            id: UUID(),
            name: "Delete Test Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(charter)
        try await repository.deleteCharter(charter.id)
        let fetched = try await repository.fetchCharter(id: charter.id)
        
        // Assert
        #expect(fetched == nil)
    }
    
    @Test("Fetch all charters - returns all")
    func testFetchAllCharters() async throws {
        // Arrange
        let repository = try makeRepository()
        let charter1 = CharterModel(
            id: UUID(),
            name: "Charter 1",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        let charter2 = CharterModel(
            id: UUID(),
            name: "Charter 2",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(charter1)
        try await repository.createCharter(charter2)
        let all = try await repository.fetchAllCharters()
        
        // Assert
        #expect(all.count == 2)
        #expect(all.contains { $0.id == charter1.id })
        #expect(all.contains { $0.id == charter2.id })
    }
    
    @Test("Save charter - updates existing")
    func testSaveCharter_UpdatesExisting() async throws {
        // Arrange
        let repository = try makeRepository()
        let original = CharterModel(
            id: UUID(),
            name: "Original Name",
            boatName: "Original Boat",
            location: "Original Location",
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        try await repository.createCharter(original)
        
        var updated = original
        updated.name = "Updated Name"
        updated.boatName = "Updated Boat"
        
        try await repository.saveCharter(updated)
        let fetched = try await repository.fetchCharter(id: original.id)
        
        // Assert
        #expect(fetched != nil)
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.boatName == "Updated Boat")
        #expect(fetched?.id == original.id) // ID should be preserved
    }
}
