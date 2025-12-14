//
//  NavigationTests.swift
//  anyfleetTests
//
//  Navigation flow tests based on Navigation PRD
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Navigation Tests")
struct NavigationTests {
    
    // MARK: - Charter Navigation Flow
    
    @Test("Create charter flow - navigates to create charter view")
    @MainActor
    func testCreateCharterFlow() {
        // Arrange
        let coordinator = AppCoordinator()
        
        // Assert: Start at home with empty path
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act: Create charter
        coordinator.createCharter()
        
        // Assert: Path should contain createCharter route
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .createCharter)
    }
    
    @Test("View charter detail - navigates to charter detail view")
    @MainActor
    func testViewCharterDetail() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Assert: Start with empty path
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act: View charter
        coordinator.viewCharter(charterID)
        
        // Assert: Path should contain charterDetail route
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
    }
    
    @Test("Charter navigation - back button pops route")
    @MainActor
    func testCharterNavigationBackButton() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Act: Navigate to charter detail
        coordinator.viewCharter(charterID)
        #expect(coordinator.chartersPath.count == 1)
        
        // Act: Pop (back button)
        coordinator.pop(from: .charters)
        
        // Assert: Path should be empty
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Charter navigation - pop to root clears all routes")
    @MainActor
    func testCharterNavigationPopToRoot() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID1 = UUID()
        let charterID2 = UUID()
        
        // Act: Navigate multiple times
        coordinator.viewCharter(charterID1)
        coordinator.viewCharter(charterID2)
        #expect(coordinator.chartersPath.count == 2)
        
        // Act: Pop to root
        coordinator.popToRoot(from: .charters)
        
        // Assert: Path should be empty
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    // MARK: - Tab Preservation
    
    @Test("Tab preservation - switching tabs preserves navigation state")
    @MainActor
    func testTabPreservation() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Act: Navigate in charters tab
        coordinator.viewCharter(charterID)
        let chartersPathBefore = coordinator.chartersPath
        
        // Act: Switch to home tab
        coordinator.selectedTab = .home
        
        // Assert: Charters tab state should be preserved
        #expect(coordinator.chartersPath == chartersPathBefore)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
    }
    
    @Test("Tab preservation - home and charters tabs are independent")
    @MainActor
    func testTabIndependence() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Act: Navigate in charters tab
        coordinator.viewCharter(charterID)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.homePath.isEmpty)
        
        // Act: Navigate in home tab
        coordinator.push(.createCharter, to: .home)
        
        // Assert: Both tabs have independent paths
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
        #expect(coordinator.homePath.count == 1)
        #expect(coordinator.homePath[0] == .createCharter)
    }
    
    // MARK: - Cross-Tab Navigation
    
    @Test("Cross-tab navigation - navigate to charter switches tab and navigates")
    @MainActor
    func testCrossTabNavigationToCharter() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Assert: Start at home tab
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act: Navigate to charter from any tab
        coordinator.navigateToCharter(charterID)
        
        // Assert: Should switch to charters tab and navigate
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
    }
    
    @Test("Cross-tab navigation - clears existing charters path before navigating")
    @MainActor
    func testCrossTabNavigationClearsPath() {
        // Arrange
        let coordinator = AppCoordinator()
        let oldCharterID = UUID()
        let newCharterID = UUID()
        
        // Act: Navigate to first charter
        coordinator.viewCharter(oldCharterID)
        #expect(coordinator.chartersPath.count == 1)
        
        // Act: Cross-tab navigate to different charter
        coordinator.navigateToCharter(newCharterID)
        
        // Assert: Path should be cleared and contain only new route
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(newCharterID))
        #expect(coordinator.chartersPath[0] != .charterDetail(oldCharterID))
    }
    
    // MARK: - Tab-Specific Navigation Methods
    
    @Test("Push route to home tab")
    @MainActor
    func testPushRouteToHomeTab() {
        // Arrange
        let coordinator = AppCoordinator()
        
        // Act: Push route to home tab
        coordinator.push(.createCharter, to: .home)
        
        // Assert: Home path should contain route
        #expect(coordinator.homePath.count == 1)
        #expect(coordinator.homePath[0] == .createCharter)
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Push route to charters tab")
    @MainActor
    func testPushRouteToChartersTab() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID = UUID()
        
        // Act: Push route to charters tab
        coordinator.push(.charterDetail(charterID), to: .charters)
        
        // Assert: Charters path should contain route
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
        #expect(coordinator.homePath.isEmpty)
    }
    
    @Test("Pop from empty path - no crash")
    @MainActor
    func testPopFromEmptyPath() {
        // Arrange
        let coordinator = AppCoordinator()
        
        // Assert: Path is empty
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act: Try to pop from empty path (should not crash)
        coordinator.pop(from: .charters)
        
        // Assert: Path should still be empty
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    @Test("Pop to root from empty path - no crash")
    @MainActor
    func testPopToRootFromEmptyPath() {
        // Arrange
        let coordinator = AppCoordinator()
        
        // Assert: Path is empty
        #expect(coordinator.chartersPath.isEmpty)
        
        // Act: Try to pop to root from empty path (should not crash)
        coordinator.popToRoot(from: .charters)
        
        // Assert: Path should still be empty
        #expect(coordinator.chartersPath.isEmpty)
    }
    
    // MARK: - Multiple Route Navigation
    
    @Test("Multiple routes - can navigate through multiple screens")
    @MainActor
    func testMultipleRoutesNavigation() {
        // Arrange
        let coordinator = AppCoordinator()
        let charterID1 = UUID()
        let charterID2 = UUID()
        
        // Act: Navigate through multiple routes
        coordinator.viewCharter(charterID1)
        coordinator.viewCharter(charterID2)
        
        // Assert: Path should contain both routes in order
        #expect(coordinator.chartersPath.count == 2)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID1))
        #expect(coordinator.chartersPath[1] == .charterDetail(charterID2))
        
        // Act: Pop once
        coordinator.pop(from: .charters)
        
        // Assert: Should be back to first route
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID1))
    }
    
    // MARK: - Route Equality
    
    @Test("Route equality - same charter IDs are equal")
    @MainActor
    func testRouteEquality() {
        // Arrange
        let charterID = UUID()
        let route1 = AppRoute.charterDetail(charterID)
        let route2 = AppRoute.charterDetail(charterID)
        
        // Assert: Same routes should be equal
        #expect(route1 == route2)
    }
    
    @Test("Route equality - different charter IDs are not equal")
    @MainActor
    func testRouteInequality() {
        // Arrange
        let charterID1 = UUID()
        let charterID2 = UUID()
        let route1 = AppRoute.charterDetail(charterID1)
        let route2 = AppRoute.charterDetail(charterID2)
        
        // Assert: Different routes should not be equal
        #expect(route1 != route2)
    }
    
    @Test("Route equality - createCharter routes are equal")
    @MainActor
    func testCreateCharterRouteEquality() {
        // Arrange
        let route1 = AppRoute.createCharter
        let route2 = AppRoute.createCharter
        
        // Assert: Same routes should be equal
        #expect(route1 == route2)
    }
    
    // MARK: - Deep Linking (Placeholder)
    
    @Test("Deep linking - placeholder implementation")
    @MainActor
    func testDeepLinkingPlaceholder() {
        // Arrange
        let coordinator = AppCoordinator()
        let url = URL(string: "sailaway://charter/550e8400-e29b-41d4-a716-446655440000")!
        
        // Act: Handle deep link (currently placeholder)
        coordinator.handleDeepLink(url)
        
        // Assert: Should not crash (implementation is TODO)
        // TODO: Add proper assertions when deep linking is implemented
        #expect(true) // Placeholder assertion
    }
}
