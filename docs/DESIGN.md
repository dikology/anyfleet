# Anyfleet Design System

> This document is the canonical reference for the Anyfleet visual language. It describes both what exists today and the evolved system we are building toward. Every design decision should trace back to something here.

The design philosophy, borrowed from cinema: *every element serves the composition. The goal is not decoration — it is to convey the emotional weight of a voyage. Structure, focal points, depth, and light exist to make the user feel like they are about to set sail.*

---

## 1. Brand Identity

**Personality:** Oceanic. Purposeful. Adventurous but precise.

**Metaphors that guide decisions:** Deep water, nautical charts, expedition logs, the horizon, morning fog over the sea. Not flashy — crafted.

**Emotional register:** The app should feel like a well-worn but beautifully maintained ship's journal. Confident typography. Rich, layered surfaces. A sense that something meaningful is being recorded.

---

## 2. Color

### Foundation Palette

These are the raw brand colors from which all semantic tokens are derived.

| Token | Value | Description |
|---|---|---|
| `primary` | `#208A8D` | Teal/ocean — the brand's defining hue |
| `primaryDark` | `#0D5273` | Deep ocean — used in gradients |
| `primaryDeep` | `#1A7887` | Mid ocean — gradient start |
| `secondary` | `#5E5240` | Warm brown — grounding accent |
| `gold` | `#FAD173` | Warm gold — highlight, duration, community |
| `oceanDeep` | `#000A0B` | Near-black with teal undertone — dark backgrounds |
| `success` | `#22C55E` | Green — synced, complete, public |
| `warning` | `#E68161` | Coral — warnings, attention |
| `error` | `#FF5459` | Red — failures, destructive |
| `info` | `#3176C6` | Blue — informational, navigation tints |

### Semantic Aliases

Semantic tokens are always preferred over raw values in view code. They decouple visuals from implementation.

**Surfaces (adaptive — follow system light/dark)**

| Token | Resolves to | Role |
|---|---|---|
| `background` | `.systemGroupedBackground` | Screen-level background |
| `backgroundSecondary` | `.secondarySystemGroupedBackground` | Second-level background |
| `surface` | `.secondarySystemGroupedBackground` | Card surfaces |
| `surfaceAlt` | `.tertiarySystemGroupedBackground` | Inset fields, subtle containers |

**Text (adaptive)**

| Token | Resolves to | Role |
|---|---|---|
| `textPrimary` | `.label` | Body text, titles |
| `textSecondary` | `.secondaryLabel` | Captions, metadata |

**Brand semantic**

| Token | Resolves to | Role |
|---|---|---|
| `vesselAccent` | `gold` | Vessel/boat identifiers |
| `communityAccent` | `gold` | Community elements |
| `highlightAccent` | `gold` | Focal highlights |
| `visibilityPublic` | `primary` | Public content badge |
| `visibilityCommunity` | `communityAccent` | Community-visible content |
| `visibilityPrivate` | `textSecondary` | Private content |
| `border` | `.separator` × 0.4 | Card borders, dividers |
| `onPrimary` | `.white` | Text/icons on primary fill |

### Gradients

Gradients are a core part of the visual language — they convey depth and direction. Use them intentionally, not decoratively.

| Token | Description | Usage |
|---|---|---|
| `ocean` / `primary` | `primaryDeep → primaryDark`, top-leading → bottom-trailing | Hero headers, feature cards, action cards |
| `primaryButton` | `primary → primaryDark` | Primary CTA button fills |
| `heroImageOverlay` | `black 15% → 50% → 75%` | Overlay on full-bleed photo cards |
| `focalGold` | `gold 15% → 5% → clear` | `.focalHighlight()` shimmer on cards |
| `focalGoldRadial` | `gold 15%` radial from bottom-center | Editor hero headers |
| `subtleBackground` | `background → oceanDeep 2%` | Screen background depth |
| `subtleOverlay` | `white 8% → white 2%` | Card glass edge treatment |

### Color Usage Rules

1. Never use raw hex values in view code — always use a `DesignSystem.Color.*` token.
2. Never use `primary` for decorative purposes where `surface` would do. Reserve brand color for actionable and focal elements.
3. `gold` signals "yours" — your vessels, your community, your highlights. Do not use it for generic UI.
4. In dark mode, lean toward `oceanDeep` as a base layer behind surfaces. The default `.systemGroupedBackground` produces a flat gray; an oceanDeep underlay gives dark mode an intentional personality.

