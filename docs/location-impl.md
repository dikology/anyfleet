# Location Intelligence & Destination Mapping — Implementation Plan

> **Scope:** Charter destination input, place autocomplete, coordinate capture, map display, and discovery geo-filtering across the iOS app and Python backend.  
> **Audience:** Inexperienced-to-intermediate iOS engineer joining the feature.

---

## 1. High-Level Review

### What this feature is responsible for

The destination/location subsystem spans charter creation, storage, sync, and community discovery:

- **Input:** User types a free-text destination in `CharterEditorView` → stored as `CharterFormState.destination: String`.
- **Persistence:** `CharterModel` carries `latitude`, `longitude`, `locationPlaceID` fields, but they are **never populated** — the entire geocoordinate scaffold exists in both the iOS model and the backend DB schema yet the data flow that fills it is missing.
- **Sync:** `CharterSyncService` sends `locationText` only; `latitude`/`longitude` are always `nil` in the payload.
- **Display:** `CharterMapView` renders annotations for discoverable charters; `MapPreviewThumbnail` shows a pin in the detail view. Both exist and work — but they only show charters that already have coordinates, which is currently no charter.

### Top-ranked problems

| # | Problem | Severity |
|---|---------|----------|
| 1 | **No autocomplete / geocoding** — `CharterFormState.destination` is free text; coordinates are never set, making the entire geo-discovery pipeline inert. | Critical |
| 2 | **Force-unwrap in `CharterMapView`** — `MapAnnotation(coordinate: charter.coordinate!)` crashes if a charter with `hasLocation == true` somehow has a nil coordinate. | High |
| 3 | **Deprecated MapKit APIs** — `Map(coordinateRegion:)`, `MapMarker`, and `MapAnnotation` are deprecated in iOS 17. `Map` selection API (`Map(selection:)`) and `Marker` / `Annotation` should be used. | High |
| 4 | **`loadCharter()` does not restore coordinates** — editing an existing charter loses `latitude`/`longitude` on round-trip because `CharterEditorViewModel.loadCharter()` maps only `location` text back to `form.destination`, discarding coordinate fields. | Medium |
| 5 | **`CharterFormState` conflates concerns** — the struct holds form input state, static region/vessel option lists, and date formatting. Region options are fully defined but `RegionPickerSection` is commented out, creating dead code. | Medium |
| 6 | **No location service abstraction** — no protocol, no injectable dependency, no test seam for place search. | Medium |
| 7 | **`calculateProgress()` ignores destination** — filling in a destination does not advance the form completion bar, signalling it is not considered important. | Low |

### Proposed refactor plan (8 steps)

1. **Define a `PlaceResult` domain model** — canonical, `Sendable` struct capturing everything returned from a place search.
2. **Create `LocationSearchService` protocol + `MKLocalSearchService` implementation** — injectable, testable, zero third-party SDK dependency.
3. **Update `CharterFormState`** — replace `destination: String` with `selectedPlace: PlaceResult?` and a separate `destinationText: String` for the live search query.
4. **Build `DestinationSearchField` view component** — reusable, self-contained SwiftUI view with search input, debounced suggestions list, and selected-state display.
5. **Update `CharterEditorViewModel`** — wire `LocationSearchService`, populate coordinates on save, restore them on load.
6. **Migrate deprecated MapKit APIs** — replace `Map(coordinateRegion:)` / `MapMarker` / `MapAnnotation` with the iOS 17 `Map` API across `CharterMapView` and `MapPreviewThumbnail`.
7. **Register `LocationSearchService` in `AppDependencies`** — inject it into `CharterEditorViewModel`.
8. **(Backend, optional) Add `/places/search` proxy endpoint** — if you want server-side place validation or want to avoid the Apple Maps dependency on device; skip for MVP.

---

## 2. Architecture & Patterns

### Target layer diagram

```
UI (CharterEditorView)
  └─ DestinationSearchField          ← new reusable component
       └─ CharterEditorViewModel     ← owns form state + orchestrates
            ├─ LocationSearchService ← new protocol (place search)
            └─ CharterStore          ← existing persistence
                  └─ CharterRepository
                       └─ AppDatabase (GRDB)
```

The `LocationSearchService` sits at the **Service** layer — it wraps MapKit and is injected via `AppDependencies`. The ViewModel never imports MapKit; it works with the protocol type only.

### Key decisions

