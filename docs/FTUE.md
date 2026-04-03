# First-Time User Experience (FTUE) — Implementation Plan

## 1. Problem

New users land on an empty Home screen (greeting + "Create Charter" `ActionCard` + empty pinned-content header) with zero context about what Anyfleet does. The only education currently in the app is per-tab swipe-action hints that fire after a delay — they teach a gesture, not the product.

App Review teams are more favorable to apps that explain their value proposition upfront, and first-session retention is significantly higher when users understand core flows before interacting.

## 2. Design Goals

| Goal | Rationale |
|------|-----------|
| **3 screens, skippable** | Enough to cover the three pillars (charter planning, library, discovery) without overstaying. A "Skip" affordance respects power users. |
| **Full-screen cover over the tab bar** | The user should not interact with the app behind the onboarding. `fullScreenCover` is the right presentation — not a sheet, not a navigation push. |
| **Matches the design system** | Ocean gradient backgrounds, teal/gold accents, `DesignSystem.Typography`, `DesignSystem.Spacing`. No new design language. |
| **SF Symbols, not custom illustrations** | The app uses SF Symbols exclusively for empty states and cards. Custom illustrations add asset weight and maintenance burden. Use large composed symbol layouts instead. |
| **Animates between pages** | `TabView(.page)` with smooth cross-fade for content, animated dot indicator. |
| **Works offline** | No network dependency — purely local UI. |
| **Testable** | FTUE completion persisted via `@AppStorage`; UI test can reset and verify. |

## 3. User Flow

```
App launch
    │
    ▼
anyfleetApp.body
    │
    ├── databaseInitError? → DatabaseUnavailableView
    │
    └── AppView
         │
         ├── hasCompletedOnboarding == false?
         │       │
         │       ▼
         │   .fullScreenCover → OnboardingView
         │       │
         │       ├── Page 1: Plan Your Charter
         │       ├── Page 2: Build Your Library
         │       └── Page 3: Discover the Community
         │               │
         │               ▼
         │           "Get Started" button
         │               │
         │               ▼
         │           hasCompletedOnboarding = true
         │           dismiss fullScreenCover
         │
         └── hasCompletedOnboarding == true → normal app experience
```

## 4. Screen Content

### Page 1 — Plan Your Charter

| Element | Value |
|---------|-------|
| Icon composition | `sailboat.fill` (large, centered) over a circle with `Gradients.primary` fill |
| Headline | "Plan Your Charter" |
| Body | "Create and manage your sailing trips — set dates, locations, crew, and track preparation progress all in one place." |
| Accent | `Colors.primary` (teal) |

### Page 2 — Build Your Library

| Element | Value |
|---------|-------|
| Icon composition | `book.fill` (large, centered) over a circle with `Colors.gold` tinted fill |
| Headline | "Build Your Library" |
| Body | "Organize checklists, practice guides, and reference material. Pin your essentials to Home for quick access before departure." |
| Accent | `Colors.gold` |

### Page 3 — Discover the Community

| Element | Value |
|---------|-------|
| Icon composition | `globe` (large, centered) over a circle with `Colors.info` tinted fill |
| Headline | "Discover the Community" |
| Body | "Explore published charters on the map, find sailing content from other captains, and share your own when you're ready." |
| Accent | `Colors.info` (blue) |

### Controls (persistent across all pages)

| Element | Behavior |
|---------|----------|
| **Page indicator** | 3 dots, teal fill for active, `Colors.border` for inactive. Animated. |
| **"Skip" button** | Top-trailing, `Typography.body` + `Colors.textSecondary`. Tapping completes onboarding immediately. Hidden on the last page. |
| **"Continue" / "Get Started"** | Bottom CTA. Pages 1–2: "Continue" advances to next page. Page 3: "Get Started" completes onboarding. Styled with `Gradients.primaryButton`, white text, pill corner radius. |
| **Swipe** | Horizontal swipe via `TabView(.page)` for natural gesture navigation. |

## 5. Architecture

### 5.1 — New Files

```
anyfleet/
├── Features/
│   └── Onboarding/
│       ├── OnboardingView.swift          # Root view: TabView + controls
│       ├── OnboardingPageView.swift       # Single page template (icon, headline, body)
│       └── OnboardingPage.swift           # Data model: enum with 3 cases
├── Resources/
│   └── Localization.swift                 # Add L10n.Onboarding nested enum
```

### 5.2 — Modified Files

| File | Change |
|------|--------|
| `App/AppView.swift` | Add `@AppStorage("hasCompletedOnboarding")` flag. Attach `.fullScreenCover(isPresented:)` gated on `!hasCompletedOnboarding`. |
| `anyfleetApp.swift` | Extend `RESET_SWIPE_ONBOARDING` env check (or add `RESET_ONBOARDING`) to also clear the `hasCompletedOnboarding` key for UI tests. |
| `Resources/Localizable.strings` (en) | Add 10 strings (3 headlines, 3 bodies, "Skip", "Continue", "Get Started", section key). |
| `Resources/Localizable.strings` (ru) | Russian translations for the same 10 strings. |

