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
                skipButton

                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageIndicator

                ctaButton
            }
        }
        // .contain keeps the ZStack identifiable for UI tests while
        // leaving all child buttons individually queryable by XCTest.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboardingView")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var skipButton: some View {
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
        .frame(height: 44)
    }

    private var pageIndicator: some View {
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
        .accessibilityHidden(true)
    }

    private var ctaButton: some View {
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

    // MARK: - Actions

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

#if DEBUG
#Preview {
    @Previewable @State var completed = false
    OnboardingView(hasCompletedOnboarding: $completed)
}
#endif
