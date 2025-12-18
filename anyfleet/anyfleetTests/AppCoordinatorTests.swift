//
//  AppCoordinatorTests.swift
//  anyfleetTests
//
//  Unit tests for AppCoordinator navigation using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("AppCoordinator Tests")
struct AppCoordinatorTests {
    
    // MARK: - Test Helpers
    
    @MainActor
    private func makeTestCoordinator() -> AppCoordinator {
        let dependencies = AppDependencies()
        return AppCoordinator(dependencies: dependencies)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default state")
    @MainActor
    func testInitialization() async throws {
        // Arrange & Act
        let coordinator = makeTestCoordinator()
        
        // Assert
        #expect(coordinator.homePath.isEmpty)
        #expect(coordinator.chartersPath.isEmpty)
        #expect(coordinator.selectedTab == .home)
    }
    
    // MARK: - Tab-Specific Navigation Tests
    
    @Test("Push route to home path")
    @MainActor
    func testPushToHomePath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        
        // Act
        coordinator.push(.createCharter, to: .home)
        
        // Assert
        #expect(coordinator.homePath.count == 1)
        #expect(coordinator.homePath.first == .createCharter)
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Push route to charters path")
    @MainActor
    func testPushToChartersPath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        
        // Act
        coordinator.push(.createCharter, to: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
        #expect(coordinator.homePath.isEmpty)
    }
    
    @Test("Push multiple routes to same path")
    @MainActor
    func testPushMultipleRoutes() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charterId = UUID()
        
        // Act
        coordinator.push(.createCharter, to: .charters)
        coordinator.push(.charterDetail(charterId), to: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.count == 2)
        #expect(coordinator.chartersPath[0] == .createCharter)
        #expect(coordinator.chartersPath[1] == .charterDetail(charterId))
    }
    
    // MARK: - Pop Navigation Tests
    
    @Test("Pop from home path")
    @MainActor
    func testPopFromHomePath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.push(.createCharter, to: .home)
        
        // Act
        coordinator.pop(from: .home)
        
        // Assert
        #expect(coordinator.homePath.isEmpty)
    }
    
    @Test("Pop from charters path")
    @MainActor
    func testPopFromChartersPath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.push(.createCharter, to: .charters)
        
        // Act
        coordinator.pop(from: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Pop from empty path does nothing")
    @MainActor
    func testPopFromEmptyPath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        
        // Act
        coordinator.pop(from: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Pop removes only last item")
    @MainActor
    func testPopRemovesOnlyLastItem() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charterId = UUID()
        coordinator.push(.createCharter, to: .charters)
        coordinator.push(.charterDetail(charterId), to: .charters)
        
        // Act
        coordinator.pop(from: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    // MARK: - Pop to Root Tests
    
    @Test("Pop to root from home path")
    @MainActor
    func testPopToRootFromHomePath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.push(.createCharter, to: .home)
        coordinator.push(.charterDetail(UUID()), to: .home)
        
        // Act
        coordinator.popToRoot(from: .home)
        
        // Assert
        #expect(coordinator.homePath.isEmpty)
    }
    
    @Test("Pop to root from charters path")
    @MainActor
    func testPopToRootFromChartersPath() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.push(.createCharter, to: .charters)
        coordinator.push(.charterDetail(UUID()), to: .charters)
        coordinator.push(.charterDetail(UUID()), to: .charters)
        
        // Act
        coordinator.popToRoot(from: .charters)
        
        // Assert
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    // MARK: - Charter-Specific Navigation Tests
    
    @Test("Create charter convenience method")
    @MainActor
    func testCreateCharter() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        
        // Act
        coordinator.createCharter()
        
        // Assert
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("View charter convenience method")
    @MainActor
    func testViewCharter() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charterId = UUID()
        
        // Act
        coordinator.viewCharter(charterId)
        
        // Assert
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charterId))
    }
    
    // MARK: - Cross-Tab Navigation Tests
    
    @Test("Navigate to create charter - switches tabs and clears path")
    @MainActor
    func testNavigateToCreateCharter() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.selectedTab = .home
        coordinator.push(.charterDetail(UUID()), to: .charters) // Add existing route
        
        // Act
        coordinator.navigateToCreateCharter()
        
        // Assert
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
    }
    
    @Test("Navigate to create charter - from home tab")
    @MainActor
    func testNavigateToCreateCharterFromHome() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        coordinator.selectedTab = .home
        
        // Act
        coordinator.navigateToCreateCharter()
        
        // Assert - Should switch to charters tab
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
        #expect(coordinator.homePath.isEmpty)
    }
    
    @Test("Navigate to charter detail - switches tabs and clears path")
    @MainActor
    func testNavigateToCharter() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charterId = UUID()
        coordinator.selectedTab = .home
        coordinator.push(.createCharter, to: .charters) // Add existing route
        
        // Act
        coordinator.navigateToCharter(charterId)
        
        // Assert
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charterId))
    }
    
    @Test("Navigate to charter - from home tab")
    @MainActor
    func testNavigateToCharterFromHome() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charterId = UUID()
        coordinator.selectedTab = .home
        
        // Act
        coordinator.navigateToCharter(charterId)
        
        // Assert - Should switch to charters tab
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charterId))
        #expect(coordinator.homePath.isEmpty)
    }
    
    // MARK: - Tab Selection Tests
    
    @Test("Selected tab can be changed")
    @MainActor
    func testSelectedTabChange() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        #expect(coordinator.selectedTab == .home)
        
        // Act
        coordinator.selectedTab = .charters
        
        // Assert
        #expect(coordinator.selectedTab == .charters)
    }
    
    // MARK: - Integration Tests
    
    @Test("Complex navigation flow")
    @MainActor
    func testComplexNavigationFlow() async throws {
        // Arrange
        let coordinator = makeTestCoordinator()
        let charter1Id = UUID()
        let charter2Id = UUID()
        
        // Act & Assert - Simulate user flow
        
        // 1. User starts on home tab
        #expect(coordinator.selectedTab == .home)
        
        // 2. User taps create charter from home (cross-tab navigation)
        coordinator.navigateToCreateCharter()
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .createCharter)
        
        // 3. User cancels/saves, goes back to charters list
        coordinator.pop(from: .charters)
        #expect(coordinator.chartersPath.isEmpty)
        
        // 4. User views a charter
        coordinator.viewCharter(charter1Id)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charter1Id))
        
        // 5. User goes back
        coordinator.pop(from: .charters)
        #expect(coordinator.chartersPath.isEmpty)
        
        // 6. User switches to home tab
        coordinator.selectedTab = .home
        #expect(coordinator.selectedTab == .home)
        
        // 7. User navigates to specific charter from home (e.g., from recent charters widget)
        coordinator.navigateToCharter(charter2Id)
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath.first == .charterDetail(charter2Id))
    }
}

