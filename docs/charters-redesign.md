# Charter Screens — Design & UX Redesign Spec

> Living document. Update as work progresses.  
> Covers: `CharterListView`, `CharterRowView`, `CharterEditorView`, `CharterDetailView`, `DesignSystem/`.

---

## Status

| Area | Status | Notes |
|------|--------|-------|
| Charter list — calendar/timeline layout | ⬜ Not started | Replaces current date-grid card |
| Charter card — visibility + sync badges | ⬜ Not started | New `CharterVisibilityBadge`, `SyncStatusBadge` |
| Charter editor — destination field | ⬜ Not started | See `location-impl.md` |
| Charter editor — form hero height | ⬜ Not started | 220pt → 140pt |
| Design system — typography scale | ⬜ Not started | Rename + resize tokens |
| Design system — corner radius enforcement | ⬜ Not started | 3 sizes only |
| Design system — gradient tokens | ⬜ Not started | Move inline grads to `Gradients` enum |
| Design system — `gold` semantic split | ⬜ Not started | Add `communityAccent` alias |
| Design system — new badge components | ⬜ Not started | Visibility + Sync status |

---

## 1. High-Level Review

- **The card layout prioritises the wrong thing.** ~40% of each `CharterRowView` is the date grid (DEPARTURE / RETURN labels, timeline dots, duration badge). Charters are time-anchored events — the start date should be structurally implicit (left gutter), not the dominant content of the card.

- **Sync status is invisible.** `CharterModel` carries `needsSync`, `lastSyncedAt`, and `visibility`, but `CharterRowView` shows none of it. Whether a charter is live on the community feed or stuck pending is core information for the user.

- **Typography tokens are mislabeled and undersized.** `largeTitle = 16pt` (custom font) is the same size as `body = 16pt` (system font). `headline = 12pt`. These are standard iOS type style names — any engineer reading them will assume `largeTitle` is ~34pt. The mismatch causes visual hierarchy bugs.

- **`gold` is doing three unrelated jobs** — vessel highlight, community badge color, form progress bar fill, duration pill. When one token means everything, it means nothing.

- **Inline `LinearGradient` explosion.** The `Gradients` enum exists in the design system but is largely unused. `CharterRowView` alone defines 6+ inline gradients. They should be tokens.

- **`DateFormatter` as a computed var in `CharterRowView` and `CharterDetailView`.** A new formatter is allocated on every `body` evaluation. Trivial fix, measurable impact on a list.

---

## 2. Architecture Decision: Calendar/Timeline List

### Why switch from the card date grid

The current three-column date grid (Departure → Duration → Return) is well-designed for what it does, but it solves the wrong problem. Users of a charter app want to answer one question from the list: *when is my next trip?* The timeline/date-gutter pattern answers this before they read a single word — the date is structural, not content.

The `CharterListViewModel` already exposes:
```swift
var upcomingCharters: [CharterModel]   // daysUntilStart >= 0
var pastCharters: [CharterModel]       // daysUntilStart < 0
var sortedByDate: [CharterModel]       // sorted by startDate
```
No ViewModel changes are needed.

### What stays on the card

| Element | Rationale |
|---------|-----------|
| Charter name | Primary identifier |
| Visibility badge | Tells you at a glance if this is public/community/private |
| Sync status badge | Is this live on the feed? Pending? Failed? |
| Duration pill (`10d`) | Trip length without redundant full dates |
| Boat name | One-line, below the name |
| Location | One-line, only if set |

### What moves to detail view only

| Element | Where it goes |
|---------|---------------|
| Full "DEPARTURE / RETURN" labeled dates | `CharterDetailView.charterHeader` — already there |
| Timeline indicator dots | Remove entirely from list |
| Full end date text | Already in detail view |

### End date on card: the edge case

When the end date is in a different month from the start, show `→ MMM d` in micro text on the card. Otherwise, duration `10d` is sufficient.

### List structure

