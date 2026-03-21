# Charter Map Redesign

## 1. Problem Statement

The charter map in its current form is the weakest screen in the app. The design review rated Discover **★★★☆☆** and called out:

- Map pins are stock teal circles with a `person.fill` placeholder — no captain avatars render even though `UserAvatarPin` is implemented
- Community badges exist in the data model (`communityBadgeURL`) but their visual weight on pins is too small to signal community affiliation at a glance
- The callout card layout is broken: captain name column is too narrow, text wraps badly, "Virtual captain" badge is hard to scan
- Filters are hidden behind a toolbar icon, opening a full separate sheet — a high-friction pattern for something users adjust constantly while browsing the map
- The map is styled in stock MapKit — no brand personality, no dark-mode ocean aesthetic
- No visual differentiation between charters at different urgency levels beyond ring color, which is indistinguishable on a saturated map background

The redesign addresses all of these. The primary design goal: **the map should feel like a live social surface, not a data query with pins on it.**

---

## 2. Goals

| Goal | Success Measure |
|---|---|
| Captain avatars visible on all pins | Avatar photos load and render; placeholder is brand-consistent |
| Community badge clearly associated with community-managed charters | Badge is legible at default zoom; ring color communicates affiliation |
| Callout card readable and actionable in one tap | Name, dates, and "View" CTA visible without truncation or overflow |
| Date filter accessible without leaving the map | Filter chip strip is always visible in the map overlay |
| Filter changes reflect instantly on pins | Map re-renders without full sheet dismiss/apply cycle |
| No raw magic values — full design system compliance | Zero `cornerRadius: 12`, zero `.system(size:weight:)` in map files |

---

## 3. Current State

### 3.1 Map Pins — `UserAvatarPin`

`UserAvatarPin` is already implemented in `CharterMapView.swift` and uses `CachedAsyncImage`. The logic is correct. The issue is that avatars are not rendering because:
- The `CachedAsyncImage` placeholder (`person.fill`) is displaying in all cases — this is likely a network/URL issue in dev, but the design is functionally relying on it anyway
- The ring size (44pt default / 52pt selected) is too small for a busy map — pins cluster and overlap unattractively
- There is no label beneath the pin so charters in the same region are indistinguishable
- The callout is anchored `.bottom` but the callout card that appears is a plain surface card using a hardcoded `cornerRadius: 12` — not a design system token

### 3.2 Callout — `CharterMapCallout`

Current layout issues:
- `HStack` layout has the captain name / date row on the left and "View" button on the right — works for English but breaks with long names or Russian text (see screenshot: "Рунов Алексей" wraps into 3 lines, crushing the adjacent column)
- Hardcoded `cornerRadius: 12` — should be `DesignSystem.Spacing.cardCornerRadius` (16pt)
- Hardcoded `cornerRadius(8)` on background in location section — not a design token
- No captain avatar in the callout — the pin has it but the expanded card does not
- "Virtual captain" inline badge is text-only — no community icon shown alongside

### 3.3 Filter Entry Point

`CharterFilterView` is a full-screen `NavigationStack` sheet requiring:
1. Tap toolbar button → sheet slides up
2. Adjust setting
3. Tap "Apply" → sheet dismisses → map re-renders

For date filtering on a map this is too much friction. Users want to drag a time window or tap a preset chip and see pins update live.

The custom date pickers (`DatePicker` with `from:` / `to:`) in the current filter sheet are unnecessary complexity for the common case of "show me charters roughly this summer" or "next 2 weeks."

---

## 4. Redesign Scope

### 4.1 Map Pin — `UserAvatarPin`

**Keep:** Core ring + avatar + community badge layering.

**Change:**

1. **Pin size:** Increase default to 48pt ring / 40pt avatar image. Selected state: 60pt ring / 52pt avatar. The current 44/36 is too small for tap targets and for visual salience.

2. **Location needle:** Add a small downward-pointing triangle (chevron mark or custom path) at the bottom of the ring circle, so the pin visually indicates exactly where on the map it is anchored. Currently the pin has no stem. Use `anchor: .bottom` on the annotation and add a 6×8pt filled triangle below the circle using a `Path`. Color matches `ringColor`.

