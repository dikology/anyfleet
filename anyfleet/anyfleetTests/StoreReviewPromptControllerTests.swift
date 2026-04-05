import Foundation
import Testing
@testable import anyfleet

@Suite("StoreReviewPromptController")
struct StoreReviewPromptControllerTests {
    @Test("charter milestone sets defaults flag once")
    @MainActor
    func charterMilestoneSetsFlagOnce() {
        let suite = "test.storeReview.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = StoreReviewPromptController(userDefaults: defaults)
        #expect(defaults.bool(forKey: "com.anyfleet.storeReview.promptedAfterCharterSave") == false)

        controller.considerPrompt(after: .charterSavedSuccessfully)
        #expect(defaults.bool(forKey: "com.anyfleet.storeReview.promptedAfterCharterSave") == true)

        controller.considerPrompt(after: .charterSavedSuccessfully)
        #expect(defaults.bool(forKey: "com.anyfleet.storeReview.promptedAfterCharterSave") == true)
    }

    @Test("checklist milestone uses separate flag from charter")
    @MainActor
    func checklistMilestoneSeparateFlag() {
        let suite = "test.storeReview.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let controller = StoreReviewPromptController(userDefaults: defaults)
        controller.considerPrompt(after: .checklistFullyCompletedFirstTime)
        #expect(defaults.bool(forKey: "com.anyfleet.storeReview.promptedAfterChecklistComplete") == true)
        #expect(defaults.bool(forKey: "com.anyfleet.storeReview.promptedAfterCharterSave") == false)
    }
}
