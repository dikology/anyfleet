import SwiftUI

// MARK: - Filter Model

struct CharterDiscoveryFilters: Equatable {
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

    /// Inclusive discovery window start (API `date_from`). Aligned to start of day when set via map helpers.
    var windowStart: Date
    /// Inclusive discovery window end (API `date_to`).
    var windowEnd: Date
    var useNearMe: Bool = false
    var radiusKm: Double = 100.0
    var sortOrder: SortOrder = .dateAscending

    init(
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        useNearMe: Bool = false,
        radiusKm: Double = 100.0,
        sortOrder: SortOrder = .dateAscending
    ) {
        let (s, e) = Self.defaultDiscoveryWindow()
        self.windowStart = windowStart ?? s
        self.windowEnd = windowEnd ?? e
        self.useNearMe = useNearMe
        self.radiusKm = radiusKm
        self.sortOrder = sortOrder
    }

    var effectiveDateFrom: Date { windowStart }
    var effectiveDateTo: Date { windowEnd }

    /// Default window: today (start of day) through the same day + 12 months (map slider track).
    static func defaultDiscoveryWindow(reference: Date = Date(), calendar: Calendar = .current) -> (Date, Date) {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.date(byAdding: .month, value: Self.mapTrackMonthSpan, to: start) ?? start
        return (start, end)
    }

    /// Months covered by the discovery map range slider (`now` → `now + span`).
    static let mapTrackMonthSpan = 12

    func isDefaultDiscoveryWindow(reference: Date = Date(), calendar: Calendar = .current) -> Bool {
        let (ds, de) = Self.defaultDiscoveryWindow(reference: reference, calendar: calendar)
        let tol: TimeInterval = 120
        return abs(windowStart.timeIntervalSince(ds)) < tol && abs(windowEnd.timeIntervalSince(de)) < tol
    }

    var dateFilterChipLabel: String {
        if isDefaultDiscoveryWindow() {
            return L10n.Charter.Discovery.Filter.DatePreset.upcoming
        }
        return shortDateWindowLabel
    }

    private var shortDateWindowLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: windowStart)) – \(f.string(from: windowEnd))"
    }

    func mapRangeMonthLabels(calendar: Calendar = .current) -> (String, String) {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return (f.string(from: windowStart), f.string(from: windowEnd))
    }

    /// Normalized thumb positions (0…1) on the fixed track from track start through +`mapTrackMonthSpan` months.
    func normalizedMapRange(reference: Date = Date(), calendar: Calendar = .current) -> (lower: Double, upper: Double) {
        let t0 = Self.mapTrackStart(reference: reference, calendar: calendar).timeIntervalSince1970
        let t1 = Self.mapTrackEnd(reference: reference, calendar: calendar).timeIntervalSince1970
        guard t1 > t0 else { return (0, 1) }
        let span = t1 - t0
        var lower = (windowStart.timeIntervalSince1970 - t0) / span
        var upper = (windowEnd.timeIntervalSince1970 - t0) / span
        lower = min(max(lower, 0), 1)
        upper = min(max(upper, 0), 1)
        if upper < lower + 0.05 {
            upper = min(lower + 0.05, 1)
        }
        return (lower, upper)
    }

    mutating func setMapWindowFromNormalized(
        lower: Double,
        upper: Double,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) {
        let t0 = Self.mapTrackStart(reference: reference, calendar: calendar).timeIntervalSince1970
        let t1 = Self.mapTrackEnd(reference: reference, calendar: calendar).timeIntervalSince1970
        guard t1 > t0 else { return }
        let span = t1 - t0
        var l = min(max(lower, 0), 1)
        var u = min(max(upper, 0), 1)
        RangeSlider.clamp(lower: &l, upper: &u, minSpan: 0.05)
        let rawStart = Date(timeIntervalSince1970: t0 + span * l)
        let rawEnd = Date(timeIntervalSince1970: t0 + span * u)
        windowStart = calendar.startOfDay(for: rawStart)
        windowEnd = calendar.startOfDay(for: rawEnd)
        if windowEnd < windowStart {
            windowEnd = windowStart
        }
    }

    mutating func applyMapDatePreset(_ preset: CharterDiscoveryMapDatePreset, reference: Date = Date(), calendar: Calendar = .current) {
        let trackStart = Self.mapTrackStart(reference: reference, calendar: calendar)
        let trackEnd = Self.mapTrackEnd(reference: reference, calendar: calendar)
        switch preset {
        case .thisWeek:
            windowStart = trackStart
            windowEnd = min(calendar.date(byAdding: .day, value: 7, to: trackStart) ?? trackEnd, trackEnd)
        case .thisMonth:
            windowStart = trackStart
            windowEnd = min(calendar.date(byAdding: .month, value: 1, to: trackStart) ?? trackEnd, trackEnd)
        case .threeMonths:
            windowStart = trackStart
            windowEnd = min(calendar.date(byAdding: .month, value: 3, to: trackStart) ?? trackEnd, trackEnd)
        case .all:
            windowStart = trackStart
            windowEnd = trackEnd
        }
        if windowEnd < windowStart { windowEnd = windowStart }
    }

    private static func mapTrackStart(reference: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: reference)
    }

    private static func mapTrackEnd(reference: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = mapTrackStart(reference: reference, calendar: calendar)
        return calendar.date(byAdding: .month, value: mapTrackMonthSpan, to: start) ?? start
    }

    var activeFilterCount: Int {
        var count = 0
        if !isDefaultDiscoveryWindow() { count += 1 }
        if useNearMe { count += 1 }
        if radiusKm != 100.0 { count += 1 }
        if sortOrder != .dateAscending { count += 1 }
        return count
    }

    var hasNonDefaultFilters: Bool { activeFilterCount > 0 }
}

// MARK: - Map-only date presets (chip row under range slider)

enum CharterDiscoveryMapDatePreset: CaseIterable {
    case thisWeek
    case thisMonth
    case threeMonths
    case all

    var localizedTitle: String {
        switch self {
        case .thisWeek: return L10n.Charter.Discovery.Filter.DatePreset.thisWeek
        case .thisMonth: return L10n.Charter.Discovery.Filter.DatePreset.thisMonth
        case .threeMonths: return L10n.Charter.Discovery.MapFilter.presetThreeMonths
        case .all: return L10n.Charter.Discovery.MapFilter.presetAll
        }
    }
}

// MARK: - Filter Sheet View (list mode — location & sort only; date is on the map bar)

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
                    mapDateHintSection
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
                    localFilters = CharterDiscoveryFilters()
                    filters = CharterDiscoveryFilters()
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

    private var mapDateHintSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.Charter.Discovery.MapFilter.dateRangeSheetHintTitle)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(L10n.Charter.Discovery.MapFilter.dateRangeSheetHintBody)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
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
                        Text("10 km").font(DesignSystem.Typography.micro)
                        Spacer()
                        Text("500 km").font(DesignSystem.Typography.micro)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
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
                .clipShape(Capsule())
                .overlay(
                    Capsule()
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