---

## 3. Typography

### Typefaces

| Face | Usage |
|---|---|
| **Onder** (custom) | Brand display — headlines, greetings, hero text |
| **SF Pro** (system) | All body, UI labels, captions |

### Type Scale

| Token | Face | Size | Weight | Usage |
|---|---|---|---|---|
| `display` | Onder | 28pt | Semibold | Hero headlines, empty state titles |
| `largeTitle` | Onder | 22pt | Semibold | Screen greetings, profile name |
| `title` | SF Pro | 20pt | Semibold | Section titles, card titles |
| `headline` | SF Pro | 17pt | Semibold | Navigation bar titles, modal headers |
| `subheader` | SF Pro | 16pt | Semibold | Card header labels |
| `body` | SF Pro | 16pt | Regular | Body text, descriptions |
| `caption` | SF Pro | 14pt | Regular | Metadata, secondary labels |
| `micro` | SF Pro | 11pt | Medium | Section labels (uppercase, 1.2 tracking), badges |

### Rules

1. Always use `Typography.*` tokens. Never call `.system(size:weight:)` or `.custom(name:size:)` directly in view code.
2. `display` and `largeTitle` (Onder) are exclusively for emotional anchor points — greetings, hero text, achievement unlocks. Do not use them for functional UI.
3. `micro` always renders uppercase with `0.8–1.2` letter-spacing. This is enforced by `SectionLabel`.
4. Gradient foreground on title text (`LinearGradient` as foreground) is an intentional design statement. Use it only in featured/hero contexts — `LibraryItemRow`, `ActionCard`. Do not apply it to body text or captions.

---

## 4. Spacing & Layout

### Spacing Scale (4pt grid)

| Token | Value | Primary use |
|---|---|---|
| `xss` | 2pt | Indicator dots, tight offsets |
| `xs` | 4pt | Icon–text gaps, badge internal padding |
| `sm` | 8pt | Row padding, between badges, between icon and label |
| `md` | 12pt | Card internal padding, field padding |
| `lg` | 16pt | Card horizontal inset, section gap |
| `xl` | 20pt | Form section spacing |
| `xxl` | 24pt | Outer screen padding, hero bottom |
| `xxxl` | 32pt | Screen-level section breathing room |
| `screenPadding` | 20pt | Standard horizontal screen margin |
| `cardPadding` | 16pt | Card internal padding |

### Corner Radius (3 values only)

| Token | Value | Usage |
|---|---|---|
| `cornerRadiusSmall` | 10pt | Buttons, text fields, chips, small badges |
| `cardCornerRadius` | 16pt | Standard cards, list rows |
| `cardCornerRadiusLarge` | 24pt | Sheets, modals, large hero cards |

**Rule:** Do not use any corner radius value not in this set. `cornerRadius: 12`, `cornerRadius: 14`, `cornerRadius: 8` are not permitted. Choose the nearest token.

### Elevation (via `heroCardStyle`)

Three elevation levels for cards:

| Level | Shadow Radius | Y Offset | Opacity | Usage |
|---|---|---|---|---|
| `.low` | 6pt | 2pt | 8% | Subtle cards, secondary content |
| `.medium` | 12pt | 4pt | 12% | Standard cards, list rows |
| `.high` | 20pt | 8pt | 16% | Featured cards, modals, floating elements |

### Layout Heights

| Token | Value | Usage |
|---|---|---|
| `featuredCardHeight` | 180pt | Hero/featured card minimum height |
| `profileHeroHeight` | 256pt | Profile hero section |
| `formHeroHeight` | 140pt | Editor/form hero header |

---

## 5. Components

### Surfaces & Containers

#### `.cardStyle()`
Standard card: `surface` background, `cardCornerRadius` (16pt), `border` overlay, low shadow (r:4, y:2, 4%).
Use for: secondary content, profile info rows, settings rows.

#### `.heroCardStyle(elevation:)`
Elevated card with gradient border (topLeading → bottomTrailing) and 3-level elevation shadow.
Use for: charter rows, library items, featured cards — any card that should feel three-dimensional.

#### `.sectionContainer()`
Surface background, `cardCornerRadius`, `border` overlay. No shadow.
Use for: form sections, grouped settings, profile sections.

