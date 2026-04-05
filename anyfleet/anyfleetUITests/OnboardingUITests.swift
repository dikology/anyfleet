import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        // UITesting=true triggers the default onboarding skip; RESET_FTUE_ONBOARDING
        // overrides that, clearing hasCompletedOnboarding so the cover appears.
        app.launchEnvironment = [
            "UITesting": "true",
            "RESET_FTUE_ONBOARDING": "true"
        ]
    }

    // MARK: - Helpers

    private func cta() -> XCUIElement {
        app.buttons.matching(identifier: "onboarding.cta").firstMatch
    }

    private func skipButton() -> XCUIElement {
        app.buttons.matching(identifier: "onboarding.skip").firstMatch
    }

    // MARK: - Tests

    func testOnboardingAppearsOnFirstLaunch() {
        app.launch()
        XCTAssertTrue(
            app.otherElements.matching(identifier: "onboardingView").firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    func testContinueThroughAllPages() {
        app.launch()
        let cta = cta()
        XCTAssertTrue(cta.waitForExistence(timeout: 5))

        cta.tap() // Page 1 → 2
        cta.tap() // Page 2 → 3
        cta.tap() // Page 3 → dismiss ("Get Started")

        XCTAssertTrue(
            app.buttons.matching(identifier: "tab.home").firstMatch
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.otherElements.matching(identifier: "onboardingView").firstMatch.exists
        )
    }

    func testSkipDismissesOnboarding() {
        app.launch()
        let skip = skipButton()
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        XCTAssertTrue(
            app.buttons.matching(identifier: "tab.home").firstMatch
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.otherElements.matching(identifier: "onboardingView").firstMatch.exists
        )
    }

    func testSkipButtonHiddenOnLastPage() {
        app.launch()
        let cta = cta()
        XCTAssertTrue(cta.waitForExistence(timeout: 5))

        cta.tap() // → page 2
        cta.tap() // → page 3

        XCTAssertFalse(skipButton().exists)
    }

    func testOnboardingDoesNotReappearAfterCompletion() {
        app.launch()
        let cta = cta()
        XCTAssertTrue(cta.waitForExistence(timeout: 5))
        cta.tap(); cta.tap(); cta.tap()

        // Relaunch without RESET_FTUE_ONBOARDING — onboarding should not show.
        app.terminate()
        app.launchEnvironment = ["UITesting": "true"]
        app.launch()

        XCTAssertFalse(
            app.otherElements.matching(identifier: "onboardingView").firstMatch
                .waitForExistence(timeout: 3)
        )
    }
}