```
UPCOMING
  17       Aegean Odyssey         [Public] ✓ Synced
  May      Lagoon 42 · 10d · Santorini

  Jun 1    Baltic Explorer        [Community] ⏳ Pending
           Bavaria C42 · 7d

──────────────────────────────────────
PAST (3)  [collapsed by default, tap to expand]
```

`@State private var showPast = false` in `CharterListView` controls the collapsed section.

---

## 3. Design System: Assessment & Improvement Plan

### 3.1 What is working well

- **Spacing scale.** The 4pt grid (`xs`=4, `sm`=8, `md`=12, `lg`=16, `xl`=20, `xxl`=24) is internally consistent and applied correctly in most places.
- **Color primitives.** `primary`, `success`, `warning`, `error`, `gold`, `surface`, `background` cover the core semantic needs.
- **`@Observable` + protocol DI.** Architecture is modern and correctly structured.
- **`Form.*` component family.** `Form.Section`, `FormTextField`, `Form.Hero`, `Form.Progress` cover the charter editor well.
- **`HeroCardStyle` elevation system.** Clean abstraction; the three-level shadow scale is useful.
- **`EmptyStateView`.** Well-built; used correctly.

### 3.2 Problems to fix

#### P1 — Typography: rename and resize (breaking but necessary)

**Current state:**
```swift
static let largeTitle = Font.custom("Onder", size: 16).weight(.semibold)  // 16pt!
static let headline   = Font.custom("Onder", size: 12).weight(.semibold)  // 12pt!
static let body       = Font.system(size: 16)
static let caption    = Font.system(size: 14)
```

`largeTitle` at 16pt is the same size as `body`. `headline` at 12pt is smaller than `caption` at 14pt. These are iOS system type style names with well-established size expectations. This will cause hierarchy bugs as the codebase grows.

**Fix — use "Onder" only at display sizes, system font for UI labels:**
```swift
// DesignSystemTypography.swift — proposed

enum Typography {
    // Display: Onder custom font, only for hero/title contexts at readable sizes
    static let display    = Font.custom("Onder", size: 28).weight(.semibold)
    static let largeTitle = Font.custom("Onder", size: 22).weight(.semibold)

    // UI labels: system font for legibility and Dynamic Type compatibility
    static let title      = Font.system(size: 20, weight: .semibold)
    static let headline   = Font.system(size: 17, weight: .semibold)
    static let subheader  = Font.system(size: 16, weight: .semibold)
    static let body       = Font.system(size: 16, weight: .regular)
    static let caption    = Font.system(size: 14, weight: .regular)
    static let micro      = Font.system(size: 11, weight: .medium)
}
```

**Impact of this change:** All existing uses of `Typography.largeTitle` and `Typography.headline` will be visually enlarged. Audit each callsite after changing — most uses of the current tiny "Onder" labels (nav titles, section headers) will look correct or even better at the new size. The callsites in `DesignSystem.SectionHeader` and `CharterRowView` headers need verification.

#### P2 — `gold` token: split into semantic aliases

**Current state:** `gold` is used for:
- Vessel name capsule on `CharterRowView` (decoration)
- Community visibility badge color (semantic state)
- Form progress bar fill (brand)
- Duration pill foreground (data label)

**Fix:** Keep `gold` as the raw hex token. Add semantic aliases that can be independently changed later:
```swift
// DesignSystemColors.swift — additions

static let gold = Color(red: 0.98, green: 0.82, blue: 0.45)   // keep as-is

// Semantic aliases
static let communityAccent  = gold          // community badge, pending state
static let highlightAccent  = gold          // duration pills, form progress
static let vesselAccent     = gold          // vessel label decoration
```

This costs nothing now but means if the design ever changes community color to amber/orange, it's a one-line change.

#### P3 — Inline gradients: move to `Gradients` enum

**Current state:** Six+ `LinearGradient(colors: [...], startPoint: .topLeading, endPoint: .bottomTrailing)` defined inline across `CharterRowView`, `CharterDetailView`, `CharterListView`, and `FormKit.swift`. The `Gradients` enum exists but only has `primary`/`ocean`/`subtleOverlay`.