- **No new singleton.** `LocationSearchService` is created in `AppDependencies.init()` and injected.
- **Single source of truth for selected place.** `CharterFormState.selectedPlace: PlaceResult?` is the only place that holds the chosen location; `latitude`/`longitude` are derived from it at save time, not stored separately in the form.
- **MKLocalSearch over third-party SDK.** Zero new dependencies, works offline against cached data, acceptable accuracy for yacht harbors.

---

## 3. Step-by-Step Implementation

### Step 1 — `PlaceResult` domain model

**File:** `Core/Models/PlaceResult.swift` (new)

```swift
import CoreLocation

/// A geocoded place returned from a location search.
/// Immutable, `Sendable`, and independent of MapKit types.
struct PlaceResult: Identifiable, Hashable, Sendable {
    let id: String          // stable place identifier (MKMapItem.identifier or constructed)
    let name: String        // display name, e.g. "Santorini"
    let subtitle: String    // region context, e.g. "South Aegean, Greece"
    let coordinate: CLLocationCoordinate2D
    let countryCode: String?

    // CLLocationCoordinate2D is not Hashable — hash on id + coords
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
```

**Rationale:** Keeping the domain model free of MapKit means ViewModels and tests never import `MapKit`; `MKMapItem` stays confined to the service implementation.

---

### Step 2 — `LocationSearchService` protocol + implementation

**File:** `Services/LocationSearchService.swift` (new)

```swift
import MapKit

// MARK: - Protocol

protocol LocationSearchService: Sendable {
    /// Returns up to `limit` place suggestions for the given query string.
    func search(query: String, limit: Int) async throws -> [PlaceResult]
}

// MARK: - MapKit implementation

final class MKLocationSearchService: LocationSearchService {
    func search(query: String, limit: Int = 5) async throws -> [PlaceResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        // Bias toward nautical regions — no hard filter so we don't drop valid results
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.0, longitude: 20.0),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.prefix(limit).map { item in
            let id = item.identifier?.rawValue
                ?? "\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)"
            return PlaceResult(
                id: id,
                name: item.name ?? item.placemark.locality ?? "Unknown",
                subtitle: [
                    item.placemark.administrativeArea,
                    item.placemark.country
                ].compactMap { $0 }.joined(separator: ", "),
                coordinate: item.placemark.coordinate,
                countryCode: item.placemark.isoCountryCode
            )
        }
    }
}

// MARK: - Test double

/// Stub for unit tests — returns a fixed list without hitting MapKit.
final class MockLocationSearchService: LocationSearchService {
    var stubbedResults: [PlaceResult] = []
    var stubbedError: Error?

    func search(query: String, limit: Int) async throws -> [PlaceResult] {
        if let error = stubbedError { throw error }
        return Array(stubbedResults.prefix(limit))
    }
}
```

**Rationale:** Protocol + concrete type lets you inject `MockLocationSearchService` in tests and swap providers (e.g., Google Places) without touching the ViewModel.

---

### Step 3 — Update `CharterFormState`

**Affected file:** `Features/Charter/CharterFormState.swift`

Replace `destination: String` with:

```swift
// Replace this:
var destination: String = ""
var region: String = ""

// With this:
/// Free-text query driving live autocomplete.
var destinationQuery: String = ""
/// The user-confirmed geocoded place. Nil until a suggestion is accepted.
var selectedPlace: PlaceResult?

/// Convenience accessor for display and sync.
var destinationText: String {
    selectedPlace?.name ?? destinationQuery
}
```

Also update `calculateProgress` reference in `CharterEditorViewModel` (see Step 5) and `CharterSummaryCard` if it reads `form.destination`.

Update mock:

```swift
static var mock: CharterFormState {
    var state = CharterFormState()
    state.selectedPlace = PlaceResult(
        id: "GR-santorini",
        name: "Santorini",
        subtitle: "South Aegean, Greece",
        coordinate: CLLocationCoordinate2D(latitude: 36.3932, longitude: 25.4615),
        countryCode: "GR"
    )
    state.destinationQuery = "Santorini"
    // ... rest unchanged
    return state
}
```

**Rationale:** Separating the live query string from the confirmed result prevents stale coordinates when the user edits text after a selection. The computed `destinationText` keeps downstream code (sync, display) unchanged.

---

### Step 4 — `DestinationSearchField` component

**File:** `Features/Charter/Components/DestinationSearchField.swift` (new)

