//
//  HomeViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for HomeViewModel using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("HomeViewModel Tests")
struct HomeViewModelTests {
    
    @Test("Initialize with coordinator and charter store")
    @MainActor
    func testInitialization() throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        
        // Act
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Assert
        #expect(coordinator.chartersPath.isEmpty)
        #expect(coordinator.selectedTab == .home)
        #expect(viewModel.activeCharter == nil)
    }
    
    @Test("Create charter tapped - switches to charters tab")
    @MainActor
    func testOnCreateCharterTapped_SwitchesTabs() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        coordinator.selectedTab = .home
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Verify initial state
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act
        viewModel.onCreateCharterTapped()
        
        // Assert - Should switch to charters tab (cross-tab navigation)
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("Create charter tapped - clears existing charter path")
    @MainActor
    func testOnCreateCharterTapped_ClearsExistingPath() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        coordinator.selectedTab = .home
        coordinator.push(.charterDetail(UUID()), to: .charters) // Add existing route
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Verify initial state has existing route
        #expect(coordinator.chartersPath.count == 1)
        
        // Act
        viewModel.onCreateCharterTapped()
        
        // Assert - Should clear path and add only create charter
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("Create charter tapped - from charters tab")
    @MainActor
    func testOnCreateCharterTapped_FromChartersTab() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        coordinator.selectedTab = .charters
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Act
        viewModel.onCreateCharterTapped()
        
        // Assert - Should stay on charters tab but clear and add route
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("Create charter tapped multiple times - replaces route each time")
    @MainActor
    func testOnCreateCharterTappedMultipleTimes() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        coordinator.selectedTab = .home
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Act
        viewModel.onCreateCharterTapped()
        viewModel.onCreateCharterTapped()
        
        // Assert - Should still have only 1 route (cross-tab navigation clears path)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("Integration - realistic user flow from home")
    @MainActor
    func testRealisticUserFlow() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        
        // Start on home tab
        #expect(coordinator.selectedTab == .home)
        
        // Act 1: User taps create charter card
        viewModel.onCreateCharterTapped()
        
        // Assert: Should immediately see charter creation view (on charters tab)
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.first == .createCharter)
        
        // Act 2: User cancels and goes back
        coordinator.pop(from: .charters)
        
        // Assert: Should be at charters list
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act 3: User switches back to home
        coordinator.selectedTab = .home
        
        // Act 4: User taps create charter again
        viewModel.onCreateCharterTapped()
        
        // Assert: Should again switch to charters and show create view
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.first == .createCharter)
    }

    // MARK: - Active Charter Selection
    
    @Test("refresh() selects charter active today based on date range")
    @MainActor
    func testRefreshSelectsActiveCharterForToday() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let store = dependencies.charterStore
        let repository = dependencies.repository
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Charter that started yesterday and ends tomorrow (should be active)
        let activeCharter = CharterModel(
            id: UUID(),
            name: "Active Charter",
            boatName: nil,
            location: nil,
            startDate: today.addingTimeInterval(-86400),
            endDate: today.addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Charter that starts tomorrow (should NOT be active yet)
        let futureCharter = CharterModel(
            id: UUID(),
            name: "Future Charter",
            boatName: nil,
            location: nil,
            startDate: today.addingTimeInterval(86400),
            endDate: today.addingTimeInterval(86400 * 2),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Persist both charters via repository, then load into store
        try await repository.createCharter(activeCharter)
        try await repository.createCharter(futureCharter)
        try await store.loadCharters()
        
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: store,
            libraryStore: dependencies.libraryStore
        )
        
        // Act
        await viewModel.refresh()
        
        // Assert
        #expect(viewModel.activeCharter?.id == activeCharter.id)
    }
    
    @Test("refresh() picks latest starting active charter when multiple overlap")
    @MainActor
    func testRefreshSelectsLatestOverlappingActiveCharter() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let store = dependencies.charterStore
        let repository = dependencies.repository
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Older active charter
        let olderCharter = CharterModel(
            id: UUID(),
            name: "Older Charter",
            boatName: nil,
            location: nil,
            startDate: today.addingTimeInterval(-86400 * 5),
            endDate: today.addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Newer active charter that also includes today
        let newerCharter = CharterModel(
            id: UUID(),
            name: "Newer Charter",
            boatName: nil,
            location: nil,
            startDate: today.addingTimeInterval(-86400 * 1),
            endDate: today.addingTimeInterval(86400 * 3),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Persist both charters via repository, then load into store
        try await repository.createCharter(olderCharter)
        try await repository.createCharter(newerCharter)
        try await store.loadCharters()
        
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: store,
            libraryStore: dependencies.libraryStore
        )
        
        // Act
        await viewModel.refresh()
        
        // Assert - picks the one with the latest startDate
        #expect(viewModel.activeCharter?.id == newerCharter.id)
    }
    
    @Test("refresh() loads charters from database if store is empty")
    @MainActor
    func testRefreshLoadsChartersIfEmpty() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let store = dependencies.charterStore
        let repository = dependencies.repository
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Create a charter directly in the database (bypassing store to simulate
        // the scenario where HomeView appears before Charters tab loads)
        let activeCharter = CharterModel(
            id: UUID(),
            name: "Active Charter",
            boatName: nil,
            location: nil,
            startDate: today.addingTimeInterval(-86400),
            endDate: today.addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        try await repository.createCharter(activeCharter)
        
        // Verify store is empty initially (hasn't loaded yet)
        #expect(store.charters.isEmpty)
        
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: store,
            libraryStore: dependencies.libraryStore
        )
        
        #expect(viewModel.activeCharter == nil)
        
        // Act - refresh should load charters from database and find the active one
        await viewModel.refresh()
        
        // Assert - charters should be loaded and active charter found
        #expect(!store.charters.isEmpty)
        #expect(store.charters.contains { $0.id == activeCharter.id })
        #expect(viewModel.activeCharter?.id == activeCharter.id)
    }
}