3. **Placeholder avatar:** Replace `Image(systemName: "person.fill")` with a monogram initial — derive it from `charter.captain.username`. Use `DesignSystem.Colors.hashColor(charter.captain.id.uuidString)` (per design review — `hashColor` must live in DesignSystem) as the background tint, white initial letter in `DesignSystem.Typography.subheader`. This makes un-avatared pins look intentional rather than broken.

4. **Community badge size:** Increase from 18×18pt to 22×22pt. Keep the white stroke border (2pt). The badge should render even while loading — use a gold `communityAccent` circle with the `sailboat` SFSymbol as its placeholder (not `EmptyView`). This makes community-managed pins immediately recognizable even before images load.

5. **Ring color logic:** Keep existing urgency colors but make the community-managed case more prominent. When `communityBadgeURL != nil`, use a 3pt stroke in `DesignSystem.Colors.communityAccent` (gold) *around* the teal ring — a double-ring effect. This creates a clear "club charter" visual identity without changing the teal base color.

6. **Selected state animation:** Use `Animation.spring` from the design system (`spring(response: 0.35, dampingFraction: 0.8)`) — not `.spring(response: 0.2)` inline.

```
Default pin:                   Selected pin:
  ┌──────────────┐               ┌───────────────────┐
  │  [teal ring] │               │  [teal ring +     │
  │  [avatar]    │               │   larger avatar]  │
  │  [badge↘]   │               │  [badge↘]         │
  │      ▼       │               │        ▼          │
  └──────────────┘               └───────────────────┘
  
Community pin (gold double-ring):
  ┌──────────────────┐
  │ [gold stroke]    │
  │  [teal fill]     │
  │  [avatar]        │
  │  [badge↘]        │
  │      ▼           │
  └──────────────────┘
```

### 4.2 Callout Card — `CharterMapCallout`

Replace the current single-row layout with a structured card.

**New layout:**

```
┌─ Charter Map Callout ────────────────────────────── [×] ─┐
│                                                           │
│  [avatar 40pt]  Marco Rossi                              │
│                 [⚓ 18pt badge]  RBYC Racing School       │
│                                                           │
│  ──────────────────────────────────────────────────      │
│                                                           │
│  Сейшелы                                     ← charter   │
│  1 May 2026 – 8 May 2026  ·  8 days                     │
│                                                           │
│              [ View Charter  ›  ]                        │
└───────────────────────────────────────────────────────────┘
```

**Specific changes:**

1. **Avatar in callout:** `CachedAsyncImage` 40pt circle, same as map pin but static size. Monogram fallback with hash color. Placed in a leading `VStack` next to captain name + community badge row.

2. **Captain name:** `DesignSystem.Typography.subheader` (16pt semibold). No truncation — allow 2 lines. Cyrillic names must not clip.

3. **Community badge row:** Only visible when `charter.communityBadgeURL != nil`. Shows the badge image (18pt) + community name in `DesignSystem.Typography.caption` in `communityAccent` color. If `isVirtualCaptain`, append " · Virtual Captain" in muted `textSecondary`.

4. **Charter name:** `DesignSystem.Typography.body` (16pt regular). Destination text. Allow 2 lines.

5. **Date range + duration pill:** Single line — `"1 May – 8 May  ·  8 days"`. Duration shown as a `Pill` component (same as used in charter list) in `vesselAccent` gold.

6. **"View Charter" button:** Full-width `PrimaryButtonStyle`. Remove the current compact "View" button squeezed into a HStack. The full-width CTA is the only action on the callout and should be the visual anchor.

7. **Callout sizing:** Use `.fixedSize(horizontal: false, vertical: true)` — let the card auto-size to content. Minimum width = screen width minus 2 × `screenPadding`. Attach via `.safeAreaInset(edge: .bottom)` on the map `ZStack`, replacing the current `.padding()` wrapping. This keeps the callout stable above the home indicator area.

8. **Corner radius:** `DesignSystem.Spacing.cardCornerRadiusLarge` (24pt) for the callout sheet feel. Top two corners rounded, bottom flush (use `UnevenRoundedRectangle` or `.cornerRadius` only on top corners).

9. **Background:** `DesignSystem.Colors.surface` + `.ultraThinMaterial` blur on the map side for depth. In dark mode, this produces the glass appearance documented in `DESIGN.md §9`.