**Fix — add missing tokens to `DesignSystemColors.swift`:**
```swift
enum Gradients {
    static let primary = LinearGradient(...)          // exists
    static let ocean = primary                         // exists

    static let focalGold = LinearGradient(            // replaces FocalHighlight inline def
        colors: [Colors.gold.opacity(0.15), Colors.gold.opacity(0.05), .clear],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let subtleBackground = LinearGradient(     // used in list/detail backgrounds
        colors: [Colors.background, Colors.oceanDeep.opacity(0.02)],
        startPoint: .top, endPoint: .bottom
    )

    static let primaryButton = LinearGradient(        // for filled CTA buttons
        colors: [Colors.primary, Color(red: 0.054, green: 0.32, blue: 0.45)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let subtleOverlay = LinearGradient(        // exists, keep
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
```

#### P4 — Corner radius: enforce exactly 3 sizes

**Current state:** 10, 12, 14, 16, 20, 24 all appear in the codebase. `Spacing.cardCornerRadius = 16` exists but is never used — all actual code hardcodes its own value.

**Fix — establish the rule and enforce it:**

| Context | Radius | Token |
|---------|--------|-------|
| Buttons, form fields, chips, small cards | 10 pt | `Spacing.cornerRadiusSmall` |
| Standard cards (`CharterRowView`, sections) | 16 pt | `Spacing.cardCornerRadius` (already exists) |
| Sheets, modals, feature cards | 24 pt | `Spacing.cardCornerRadiusLarge` (already exists) |
| Pills, tags, status badges | `Capsule()` | n/a |

Add `cornerRadiusSmall = 10` to `DesignSystemSpacing.swift`. Then do a pass replacing every hardcoded `cornerRadius(10)`, `cornerRadius(12)`, `cornerRadius(14)` with the token. Delete the freestanding `12` and `14` values.

#### P5 — `oceanDeep` color: use it or lose it

**Current state:** `oceanDeep = Color(red: 0.02, green: 0.28, blue: 0.36)` is used exclusively as `.opacity(0.02)` and `.opacity(0.03)` — at those opacities it is perceptually identical to black. The color was presumably intended to give backgrounds a subtle nautical tint.

**Fix options:**
- **Use it properly:** Apply `oceanDeep.opacity(0.06)` on list scroll area backgrounds to create a faint teal depth effect. Test in both light and dark mode.
- **Remove it:** If the effect isn't visible at any reasonable opacity, delete the token and its references.

#### P6 — `DesignSystem.Form.Section` nesting creates visual noise

**Current state:** Each form section gets its own white card with full padding, border, and shadow. `CharterEditorView` stacks five of these. The result is a "bubble wrap" effect — lots of individual containers competing for attention.

**Fix:** For multi-section forms, consider:
- A single outer container with `Divider()`s between sections (reduces card count from 5 to 1)
- Or group closely related fields (e.g., vessel + guests) into one section instead of separate cards

This doesn't require a DesignSystem API change — it's a layout composition decision in `CharterEditorView`.

#### P7 — `Form.Hero` height: 220pt → 140pt

**Current state:** The hero banner occupies 220pt, pushing all form fields below the fold on small devices.

**Fix:** Add a `height` parameter to `DesignSystem.Form.Hero` (defaulting to 140pt):
```swift
// FormKit.swift
struct Hero: View {
    let title: String
    let subtitle: String
    let icon: String?
    let height: CGFloat         // new param, default 140
    let gradient: LinearGradient

    init(..., height: CGFloat = 140, ...) { ... }

    var body: some View {
        gradient.frame(height: height)   // was hardcoded 220
        ...
    }
}
```

#### P8 — Missing: loading skeleton state

**Current state:** `CharterDetailView.isLoading` shows a bare `ProgressView()`. The list has no skeleton. For a network-backed list this is a visible gap.