```swift
import SwiftUI
import CoreLocation

/// A destination input with live autocomplete powered by `LocationSearchService`.
///
/// Usage:
/// ```swift
/// DestinationSearchField(
///     query: $viewModel.form.destinationQuery,
///     selectedPlace: $viewModel.form.selectedPlace,
///     searchService: locationSearchService
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
                        selectedPlace = nil   // user edited after selection — reset
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
            try? await Task.sleep(for: .milliseconds(300))   // 300ms debounce
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
```

**Rationale:** Encapsulating search state, debounce logic, and the two-phase input (query → confirmed) inside a focused component keeps `CharterEditorView` simple. The confirmed-state pill provides clear feedback that coordinates were captured.

---

### Step 5 — Update `CharterEditorViewModel`

**Affected file:** `Features/Charter/CharterEditorViewModel.swift`

#### 5a — Inject `LocationSearchService`

```swift
// Add to dependencies section
private let locationSearchService: any LocationSearchService

init(
    charterStore: CharterStore,
    charterSyncService: CharterSyncService? = nil,
    locationSearchService: any LocationSearchService = MKLocationSearchService(),
    charterID: UUID? = nil,
    onDismiss: @escaping () -> Void,
    initialForm: CharterFormState? = nil
) {
    self.charterStore = charterStore
    self.charterSyncService = charterSyncService
    self.locationSearchService = locationSearchService
    self.charterID = charterID
    self.onDismiss = onDismiss
    self.form = initialForm ?? CharterFormState()
}
```

#### 5b — Restore coordinates when loading an existing charter

```swift
func loadCharter() async {
    guard let charterID, !isNewCharter else { return }
    isLoading = true
    defer { isLoading = false }

    do {
        let charter = try await charterStore.fetchCharter(charterID)
        form.name = charter.name
        form.startDate = charter.startDate
        form.endDate = charter.endDate
        form.vessel = charter.boatName ?? ""
        form.visibility = charter.visibility

        // Restore geocoded place if available
        if let lat = charter.latitude,
           let lon = charter.longitude,
           let locationText = charter.location {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            form.selectedPlace = PlaceResult(
                id: charter.locationPlaceID ?? "\(lat),\(lon)",
                name: locationText,
                subtitle: "",
                coordinate: coordinate,
                countryCode: nil
            )
            form.destinationQuery = locationText
        } else {
            form.destinationQuery = charter.location ?? ""
        }
    } catch {
        handleError(error)
    }
}
```

#### 5c — Pass coordinates when saving

In `saveCharter()`, replace the `location:` parameter usage with:

```swift
// When creating:
var charter = try await charterStore.createCharter(
    name: charterName,
    boatName: form.vessel.isEmpty ? nil : form.vessel,
    location: form.destinationText.isEmpty ? nil : form.destinationText,
    latitude: form.selectedPlace?.coordinate.latitude,
    longitude: form.selectedPlace?.coordinate.longitude,
    locationPlaceID: form.selectedPlace?.id,
    startDate: form.startDate,
    endDate: form.endDate,
    checkInChecklistID: nil
)

// When updating — same pattern for updateCharter()
```

> **Note:** `CharterStore.createCharter()` and `updateCharter()` need new `latitude`, `longitude`, `locationPlaceID` parameters. Trace through `CharterStore → CharterRepository → CharterRecord` and add the fields there too (they are already in the DB schema).

#### 5d — Count destination in progress

```swift
private func calculateProgress() -> Double {
    let total = 5.0
    var count = 0.0
    if !form.name.isEmpty { count += 1 }
    if form.startDate != .now { count += 1 }
    if form.endDate != .now { count += 1 }
    if !form.vessel.isEmpty { count += 1 }
    if form.selectedPlace != nil || !form.destinationQuery.isEmpty { count += 1 }
    return count / total
}
```

---

### Step 6 — Update `CharterEditorView` — replace `TextField` with `DestinationSearchField`

**Affected file:** `Features/Charter/CharterEditorView.swift`

```swift
// Replace lines 31-38:
DesignSystem.Form.Section(title: L10n.charterCreateDestination, subtitle: L10n.charterCreateChooseWhereYouWillSail) {
    DestinationSearchField(
        query: $viewModel.form.destinationQuery,
        selectedPlace: $viewModel.form.selectedPlace,
        searchService: viewModel.locationSearchService
    )
}
```

Make `viewModel.locationSearchService` accessible (either `internal` visibility on the property, or expose a passthrough computed var).

---

### Step 7 — Migrate deprecated MapKit APIs

#### 7a — `CharterMapView.swift`

The existing code uses the deprecated `Map(coordinateRegion:annotationItems:)` + `MapAnnotation`. Replace with the iOS 17 `Map` API:

```swift
import SwiftUI
import MapKit

