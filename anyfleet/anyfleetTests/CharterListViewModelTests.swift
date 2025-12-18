//
//  CharterListViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for CharterListViewModel using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterListViewModel Tests")
struct CharterListViewModelTests {
    
    @Test("Initialize with empty store")
    @MainActor
    func testInitialization() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        // Act
        let viewModel = CharterListViewModel(charterStore: store)
        
        // Assert
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.isEmpty == true)
        #expect(viewModel.charters.isEmpty == true)
    }
    
    @Test("Load charters - success")
    @MainActor
    func testLoadCharters_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let testCharters = [
            CharterModel(
                id: UUID(),
                name: "Charter 1",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Charter 2",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(testCharters)
        
        // Act
        await viewModel.loadCharters()
        
        // Assert
        #expect(mockRepository.fetchAllChartersCallCount == 1)
        #expect(viewModel.charters.count == 2)
        #expect(viewModel.isEmpty == false)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Load charters - handles errors gracefully")
    @MainActor
    func testLoadCharters_HandlesErrors() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.fetchAllChartersResult = .failure(testError)
        
        // Act
        await viewModel.loadCharters()
        
        // Assert
        #expect(mockRepository.fetchAllChartersCallCount == 1)
        #expect(viewModel.charters.isEmpty)
        #expect(viewModel.isEmpty == true)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Load charters - prevents duplicate loads")
    @MainActor
    func testLoadCharters_PreventsDuplicates() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        mockRepository.fetchAllChartersResult = .success([])
        
        // Simulate load in progress
        viewModel.isLoading = true
        
        // Act
        await viewModel.loadCharters()
        
        // Assert
        // Should not call repository since load is already in progress
        #expect(mockRepository.fetchAllChartersCallCount == 0)
    }
    
    @Test("Refresh - reloads charters")
    @MainActor
    func testRefresh() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        mockRepository.fetchAllChartersResult = .success([])
        
        // Act
        await viewModel.refresh()
        
        // Assert
        #expect(mockRepository.fetchAllChartersCallCount == 1)
    }
    
    @Test("Sorted by date - returns charters in correct order")
    @MainActor
    func testSortedByDate() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let testCharters = [
            CharterModel(
                id: UUID(),
                name: "Charter Yesterday",
                boatName: nil,
                location: nil,
                startDate: yesterday,
                endDate: yesterday.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Charter Tomorrow",
                boatName: nil,
                location: nil,
                startDate: tomorrow,
                endDate: tomorrow.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Charter Today",
                boatName: nil,
                location: nil,
                startDate: now,
                endDate: now.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(testCharters)
        await viewModel.loadCharters()
        
        // Act
        let sorted = viewModel.sortedByDate
        
        // Assert
        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Charter Tomorrow")
        #expect(sorted[1].name == "Charter Today")
        #expect(sorted[2].name == "Charter Yesterday")
    }
    
    @Test("Upcoming charters - filters correctly")
    @MainActor
    func testUpcomingCharters() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let testCharters = [
            CharterModel(
                id: UUID(),
                name: "Past Charter",
                boatName: nil,
                location: nil,
                startDate: yesterday,
                endDate: yesterday.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Future Charter",
                boatName: nil,
                location: nil,
                startDate: tomorrow,
                endDate: tomorrow.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(testCharters)
        await viewModel.loadCharters()
        
        // Act
        let upcoming = viewModel.upcomingCharters
        
        // Assert
        #expect(upcoming.count == 1)
        #expect(upcoming[0].name == "Future Charter")
    }
    
    @Test("Past charters - filters correctly")
    @MainActor
    func testPastCharters() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)
        
        let testCharters = [
            CharterModel(
                id: UUID(),
                name: "Past Charter",
                boatName: nil,
                location: nil,
                startDate: yesterday,
                endDate: yesterday.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            ),
            CharterModel(
                id: UUID(),
                name: "Future Charter",
                boatName: nil,
                location: nil,
                startDate: tomorrow,
                endDate: tomorrow.addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(testCharters)
        await viewModel.loadCharters()
        
        // Act
        let past = viewModel.pastCharters
        
        // Assert
        #expect(past.count == 1)
        #expect(past[0].name == "Past Charter")
    }
    
    @Test("IsEmpty - returns true for empty list")
    @MainActor
    func testIsEmpty_EmptyList() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        mockRepository.fetchAllChartersResult = .success([])
        await viewModel.loadCharters()
        
        // Act & Assert
        #expect(viewModel.isEmpty == true)
    }
    
    @Test("IsEmpty - returns false for non-empty list")
    @MainActor
    func testIsEmpty_NonEmptyList() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let testCharters = [
            CharterModel(
                id: UUID(),
                name: "Charter 1",
                boatName: nil,
                location: nil,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                createdAt: Date(),
                checkInChecklistID: nil
            )
        ]
        
        mockRepository.fetchAllChartersResult = .success(testCharters)
        await viewModel.loadCharters()
        
        // Act & Assert
        #expect(viewModel.isEmpty == false)
    }
    
    @Test("Delete charter - success")
    @MainActor
    func testDeleteCharter_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let charter1 = CharterModel(
            id: UUID(),
            name: "Charter 1",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        let charter2 = CharterModel(
            id: UUID(),
            name: "Charter 2",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.fetchAllChartersResult = .success([charter1, charter2])
        await viewModel.loadCharters()
        
        #expect(viewModel.charters.count == 2)
        
        mockRepository.deleteCharterResult = .success(())
        
        // Act
        try await viewModel.deleteCharter(charter1.id)
        
        // Assert
        #expect(viewModel.charters.count == 1)
        #expect(viewModel.charters.first?.id == charter2.id)
        #expect(mockRepository.deleteCharterCallCount == 1)
    }
    
    @Test("Delete charter - failure propagates error")
    @MainActor
    func testDeleteCharter_Failure() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let charter = CharterModel(
            id: UUID(),
            name: "Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.fetchAllChartersResult = .success([charter])
        await viewModel.loadCharters()
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.deleteCharterResult = .failure(testError)
        
        // Act & Assert
        await #expect(throws: testError) {
            try await viewModel.deleteCharter(charter.id)
        }
        
        // Charter should still be in list since delete failed
        #expect(viewModel.charters.count == 1)
    }
    
    @Test("Delete charter - updates empty state")
    @MainActor
    func testDeleteCharter_UpdatesEmptyState() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterListViewModel(charterStore: store)
        
        let charter = CharterModel(
            id: UUID(),
            name: "Only Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.fetchAllChartersResult = .success([charter])
        await viewModel.loadCharters()
        
        #expect(viewModel.isEmpty == false)
        
        mockRepository.deleteCharterResult = .success(())
        
        // Act
        try await viewModel.deleteCharter(charter.id)
        
        // Assert - Should now be empty
        #expect(viewModel.isEmpty == true)
        #expect(viewModel.charters.isEmpty)
    }
}