#### `.glassPanel()`
`.ultraThinMaterial` + `white.opacity(0.15)` border.
Use for: overlays on photos, contextual chips floating over hero images.

#### `.formFieldStyle()`
`surfaceAlt` background, `cornerRadiusSmall` (10pt). No border.
Use for: text input fields.

---

### Buttons

#### `PrimaryButtonStyle`
Full-width, `primaryButton` gradient fill, white text, `cornerRadiusSmall`. Press scale 0.98.
Use for: the one primary action on a screen.

#### `SecondaryButtonStyle`
Full-width, `surface` fill, `textPrimary` text, `border` overlay. No gradient.
Use for: secondary or destructive actions alongside a primary.

#### `OutlineButtonStyle`
No fill, `border` stroke only.
Use for: tertiary actions, cancel buttons.

#### `FloatingActionButton` *(to be built)*
Large pill (height 56pt), `primaryButton` gradient or white fill, `cardCornerRadiusLarge`, backdrop blur blur (`.regularMaterial`), `shadowStrong`. Fixed to the bottom of the screen with `safeAreaInset`.
Use for: the single most important action on a detail/view screen (e.g. "Add Check-in", "Fork Content", "Open Skipass").

---

### Text Elements

#### `SectionLabel`
Uppercase `micro` (11pt medium), 1.2 letter-spacing, `textSecondary`. Used before content sections.

#### `SectionHeader`
`headline` title + optional `caption` subtitle. Left-aligned with `screenPadding`.

#### `Pill`
`caption` text, `border.opacity(0.5)` background, `cornerRadiusSmall`, light padding. For tags and type labels.

---

### Data Display

#### `StatsRow` *(to be built)*
Horizontal row of 2–4 stat groups, pipe-separated. Each group: SF Symbol icon (tinted, 14pt) + bold number + `caption` label. Height ~36pt.
Use for: vessel/charter key stats on detail cards and mini-cards.

```
⛵ 26 ski runs  |  ⛰ 112 km  |  📋 8 types
```

#### `OverlayChip` *(to be built)*
A `.glassPanel()` pill floating over a photo card. Contains an icon + text. Positioned using `.overlay(alignment:)`.
Variants: `temperature`, `countdown`, `memberCount`, `distance`.
Use for: contextual at-a-glance information directly on hero photo cards.

#### `AvatarStack`
Overlapping circular avatars (24pt diameter, 16pt overlap). Initial fallback with `hashColor`. Optional "+N" count chip.
Sizes: `.small` (20pt), `.medium` (24pt), `.large` (32pt).
Use for: showing social presence on cards, "who else is on this charter".

#### `TimelineIndicator`
8pt circle dot — active = `primary` with 16pt glow ring, inactive = `border`.
Use for: vertical timeline steps in charter and checklist views.

---

### Status & Feedback

#### `SyncStatusBadge`
Four states with animation:
- **Synced:** Pulsing green lantern
- **Syncing:** Rotating arrows + "Syncing…" label
- **Pending:** Clock icon
- **Failed:** Warning triangle + optional retry button

#### `VisibilityBadge`
Icon + label pill. Colors: `visibilityPublic` (teal), `visibilityCommunity` (gold), `visibilityPrivate` (gray).

#### `ErrorBanner`
Slides in from bottom. Warning triangle + description + optional retry + dismiss.
**Proposed extension:** Add a `style` parameter — `.error` (current red-tinted), `.success` (green-tinted, checkmark), `.warning` (gold-tinted). This replaces the need for a separate toast component.

#### `SkeletonBlock`
Shimmer animation: `surface → surfaceAlt → surface` gradient, 1.2s linear loop.
Always present a skeleton that matches the exact shape of the real content.

---

### Cards

#### `ActionCard`
Full-bleed `primary` gradient card (shadow r:12, y:8). Icon circle + title + subtitle + arrow CTA button.
Use for: the home screen "no active charter" state, onboarding prompts.

#### `SelectableCard`
Generic selectable container. Selection state: 2pt `primary` border + elevated shadow.