10. **Dismiss button:** `xmark.circle.fill` at `.topTrailing` overlay — keep, but use `DesignSystem.Colors.textSecondary` and size 22pt (currently 20pt — below min icon size for accessibility).

### 4.3 Inline Filter Bar — New Component: `MapFilterBar`

This is the primary UX change. Replace the full filter sheet entry point with a persistent horizontal strip that floats over the top of the map.

**Placement:** `.overlay(alignment: .top)` on the `CharterMapView`, pinned just below the navigation bar safe area. The bar is always visible in map mode. It does not appear in list mode (list mode keeps the existing `activeFiltersBar` at the top of the scroll view).

**Structure:**

```
┌─ MapFilterBar ──────────────────────────────────────────────────────────┐
│  [↔ date chip]  [Near Me chip]  [Sort chip]           [↺ Reset?]        │
└─────────────────────────────────────────────────────────────────────────┘
```

Each chip is a `FilterChip` (already in `CharterFilterView`). The chips are scrollable horizontally. Tapping a chip opens a compact inline popover — **not** a full sheet. The "Reset" button appears only when any filter is non-default.

**Date Chip — `MapDateFilterPopover`:**

This is the most important change. Instead of two `DatePicker` fields, the date filter uses a **horizontal month-range slider** with preset snap points.

Design:
```
  ┌─ Date Range ─────────────────────────────────────────┐
  │                                                        │
  │  ● ── ○ ─────────────────────────────────────────○   │
  │  Now                                           +1yr   │
  │                                                        │
  │  Drag to set window, or tap a preset:                 │
  │                                                        │
  │  [This Week]  [This Month]  [3 Months]  [All]         │
  └────────────────────────────────────────────────────────┘
```

Implementation approach:
- Two `@State` values: `windowStart: Date` and `windowEnd: Date`
- A custom `RangeSlider` component (new — not in design system yet, see §5 below) with two thumb handles on a single track
- Track spans `now` to `now + 12 months`
- Labels below the track show the selected month abbreviations: `"Apr" ── "Jul"`
- Preset chips below the slider snap both handles to predefined positions with `withAnimation(.spring)` and haptic feedback (`.selection`)
- Changes to the slider apply **live** — no Apply/Cancel. The map pins update as the user drags. Debounce at 300ms to avoid re-fetching on every drag tick.
- The popover dismisses on tap outside using `.popover` or a custom overlay dismiss tap area

**Popover styling:**
- Background: `DesignSystem.Colors.surface` + `cardCornerRadiusLarge` (24pt)
- Attached to the date chip via a custom `anchoredBubble` modifier (positions above the chip with a small arrow pointer)
- Width: `min(screen_width - 2 * screenPadding, 360pt)`

**Near Me chip:** Tapping toggles `useNearMe` directly (no popover needed). When active: shows `FilterChip` in selected state. The radius slider is promoted to a second row below the chip strip (a compact `Slider` from 10–500km with current value label).

**Sort chip:** Tapping opens a compact 3-item menu using `.confirmationDialog` or a small `Menu`. Not a full sheet.

**Changes to `CharterDiscoveryView`:**

- In map mode: inject `MapFilterBar` as a `.overlay(alignment: .top)` on `mapView`
- Keep the toolbar filter button and filter sheet for list mode only (or remove entirely — the `MapFilterBar` handles the map, and the existing `activeFiltersBar` in the list scroll view handles the list)
- `viewModel.showFilters` binding should still work for the list mode sheet

### 4.4 Map Style

Apply a custom `MapStyle` configuration for brand alignment. Per `DESIGN.md §11` backlog — `MapStyleWrapper` is listed as a low-priority backlog item. Include it here as part of the map redesign.

```swift
Map(position: $position, selection: $selectedCharterID) { ... }
    .mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .hotel]),
                        showsTraffic: false))
    .preferredColorScheme(nil) // Respect system
```

In dark mode, SwiftUI's `.standard` map style renders a dark map automatically. No custom tile layer required for MVP — just suppress irrelevant POIs so map pins are not competing with restaurant icons.

Optional for polish: use `.imagery(elevation: .realistic)` with `opacity(0.9)` in light mode for the oceanic satellite look visible in the current app screenshots — the deep blue ocean context makes the sailing location context immediately legible.

---

## 5. New Components Required

### 5.1 `RangeSlider` — `DesignSystem/Components/RangeSlider.swift`

