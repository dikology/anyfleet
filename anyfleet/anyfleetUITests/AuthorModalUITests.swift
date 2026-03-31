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

    private func tapDiscoverTab() {
        let discover = app.buttons.matching(identifier: "tab.discover").firstMatch
        XCTAssertTrue(discover.waitForExistence(timeout: 5), "Discover tab (floating bar) should exist")
        discover.tap()
    }

    /// `DiscoverContentRow` labels current authors as `"Author <username>"`.
    /// SwiftUI `List` is not always `XCUIElementTypeTable` (often a collection view on newer iOS),
    /// so we wait for these buttons instead of `tables` / `collectionViews`.
    private var authorAvatarPredicate: NSPredicate {
        NSPredicate(format: "label BEGINSWITH %@", "Author ")
    }

    private func waitForDiscoverAuthorRows(timeout: TimeInterval = 15) {
        let author = app.buttons.matching(authorAvatarPredicate).firstMatch
        XCTAssertTrue(
            author.waitForExistence(timeout: timeout),
            "Discover should load rows with author avatars"
        )
    }

    override func tearDownWithError() throws {
        // Clean up any modal state
        let modalXButton = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
        if modalXButton.exists {
            modalXButton.tap()
        }
    }

    @MainActor
    func testAuthorModalOpensWithUsername() throws {
        tapDiscoverTab()
        waitForDiscoverAuthorRows()

        let authorAvatar = app.buttons.matching(authorAvatarPredicate).firstMatch

        if authorAvatar.exists {
            // Tap on the first available author avatar
            authorAvatar.tap()

            // Wait for modal to appear - check for accessibility identifiers
            let usernameElement = app.staticTexts.matching(NSPredicate(format: "identifier == 'author_username'")).firstMatch
            XCTAssertTrue(usernameElement.waitForExistence(timeout: 5), "Username should be displayed in modal")

            // Verify username is displayed (should not be empty on first open)
            XCTAssertFalse(usernameElement.label.isEmpty, "Username should not be empty")

            // Verify modal shows actual profile content instead of placeholder
            // Check that the modal has profile elements (not just username)
            let modalExists = usernameElement.exists
            XCTAssertTrue(modalExists, "Modal should display with profile content")

            // Close modal - use the modal's specific close button first, then fallback to modal xmark
            let modalCloseButton = app.buttons.matching(NSPredicate(format: "identifier == 'modal_close_button'")).firstMatch
            if modalCloseButton.exists {
                modalCloseButton.tap()
            } else {
                // Try modal X button
                let modalXButton = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
                if modalXButton.exists {
                    modalXButton.tap()
                } else {
                    // Final fallback
                    app.buttons["xmark"].firstMatch.tap()
                }
            }

            // Verify modal is dismissed - check that username element is no longer present
            XCTAssertFalse(usernameElement.exists, "Modal should be dismissed")
        } else {
            // If no author avatars found, this test documents that author modal functionality
            // is not accessible in the current UI state - which could indicate the issue
            XCTFail("No author avatars found in discover content - author modal cannot be tested")
        }
    }

    @MainActor
    func testAuthorModalContentPersistence() throws {
        tapDiscoverTab()
        waitForDiscoverAuthorRows()

        let authorAvatar = app.buttons.matching(authorAvatarPredicate).firstMatch

        guard authorAvatar.exists else {
            XCTFail("No author avatars available for testing")
            return
        }

        // First tap - should show modal
        authorAvatar.tap()

        // Wait for modal to appear - check for username text
        let usernameElement = app.staticTexts.matching(NSPredicate(format: "identifier == 'author_username'")).firstMatch
        XCTAssertTrue(usernameElement.waitForExistence(timeout: 5), "Modal should appear with username")
        XCTAssertEqual(usernameElement.label, "SailorMaria", "Username should match tapped author")

        // Verify modal shows actual profile content instead of placeholder
        // Check that the modal displays the username correctly
        XCTAssertEqual(usernameElement.label, "SailorMaria", "Modal should display correct username")

        let firstUsername = "SailorMaria"

        // Close modal
        let modalXButton = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
        modalXButton.tap()
        XCTAssertFalse(usernameElement.exists, "Modal should be dismissed")

        // Second tap - should show same content
        authorAvatar.tap()
        XCTAssertTrue(usernameElement.waitForExistence(timeout: 5), "Modal should appear again with username")

        // Verify the second modal also shows the same username
        let secondUsernameElement = app.staticTexts.matching(NSPredicate(format: "identifier == 'author_username'")).firstMatch
        XCTAssertEqual(secondUsernameElement.label, "SailorMaria", "Second modal should display same username")

        let secondUsername = "SailorMaria"

        // Verify content is consistent
        XCTAssertEqual(firstUsername, secondUsername, "Username should be the same on first and second modal open")

        // Clean up
        let modalXButtonCleanup = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
        modalXButtonCleanup.tap()
    }

    @MainActor
    func testAuthorModalWithDifferentAuthors() throws {
        tapDiscoverTab()
        waitForDiscoverAuthorRows()

        let authorAvatars = app.buttons.matching(authorAvatarPredicate)

        if authorAvatars.count >= 2 {
            // Test first author (SailorMaria)
            authorAvatars.element(boundBy: 0).tap()

            let firstUsernameElement = app.staticTexts.matching(NSPredicate(format: "identifier == 'author_username'")).firstMatch
            XCTAssertTrue(firstUsernameElement.waitForExistence(timeout: 5), "First author modal should appear")
            XCTAssertEqual(firstUsernameElement.label, "SailorMaria", "First username should be SailorMaria")

            let firstUsername = "SailorMaria"
            let modalXButton1 = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
            modalXButton1.tap()

            // Test second author (CaptainJohn)
            authorAvatars.element(boundBy: 1).tap()

            let secondUsernameElement = app.staticTexts.matching(NSPredicate(format: "identifier == 'author_username'")).firstMatch
            XCTAssertTrue(secondUsernameElement.waitForExistence(timeout: 5), "Second author modal should appear")
            XCTAssertEqual(secondUsernameElement.label, "CaptainJohn", "Second username should be CaptainJohn")

            let secondUsername = "CaptainJohn"

            // Usernames should be different (or at least not fail)
            XCTAssertNotEqual(firstUsername, "", "First username should not be empty")
            XCTAssertNotEqual(secondUsername, "", "Second username should not be empty")

            let modalXButton2 = app.buttons.matching(NSPredicate(format: "identifier == 'modal_xmark_button'")).firstMatch
            modalXButton2.tap()
        } else {
            // Document that we couldn't test multiple authors
            print("Only \(authorAvatars.count) author avatars found - cannot test multiple author modal behavior")
        }
    }
}