import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["RESET_SWIPE_ONBOARDING"] = "true"
    }

    func testOnboardingAppearsOnFirstLaunch() {
        app.launch()
        XCTAssertTrue(app.otherElements["onboardingView"].waitForExistence(timeout: 3))
    }

    func testContinueThroughAllPages() {
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))

        cta.tap() // Page 1 → 2
        cta.tap() // Page 2 → 3
        cta.tap() // Page 3 → dismiss ("Get Started")

        XCTAssertTrue(app.otherElements["tab.home"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["onboardingView"].exists)
    }

    func testSkipDismissesOnboarding() {
        app.launch()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()

        XCTAssertTrue(app.otherElements["tab.home"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["onboardingView"].exists)
    }

    func testSkipButtonHiddenOnLastPage() {
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))

        cta.tap() // → page 2
        cta.tap() // → page 3

        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testOnboardingDoesNotReappearAfterCompletion() {
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))
        cta.tap(); cta.tap(); cta.tap()

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "RESET_SWIPE_ONBOARDING")
        app.launch()

        XCTAssertFalse(app.otherElements["onboardingView"].waitForExistence(timeout: 2))
    }
}
