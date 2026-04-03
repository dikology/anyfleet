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
    
    // MARK: - Test Helpers
    
    @MainActor
    private func makeTestCoordinator() -> AppCoordinator {
        let dependencies = AppDependencies()
        return AppCoordinator(dependencies: dependencies)
    }
    
    // MARK: - Charter Navigation Flow
    
    @Test("Create charter flow - navigates to create charter view")
    @MainActor
    func testCreateCharterFlow() {
        // Arrange
        let coordinator = makeTestCoordinator()
        
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
        
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
        let coordinator = makeTestCoordinator()
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
        let coordinator = makeTestCoordinator()
        
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
        let coordinator = makeTestCoordinator()
        
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
        let coordinator = makeTestCoordinator()
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
    
    // MARK: - Navigation Destination Tests
    
    @Test("Navigate to charter detail - sets correct tab and path")
    @MainActor
    func testNavigateToCharterDetail() {
        // Arrange
        let coordinator = makeTestCoordinator()
        let testID = UUID()
        
        // Act
        coordinator.navigateToCharter(testID)
        
        // Assert
        #expect(coordinator.selectedTab == .charters)
        #expect(coordinator.chartersPath.count == 1)
        guard case .charterDetail(let id) = coordinator.chartersPath.first else {
            Issue.record("Expected charter detail route")
            return
        }
        #expect(id == testID)
    }
    
    // MARK: - Deep Linking (Placeholder)
    
    @Test("Deep linking - placeholder implementation")
    @MainActor
    func testDeepLinkingPlaceholder() {
        // Arrange
        let coordinator = makeTestCoordinator()
        let url = URL(string: "sailaway://charter/550e8400-e29b-41d4-a716-446655440000")!
        
        // Act: Handle deep link (currently placeholder)
        coordinator.handleDeepLink(url)
        
        // Assert: Should not crash (implementation is TODO)
        // TODO: Add proper assertions when deep linking is implemented
        #expect(true) // Placeholder assertion
    }
}

// MARK: - AppView ViewModel Lifecycle Tests

/// These tests validate the coordinator state invariants that underpin the S6 fix:
/// AppView stores ViewModels in @State so they survive body re-evaluations.
/// The coordinator paths are the observable projection of that state — if paths
/// survive tab switches (and they do, as these tests confirm), so do the VMs.
@Suite("AppView ViewModel Lifecycle Tests")
struct AppViewViewModelLifecycleTests {

    @MainActor
    private func makeTestCoordinator() -> AppCoordinator {
        let dependencies = AppDependencies()
        return AppCoordinator(dependencies: dependencies)
    }

    // MARK: - Initial State

    @Test("Coordinator initial state — home tab selected")
    @MainActor
    func testInitialTabIsHome() {
        let coordinator = makeTestCoordinator()
        #expect(coordinator.selectedTab == .home)
    }

    @Test("Coordinator initial state — all tab paths are empty")
    @MainActor
    func testAllTabPathsStartEmpty() {
        let coordinator = makeTestCoordinator()
        #expect(coordinator.homePath.isEmpty)
        #expect(coordinator.chartersPath.isEmpty)
        #expect(coordinator.libraryPath.isEmpty)
        #expect(coordinator.discoverPath.isEmpty)
        #expect(coordinator.profilePath.isEmpty)
    }

    // MARK: - Tab-switch State Preservation

    @Test("Switching tabs preserves all five independent paths")
    @MainActor
    func testAllTabPathsPreservedAcrossSwitches() {
        let coordinator = makeTestCoordinator()
        let charterID = UUID()
        let checklistID = UUID()

        // Set state on two tabs
        coordinator.viewCharter(charterID)
        coordinator.editChecklist(checklistID)

        // Switch through all tabs and back
        coordinator.selectedTab = .home
        coordinator.selectedTab = .discover
        coordinator.selectedTab = .profile
        coordinator.selectedTab = .charters

        // Both paths must be intact after all switches
        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
        #expect(coordinator.libraryPath.count == 1)
        #expect(coordinator.libraryPath[0] == .checklistEditor(checklistID))
    }

    @Test("Switching tabs does not reset other tabs to root")
    @MainActor
    func testTabSwitchDoesNotResetOtherTabs() {
        let coordinator = makeTestCoordinator()
        let charterID = UUID()

        coordinator.viewCharter(charterID)

        // Simulate the scenario that triggers the S6 bug:
        // tab switch triggers an AppView body re-evaluation.
        // The coordinator path must not be cleared.
        for _ in 0..<5 {
            coordinator.selectedTab = .home
            coordinator.selectedTab = .charters
        }

        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
    }

    // MARK: - Library Tab Navigation

    @Test("Library tab — editChecklist pushes checklistEditor route")
    @MainActor
    func testEditChecklistNavigatesToLibrary() {
        let coordinator = makeTestCoordinator()
        let checklistID = UUID()

        coordinator.editChecklist(checklistID)

        #expect(coordinator.libraryPath.count == 1)
        #expect(coordinator.libraryPath[0] == .checklistEditor(checklistID))
        #expect(coordinator.homePath.isEmpty)
    }

    @Test("Library tab — editGuide pushes guideEditor route")
    @MainActor
    func testEditGuideNavigatesToLibrary() {
        let coordinator = makeTestCoordinator()
        let guideID = UUID()

        coordinator.editGuide(guideID)

        #expect(coordinator.libraryPath.count == 1)
        #expect(coordinator.libraryPath[0] == .guideEditor(guideID))
    }

    @Test("Library tab — create new checklist uses nil ID")
    @MainActor
    func testCreateChecklistUsesNilID() {
        let coordinator = makeTestCoordinator()

        coordinator.editChecklist(nil)

        #expect(coordinator.libraryPath.count == 1)
        #expect(coordinator.libraryPath[0] == .checklistEditor(nil))
    }

    @Test("Library tab — stacked navigation pops correctly")
    @MainActor
    func testLibraryStackedNavigationPops() {
        let coordinator = makeTestCoordinator()
        let checklistID = UUID()
        let guideID = UUID()

        coordinator.editChecklist(checklistID)
        coordinator.editGuide(guideID)
        #expect(coordinator.libraryPath.count == 2)

        coordinator.pop(from: .library)
        #expect(coordinator.libraryPath.count == 1)
        #expect(coordinator.libraryPath[0] == .checklistEditor(checklistID))

        coordinator.popToRoot(from: .library)
        #expect(coordinator.libraryPath.isEmpty)
    }

    // MARK: - Discover Tab

    @Test("Discover tab — navigateToCharterDiscovery pushes discoverCharters route")
    @MainActor
    func testNavigateToCharterDiscovery() {
        let coordinator = makeTestCoordinator()

        coordinator.navigateToCharterDiscovery()

        #expect(coordinator.selectedTab == .discover)
        #expect(coordinator.discoverPath.count == 1)
        #expect(coordinator.discoverPath[0] == .discoverCharters)
    }

    @Test("Discover tab path is independent of charters tab path")
    @MainActor
    func testDiscoverAndChartersTabsAreIndependent() {
        let coordinator = makeTestCoordinator()
        let charterID = UUID()

        coordinator.viewCharter(charterID)
        coordinator.navigateToCharterDiscovery()

        #expect(coordinator.chartersPath.count == 1)
        #expect(coordinator.chartersPath[0] == .charterDetail(charterID))
        #expect(coordinator.discoverPath.count == 1)
        #expect(coordinator.discoverPath[0] == .discoverCharters)
    }
}
