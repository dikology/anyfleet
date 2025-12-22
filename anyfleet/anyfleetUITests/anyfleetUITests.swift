//
//  anyfleetUITests.swift
//  anyfleetUITests
//
//  Created by Денис on 12/11/25.
//

import XCTest

final class anyfleetUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // Take screenshot of launch screen
        snapshot("01Launch")

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // Wait for app to load
        sleep(2)

        // Screenshot 1: Main screen (assuming it's the charter list or home screen)
        snapshot("01Home")

        // Try to navigate to different screens - adjust these based on your app's actual UI
        // This is a basic template - you'll need to customize based on your app's navigation

        // Example: If there's a tab bar or navigation
        // Look for common UI elements that might exist in your app

        // Screenshot 2: Charter list (if accessible)
        if app.buttons["Charters"].exists || app.staticTexts["Charters"].exists {
            snapshot("02CharterList")
        }

        // Screenshot 3: Library (if accessible)
        if app.buttons["Library"].exists || app.staticTexts["Library"].exists {
            app.buttons["Library"].tap()
            sleep(1)
            snapshot("03Library")
        }

        // Screenshot 4: Create/Add screen (if accessible)
        if app.buttons["Add"].exists || app.buttons["Create"].exists || app.buttons["New"].exists {
            app.buttons["Add"].tap()
            sleep(1)
            snapshot("04Create")
        }
    }

    // Disabled for screenshot automation - only testScreenshots should run
    // @MainActor
    // func testLaunchPerformance() throws {
    //     // This measures how long it takes to launch your application.
    //     measure(metrics: [XCTApplicationLaunchMetric()]) {
    //         XCUIApplication().launch()
    //     }
    // }
}