#### `ContextMiniCard` *(to be built)*
A compact card that appears at the top of detail screens to provide navigation context. Contains:
- Thumbnail (square, 64pt, `cardCornerRadius`)
- Title (`subheader`)
- Subtitle (`caption`, `textSecondary`)
- One `StatsRow` or key metadata line
Styled with `.cardStyle()`. Collapses on scroll using `ScrollView` offset tracking.
Use for: top of `CharterDetailView`, `LibraryContentDetailView` — replacing the large rebuilt hero card.

---

### Form Components

All in the `DesignSystem.Form` namespace.

#### `BubbleCard`
`surface` background + `cardCornerRadius` + white 5% border. Groups related form fields.

#### `BubbleTextField`
`surfaceAlt` background + optional leading/trailing icon. Uses `.formFieldStyle()`.

#### `FieldLabelMicro`
Uppercase `micro` + 0.8 tracking. Use above form fields.

#### `FormTextField`
Standard field with `.formFieldStyle()`.

#### `Progress`
`primary → gold` gradient capsule fill + percentage label. Animated fill.

#### `Hero` (Form)
140pt dark gradient header with icon watermark + title/subtitle. Used in editor screens.

#### `SummaryRow`
Icon (emoji or SFSymbol) + label + value + optional detail. Used in charter detail and editor summaries.

**Note:** Replace emoji icons (`📅`, `📍`) in `SummaryRow` with tinted SFSymbol circles for brand consistency.

---

### Profile Components

#### `Profile.Hero`
256pt full-bleed hero — photo or `primary` gradient fallback. Glass edit button (`.glassPanel()`) top-right.

#### `Profile.HeaderContent`
112pt avatar with border ring, camera picker overlay. Username in `largeTitle` (Onder). Metadata row: location, member-since, community pill.

#### `Profile.InfoRow`
Icon + label + value + detail. Tinted icon background.

#### `Profile.MetricsCard`
`sectionContainer` with a list of icon + label + value rows.

---

## 6. Patterns

### Screen Anatomy

Every screen follows this structure:

```
NavigationView
  ├── .navigationBarTitleDisplayMode(.inline)
  ├── .toolbar { ToolbarItem(.principal) { Text in Typography.headline } }
  └── ScrollView (or List)
       ├── Optional: ContextMiniCard (on detail screens)
       ├── Content sections with SectionLabel headers
       └── Bottom safe area padding for FloatingActionButton
Optional: FloatingActionButton (safeAreaInset bottom)
```

### List Configuration

All lists use:
```swift
.listStyle(.plain)
.scrollContentBackground(.hidden)
// Row background: Color.clear
// Row separator: .hidden
```

This floats cards over the screen background. Never use `.insetGrouped` or `.grouped` list styles.

### Loading States

1. Show skeleton rows on initial load (`CharterSkeletonRow`, `LibrarySkeletonRow`)
2. Show `ProgressView` on detail loading
3. Never show an empty state before the first load completes
4. Support `.refreshable {}` on all scrollable list screens

### Error & Success Feedback

- Network/mutation errors → `ErrorBanner` (bottom slide-in)
- Success confirmations → `ErrorBanner` with `.success` style, auto-dismiss after 2.5s
- Destructive actions → Modal confirmation (`DeleteConfirmationModal`, `CharterDeleteModal`)
- No inline alert dialogs for routine errors

### Navigation

- All sheets use `cardCornerRadiusLarge` (24pt) on their top corners
- Navigation pushes are used for detail screens; sheets for editors and confirmations
- The tab bar is the only persistent navigation chrome — do not add bottom bars in pushed views

### Empty States