### 5.3 — Data Model

```swift
// Features/Onboarding/OnboardingPage.swift

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
```

### 5.4 — Page Template View

```swift
// Features/Onboarding/OnboardingPageView.swift

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            Spacer()

            // Icon composition
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(page.accentColor.opacity(0.06))
                    .frame(width: 200, height: 200)
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(page.accentColor)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Text(page.headline)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
            }

            Spacer()
            Spacer()
        }
    }
}
```

### 5.5 — Root Onboarding View

```swift
// Features/Onboarding/OnboardingView.swift

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages = OnboardingPage.allCases

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (hidden on last page)
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(L10n.Onboarding.skip) {
                            completeOnboarding()
                        }
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.trailing, DesignSystem.Spacing.screenPadding)
                        .padding(.top, DesignSystem.Spacing.md)
                        .accessibilityIdentifier("onboarding.skip")
                    }
                }

                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(pages) { page in
                        Circle()
                            .fill(page.rawValue == currentPage
                                  ? DesignSystem.Colors.primary
                                  : DesignSystem.Colors.border)
                            .frame(width: 8, height: 8)
                            .scaleEffect(page.rawValue == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xl)

                // CTA button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1
                         ? L10n.Onboarding.continueButton
                         : L10n.Onboarding.getStarted)
                        .font(DesignSystem.Typography.bodySemibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Gradients.primaryButton)
                        .cornerRadius(DesignSystem.Spacing.cornerRadiusPill)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.xxxl)
                .accessibilityIdentifier("onboarding.cta")
            }
        }
        .accessibilityIdentifier("onboardingView")
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
```

### 5.6 — AppView Integration

```swift
// App/AppView.swift — additions only

struct AppView: View {
    // ... existing properties ...

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        // ... existing ZStack ...
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { newValue in
                if !newValue { hasCompletedOnboarding = true }
            }
        )
    }
}
```

### 5.7 — anyfleetApp.swift — Test Reset

```swift
// anyfleetApp.swift — extend the existing init reset block

init() {
    if ProcessInfo.processInfo.environment["RESET_SWIPE_ONBOARDING"] == "true" {
        [
            "hasSeenCharterSwipeHint",
            "hasSeenLibrarySwipeHint",
            "hasSeenDiscoverSwipeHint",
            "hasCompletedOnboarding"          // ← add
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
    // ... rest unchanged
}
```

## 6. Localization Strings

### English

```
// MARK: - Onboarding

"onboarding.charter.headline" = "Plan Your Charter";
"onboarding.charter.body" = "Create and manage your sailing trips — set dates, locations, crew, and track preparation progress all in one place.";
"onboarding.library.headline" = "Build Your Library";
"onboarding.library.body" = "Organize checklists, practice guides, and reference material. Pin your essentials to Home for quick access before departure.";
"onboarding.discover.headline" = "Discover the Community";
"onboarding.discover.body" = "Explore published charters on the map, find sailing content from other captains, and share your own when you're ready.";
"onboarding.skip" = "Skip";
"onboarding.continue" = "Continue";
"onboarding.getStarted" = "Get Started";
```

### Russian

```
"onboarding.charter.headline" = "Спланируйте чартер";
"onboarding.charter.body" = "Создавайте и управляйте парусными поездками — даты, маршруты, экипаж и подготовка в одном месте.";
"onboarding.library.headline" = "Соберите библиотеку";
"onboarding.library.body" = "Чек-листы, справочники и руководства. Закрепите важное на главном экране для быстрого доступа перед выходом.";
"onboarding.discover.headline" = "Откройте сообщество";
"onboarding.discover.body" = "Исследуйте чартеры на карте, находите материалы других капитанов и делитесь своими, когда будете готовы.";
"onboarding.skip" = "Пропустить";
"onboarding.continue" = "Далее";
"onboarding.getStarted" = "Начать";
```

### L10n Enum Additions

