import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case charter
    case library
    case discover

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .charter:  "sailboat.fill"
        case .library:  "book.fill"
        case .discover: "globe"
        }
    }

    var headline: String {
        switch self {
        case .charter:  L10n.Onboarding.charterHeadline
        case .library:  L10n.Onboarding.libraryHeadline
        case .discover: L10n.Onboarding.discoverHeadline
        }
    }

    var body: String {
        switch self {
        case .charter:  L10n.Onboarding.charterBody
        case .library:  L10n.Onboarding.libraryBody
        case .discover: L10n.Onboarding.discoverBody
        }
    }

    var accentColor: Color {
        switch self {
        case .charter:  DesignSystem.Colors.primary
        case .library:  DesignSystem.Colors.gold
        case .discover: DesignSystem.Colors.info
        }
    }
}
