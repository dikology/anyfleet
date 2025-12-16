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
    
    @Test("Initialize with coordinator")
    @MainActor
    func testInitialization() async throws {
        // Arrange
        let coordinator = AppCoordinator()
        
        // Act
        let viewModel = HomeViewModel(coordinator: coordinator)
        
        // Assert
        // ViewModel is successfully created (test passes if no exception thrown)
        // We can verify the coordinator is properly stored by testing behavior
        #expect(coordinator.chartersPath.isEmpty)
        #expect(coordinator.selectedTab == .home)
    }
    
    @Test("Create charter tapped - switches to charters tab")
    @MainActor
    func testOnCreateCharterTapped_SwitchesTabs() async throws {
        // Arrange
        let coordinator = AppCoordinator()
        coordinator.selectedTab = .home
        let viewModel = HomeViewModel(coordinator: coordinator)
        
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
        let coordinator = AppCoordinator()
        coordinator.selectedTab = .home
        coordinator.push(.charterDetail(UUID()), to: .charters) // Add existing route
        let viewModel = HomeViewModel(coordinator: coordinator)
        
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
        let coordinator = AppCoordinator()
        coordinator.selectedTab = .charters
        let viewModel = HomeViewModel(coordinator: coordinator)
        
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
        let coordinator = AppCoordinator()
        coordinator.selectedTab = .home
        let viewModel = HomeViewModel(coordinator: coordinator)
        
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
        let coordinator = AppCoordinator()
        let viewModel = HomeViewModel(coordinator: coordinator)
        
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
}

