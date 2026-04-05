import Foundation
import StoreKit
import UIKit

/// Positive moments where asking for an App Store review is appropriate (Apple HIG: after value delivered, not on launch).
enum StoreReviewMilestone: Sendable {
    /// User successfully saved a charter from the editor (create or update).
    case charterSavedSuccessfully
    /// User checked the last remaining item in a checklist execution session.
    case checklistFullyCompletedFirstTime
}

/// Abstraction for ``StoreReviewPromptController`` so view models stay testable without StoreKit.
@MainActor
protocol StoreReviewPrompting: AnyObject {
    func considerPrompt(after milestone: StoreReviewMilestone)
}

/// Throttled, milestone-based wrapper around `SKStoreReviewController`.
///
/// Persists one-shot flags in `UserDefaults` so we do not ask on every save. The system still caps how often
/// the rating UI can appear (see `SKStoreReviewController` documentation).
@MainActor
final class StoreReviewPromptController: StoreReviewPrompting {
    private let defaults: UserDefaults

    private enum Keys {
        static let charterSave = "com.anyfleet.storeReview.promptedAfterCharterSave"
        static let checklistComplete = "com.anyfleet.storeReview.promptedAfterChecklistComplete"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func considerPrompt(after milestone: StoreReviewMilestone) {
        switch milestone {
        case .charterSavedSuccessfully:
            guard !defaults.bool(forKey: Keys.charterSave) else { return }
            defaults.set(true, forKey: Keys.charterSave)
        case .checklistFullyCompletedFirstTime:
            guard !defaults.bool(forKey: Keys.checklistComplete) else { return }
            defaults.set(true, forKey: Keys.checklistComplete)
        }
        requestReviewIfPossible()
    }

    private func requestReviewIfPossible() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            AppLogger.services.debug("Store review: no foreground window scene")
            return
        }
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
