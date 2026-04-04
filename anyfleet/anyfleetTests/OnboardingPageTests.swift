import Testing
@testable import anyfleet

@Suite("OnboardingPage model")
struct OnboardingPageTests {
    @Test func allCasesHaveUniqueIcons() {
        let icons = OnboardingPage.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }

    @Test func allCasesHaveNonEmptyStrings() {
        for page in OnboardingPage.allCases {
            #expect(!page.headline.isEmpty)
            #expect(!page.body.isEmpty)
        }
    }

    @Test func pageOrderMatchesProductSpec() {
        let pages = OnboardingPage.allCases
        #expect(pages[0] == .charter)
        #expect(pages[1] == .library)
        #expect(pages[2] == .discover)
    }

    @Test func allCasesHaveDistinctRawValues() {
        let rawValues = OnboardingPage.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test func identifiableIDMatchesRawValue() {
        for page in OnboardingPage.allCases {
            #expect(page.id == page.rawValue)
        }
    }
}