**Fix:** Add a `SkeletonRow` view that mirrors `CharterTimelineRow`'s shape with animated shimmer:
```swift
// DesignSystem/Components/SkeletonRow.swift
extension DesignSystem {
    struct SkeletonBlock: View {
        let width: CGFloat?
        let height: CGFloat
        @State private var animating = false

        var body: some View {
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                .fill(
                    LinearGradient(
                        colors: [Colors.surface, Colors.surfaceAlt, Colors.surface],
                        startPoint: animating ? .leading : .trailing,
                        endPoint: animating ? .trailing : .leading
                    )
                )
                .frame(width: width, height: height)
                .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { animating = true } }
        }
    }
}
```

---

## 4. New Components to Build

### 4.1 `CharterVisibilityBadge`

**File:** `DesignSystem/Components/CharterVisibilityBadge.swift`

```swift
extension DesignSystem {
    struct CharterVisibilityBadge: View {
        let visibility: CharterVisibility

        var body: some View {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: visibility.systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(visibility.displayName)
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(.semibold)
            }
            .foregroundColor(visibility.accentColor)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(visibility.accentColor.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(visibility.accentColor.opacity(0.3), lineWidth: 1))
            .accessibilityLabel("Visibility: \(visibility.displayName)")
        }
    }
}

// Design token extensions on CharterVisibility
extension CharterVisibility {
    var accentColor: Color {
        switch self {
        case .public:    return DesignSystem.Colors.primary
        case .community: return DesignSystem.Colors.communityAccent
        case .private:   return DesignSystem.Colors.textSecondary
        }
    }

    /// Color for the ambient corner glow on the card
    var glowColor: Color {
        switch self {
        case .public:    return DesignSystem.Colors.primary
        case .community: return DesignSystem.Colors.communityAccent
        case .private:   return DesignSystem.Colors.error
        }
    }
}
```

### 4.2 `SyncStatusBadge`

**File:** `DesignSystem/Components/SyncStatusBadge.swift`

```swift
extension DesignSystem {
    enum SyncStatus {
        case synced, pending, failed, privateOnly

        var label: String {
            switch self {
            case .synced:      return "Synced"
            case .pending:     return "Pending"
            case .failed:      return "Failed"
            case .privateOnly: return "Private"
            }
        }

        var icon: String {
            switch self {
            case .synced:      return "checkmark.circle.fill"
            case .pending:     return "gear"
            case .failed:      return "exclamationmark.triangle.fill"
            case .privateOnly: return "lock.fill"
            }
        }

        var color: Color {
            switch self {
            case .synced:      return DesignSystem.Colors.success
            case .pending:     return DesignSystem.Colors.warning
            case .failed:      return DesignSystem.Colors.error
            case .privateOnly: return DesignSystem.Colors.textSecondary
            }
        }
    }

    struct SyncStatusBadge: View {
        let status: SyncStatus

        var body: some View {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: status.icon)
                    .font(.system(size: 11))
                Text(status.label)
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(.semibold)
            }
            .foregroundColor(status.color)
            .accessibilityLabel("Sync status: \(status.label)")
        }
    }
}

// Derive sync status from CharterModel
extension CharterModel {
    var syncStatus: DesignSystem.SyncStatus {
        guard visibility != .private else { return .privateOnly }
        if needsSync { return .pending }
        if lastSyncedAt != nil { return .synced }
        return .pending
    }
}
```

---

## 5. Updated `CharterListView` + `CharterTimelineRow`

### 5.1 `CharterTimelineRow` — full drop-in

Replaces `CharterRowView`. The date gutter becomes structural; the card content is compact.

