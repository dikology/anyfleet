import SwiftUI
import UIKit

/// Horizontal filter strip for charter discovery **map** mode (date window, near me, sort, reset).
struct MapFilterBar: View {
    @Binding var filters: CharterDiscoveryFilters
    var onDebouncedApply: () -> Void
    var onImmediateApply: () -> Void
    var onNearMeToggled: () -> Void

    @State private var showDatePanel = false
    @State private var lowerN = 0.0
    @State private var upperN = 1.0
    /// Avoid treating programmatic slider sync as a user drag (prevents redundant API calls when opening the panel).
    @State private var suppressSliderCommit = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    FilterChip(
                        label: L10n.Charter.Discovery.MapFilter.dateRangeChip,
                        isSelected: showDatePanel || !filters.isDefaultDiscoveryWindow()
                    ) {
                        showDatePanel.toggle()
                        if showDatePanel { syncNormalizedFromFilters() }
                    }

                    FilterChip(
                        label: L10n.Charter.Discovery.Filter.nearMe,
                        isSelected: filters.useNearMe
                    ) {
                        var f = filters
                        f.useNearMe.toggle()
                        filters = f
                        if filters.useNearMe { onNearMeToggled() }
                        onImmediateApply()
                    }

                    Menu {
                        ForEach(CharterDiscoveryFilters.SortOrder.allCases, id: \.self) { order in
                            Button {
                                var f = filters
                                f.sortOrder = order
                                filters = f
                                selectionHaptic()
                                onImmediateApply()
                            } label: {
                                HStack {
                                    Text(order.localizedLabel)
                                    if filters.sortOrder == order {
                                        Spacer(minLength: 8)
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        sortMenuLabel
                    }

                    if filters.hasNonDefaultFilters {
                        Button {
                            filters = CharterDiscoveryFilters()
                            showDatePanel = false
                            syncNormalizedFromFilters()
                            onImmediateApply()
                        } label: {
                            Text(L10n.Charter.Discovery.MapFilter.resetChip)
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if showDatePanel {
                datePanel
            }

            if filters.useNearMe {
                nearMeRadiusRow
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background.opacity(0.94),
                    DesignSystem.Colors.background.opacity(0.65),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onChange(of: filters.windowStart) { _, _ in
            if showDatePanel { syncNormalizedFromFilters() }
        }
        .onChange(of: filters.windowEnd) { _, _ in
            if showDatePanel { syncNormalizedFromFilters() }
        }
    }

    private var sortMenuLabel: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(L10n.Charter.Discovery.MapFilter.sortChip)
            Image(systemName: "chevron.down")
                .font(DesignSystem.Typography.micro)
        }
        .font(DesignSystem.Typography.caption)
        .fontWeight(filters.sortOrder == .dateAscending ? .regular : .semibold)
        .foregroundColor(filters.sortOrder == .dateAscending ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primary)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            filters.sortOrder == .dateAscending
                ? DesignSystem.Colors.surface
                : DesignSystem.Colors.primary.opacity(0.12)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    filters.sortOrder == .dateAscending ? DesignSystem.Colors.border : DesignSystem.Colors.primary.opacity(0.4),
                    lineWidth: 1
                )
        )
    }

    private var datePanel: some View {
        let caps = filters.mapRangeMonthLabels()
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(L10n.Charter.Discovery.Filter.sectionDateRange)
                .font(DesignSystem.Typography.subheader)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            RangeSlider(
                lower: $lowerN,
                upper: $upperN,
                minSpan: 0.05,
                lowerCaption: caps.0,
                upperCaption: caps.1
            )
            .onChange(of: lowerN) { _, _ in
                if !suppressSliderCommit { commitSliderWindow() }
            }
            .onChange(of: upperN) { _, _ in
                if !suppressSliderCommit { commitSliderWindow() }
            }

            HStack {
                Text(L10n.Charter.Discovery.MapFilter.trackNow)
                Spacer()
                Text(L10n.Charter.Discovery.MapFilter.trackPlusOneYear)
            }
            .font(DesignSystem.Typography.micro)
            .foregroundStyle(DesignSystem.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(CharterDiscoveryMapDatePreset.allCases, id: \.self) { preset in
                        FilterChip(
                            label: preset.localizedTitle,
                            isSelected: false
                        ) {
                            var f = filters
                            f.applyMapDatePreset(preset)
                            filters = f
                            syncNormalizedFromFilters()
                            selectionHaptic()
                            onImmediateApply()
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: 360)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadiusLarge, style: .continuous)
                .stroke(DesignSystem.Colors.border.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var nearMeRadiusRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(L10n.Charter.Discovery.Filter.searchRadius)
                    .font(DesignSystem.Typography.caption)
                Spacer()
                Text(radiusCaption(filters.radiusKm))
                    .font(DesignSystem.Typography.micro)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Slider(value: Binding(
                get: { filters.radiusKm },
                set: { new in
                    var f = filters
                    f.radiusKm = new
                    filters = f
                    onDebouncedApply()
                }
            ), in: 10...500, step: 10)
            .tint(DesignSystem.Colors.primary)
            HStack {
                Text("10 km").font(DesignSystem.Typography.micro)
                Spacer()
                Text("500 km").font(DesignSystem.Typography.micro)
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous))
    }

    private func radiusCaption(_ km: Double) -> String {
        km >= 500 ? L10n.Charter.Discovery.Filter.anyDistance : "\(Int(km)) km"
    }

    private func syncNormalizedFromFilters() {
        suppressSliderCommit = true
        let pair = filters.normalizedMapRange()
        lowerN = pair.lower
        upperN = pair.upper
        DispatchQueue.main.async {
            suppressSliderCommit = false
        }
    }

    private func commitSliderWindow() {
        var f = filters
        f.setMapWindowFromNormalized(lower: lowerN, upper: upperN)
        filters = f
        onDebouncedApply()
    }

    private func selectionHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
