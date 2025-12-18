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
                    
                    // Primary card: adaptive based on charter state
                    if let charter = viewModel.activeCharter {
                        activeCharterCard(charter: charter)
                    } else {
                        createCharterCard
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

    // MARK: - Primary Card: Active Charter State
    
    private func activeCharterCard(charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
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
        .padding(DesignSystem.Spacing.cardPadding)
        .background(DesignSystem.Gradients.ocean)
        .cornerRadius(DesignSystem.Spacing.cardCornerRadiusLarge)
        .shadow(color: DesignSystem.Colors.shadowStrong, radius: 12, y: 6)
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .onTapGesture {
            viewModel.onActiveCharterTapped(charter)
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
        // Navigate to the appropriate editor in the Library tab for now.
        viewModel.onPinnedItemTapped(item)
    }
}

#Preview {
    // Simple preview wiring with real dependencies
    let dependencies = AppDependencies()
    let coordinator = AppCoordinator()
    let viewModel = HomeViewModel(
        coordinator: coordinator,
        charterStore: dependencies.charterStore,
        libraryStore: dependencies.libraryStore
    )
    return HomeView(viewModel: viewModel)
        .environment(dependencies)
}
