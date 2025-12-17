import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                // LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg, pinnedViews: []) {
                //     ActionCard(
                //         icon: "sailboat.fill",
                //         title: L10n.homeCreateCharterTitle,
                //         subtitle: L10n.homeCreateCharterSubtitle,
                //         buttonTitle: L10n.homeCreateCharterAction,
                //         onTap: { viewModel.onCreateCharterTapped() },
                //         onButtonTap: { viewModel.onCreateCharterTapped() }
                //     )
                // }
                // .padding(.horizontal, DesignSystem.Spacing.lg)
                // .padding(.vertical, DesignSystem.Spacing.lg + DesignSystem.Spacing.sm)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Greeting header
                    headerSection
                    
                    // Primary card: adaptive based on charter state
                    if let charter = viewModel.activeCharter {
                        activeCharterCard(charter: charter)
                    } else {
                        createCharterCard
                    }
                    
                    // Reference content: pinned checklists and guides
                    //referenceContentSection
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(greetingText)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(dateText)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return L10n.Greeting.morning
        case 12..<17:
            return L10n.Greeting.day
        case 17..<22:
            return L10n.Greeting.evening
        default:
            return L10n.Greeting.night
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    // MARK: - Primary Card: Active Charter State
    
    private func activeCharterCard(charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Badge label
            Text(L10n.homeActiveCharterTitle)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.85))
            
            // Charter name (title)
            Text(charter.name)
                .font(DesignSystem.Typography.title)
                .foregroundColor(.white)
            
            // Location with icon
            if let location = charter.location, !location.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(location)
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // .padding(DesignSystem.Spacing.cardPadding)
        // .background(DesignSystem.Colors.oceanGradient)
        // .cornerRadius(DesignSystem.Spacing.cardCornerRadiusLarge)
         .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .onTapGesture {
            //viewModel.onActiveCharterTapped(charter)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active charter")
        .accessibilityValue(charter.name)
        .accessibilityHint("Double tap to view details and checkins")
    }
    
    // MARK: - Primary Card: Create Charter State
    
    private var createCharterCard: some View {
        ActionCard(
            icon: "sailboat.fill",
            title: L10n.homeCreateCharterTitle,
            subtitle: L10n.homeCreateCharterSubtitle,
            buttonTitle: L10n.homeCreateCharterAction,
            onTap: { viewModel.onCreateCharterTapped() },
            onButtonTap: { viewModel.onCreateCharterTapped() }
        )
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(coordinator: AppCoordinator()))
}
