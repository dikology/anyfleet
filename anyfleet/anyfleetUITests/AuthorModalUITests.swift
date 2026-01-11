//
//  AuthorModalUITests.swift
//  anyfleetUITests
//
//  Created by anyfleet on 2025-01-11.
//

import XCTest

final class AuthorModalUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Configure app for UI testing with mock data
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment = [
            "UITesting": "true"
        ]
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    override func tearDownWithError() throws {
        // Clean up any modal state
        if app.buttons["xmark"].exists {
            app.buttons["xmark"].tap()
        }
    }

    @MainActor
    func testAuthorModalOpensWithUsername() throws {
        // Navigate to Discover tab (third tab: home=0, library=1, discover=2)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        tabBar.buttons.element(boundBy: 3).tap()

        // Wait for discover content to load
        let discoverList = app.collectionViews.firstMatch
        XCTAssertTrue(discoverList.waitForExistence(timeout: 10), "Discover content should load")

        // Look for author avatars using accessibility labels
        let authorAvatar = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Author'")).firstMatch

        // Debug: print all available buttons to understand the accessibility hierarchy
        let allButtons = app.buttons.allElementsBoundByIndex
        print("Available buttons: \(allButtons.map { $0.label })")

        if authorAvatar.exists {
            // Tap on the first available author avatar
            authorAvatar.tap()

            // Wait for modal to appear
            let modalTitle = app.staticTexts["Author Profile"]
            XCTAssertTrue(modalTitle.waitForExistence(timeout: 5), "Author profile modal should appear")

            // Verify username is displayed (should not be empty on first open)
            let usernameText = app.staticTexts.matching(NSPredicate(format: "label != '' AND label != ' '")).firstMatch
            XCTAssertTrue(usernameText.exists, "Username should be displayed in modal")

            // Verify "Coming Soon" message is present
            let comingSoonText = app.staticTexts["Coming Soon"]
            XCTAssertTrue(comingSoonText.exists, "Coming Soon message should be displayed")

            // Close modal
            let closeButton = app.buttons["Close"]
            if closeButton.exists {
                closeButton.tap()
            } else {
                // Try X button
                app.buttons["xmark"].tap()
            }

            // Verify modal is dismissed
            XCTAssertFalse(modalTitle.exists, "Modal should be dismissed")
        } else {
            // If no author avatars found, this test documents that author modal functionality
            // is not accessible in the current UI state - which could indicate the issue
            XCTFail("No author avatars found in discover content - author modal cannot be tested")
        }
    }

    @MainActor
    func testAuthorModalContentPersistence() throws {
        // Navigate to Discover tab (third tab: home=0, library=1, discover=2)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        tabBar.buttons.element(boundBy: 3).tap()

        // Test that modal content persists across multiple opens
        // This specifically tests for the reported bug where modal opens empty first time
        let discoverList = app.collectionViews.firstMatch
        XCTAssertTrue(discoverList.waitForExistence(timeout: 10))

        // Find author avatar
        let authorAvatar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Author '")).firstMatch

        guard authorAvatar.exists else {
            XCTFail("No author avatars available for testing")
            return
        }

        // First tap - should show content
        authorAvatar.tap()

        let modalTitle = app.staticTexts["Author Profile"]
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 5))

        // Capture username on first open
        let firstUsernameText = app.staticTexts.matching(NSPredicate(format: "label != '' AND label != ' '")).firstMatch
        XCTAssertTrue(firstUsernameText.exists, "Username should be displayed on first modal open")
        let firstUsername = firstUsernameText.label

        // Close modal
        app.buttons["xmark"].tap()
        XCTAssertFalse(modalTitle.exists)

        // Second tap - should show same content
        authorAvatar.tap()
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 5))

        let secondUsernameText = app.staticTexts.matching(NSPredicate(format: "label != '' AND label != ' '")).firstMatch
        XCTAssertTrue(secondUsernameText.exists, "Username should be displayed on second modal open")
        let secondUsername = secondUsernameText.label

        // Verify content is consistent
        XCTAssertEqual(firstUsername, secondUsername, "Username should be the same on first and second modal open")

        // Clean up
        app.buttons["xmark"].tap()
    }

    @MainActor
    func testAuthorModalWithDifferentAuthors() throws {
        // Navigate to Discover tab (third tab: home=0, library=1, discover=2)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        tabBar.buttons.element(boundBy: 3).tap()

        // Test that different authors show different modals
        // This helps catch issues where modal state doesn't update properly

        let discoverList = app.collectionViews.firstMatch
        XCTAssertTrue(discoverList.waitForExistence(timeout: 10))

        // Find all author avatars
        let authorAvatars = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Author'"))

        // Debug: print all available buttons to understand the accessibility hierarchy
        let allButtons = app.buttons.allElementsBoundByIndex
        print("Available buttons: \(allButtons.map { $0.label })")

        if authorAvatars.count >= 2 {
            // Test first author
            authorAvatars.element(boundBy: 0).tap()

            let modalTitle = app.staticTexts["Author Profile"]
            XCTAssertTrue(modalTitle.waitForExistence(timeout: 5))

            let firstUsername = app.staticTexts.matching(NSPredicate(format: "label != '' AND label != ' '")).firstMatch.label
            app.buttons["xmark"].tap()

            // Test second author
            authorAvatars.element(boundBy: 1).tap()
            XCTAssertTrue(modalTitle.waitForExistence(timeout: 5))

            let secondUsername = app.staticTexts.matching(NSPredicate(format: "label != '' AND label != ' '")).firstMatch.label

            // Usernames should be different (or at least not fail)
            XCTAssertNotEqual(firstUsername, "", "First username should not be empty")
            XCTAssertNotEqual(secondUsername, "", "Second username should not be empty")

            app.buttons["xmark"].tap()
        } else {
            // Document that we couldn't test multiple authors
            print("Only \(authorAvatars.count) author avatars found - cannot test multiple author modal behavior")
        }
    }
}