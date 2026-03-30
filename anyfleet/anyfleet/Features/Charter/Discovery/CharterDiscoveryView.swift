import SwiftUI

/// Main discovery view showing public charters from the community.
/// Supports list and map view modes with date/location filters.
struct CharterDiscoveryView: View {
    @State private var viewModel: CharterDiscoveryViewModel
    /// After the user opens map once, keep `Map` in the hierarchy when switching back to list so MapKit's Metal drawable is not torn down mid-frame (avoids debug Metal asserts and occasional crashes).
    @State private var mapEverMounted = false
    @Environment(\.appCoordinator) private var coordinator
    @Environment(\.appDependencies) private var dependencies

    init(viewModel: CharterDiscoveryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            mainContent
            errorBanner
        }
        .onChange(of: viewModel.showMapView) { _, show in
            if show { mapEverMounted = true }
        }
        .navigationTitle(L10n.Charter.Discovery.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.showFilters) {
            CharterFilterView(
                filters: $viewModel.filters,
                onApply: { Task { await viewModel.applyFilters() } },
                onReset: { Task { await viewModel.resetFilters() } }
            )
        }
        .sheet(item: $viewModel.selectedCharter) { charter in
            NavigationStack {
                DiscoveredCharterDetailView(charter: charter) {
                    viewModel.selectedCharter = nil
                }
            }
        }
        .animation(DesignSystem.Motion.standard, value: viewModel.showFilters)
        .animation(DesignSystem.Motion.standard, value: viewModel.selectedCharter?.id)
        .task { await viewModel.loadInitial() }
        .refreshable {
            HapticEngine.impact(.light)
            await viewModel.refresh()
        }
        .onAppear { viewModel.requestLocationIfNeeded() }
        .onChange(of: dependencies.charterSyncService.lastSyncDate) {
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            listView
                .opacity(viewModel.showMapView ? 0 : 1)
                .allowsHitTesting(!viewModel.showMapView)

            if mapEverMounted {
                mapView
                    .opacity(viewModel.showMapView ? 1 : 0)
                    .allowsHitTesting(viewModel.showMapView)
                    .accessibilityHidden(!viewModel.showMapView)
            }
        }
    }

    private var discoveryListPhase: Int {
        if viewModel.isLoading && viewModel.charters.isEmpty { 0 }
        else if viewModel.isEmpty { 1 }
        else { 2 }
    }

    private var listView: some View {
        ZStack {
            if viewModel.isLoading && viewModel.charters.isEmpty {
                DiscoverySkeletonList()
                    .transition(.opacity)
            } else if viewModel.isEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        activeFiltersBar
                        charterList
                        loadMoreButton
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
                .background(DesignSystem.Colors.background.ignoresSafeArea())
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: discoveryListPhase)
    }

    private var mapView: some View {
        CharterMapView(charters: viewModel.charters) { charter in
            viewModel.selectedCharter = charter
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                if viewModel.showMapView {
                    MapFilterBar(
                        filters: $viewModel.filters,
                        onDebouncedApply: { viewModel.scheduleDebouncedFilterApply() },
                        onImmediateApply: { Task { await viewModel.applyFiltersImmediately() } },
                        onNearMeToggled: { viewModel.requestLocationIfNeeded() }
                    )
                }
                if viewModel.isLoading {
                    ProgressView()
                        .padding(DesignSystem.Spacing.cardPadding)
                        .glassPanel()
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
                        .padding(.top, DesignSystem.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Charter List

    private var charterList: some View {
        ForEach(viewModel.charters) { charter in
            CharterDiscoveryRow(charter: charter) {
                viewModel.selectedCharter = charter
            }
        }
    }

    private var loadMoreButton: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            } else if viewModel.hasMore && !viewModel.charters.isEmpty {
                Button(L10n.Charter.Discovery.loadMore) {
                    Task { await viewModel.loadMore() }
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding()
            }
        }
    }

    // MARK: - Active Filters Bar

    @ViewBuilder
    private var activeFiltersBar: some View {
        if viewModel.filters.activeFilterCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    FilterChip(
                        label: viewModel.filters.dateFilterChipLabel,
                        isSelected: !viewModel.filters.isDefaultDiscoveryWindow()
                    ) {
                        withAnimation(DesignSystem.Motion.spring) {
                            viewModel.showMapView = true
                        }
                    }

                    if viewModel.filters.useNearMe {
                        FilterChip(
                            label: L10n.Charter.Discovery.Filter.withinKm(Int(viewModel.filters.radiusKm)),
                            isSelected: true
                        ) {
                            viewModel.showFilters = true
                        }
                    }

                    Button {
                        Task { await viewModel.resetFilters() }
                    } label: {
                        Label(L10n.Charter.Discovery.clearAll, systemImage: "xmark.circle.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityLabel(L10n.Charter.Discovery.clearAll)
                }
            }
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            Image(systemName: "sailboat.fill")
                .font(DesignSystem.Typography.symbolPlateHero)
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.4))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(L10n.Charter.Discovery.emptyTitle)
                    .font(DesignSystem.Typography.title)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(emptyStateMessage)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            if viewModel.filters.activeFilterCount > 0 {
                Button(L10n.Charter.Discovery.clearFilters) {
                    Task { await viewModel.resetFilters() }
                }
                .buttonStyle(DesignSystem.SecondaryButtonStyle())
            }

            Spacer()
            Spacer()
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        Group {
            if viewModel.showErrorBanner, let error = viewModel.currentError {
                VStack {
                    Spacer()
                    ErrorBanner(
                        error: error,
                        onDismiss: { viewModel.clearError() },
                        onRetry: { Task { await viewModel.refresh() } }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                filterButton
                viewToggleButton
            }
        }
    }

    private var filterButton: some View {
        Button {
            viewModel.showFilters = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(DesignSystem.Typography.headlineRegular)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if viewModel.filters.activeFilterCount > 0 {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel(L10n.Charter.Discovery.Filter.title)
    }

    private var viewToggleButton: some View {
        Button {
            withAnimation(DesignSystem.Motion.standard) {
                viewModel.showMapView.toggle()
            }
        } label: {
            Image(systemName: viewModel.showMapView ? "list.bullet" : "map")
                .font(DesignSystem.Typography.headlineRegular)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Helpers

    private var emptyStateMessage: String {
        if viewModel.filters.activeFilterCount > 0 {
            return L10n.Charter.Discovery.emptyFiltered
        }
        if viewModel.filters.useNearMe {
            return L10n.Charter.Discovery.emptyNearby
        }
        return L10n.Charter.Discovery.emptyDefault
    }
}

// MARK: - Skeleton list

private struct DiscoverySkeletonList: View {
    @State private var animating = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    SyncedCharterSkeletonRow(animating: animating)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(DesignSystem.Motion.skeleton) {
                animating = true
            }
        }
    }
}

private struct SyncedCharterSkeletonRow: View {
    let animating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                DesignSystem.SkeletonBlock(width: 32, height: 32, animating: animating)
                DesignSystem.SkeletonBlock(width: 24, height: 11, animating: animating)
            }
            .frame(width: 48)
            .padding(.top, DesignSystem.Spacing.md)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    DesignSystem.SkeletonBlock(width: 72, height: 20, animating: animating)
                    Spacer()
                    DesignSystem.SkeletonBlock(width: 56, height: 16, animating: animating)
                }
                DesignSystem.SkeletonBlock(height: 18, animating: animating)
                DesignSystem.SkeletonBlock(width: 160, height: 14, animating: animating)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}