```swift
struct CharterTimelineRow: View {
    let charter: CharterModel
    let onTap: () -> Void

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let returnFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                dateGutter
                    .frame(width: 48)
                compactCard
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Swipe actions wired at the list level, not here
        }
    }

    // MARK: - Date Gutter

    private var dateGutter: some View {
        VStack(spacing: 2) {
            Text(Self.dayFormatter.string(from: charter.startDate))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(charter.isUpcoming
                    ? DesignSystem.Colors.textPrimary
                    : DesignSystem.Colors.textSecondary)
                .monospacedDigit()
            Text(Self.monthFormatter.string(from: charter.startDate))
                .font(DesignSystem.Typography.micro)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .accessibilityHidden(true)   // date is part of accessibilityLabel on the row
    }

    // MARK: - Card

    private var compactCard: some View {
        ZStack(alignment: .topLeading) {
            // Ambient corner glow keyed to visibility
            if charter.visibility != .private {
                RadialGradient(
                    colors: [charter.visibility.glowColor.opacity(0.22), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 130
                )
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                topRow
                nameRow
                metaRow
            }
            .padding(DesignSystem.Spacing.md)
        }
        .heroCardStyle(elevation: charter.isUpcoming ? .medium : .low)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            DesignSystem.CharterVisibilityBadge(visibility: charter.visibility)
            Spacer()
            DesignSystem.SyncStatusBadge(status: charter.syncStatus)
        }
    }

    private var nameRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(charter.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
            // Show return date only when it falls in a different month
            if returnIsInDifferentMonth {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                    Text(Self.returnFormatter.string(from: charter.endDate))
                        .font(DesignSystem.Typography.micro)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Duration pill
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("\(charter.durationDays)d")
                    .fontWeight(.semibold)
            }
            .font(DesignSystem.Typography.micro)
            .foregroundColor(DesignSystem.Colors.primary)

            if charter.boatName != nil || charter.location != nil {
                Text("·")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Boat name
            if let boat = charter.boatName {
                Label(boat, systemImage: "sailboat.fill")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.gold)
                    .lineLimit(1)
            }

            // Location
            if let location = charter.location {
                if charter.boatName != nil {
                    Text("·")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Label(location, systemImage: "mappin")
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    private var returnIsInDifferentMonth: Bool {
        let cal = Calendar.current
        return cal.component(.month, from: charter.startDate)
            != cal.component(.month, from: charter.endDate)
    }

    private var accessibilityDescription: String {
        let day = Self.dayFormatter.string(from: charter.startDate)
        let month = Self.monthFormatter.string(from: charter.startDate)
        let vis = charter.visibility.displayName
        let sync = charter.syncStatus.label
        let dur = "\(charter.durationDays) days"
        return "\(charter.name). \(vis). \(sync). Starts \(day) \(month). \(dur)."
    }
}
```

### 5.2 `CharterListView` — updated list body

Add `@State private var showPast = false` to `CharterListView`.

```swift
private var charterList: some View {
    List {
        // UPCOMING SECTION
        if !viewModel.upcomingCharters.isEmpty {
            Section {
                ForEach(viewModel.upcomingCharters.sorted { $0.startDate < $1.startDate }) { charter in
                    CharterTimelineRow(
                        charter: charter,
                        onTap: { coordinator.viewCharter(charter.id) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { try? await viewModel.deleteCharter(charter.id) }
                        } label: { Label("Delete", systemImage: "trash") }

                        Button { coordinator.editCharter(charter.id) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
                    }
                }
            } header: {
                sectionLabel("Upcoming")
            }
        }

        // PAST SECTION (collapsed by default)
        if !viewModel.pastCharters.isEmpty {
            Section {
                if showPast {
                    ForEach(viewModel.pastCharters.sorted { $0.startDate > $1.startDate }) { charter in
                        CharterTimelineRow(
                            charter: charter,
                            onTap: { coordinator.viewCharter(charter.id) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { try? await viewModel.deleteCharter(charter.id) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            } header: {
                Button {
                    withAnimation(.spring(response: 0.3)) { showPast.toggle() }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        sectionLabel("Past (\(viewModel.pastCharters.count))")
                        Spacer()
                        Image(systemName: showPast ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(
        LinearGradient(
            colors: [DesignSystem.Colors.background, DesignSystem.Colors.oceanDeep.opacity(0.02)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    )
}

private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(DesignSystem.Typography.micro)
        .fontWeight(.semibold)
        .foregroundColor(DesignSystem.Colors.textSecondary)
        .textCase(.uppercase)
        .tracking(0.8)
        .padding(.vertical, DesignSystem.Spacing.xs)
}
```

---

## 6. Charter Editor Changes

### 6.1 Hero height

