import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            Spacer()

            iconComposition

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
        .accessibilityElement(children: .combine)
    }

    private var iconComposition: some View {
        ZStack {
            Circle()
                .fill(page.accentColor.opacity(0.06))
                .frame(width: 200, height: 200)
            Circle()
                .fill(page.accentColor.opacity(0.12))
                .frame(width: 140, height: 140)
            Image(systemName: page.icon)
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(page.accentColor)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPageView(page: .charter)
        .background(DesignSystem.Colors.background)
}
#endif