struct CharterMapView: View {
    let charters: [DiscoverableCharter]
    let onSelectCharter: (DiscoverableCharter) -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCharterID: UUID?

    private var chartersWithLocation: [DiscoverableCharter] {
        charters.filter { $0.hasLocation }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedCharterID) {
                ForEach(chartersWithLocation) { charter in
                    if let coordinate = charter.coordinate {
                        Annotation(charter.name, coordinate: coordinate, anchor: .bottom) {
                            CharterMapAnnotation(
                                charter: charter,
                                isSelected: selectedCharterID == charter.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCharterID = charter.id
                                }
                            }
                        }
                        .tag(charter.id)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear { fitMapToCharters() }
            .onChange(of: charters.count) { fitMapToCharters() }

            if let id = selectedCharterID,
               let charter = charters.first(where: { $0.id == id }) {
                CharterMapCallout(charter: charter) {
                    onSelectCharter(charter)
                } onDismiss: {
                    withAnimation { selectedCharterID = nil }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Dismiss callout when tapping empty map area
        .onChange(of: selectedCharterID) { id in
            if id == nil { /* already dismissed */ }
        }
    }

    private func fitMapToCharters() {
        guard !chartersWithLocation.isEmpty else { return }
        let lats = chartersWithLocation.compactMap { $0.latitude }
        let lons = chartersWithLocation.compactMap { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 1.0),
                                   longitudeDelta: max((maxLon - minLon) * 1.4, 1.0))
        )
        withAnimation { position = .region(region) }
    }
}
```

Key changes:
- `Map(position:selection:)` replaces deprecated `Map(coordinateRegion:annotationItems:)`
- `Annotation` replaces `MapAnnotation`
- `MapCameraPosition` replaces `MKCoordinateRegion` state
- Force-unwrap `charter.coordinate!` is eliminated — guard-let inside `ForEach`
- `charters_with_location` renamed to `chartersWithLocation` (Swift naming convention)

#### 7b — `MapPreviewThumbnail.swift`

```swift
import SwiftUI
import MapKit

struct MapPreviewThumbnail: View {
    let coordinate: CLLocationCoordinate2D
    var height: CGFloat = 120
    var annotationTitle: String = ""

    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        )) {
            Marker(annotationTitle, coordinate: coordinate)
                .tint(DesignSystem.Colors.primary)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm))
        .disabled(true)
        .allowsHitTesting(false)
        .accessibilityLabel("Map preview showing destination: \(annotationTitle)")
        .accessibilityHidden(true)
    }
}
```

Key changes:
- `Map(initialPosition:)` replaces `Map(coordinateRegion:)` — `@State` region binding is no longer needed
- `Marker` replaces deprecated `MapMarker`
- `allowsHitTesting(false)` is more explicit than `.disabled(true)` for non-interactive maps

---

### Step 8 — Register in `AppDependencies`

**Affected file:** `App/AppDependencies.swift`

```swift
/// Place search service for destination autocomplete
let locationSearchService: any LocationSearchService
```

In `init()`:

```swift
self.locationSearchService = MKLocationSearchService()
```

Pass it when creating `CharterEditorViewModel` from any view that instantiates it:

```swift
CharterEditorViewModel(
    charterStore: dependencies.charterStore,
    charterSyncService: dependencies.charterSyncService,
    locationSearchService: dependencies.locationSearchService,
    charterID: charterID,
    onDismiss: dismiss.callAsFunction
)
```

---

### Step 9 (Backend) — Propagate coordinates through `CharterStore`

The `CharterStore.createCharter()` and `updateCharter()` methods currently do not accept location coordinate parameters. Add them:

**`CharterStore.swift`** — add parameters:

```swift
func createCharter(
    name: String,
    boatName: String?,
    location: String?,
    latitude: Double?,
    longitude: Double?,
    locationPlaceID: String?,
    startDate: Date,
    endDate: Date,
    checkInChecklistID: UUID?
) async throws -> CharterModel
```

**`CharterRecord.swift`** — verify `latitude`, `longitude`, `locationPlaceID` columns exist (they should, matching `CharterModel`).

**`CharterSyncService`** — the push payload already uses `CharterCreateRequest`/`CharterUpdateRequest` which include `latitude`, `longitude`, `locationPlaceId`. Verify the mapping from `CharterModel` → request includes these fields. If not, add:

```swift
let request = CharterCreateRequest(
    // ...existing fields...
    latitude: charter.latitude,
    longitude: charter.longitude,
    locationPlaceId: charter.locationPlaceID
)
```

---

## 4. Issues & Recommendations by Category

### Architecture

| Issue | File | Recommendation |
|-------|------|----------------|
| No service abstraction for place search | — | Add `LocationSearchService` protocol (Step 2) |
| `CharterFormState` conflates input state + static data | `CharterFormState.swift` | Move `regionOptions`/`vesselOptions` static data to their own namespaced types or enums; remove dead `region: String` field once `selectedPlace` is in place |
| `CharterSyncService.push()` silently drops coordinates | `CharterSyncService.swift` | Verify the `CharterModel → CharterCreateRequest` mapping explicitly passes `latitude`, `longitude`, `locationPlaceID` |
| `loadCharter()` discards coordinates on edit | `CharterEditorViewModel.swift` | Restore `PlaceResult` from stored lat/lon (Step 5b) |

### Code Quality

| Issue | File | Recommendation |
|-------|------|----------------|
| `charters_with_location` — snake_case in Swift | `CharterMapView.swift` | Rename to `chartersWithLocation` |
| Force-unwrap `charter.coordinate!` | `CharterMapView.swift` | Eliminate with `if let coordinate = charter.coordinate` inside `ForEach` (Step 7a) |
| `calculateProgress()` magic constant `5.0` | `CharterEditorViewModel.swift` | Extract as a `private static let totalProgressFields = 5` constant, or derive dynamically |
| Duplicate create/update logic in `saveCharter()` | `CharterEditorViewModel.swift` | Minor — acceptable given the structural differences; add inline comment separating the branches clearly |
| `CharterFormState.dateSummary` creates a new `DateFormatter` on every call | `CharterFormState.swift` | Cache formatter as a `static let` |

### Swift / SwiftUI

| Issue | File | Recommendation |
|-------|------|----------------|
| Deprecated `Map(coordinateRegion:)` | `CharterMapView.swift`, `MapPreviewThumbnail.swift` | Migrate to `Map(position:)` / `Map(initialPosition:)` (Step 7) |
| Deprecated `MapMarker` | `MapPreviewThumbnail.swift` | Replace with `Marker` (Step 7b) |
| Deprecated `MapAnnotation` | `CharterMapView.swift` | Replace with `Annotation` (Step 7a) |
| `@State private var region: MKCoordinateRegion` in thumbnail | `MapPreviewThumbnail.swift` | Use `Map(initialPosition:)` — no `@State` needed for non-interactive map |
| `.onChange(of: charters.count) { _ in }` uses deprecated two-argument form | `CharterMapView.swift` | Update to three-argument form `{ old, new in }` (iOS 17+) |

### UX / UI

| Issue | File | Recommendation |
|-------|------|----------------|
| Plain `TextField` for destination — no affordance for geocoding | `CharterEditorView.swift` | Replace with `DestinationSearchField` (Steps 4, 6) |
| No visual feedback that destination lacks coordinates | `CharterEditorView.swift` | After save, show an inline note "No map location — type and select from suggestions" if `selectedPlace == nil` |
| Destination does not advance completion progress | `CharterEditorViewModel.swift` | Include in `calculateProgress()` (Step 5d) |
| `CharterMapCallout` dismiss button uses `offset(x:y:)` hack | `CharterMapView.swift` | Use `overlay(alignment: .topTrailing)` with proper padding instead of manual offset |
| `MapPreviewThumbnail` accessibility label is generic | `MapPreviewThumbnail.swift` | Include destination name in label: `"Map preview: \(annotationTitle)"` (fixed in Step 7b) |
| No empty state for map when zero charters have coordinates | `CharterMapView.swift` | Show a placeholder message: "Destinations appear here once captains add locations" |

### Tests

| Priority | Test | What to cover |
|----------|------|---------------|
| High | `LocationSearchServiceTests` | Verify `MKLocationSearchService` correctly maps `MKMapItem` → `PlaceResult`; mock `MKLocalSearch` |
| High | `CharterEditorViewModelTests` | Verify `saveCharter()` populates `latitude`/`longitude` from `form.selectedPlace`; verify `loadCharter()` restores `selectedPlace` when charter has coordinates |
| Medium | `DestinationSearchFieldTests` | Verify debounce: rapid input triggers only one search call; verify `selectedPlace` is cleared when query is edited post-selection |
| Medium | `CharterSyncServiceTests` | Verify `push()` includes non-nil `latitude`/`longitude` when charter has them |
| Low | `PlaceResultTests` | Hash equality, `Sendable` conformance, nil coordinate handling |

**Example test outline — ViewModel coordinates round-trip:**

```swift
@Test func saveCharterPersistsCoordinates() async throws {
    let mockSearch = MockLocationSearchService()
    let viewModel = CharterEditorViewModel(
        charterStore: mockCharterStore,
        locationSearchService: mockSearch,
        onDismiss: {}
    )
    viewModel.form.selectedPlace = PlaceResult(
        id: "test-1",
        name: "Santorini",
        subtitle: "Greece",
        coordinate: CLLocationCoordinate2D(latitude: 36.39, longitude: 25.46),
        countryCode: "GR"
    )
    viewModel.form.name = "Summer Charter"

    await viewModel.saveCharter()

    let saved = try await mockCharterStore.fetchCharter(viewModel.createdCharterID!)
    #expect(saved.latitude == 36.39)
    #expect(saved.longitude == 25.46)
    #expect(saved.locationPlaceID == "test-1")
}
```

---

## 5. Backend Considerations

The backend already supports the full location schema. No schema migrations are needed.

**Verify these existing behaviours:**

1. `PUT /charters/{id}` accepts partial updates — confirm `latitude`/`longitude`/`location_place_id` are updated independently of `location_text`.
2. `GET /charters/discover` haversine query (`sqrt(pow((latitude - near_lat) * 111.32, 2) + ...)`) will now return results once iOS clients start sending coordinates.
3. The distance formula uses an approximation — this is fine for yacht charter distances (50–500 km ranges), but add a comment to `charter.py` explaining the approximation.

**Optional — server-side geocoding fallback (post-MVP):**

If you want to geocode charters that were created before this feature ships, add a background task:

```python
# app/tasks/geocode_charters.py
# For each Charter where location_text IS NOT NULL AND latitude IS NULL,
# call a geocoding API (e.g., Nominatim / Google Maps) and backfill coordinates.
```

This is not required for the MVP — iOS will start sending coordinates going forward.

---

## 6. File Change Summary

| File | Change type | Description |
|------|-------------|-------------|
| `Core/Models/PlaceResult.swift` | **New** | Domain model for geocoded place |
| `Services/LocationSearchService.swift` | **New** | Protocol + MKLocalSearch implementation + mock |
| `Features/Charter/Components/DestinationSearchField.swift` | **New** | Autocomplete input component |
| `Features/Charter/CharterFormState.swift` | **Edit** | `destination: String` → `selectedPlace: PlaceResult?` + `destinationQuery` |
| `Features/Charter/CharterEditorViewModel.swift` | **Edit** | Inject service, restore coords on load, pass coords on save |
| `Features/Charter/CharterEditorView.swift` | **Edit** | Replace `TextField` with `DestinationSearchField` |
| `Features/Charter/Discovery/CharterMapView.swift` | **Edit** | Migrate to iOS 17 Map API, fix force-unwrap, rename snake_case var |
| `Features/Charter/Discovery/MapPreviewThumbnail.swift` | **Edit** | Migrate to `Map(initialPosition:)` + `Marker` |
| `App/AppDependencies.swift` | **Edit** | Register `locationSearchService` |
| `Core/Stores/CharterStore.swift` | **Edit** | Add `latitude`/`longitude`/`locationPlaceID` params to create/update |

---

## 7. Implementation Order

```
Week 1
  Day 1-2  Step 1-2: PlaceResult + LocationSearchService (pure Swift, no UI, easy to test first)
  Day 3    Step 3: CharterFormState migration (touches many call sites — do this before UI)
  Day 4-5  Step 4: DestinationSearchField component + Previews

Week 2
  Day 1-2  Step 5: ViewModel wiring (load + save coordinates)
  Day 2    Step 6: Wire DestinationSearchField into CharterEditorView
  Day 3    Step 7: MapKit API migration (isolated, no data dependency)
  Day 4    Step 8-9: AppDependencies + CharterStore params
  Day 5    Tests + backend verification
```
