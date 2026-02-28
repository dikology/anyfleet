import SwiftUI

/// Main discovery view showing public charters from the community.
/// Supports list and map view modes with date/location filters.
struct CharterDiscoveryView: View {
    @State private var viewModel: CharterDiscoveryViewModel
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
        .navigationTitle("Discover Charters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.showFilters) {
            CharterFilterView(
                filters: $viewModel.filters,
                onApply: { Task { await viewModel.applyFilters() } },
                onReset: { viewModel.resetFilters() }
            )
        }
        .sheet(item: $viewModel.selectedCharter) { charter in
            NavigationStack {
                DiscoveredCharterDetailView(charter: charter) {
                    viewModel.selectedCharter = nil
                }
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.refresh() }
        .onAppear { viewModel.requestLocationIfNeeded() }
        .onChange(of: dependencies.charterSyncService.lastSyncDate) {
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.showMapView {
            mapView
        } else {
            listView
        }
    }

    private var listView: some View {
        Group {
            if viewModel.isEmpty {
                emptyState
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
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.charters.isEmpty {
                loadingState
            }
        }
    }

    private var mapView: some View {
        CharterMapView(charters: viewModel.charters) { charter in
            viewModel.selectedCharter = charter
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.top, 8)
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
                Button("Load More") {
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
                        label: viewModel.filters.datePreset.rawValue,
                        isSelected: viewModel.filters.datePreset != .upcoming
                    ) {
                        viewModel.showFilters = true
                    }

                    if viewModel.filters.useNearMe {
                        FilterChip(
                            label: "Within \(Int(viewModel.filters.radiusKm)) km",
                            isSelected: true
                        ) {
                            viewModel.showFilters = true
                        }
                    }

                    Button {
                        viewModel.resetFilters()
                    } label: {
                        Label("Clear all", systemImage: "xmark.circle.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityLabel("Clear all filters")
                }
            }
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            Image(systemName: "sailboat")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.4))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Charters Found")
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
                Button("Clear Filters") {
                    viewModel.resetFilters()
                }
                .buttonStyle(DesignSystem.SecondaryButtonStyle())
                .accessibilityHint("Remove all active filters to see more results")
            }

            Spacer()
            Spacer()
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Discovering charters...")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
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
                    .font(.system(size: 17))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if viewModel.filters.activeFilterCount > 0 {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .accessibilityLabel("Filters")
        .accessibilityValue(viewModel.filters.activeFilterCount > 0
            ? "\(viewModel.filters.activeFilterCount) active"
            : "none active")
        .accessibilityHint("Double tap to open filter options")
    }

    private var viewToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.showMapView.toggle()
            }
        } label: {
            Image(systemName: viewModel.showMapView ? "list.bullet" : "map")
                .font(.system(size: 17))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .accessibilityLabel(viewModel.showMapView ? "Switch to list view" : "Switch to map view")
        .accessibilityHint("Toggle between list and map display")
    }

    // MARK: - Helpers

    private var emptyStateMessage: String {
        if viewModel.filters.activeFilterCount > 0 {
            return "No charters match your current filters. Try adjusting your date range or location."
        }
        if viewModel.filters.useNearMe {
            return "No public charters found nearby. Try expanding your search radius."
        }
        return "No public charters are available right now. Check back soon!"
    }
}
