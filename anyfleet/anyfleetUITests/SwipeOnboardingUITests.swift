//
//  SwipeOnboardingUITests.swift
//  anyfleetUITests
//
//  Guards first-run swipe onboarding (tip chip + peek animation wiring).
//

import XCTest

final class SwipeOnboardingUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    private func launch(resetSwipeOnboarding: Bool) {
        app.launchArguments = ["-ui-testing"]
        var env: [String: String] = ["UITesting": "true"]
        if resetSwipeOnboarding {
            env["RESET_SWIPE_ONBOARDING"] = "true"
        }
        app.launchEnvironment = env
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }

    private var swipeTipChip: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "swipeOnboardingTipChip").firstMatch
    }

    /// Custom `FloatingTabBar` exposes tab buttons with the same identifiers as the hidden `TabView` tabs.
    private func tapFloatingTab(identifier: String) {
        let tab = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Floating tab \(identifier) should exist")
        tab.tap()
    }

    private func openChartersTab() {
        tapFloatingTab(identifier: "tab.charters")
    }

    private func openLibraryTab() {
        tapFloatingTab(identifier: "tab.library")
    }

    private func openDiscoverTab() {
        tapFloatingTab(identifier: "tab.discover")
    }

    // MARK: - Tests

    /// Tip chip appears once after load when onboarding flags were reset (Discover content tab).
    @MainActor
    func testDiscoverSwipeOnboardingShowsTipChip() throws {
        launch(resetSwipeOnboarding: true)
        openDiscoverTab()

        XCTAssertTrue(swipeTipChip.waitForExistence(timeout: 5), "Swipe tip chip should appear on Discover content tab")
    }

    @MainActor
    func testLibrarySwipeOnboardingShowsTipChip() throws {
        launch(resetSwipeOnboarding: true)
        openLibraryTab()

        XCTAssertTrue(swipeTipChip.waitForExistence(timeout: 5), "Swipe tip chip should appear on Library list")
    }

    @MainActor
    func testCharterSwipeOnboardingShowsTipChip() throws {
        launch(resetSwipeOnboarding: true)
        openChartersTab()

        XCTAssertTrue(swipeTipChip.waitForExistence(timeout: 5), "Swipe tip chip should appear on Charter list")
    }

    /// After onboarding completes, a second launch without reset must not show the chip again quickly.
    @MainActor
    func testSwipeOnboardingNotReshownWithoutReset() throws {
        launch(resetSwipeOnboarding: true)
        openDiscoverTab()
        XCTAssertTrue(swipeTipChip.waitForExistence(timeout: 5))

        // Allow onboarding task to finish (~0.8s delay + ~2.5s display + animation).
        Thread.sleep(forTimeInterval: 4)

        app.terminate()
        launch(resetSwipeOnboarding: false)
        openDiscoverTab()

        XCTAssertFalse(
            swipeTipChip.waitForExistence(timeout: 2),
            "Tip chip should not reappear when onboarding was already completed"
        )
    }

    /// Custom filter chips are present and tappable (regression guard for segmented → chip tabs).
    @MainActor
    func testLibraryFilterChipsExist() throws {
        launch(resetSwipeOnboarding: false)
        openLibraryTab()

        XCTAssertTrue(
            app.buttons.matching(identifier: "library.filterChip.all").firstMatch.waitForExistence(timeout: 8),
            "All filter chip should exist"
        )
        XCTAssertTrue(app.buttons.matching(identifier: "library.filterChip.checklists").firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(identifier: "library.filterChip.guides").firstMatch.exists)

        app.buttons.matching(identifier: "library.filterChip.guides").firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "library.filterChip.guides").firstMatch.exists)
    }
}