A two-handle UIKit-free SwiftUI range slider. Required for the date window filter.

**Interface:**
```swift
struct RangeSlider: View {
    @Binding var lower: Double       // 0.0–1.0 normalized
    @Binding var upper: Double       // 0.0–1.0 normalized, always > lower + minSpan
    var minSpan: Double = 0.05       // minimum gap between handles (≈ 1 week on 12-month scale)
    var trackColor: Color = DesignSystem.Colors.primary.opacity(0.2)
    var rangeColor: Color = DesignSystem.Colors.primary
    var thumbSize: CGFloat = 24
}
```

Implementation: `GeometryReader` to get track width; two draggable circle thumbs with `.gesture(DragGesture(minimumDistance: 0))`. The filled range between handles uses a `Rectangle` overlay clipped to the thumb positions.

Label strip below: `HStack { Text(lowerLabel); Spacer(); Text(upperLabel) }` using `Typography.caption` in `textSecondary`.

Accessibility: `.accessibilityValue(lowerLabel + " to " + upperLabel)` on the whole slider.

### 5.2 `MapFilterBar` — `Features/Charter/Discovery/MapFilterBar.swift`

Described in §4.3. Owns `@Binding var filters: CharterDiscoveryFilters` and exposes individual chip + popover interactions. Does not own filter state — it reflects `CharterDiscoveryViewModel.filters`.

### 5.3 `AnchoredBubble` view modifier — `DesignSystem/Components/AnchoredBubble.swift`

A lightweight modifier that presents a floating card anchored above a view, with a small pointing triangle at the bottom. Used for the date filter popover.

```swift
extension View {
    func anchoredBubble<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View
}
```

Positions the bubble card above the anchor using `PreferenceKey` to read the anchor frame, then overlays it at the correct position. This is simpler than `.popover` (which on iPhone renders as a full sheet).

---

## 6. Changes to Existing Files

| File | Change |
|---|---|
| `CharterMapView.swift` | Increase pin sizes; add needle stem; monogram placeholder; community double-ring; fix `cornerRadius: 12` → token; add `MapFilterBar` overlay in map mode; apply `MapStyle` config |
| `CharterDiscoveryView.swift` | Inject `MapFilterBar` overlay on `mapView`; keep `CharterFilterView` sheet for list mode only; wire live-filter debounce to `viewModel.applyFilters()` |
| `CharterFilterView.swift` | Remove date range preset section (date is now handled in `MapFilterBar`); keep location + sort sections for the list filter sheet |
| `CharterDiscoveryViewModel.swift` | Add `debounceFilterUpdates()` method (300ms debounce on filter changes that triggers `applyFilters()`); expose `mapFilterBarVisible: Bool` computed from `showMapView` |
| `DesignSystem/Components/` | Add `RangeSlider.swift`, `MapFilterBar.swift`, `AnchoredBubble.swift` |
| `DesignSystemColors.swift` | Add `hashColor(_ seed: String) -> Color` static method (consolidates the duplicated utility from `DiscoverContentRow` and `LibraryItemRow`) |
| `CharterDiscoveryFilters` | Add `windowStart: Date` and `windowEnd: Date` to replace `datePreset` + `customDateFrom` / `customDateTo`; keep `DatePreset` enum for backward compat with list filter; add `preset(for:)` helper that maps a preset to `(windowStart, windowEnd)` |

---

## 7. Design System Compliance Fixes (in-scope)

The following violations exist in the map files today and must be fixed as part of this task:

| Violation | Location | Fix |
|---|---|---|
| `cornerRadius: 12` | `CharterMapCallout` background | → `DesignSystem.Spacing.cardCornerRadius` |
| `cornerRadius(8)` | `CharterFilterView` custom date section | → `DesignSystem.Spacing.cornerRadiusSmall` |
| `.font(.system(size: 20))` | Dismiss button in callout | → `DesignSystem.Typography.body` font + `.imageScale(.large)` |
| `.font(.system(size: isSelected ? 22 : 18))` | Pin placeholder icon | → `DesignSystem.Typography.title` / `.subheader` |
| `.font(.caption2)` | Radius slider labels | → `DesignSystem.Typography.micro` |
| `cornerRadius: 20` | `FilterChip` | → This is a pill shape — keep the full pill radius but compute it as `height / 2` using `clipShape(Capsule())` instead of a hardcoded value |

