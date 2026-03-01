import SwiftUI
import CoreLocation

/// A destination input with live autocomplete powered by `LocationSearchService`.
///
/// Usage:
/// ```swift
/// DestinationSearchField(
///     query: $viewModel.form.destinationQuery,
///     selectedPlace: $viewModel.form.selectedPlace,
///     searchService: viewModel.locationSearchService
/// )
/// ```
struct DestinationSearchField: View {
    @Binding var query: String
    @Binding var selectedPlace: PlaceResult?
    let searchService: any LocationSearchService

    @State private var suggestions: [PlaceResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var isConfirmed: Bool { selectedPlace != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            inputField
            if !suggestions.isEmpty {
                suggestionsList
            }
            if let place = selectedPlace {
                confirmedPlacePill(place)
            }
        }
    }

    // MARK: - Subviews

    private var inputField: some View {
        HStack {
            Image(systemName: isConfirmed ? "mappin.circle.fill" : "magnifyingglass")
                .foregroundColor(isConfirmed ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                .frame(width: 20)

            TextField(L10n.charterCreateChooseWhereYouWillSail, text: $query)
                .formFieldStyle()
                .onChange(of: query) { _, newValue in
                    if selectedPlace != nil && newValue != selectedPlace?.name {
                        selectedPlace = nil
                    }
                    scheduleSearch(newValue)
                }

            if isSearching {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { place in
                Button {
                    accept(place)
                } label: {
                    PlaceSuggestionRow(place: place)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, DesignSystem.Spacing.md)
            }
        }
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Spacing.sm)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }

    private func confirmedPlacePill(_ place: PlaceResult) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(DesignSystem.Colors.primary)
                .font(.caption)
            Text(place.subtitle)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.leading, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected: \(place.name), \(place.subtitle)")
    }

    // MARK: - Logic

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            suggestions = (try? await searchService.search(query: query, limit: 5)) ?? []
        }
    }

    private func accept(_ place: PlaceResult) {
        selectedPlace = place
        query = place.name
        suggestions = []
        searchTask?.cancel()
    }
}

// MARK: - Suggestion Row

private struct PlaceSuggestionRow: View {
    let place: PlaceResult

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "mappin")
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                if !place.subtitle.isEmpty {
                    Text(place.subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.name), \(place.subtitle)")
        .accessibilityHint("Double tap to select this destination")
    }
}
