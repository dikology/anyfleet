//
//  CharterStoreTests.swift
//  anyfleetTests
//
//  Unit tests for CharterStore using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterStore Tests")
struct CharterStoreTests {
    
    @Test("Create charter - success")
    @MainActor
    func testCreateCharter_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let expectedCharter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.createCharterResult = .success(())
        
        // Act
        let result = try await store.createCharter(
            name: expectedCharter.name,
            boatName: expectedCharter.boatName,
            location: expectedCharter.location,
            startDate: expectedCharter.startDate,
            endDate: expectedCharter.endDate
        )
        
        // Assert
        #expect(result.name == expectedCharter.name)
        #expect(result.boatName == expectedCharter.boatName)
        #expect(result.location == expectedCharter.location)
        #expect(store.charters.count == 1)
        #expect(store.charters.first?.id == result.id)
        #expect(mockRepository.createCharterCallCount == 1)
        #expect(mockRepository.lastCreatedCharter?.name == expectedCharter.name)
    }
    
    @Test("Create charter - failure propagates error")
    @MainActor
    func testCreateCharter_Failure() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.createCharterResult = .failure(testError)
        
        // Act & Assert
        await #expect(throws: testError) {
            try await store.createCharter(
                name: "Test",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date()
            )
        }
        
        #expect(store.charters.isEmpty)
        #expect(mockRepository.createCharterCallCount == 1)
    }
    
    @Test("Load charters - success")
    @MainActor
    func testLoadCharters_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let charters = [
            CharterModel(
                id: UUID(),
                name: "Charter 1",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date(),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Charter 2",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date(),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(charters)
        
        // Act
        try await store.loadCharters()
        
        // Assert
        #expect(store.charters.count == 2)
        #expect(store.charters[0].name == "Charter 1")
        #expect(store.charters[1].name == "Charter 2")
        #expect(mockRepository.fetchAllChartersCallCount == 1)
    }
    
    @Test("Load charters - propagates errors")
    @MainActor
    func testLoadCharters_PropagatesErrors() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.fetchAllChartersResult = .failure(testError)
        
        // Act & Assert - should throw error
        await #expect(throws: testError) {
            try await store.loadCharters()
        }
        
        // Assert
        #expect(store.charters.isEmpty)
    }
    
    @Test("Create charter - adds to charters list")
    @MainActor
    func testCreateCharter_AddsToList() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        // Act
        let charter1 = try await store.createCharter(
            name: "First",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let charter2 = try await store.createCharter(
            name: "Second",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        // Assert
        #expect(store.charters.count == 2)
        #expect(store.charters.contains { $0.id == charter1.id })
        #expect(store.charters.contains { $0.id == charter2.id })
    }
    
    @Test("Create charter - with optional parameters")
    @MainActor
    func testCreateCharter_WithOptionalParameters() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let checklistID = UUID()
        
        // Act
        let result = try await store.createCharter(
            name: "Test",
            boatName: "Boat",
            location: "Location",
            startDate: Date(),
            endDate: Date(),
            checkInChecklistID: checklistID
        )
        
        // Assert
        #expect(result.name == "Test")
        #expect(result.boatName == "Boat")
        #expect(result.location == "Location")
        #expect(result.checkInChecklistID == checklistID)
    }
    
    @Test("Delete charter - success")
    @MainActor
    func testDeleteCharter_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        // Create charters first
        let charter1 = try await store.createCharter(
            name: "Charter 1",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let charter2 = try await store.createCharter(
            name: "Charter 2",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        #expect(store.charters.count == 2)
        
        mockRepository.deleteCharterResult = .success(())
        
        // Act
        try await store.deleteCharter(charter1.id)
        
        // Assert
        #expect(store.charters.count == 1)
        #expect(store.charters.first?.id == charter2.id)
        #expect(mockRepository.deleteCharterCallCount == 1)
        #expect(!store.charters.contains { $0.id == charter1.id })
    }
    
    @Test("Delete charter - failure propagates error")
    @MainActor
    func testDeleteCharter_Failure() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let charter = try await store.createCharter(
            name: "Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.deleteCharterResult = .failure(testError)
        
        // Act & Assert
        await #expect(throws: testError) {
            try await store.deleteCharter(charter.id)
        }
        
        // Charter should still be in the list since delete failed
        #expect(store.charters.count == 1)
        #expect(mockRepository.deleteCharterCallCount == 1)
    }
    
    @Test("Delete charter - removes only specified charter")
    @MainActor
    func testDeleteCharter_RemovesOnlySpecified() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let charter1 = try await store.createCharter(
            name: "Charter 1",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let charter2 = try await store.createCharter(
            name: "Charter 2",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let charter3 = try await store.createCharter(
            name: "Charter 3",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        #expect(store.charters.count == 3)
        
        // Act - Delete middle charter
        try await store.deleteCharter(charter2.id)
        
        // Assert
        #expect(store.charters.count == 2)
        #expect(store.charters.contains { $0.id == charter1.id })
        #expect(!store.charters.contains { $0.id == charter2.id })
        #expect(store.charters.contains { $0.id == charter3.id })
    }
    
    @Test("Delete charter - deleting non-existent charter")
    @MainActor
    func testDeleteCharter_NonExistent() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let charter = try await store.createCharter(
            name: "Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        let nonExistentID = UUID()
        
        // Act - Delete non-existent charter
        try await store.deleteCharter(nonExistentID)
        
        // Assert - Original charter should still be there
        #expect(store.charters.count == 1)
        #expect(store.charters.first?.id == charter.id)
    }
}