```swift
// Resources/Localization.swift — add inside enum L10n

enum Onboarding {
    static let charterHeadline = NSLocalizedString(
        "onboarding.charter.headline", tableName: "Localizable",
        comment: "Onboarding page 1 headline: charter planning"
    )
    static let charterBody = NSLocalizedString(
        "onboarding.charter.body", tableName: "Localizable",
        comment: "Onboarding page 1 body text"
    )
    static let libraryHeadline = NSLocalizedString(
        "onboarding.library.headline", tableName: "Localizable",
        comment: "Onboarding page 2 headline: library"
    )
    static let libraryBody = NSLocalizedString(
        "onboarding.library.body", tableName: "Localizable",
        comment: "Onboarding page 2 body text"
    )
    static let discoverHeadline = NSLocalizedString(
        "onboarding.discover.headline", tableName: "Localizable",
        comment: "Onboarding page 3 headline: community discovery"
    )
    static let discoverBody = NSLocalizedString(
        "onboarding.discover.body", tableName: "Localizable",
        comment: "Onboarding page 3 body text"
    )
    static let skip = NSLocalizedString(
        "onboarding.skip", tableName: "Localizable",
        comment: "Onboarding skip button"
    )
    static let continueButton = NSLocalizedString(
        "onboarding.continue", tableName: "Localizable",
        comment: "Onboarding continue button"
    )
    static let getStarted = NSLocalizedString(
        "onboarding.getStarted", tableName: "Localizable",
        comment: "Onboarding final page CTA"
    )
}
```

## 7. Testing Plan

### 7.1 — Unit Tests

```swift
// anyfleetTests/OnboardingPageTests.swift

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
}
```

### 7.2 — UI Tests

```swift
// anyfleetUITests/OnboardingUITests.swift

import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["RESET_SWIPE_ONBOARDING"] = "true"
        // Clearing this key causes the onboarding to appear
    }

    func testOnboardingAppearsOnFirstLaunch() {
        app.launch()
        XCTAssertTrue(app.otherElements["onboardingView"].waitForExistence(timeout: 3))
    }

    func testContinueThroughAllPages() {
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))

        // Page 1 → 2
        cta.tap()
        // Page 2 → 3
        cta.tap()
        // Page 3 → dismiss ("Get Started")
        cta.tap()

        // Verify onboarding dismissed and Home tab visible
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

    func testOnboardingDoesNotReappearAfterCompletion() {
        app.launch()
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))
        cta.tap(); cta.tap(); cta.tap()

        // Relaunch without resetting
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "RESET_SWIPE_ONBOARDING")
        app.launch()

        XCTAssertFalse(app.otherElements["onboardingView"].waitForExistence(timeout: 2))
    }
}
```

## 8. Accessibility

| Requirement | Implementation |
|-------------|----------------|
| VoiceOver page reading | Each `OnboardingPageView` uses `.accessibilityElement(children: .combine)` on the content VStack so the icon + headline + body read as one unit. |
| Skip button reachable | Standard `Button` with `.accessibilityIdentifier`. Positioned in top-trailing for thumb reach. |
| Page indicator | Decorative only — `.accessibilityHidden(true)`. VoiceOver users navigate via swipe or CTA. |
| CTA label changes | Button text dynamically reflects "Continue" vs "Get Started", so VoiceOver reads the correct action. |
| Dynamic Type | Uses `DesignSystem.Typography` (system text styles). Icon size uses fixed points but is decorative; text scales. |

## 9. Effort Estimate

| Task | Effort |
|------|--------|
| `OnboardingPage.swift` data model | 15 min |
| `OnboardingPageView.swift` template | 30 min |
| `OnboardingView.swift` root view | 45 min |
| `AppView.swift` integration | 15 min |
| `anyfleetApp.swift` test reset | 5 min |
| Localization strings (en + ru) | 20 min |
| `L10n.Onboarding` enum | 15 min |
| Unit tests | 15 min |
| UI tests | 30 min |
| Visual polish + dark mode check | 30 min |
| **Total** | **~3.5 hours** |

## 10. Implementation Order

1. **L10n strings** — add localization keys and translations first so the compiler can resolve them.
2. **`OnboardingPage` model** — pure data, no UI dependency.
3. **`OnboardingPageView`** — single-page template, previewable in isolation.
4. **`OnboardingView`** — compose pages + controls, previewable standalone.
5. **`AppView` integration** — `@AppStorage` flag + `.fullScreenCover`.
6. **`anyfleetApp` test reset** — extend the environment variable check.
7. **Unit tests** — verify model invariants.
8. **UI tests** — verify full flow, skip, and persistence.
9. **Visual QA** — light mode, dark mode, small/large Dynamic Type, both locales.

## 11. Future Considerations

| Topic | Notes |
|-------|-------|
| **Conditional re-show** | If significant new features launch (e.g., Voyage Log, Flashcard Decks), consider a "What's New" variant that reuses the same paged infrastructure with a `hasSeenWhatsNew_vX` key. |
| **Analytics events** | When crash/analytics tooling is added (R2), fire events for `onboarding_page_viewed(page:)`, `onboarding_skipped(onPage:)`, `onboarding_completed`. |
| **A/B page count** | The 3-page design is intentionally minimal. If analytics show high skip rates on page 1, consider a single-page "welcome" variant. |
| **Deep link into features** | Future enhancement: CTA on each page could navigate directly to the relevant tab (e.g., "Try it now" on page 1 → Charters tab with create flow open). Requires coordinator wiring and is out of scope for v1. |
