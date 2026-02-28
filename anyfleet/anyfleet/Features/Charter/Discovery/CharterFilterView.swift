import SwiftUI

// MARK: - Filter Model

struct CharterDiscoveryFilters: Equatable {
    enum DatePreset: String, CaseIterable {
        case upcoming = "Upcoming"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case custom = "Custom"

        var localizedLabel: String {
            switch self {
            case .upcoming: return L10n.Charter.Discovery.Filter.DatePreset.upcoming
            case .thisWeek: return L10n.Charter.Discovery.Filter.DatePreset.thisWeek
            case .thisMonth: return L10n.Charter.Discovery.Filter.DatePreset.thisMonth
            case .custom: return L10n.Charter.Discovery.Filter.DatePreset.custom
            }
        }

        var dateRange: (Date, Date)? {
            let now = Date()
            let cal = Calendar.current
            switch self {
            case .upcoming:
                return (now, cal.date(byAdding: .year, value: 1, to: now) ?? now)
            case .thisWeek:
                return (now, cal.date(byAdding: .day, value: 7, to: now) ?? now)
            case .thisMonth:
                return (now, cal.date(byAdding: .month, value: 1, to: now) ?? now)
            case .custom:
                return nil
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case dateAscending = "Date (Earliest First)"
        case distanceAscending = "Distance (Closest First)"
        case recentlyPosted = "Recently Posted"

        var localizedLabel: String {
            switch self {
            case .dateAscending: return L10n.Charter.Discovery.Filter.SortOrder.dateAscending
            case .distanceAscending: return L10n.Charter.Discovery.Filter.SortOrder.distanceAscending
            case .recentlyPosted: return L10n.Charter.Discovery.Filter.SortOrder.recentlyPosted
            }
        }
    }

    var datePreset: DatePreset = .upcoming
    var customDateFrom: Date = Date()
    var customDateTo: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var useNearMe: Bool = false
    var radiusKm: Double = 100.0
    var sortOrder: SortOrder = .dateAscending

    var effectiveDateFrom: Date {
        datePreset == .custom ? customDateFrom : (datePreset.dateRange?.0 ?? Date())
    }

    var effectiveDateTo: Date {
        datePreset == .custom ? customDateTo : (datePreset.dateRange?.1 ?? Date())
    }

    var activeFilterCount: Int {
        var count = 0
        if datePreset != .upcoming { count += 1 }
        if useNearMe { count += 1 }
        if radiusKm != 100.0 { count += 1 }
        if sortOrder != .dateAscending { count += 1 }
        return count
    }

    static let `default` = CharterDiscoveryFilters()
}

// MARK: - Filter Sheet View

struct CharterFilterView: View {
    @Binding var filters: CharterDiscoveryFilters
    let onApply: () -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localFilters: CharterDiscoveryFilters

    init(filters: Binding<CharterDiscoveryFilters>, onApply: @escaping () -> Void, onReset: @escaping () -> Void) {
        self._filters = filters
        self.onApply = onApply
        self.onReset = onReset
        self._localFilters = State(initialValue: filters.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    dateSection
                    locationSection
                    sortSection
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle(L10n.Charter.Discovery.Filter.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Charter.Discovery.Filter.apply) {
                        filters = localFilters
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(L10n.Charter.Discovery.Filter.reset) {
                    localFilters = .default
                    filters = .default
                    onReset()
                    dismiss()
                }
                .foregroundColor(DesignSystem.Colors.error)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.background)
            }
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.Filter.sectionDateRange)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(CharterDiscoveryFilters.DatePreset.allCases, id: \.self) { preset in
                        FilterChip(
                            label: preset.localizedLabel,
                            isSelected: localFilters.datePreset == preset
                        ) {
                            localFilters.datePreset = preset
                        }
                    }
                }
            }

            if localFilters.datePreset == .custom {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    DatePicker(L10n.charterCreateFrom, selection: $localFilters.customDateFrom, displayedComponents: .date)
                        .font(DesignSystem.Typography.body)
                    DatePicker(L10n.charterCreateTo, selection: $localFilters.customDateTo,
                               in: localFilters.customDateFrom...,
                               displayedComponents: .date)
                        .font(DesignSystem.Typography.body)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.Spacing.sm)
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.Filter.sectionLocation)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Toggle(isOn: $localFilters.useNearMe) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Charter.Discovery.Filter.nearMe)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(L10n.Charter.Discovery.Filter.nearMeSubtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.primary)

            if localFilters.useNearMe {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text(L10n.Charter.Discovery.Filter.searchRadius)
                            .font(DesignSystem.Typography.body)
                        Spacer()
                        Text(radiusLabel(localFilters.radiusKm))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Slider(value: $localFilters.radiusKm, in: 10...500, step: 10)
                        .tint(DesignSystem.Colors.primary)
                    HStack {
                        Text("10 km").font(.caption2)
                        Spacer()
                        Text("500 km").font(.caption2)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.Filter.sectionSortBy)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ForEach(CharterDiscoveryFilters.SortOrder.allCases, id: \.self) { sort in
                Button {
                    localFilters.sortOrder = sort
                } label: {
                    HStack {
                        Text(sort.localizedLabel)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Spacer()
                        if localFilters.sortOrder == sort {
                            Image(systemName: "checkmark")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                if sort != CharterDiscoveryFilters.SortOrder.allCases.last {
                    Divider()
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Spacing.sm)
    }

    private func radiusLabel(_ km: Double) -> String {
        km >= 500 ? L10n.Charter.Discovery.Filter.anyDistance : "\(Int(km)) km"
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    isSelected
                        ? DesignSystem.Colors.primary.opacity(0.12)
                        : DesignSystem.Colors.surface
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? DesignSystem.Colors.primary.opacity(0.4) : DesignSystem.Colors.border,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
