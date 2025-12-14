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
nonisolated struct LocalRepositoryIntegrationTests {
    
    var database: AppDatabase!
    var repository: LocalRepository!
    
    nonisolated init() async throws {
        database = try AppDatabase.makeEmpty()
        repository = LocalRepository(database: database)
    }
    
    @Test("Create and fetch charter - full flow")
    nonisolated func testCreateAndFetchCharter() async throws {
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
    
    @Test("Fetch charters by status - active")
    nonisolated func testFetchChartersByStatus_Active() async throws {
        // Arrange
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
    nonisolated func testFetchChartersByStatus_Upcoming() async throws {
        // Arrange
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
        #expect(upcoming.count >= 1)
        #expect(upcoming.contains { $0.id == upcomingCharter.id })
    }
    
    @Test("Fetch charters by status - past")
    nonisolated func testFetchChartersByStatus_Past() async throws {
        // Arrange
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
        #expect(past.count >= 1)
        #expect(past.contains { $0.id == pastCharter.id })
    }
    
    @Test("Mark charter as synced")
    nonisolated func testMarkCharterSynced() async throws {
        // Arrange
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
    nonisolated func testDeleteCharter() async throws {
        // Arrange
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
    nonisolated func testFetchAllCharters() async throws {
        // Arrange
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
        #expect(all.count >= 2)
        #expect(all.contains { $0.id == charter1.id })
        #expect(all.contains { $0.id == charter2.id })
    }
    
    @Test("Save charter - updates existing")
    nonisolated func testSaveCharter_UpdatesExisting() async throws {
        // Arrange
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