---

## 8. UX Details & Edge Cases

### 8.1 Pin Clustering

At low zoom levels, pins will overlap. The current `Map` API supports clustering via `MapCluster`. When 3+ pins overlap:
- Show a cluster pin: teal gradient circle with count label in `Typography.subheader`
- If all clustered charters belong to the same community: show community badge on the cluster pin
- Tapping a cluster zooms in (default `Map` behavior) — do not open a callout for clusters

### 8.2 Callout When Map Is Filtered

When date filter is active, callout should show a subtle "Within your date filter" confirmation — a single `caption` label below the date range, e.g. "In your filter range" with a `checkmark.circle` icon in `primary` color. Only if the charter date falls entirely within the active filter window.

### 8.3 Empty Map State

When filters produce zero pins: show a centered overlay card (not a full screen empty state — the map background should still be visible):
```
┌──────────────────────────────────────────┐
│  🪝  No charters in this period          │
│      Adjust your date range or zoom out  │
│      [ Clear Filters ]                   │
└──────────────────────────────────────────┘
```
Styled as `.glassPanel()` with `cardCornerRadiusLarge`. Width = 80% of screen.

### 8.4 Virtual Captain Callout Treatment

When `charter.captain.isVirtualCaptain == true`:
- Show community name row (badge + name) prominently below the captain name
- Do **not** show a "View Profile" link — virtual captains have no app profile
- The "View Charter" button still navigates to `DiscoveredCharterDetailView`
- In the callout avatar: render VC avatar if loaded, else monogram from `displayName`

### 8.5 Loading State on Map

While `viewModel.isLoading` is true (e.g. after a filter change):
- Keep existing pins rendered (stale data is better than a blank map)
- Show a small `ProgressView` as a `.glassPanel()` pill at the top of the map (already implemented but unstyled — apply `DesignSystem.Spacing.cornerRadiusSmall` + `cardPadding`)
- Pins that are being removed fade out with `.transition(.opacity)` + `Animation.standard`

---

## 9. Implementation Order

### Phase 1 — Pin + Callout (no new components needed)
1. Fix `UserAvatarPin`: increase size, add needle, monogram fallback, double-ring for community
2. Fix `CharterMapCallout`: new layout with avatar + community row + full-width CTA + token-based corner radius
3. Fix all in-scope design system compliance violations (§7)

### Phase 2 — `RangeSlider` + `MapFilterBar`
4. Build `RangeSlider` in DesignSystem
5. Build `AnchoredBubble` modifier
6. Build `MapFilterBar` using `FilterChip` + `RangeSlider` popovers
7. Update `CharterDiscoveryFilters` model to `windowStart`/`windowEnd`
8. Wire `MapFilterBar` into `CharterDiscoveryView` map mode overlay
9. Add `debounceFilterUpdates()` to `CharterDiscoveryViewModel`

### Phase 3 — Map Style + Polish
10. Apply `MapStyle` configuration
11. Add cluster support
12. Empty map state overlay card
13. Dark mode depth pass on callout (`.ultraThinMaterial` background)

---

## 10. Open Questions

| # | Question | Recommendation |
|---|---|---|
| 1 | **Range slider: 12-month track or rolling window?** The track could be fixed Jan–Dec or rolling from today. | Rolling from today (`now` to `now + 12 months`) is more useful for discovery. |
| 2 | **List mode: keep full filter sheet or migrate to a compact inline bar too?** | Keep full filter sheet for list mode — the vertical scroll layout has room for an `activeFiltersBar` but not a horizontal chip strip. |
| 3 | **Near Me chip in `MapFilterBar`: show radius bubble or just toggle?** | Just toggle — radius is a secondary concern. Power users can access it in the list filter sheet or via a secondary popover. |
| 4 | **Should the date range filter on the map query the backend live or client-side filter loaded data?** | Client-side filter the loaded set for immediate feedback; re-query backend only when the window extends beyond the loaded range (i.e. user selects dates > current `loadedTo`). |
| 5 | **Callout: swipe up to full detail, or always require "View Charter" tap?** | Add a `onDragGesture` that triggers `onViewDetail` when dragged up ≥ 50pt — iOS convention for "swipe up to expand". |

