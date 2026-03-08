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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Greeting header
                    headerSection
                    
                    // Primary hero card: active → next → create
                    if let charter = viewModel.activeCharter {
                        heroCharterCard(charter: charter, badge: L10n.homeActiveCharterTitle)
                    } else if let next = viewModel.nextCharter {
                        heroCharterCard(charter: next, badge: L10n.homeNextCharterTitle)
                    } else {
                        createCharterCard
                    }
                    
                    // Upcoming strip: shown when no active charter and 2+ upcoming (first is in hero)
                    if viewModel.activeCharter == nil, viewModel.upcomingCharters.count > 1 {
                        upcomingStripSection
                    }
                    
                    Spacer()
                    
                    // Reference content: pinned library items
                    if !viewModel.pinnedLibraryItems.isEmpty {
                        referenceContentSection
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .task {
                await viewModel.refresh()
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

    // MARK: - Hero Charter Card (Active or Next)
    
    private func heroCharterCard(charter: CharterModel, badge: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Badge pill
            Text(badge.uppercased())
                .font(DesignSystem.Typography.micro)
                .fontWeight(.semibold)
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.primary.opacity(0.9))
                .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
            
            Spacer(minLength: 0)
            
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
            
            // Time until start (for next charter)
            if charter.isUpcoming, !charter.timeUntilStartDisplay.isEmpty {
                Text(charter.timeUntilStartDisplay)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // View Charter button
            HStack {
                Spacer()
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(L10n.homeViewCharter)
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.oceanDeep)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .background(Color.white)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: DesignSystem.Spacing.featuredCardHeight)
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            ZStack {
                Image("HeroCardBackground")
                    .resizable()
                    .scaledToFill()
                    .clipped()
                DesignSystem.Gradients.heroImageOverlay
            }
        )
        .cornerRadius(DesignSystem.Spacing.cardCornerRadiusLarge)
        .shadow(color: DesignSystem.Colors.shadowStrong, radius: 12, y: 6)
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .onTapGesture {
            if charter.isUpcoming {
                viewModel.onUpcomingCharterTapped(charter)
            } else {
                viewModel.onActiveCharterTapped(charter)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge == L10n.homeActiveCharterTitle ? "Active charter" : "Next charter")
        .accessibilityValue(charter.name)
        .accessibilityHint("Double tap to view details")
    }
    
    // MARK: - Upcoming Strip
    
    private var upcomingStripSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(L10n.homeUpcomingTripsTitle, subtitle: nil)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(chartersForStrip) { charter in
                        upcomingStripCard(charter: charter)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .padding(.horizontal, -DesignSystem.Spacing.screenPadding)
        }
    }
    
    /// Charters to show in strip: all upcoming except the first (which is in hero when no active).
    private var chartersForStrip: [CharterModel] {
        guard viewModel.activeCharter == nil else { return [] }
        let upcoming = viewModel.upcomingCharters
        return Array(upcoming.dropFirst())
    }
    
    private func upcomingStripCard(charter: CharterModel) -> some View {
        Button {
            viewModel.onUpcomingCharterTapped(charter)
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(charter.timeUntilStartDisplay)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(charter.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                }
                
                if let location = charter.location, !location.isEmpty {
                    Text(location)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(color: DesignSystem.Colors.shadowStrong.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                    .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upcoming charter")
        .accessibilityValue(charter.name)
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
    
    // MARK: - Pinned Content Section
    
    private var referenceContentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionHeader(
                "📌 " + L10n.homePinnedContentTitle,
                subtitle: L10n.homePinnedContentSubtitle
            )
            
            let items = viewModel.pinnedLibraryItems
            let columns = [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
            ]
            
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                ForEach(items.prefix(6)) { item in
                    Button {
                        // For now, open in the Library tab using edit flows
                        onPinnedItemTapped(item)
                    } label: {
                        pinnedItemCard(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }
    
    @ViewBuilder
    private func pinnedItemCard(_ item: LibraryModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.18),
                                    DesignSystem.Colors.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: item.type.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(item.type.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.border.opacity(0.4))
                        )
                }
                
                Spacer()
            }
            
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignSystem.Colors.surface)
                .shadow(
                    color: DesignSystem.Colors.shadowStrong.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.border.opacity(0.7),
                            DesignSystem.Colors.border.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func onPinnedItemTapped(_ item: LibraryModel) {
        // Navigate to the appropriate reader view in the Library tab.
        viewModel.onPinnedItemTapped(item)
    }
}

#Preview {
    MainActor.assumeIsolated {
        // Simple preview wiring with real dependencies
        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = HomeViewModel(
            coordinator: coordinator,
            charterStore: dependencies.charterStore,
            libraryStore: dependencies.libraryStore
        )
        return HomeView(viewModel: viewModel)
            .environment(dependencies)
    }
}
