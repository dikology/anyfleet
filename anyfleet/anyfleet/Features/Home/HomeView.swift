import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg, pinnedViews: []) {
                ActionCard(
                    icon: "sailboat.fill",
                    title: L10n.homeCreateCharterTitle,
                    subtitle: L10n.homeCreateCharterSubtitle,
                    buttonTitle: L10n.homeCreateCharterAction,
                    onTap: { viewModel.onCreateCharterTapped() },
                    onButtonTap: { viewModel.onCreateCharterTapped() }
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.lg + DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(appModel: AppModel()))
}