Two variants:
- `EmptyStateView` — with primary CTA button (use when there's a clear creation action)
- `EmptyStateHero` — without button (use for filtered/search results with no matches)

Both use: 120pt gradient circle container + SFSymbol (`.light` weight, 48pt) + `display` title + `body` description.

---

## 7. Motion & Animation

### Defined Constants *(to be standardized)*

| Token | Curve | Duration | Usage |
|---|---|---|---|
| `standard` | `.easeOut` | 0.2s | Most transitions, value changes |
| `interactive` | `.easeOut` | 0.12s | Button press scale, tap responses |
| `spring` | `.spring(response: 0.35, dampingFraction: 0.8)` | — | Cards appearing, sheet transitions, list inserts |
| `skeleton` | `.linear` | 1.2s | Skeleton shimmer loop |
| `slow` | `.easeInOut` | 0.4s | Modal appearances, full-screen transitions |

### Principles

1. UI animations should feel like water — smooth, with natural deceleration.
2. Interactive feedback (button press) must be immediate — `interactive` at 0.12s.
3. Data appearing (cards loading) should spring in, not fade in linearly.
4. Never animate decorative elements (backgrounds, gradients) unless they are the focal point.
5. Skeleton loading should run at a constant linear speed — it signals "working", not "arriving".

---

## 8. Iconography

**System:** SF Symbols exclusively. No custom icon assets.

**Sizing:**
- Navigation bar buttons: 20pt
- Card/row icons inside a circle container: 20–24pt
- Hero/empty state icons: 48–56pt (`.light` weight at this size)
- Inline metadata icons: 14–16pt

**Containers:**
- Small tinted circle (28–32pt): `surface` or brand-tinted background + icon at 14pt. Used in profile info rows, stat labels.
- Medium gradient circle (40–48pt): `primary` gradient background + white icon at 20pt. Used in library items, community badges.
- Large gradient circle (80–120pt): `primary` gradient background + white icon at 40pt. Used in empty states.

**Brand icon:** `sailboat` (SF Symbol) is the primary brand icon — used in empty states, hero headers, the home screen. Never `car.fill` or unrelated metaphors.

---

## 9. Dark Mode

Dark mode is not "inverted light mode." It is a distinct presentation.

### Principles

1. Use `oceanDeep` as the true dark background layer. Place it under `background` with `2–4%` opacity to give dark surfaces a teal personality.
2. Cards in dark mode should feel like they emit a faint inner light — achieve this with `white.opacity(0.06)` top-edge borders (the `subtleOverlay` gradient).
3. Teal and gold accents become *more* prominent in dark mode — let them breathe.
4. Photo hero cards in dark mode look stunning — lean into them. They should be the dominant visual element on dark screens.
5. Never hardcode `Color.black` or `Color.white` in view code — always use semantic tokens that adapt.

---

## 10. Accessibility

1. All interactive elements must meet a minimum 44×44pt tap target.
2. Color is never the *only* signal — pair color with an icon or label (e.g. `VisibilityBadge` uses both color and icon).
3. `SkeletonBlock` placeholders must not be accessible elements — use `.accessibilityHidden(true)`.
4. Typography scale should not use fixed sizes that don't respect Dynamic Type — confirm all `Font.system` calls use semantic sizes where possible.
5. `SyncStatusBadge` animated states should provide `.accessibilityLabel` for VoiceOver.

---

## 11. Components Backlog

Components that should be built to close current gaps:

| Component | Priority | Description |
|---|---|---|
| `FloatingActionButton` | High | Pill CTA floating over content, blur backdrop |
| `ContextMiniCard` | High | Compact detail context header that collapses on scroll |
| `StatsRow` | High | Inline icon+number+label horizontal stat strip |
| `OverlayChip` | Medium | Glass floating badge for hero photo cards |
| `ToastView` / `ErrorBanner.success` | High | Success feedback for mutations |
| `AvatarStack` (enhanced) | Medium | Overlapping avatars with count, emoji reactions |
| `MilestoneTimeline` | Medium | Numbered vertical timeline for charters/checklists |
| `MapStyleWrapper` | Low | Teal-tinted MapKit overlay consistent with brand |
| `HapticEngine` | Low | Centralized haptics (`.selection`, `.impact`, `.notification`) |

---

## 12. Governance Rules

These rules apply to all new and edited view code:

1. **No raw values in views.** Colors, spacing, corner radii, and font sizes must come from `DesignSystem.*` tokens.
2. **Strings are not icons.** Emoji in `SummaryRow` (`📅`, `📍`) must be replaced with `Image(systemName:)` + a tinted circle container.
3. **One primary action per screen.** If a screen has a `PrimaryButtonStyle` or `FloatingActionButton`, it can only have one. All other actions are secondary or outline.
4. **Skeleton before empty.** Never show `EmptyStateView` on the first load — show skeletons until the first data response completes.
5. **Token misuse.** Using `Spacing.md` as a corner radius is incorrect — spacing tokens are not corner radius tokens. Use `cornerRadiusSmall`, `cardCornerRadius`, or `cardCornerRadiusLarge`.
6. **hashColor must be shared.** The `hashColor()` utility for avatar colors must live in `DesignSystem.Color` — not copied between feature views.