Add a `height` parameter to `DesignSystem.Form.Hero` (default 140pt). Update `CharterEditorView` to pass `height: 140`.

### 6.2 Destination field

Replace the raw `TextField` destination section with `DestinationSearchField` from `location-impl.md §4`. The section becomes:

```swift
DesignSystem.Form.Section(title: L10n.charterCreateDestination, subtitle: L10n.charterCreateChooseWhereYouWillSail) {
    DestinationSearchField(
        query: $viewModel.form.destinationQuery,
        selectedPlace: $viewModel.form.selectedPlace,
        searchService: viewModel.locationSearchService
    )
}
```

### 6.3 Remove commented-out sections

Delete the commented-out `CrewSection`, `BudgetSection`, and `RegionPickerSection` blocks. They can be restored from git when those features ship.

### 6.4 Vessel field — use `FormTextField`

```swift
// Replace raw TextField with:
DesignSystem.Form.FormTextField(
    placeholder: L10n.charterCreateVesselNamePlaceholder,
    text: $viewModel.form.vessel
)
```

---

## 7. Design System Spacing & Sizing Summary

### Spacing tokens (final)

| Token | Value | Usage |
|-------|-------|-------|
| `xss` | 2 pt | Indicator dots, tight offsets |
| `xs` | 4 pt | Icon–text gap, badge padding |
| `sm` | 8 pt | Row padding, between badges |
| `md` | 12 pt | Card inner padding, field padding |
| `lg` | 16 pt | Card horizontal inset, section gap |
| `xl` | 20 pt | Form section spacing |
| `xxl` | 24 pt | Outer padding, hero bottom padding |
| `xxxl` | 32 pt | Screen-level section breathing room |
| `screenPadding` | 20 pt | Horizontal page margins (existing) |

Add `xss = 2` and `xxxl = 32` to `DesignSystemSpacing.swift`.

### Corner radius rules

| Context | Value | Token |
|---------|-------|-------|
| Buttons, fields, chips, small elements | 10 pt | `cornerRadiusSmall` (new) |
| Cards, list items, section containers | 16 pt | `cardCornerRadius` (existing) |
| Sheets, modals, feature surfaces | 24 pt | `cardCornerRadiusLarge` (existing) |
| Pills, tags, status badges | `Capsule()` | — |

Add `cornerRadiusSmall: CGFloat = 10` to `DesignSystemSpacing.swift`.

### Color tokens (additions only)

```swift
// DesignSystemColors.swift — add these

// Semantic aliases for gold
static let communityAccent = gold    // community badge, pending sync
static let highlightAccent = gold    // duration pills, progress fill
static let vesselAccent    = gold    // vessel label decoration

// Visibility semantic colors
static let visibilityPublic    = primary        // = #208A8D
static let visibilityCommunity = communityAccent // = gold
static let visibilityPrivate   = textSecondary   // neutral for non-failed private

// Spacing addition
// (these live in DesignSystemSpacing.swift but noted here for reference)
// cornerRadiusSmall = 10
```

---

## 8. Accessibility & Localization Checklist

Use this for every screen touching charter UI:

- [ ] All font sizes use `Typography.*` tokens, not inline literals
- [ ] All spacing uses `Spacing.*` tokens — no `Spacing.xs + 2` magic offsets
- [ ] All colors use `Colors.*` semantic tokens
- [ ] Tap targets: `Button` (not `.onTapGesture`), min 44×44 pt
- [ ] `DateFormatter` / `NumberFormatter` are `static let`, not computed vars
- [ ] Composite cards have a meaningful `.accessibilityLabel` string (not just children combined)
- [ ] Color-only state has an accompanying text label (sync status badge = color + word)
- [ ] No hardcoded strings — use `L10n.*`
- [ ] Empty, loading, and error states all handled
- [ ] Dynamic Type: verify at `.accessibility1` in Xcode Simulator
- [ ] Corner radius uses one of the three approved values (10, 16, 24, or `Capsule()`)
- [ ] New reusable UI elements extracted to `DesignSystem/Components/`
- [ ] Animations respect `@Environment(\.accessibilityReduceMotion)`
