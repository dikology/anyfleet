# Anyfleet Design Review

> Reviewed against the current codebase and benchmarked against a reference app with strong visual execution.
> Goal: identify where the app feels like a prototype vs. a polished product, and surface actionable improvements.

---

## Summary Verdict

The design foundation is genuinely solid. The token system (colors, spacing, typography) is well-structured, the `heroCardStyle` elevation system is thoughtful, and key screens like the Charter List and Library are more polished than average. The brand identity — teal/ocean palette, Onder typeface, gold accent — is distinctive and coherent.

The gap between "prototype" and "product" is not about the design system itself. It is about **surface richness**, **emotional resonance**, and **consistency of execution across all screens**. Several screens have been styled; several others are still plainly functional. The reference app stands apart because every card, every detail row, every transition feels *crafted* — not just laid out.

---

## What the Reference App Does That We Don't

### 1. Hero Cards Are Genuinely Cinematic

The reference app treats hero photo cards as compositions. Contextual data floats *over* the image as distinct overlay chips — a temperature badge top-center, a user-presence cluster bottom-left, a social counter bottom-right. Each element is independently positioned and styled.

Our hero cards use a `heroImageOverlay` gradient with stacked text — this reads well but feels flat by comparison. There are no floating widget compositions, no social presence, no contextual data at a glance.

**Opportunity:** Introduce composable overlay badge slots on hero photo cards. Even a single contextual chip (e.g. charter countdown, member count) positioned over a photo dramatically elevates perceived quality.

---

### 2. Social Presence Is Embedded Everywhere

In the reference app, user avatar stacks appear directly on cards — with emoji reactions overlaid on individual avatars. This makes the app feel alive and inhabited. You see *who else is here* before you open anything.

We have `CommunityBadge` and avatar stacks in `DiscoverContentRow` and `LibraryItemRow`, but they're small, placed in detail rows, and carry no emotional signal (no reactions, no count).

**Opportunity:** Make avatar stacks a first-class design element. Elevate them visually (larger, with overlap, with a count chip) and place them on hero cards, not just in metadata rows.

---

### 3. Detail Screens Lose Navigation Context

When drilling into a detail in the reference app, a compact mini-card appears at the top of the screen — a thumbnail + key stats + title. This gives instant wayfinding: you always know what you're looking at and where you came from.

Our `CharterDetailView` opens with a large hero card rebuilt from scratch. The `LibraryContentDetailView` has no such context card. There is a disconnect between the list item you tapped and the detail screen that opened.

**Opportunity:** Introduce a "context header" pattern for detail screens — a compact version of the originating card (thumbnail, name, one key stat) that sits at the top and collapses on scroll.

---

### 4. The Dark Mode Aesthetic Is Functional, Not Intentional

The reference app's dark variant feels *designed* — not just adapted. Rich dark backgrounds (#0A0A0A–#111111), components that glow slightly at their edges, photo cards that pop against deep surfaces, a sense of depth and atmosphere.

Our dark mode is entirely reliant on UIKit's adaptive semantic colors (`systemGroupedBackground`, `secondarySystemGroupedBackground`). These are contextually correct but produce a flat, gray-on-dark-gray appearance. The teal and gold accents are strong but they're punctuating a bland dark canvas.

**Opportunity:** Layer intentional depth into dark surfaces. The `oceanDeep` color already exists — use it as a true dark background tint. Introduce subtle inner glows on elevated cards in dark mode. Even `white.opacity(0.06)` borders on cards make a significant difference at night.

---

### 5. Floating Bottom Actions Are Absent from View Screens

The reference app's floating "Open Skipass" CTA is a highly polished iOS pattern — a large pill button floating above the content, blurred background, rounded corners. It makes the primary action impossible to miss without disrupting the scroll.

We use sticky footer CTAs in editors (`CharterEditorView`, `ChecklistExecutionView`), but view-mode screens that have primary actions (e.g. "Add check-in", "Fork this content") often bury those actions in a navigation bar button or a small in-content button.

**Opportunity:** Introduce a `FloatingActionButton` system component. Use it on screens where there is one clear primary action and it should always be reachable.

---

### 6. Stats Are Not a Design Element

The reference app's "26 ski runs / 112 km / 8 types" row is a small but impactful detail. Three stat groups, pipe-separated, each with an icon — compressed into a single horizontal row that reads instantly.

Our stats appear as `FormSummaryRow` items with emoji icons, or metadata label-value pairs. They're readable but not *scannable*. There's no visual hierarchy that lets you parse key numbers at a glance before reading text.

**Opportunity:** Design a `StatsRow` component: horizontally laid-out stat groups with an icon, a bold number, and a label. Use it on charter and content detail cards.

---

### 7. Numbered/Milestone Timeline Is Underused

The "Visit Log" in the reference app uses a numbered vertical timeline — circle badges with sequence numbers, connecting lines, media thumbnails. This creates a sense of journey and achievement.

We have a `TimelineIndicator` component and use it in the Charter List date gutter. But the actual timeline concept — a visual log of places visited, actions taken — never surfaces in the experience. Charters are a sequence of events but they're displayed as a flat list.

**Opportunity:** Introduce a milestone/journey timeline view for charters — especially on the detail screen. Check-in items with numbered badges, connecting lines, and completion states would transform the checklist into a voyage log.

---

## Screen-by-Screen Assessment

### Home — ★★★★☆ (Strong, one refinement needed)

Well-structured. The hero charter card with the `heroImageOverlay` gradient is effective. The greeting with Onder font is the best use of brand typography in the app.

**Issues:**
- Pinned item cards use hardcoded `cornerRadius: 14` instead of a design token
- No social presence signal anywhere on the home screen — it could show "3 of your friends are sailing this month"
- The "no charter" `ActionCard` with primary gradient is good, but the icon (SFSymbol on a gradient bg) lacks personality versus a custom illustration or photo background

---

### Charter List — ★★★★☆ (Polished, minor gaps)

The date gutter is the app's most distinctive layout pattern. `heroCardStyle` with `CharterVisibilityBadge` + `SyncStatusBadge` is thorough.

**Issues:**
- Duration pill and vessel label are the right accents but they sit in a bottom metadata row that feels dense. Consider icon-only or abbreviated form
- Past charters collapse behind a button — the animation and affordance for this interaction needs to feel more physical (spring animation on the expand, chevron rotation)
- "Upcoming" section header is a plain label; a subtle background treatment or icon would give it more visual weight

---

### Charter Detail — ★★★☆☆ (Functional, under-designed)

The most important screen in the app feels the most unfinished. A large card with `FormSummaryRow` items using emoji icons reads as a development placeholder.

**Issues:**
- Charter name uses raw `font(.system(size: 24, weight: .bold))` — not a typography token
- Emoji icons (`📅`, `📍`) are not brand-consistent — use SFSymbols with tinted circles
- The check-in section is a single `NavigationLink` row; the detail screen needs to be a full voyage experience (map preview, timeline, weather, crew)
- No visual personality — the oceanDeep gradient tint is subtle to the point of invisible

---

### Charter Editor — ★★★★★ (Best-executed screen)

The most polished screen in the app. The `focalGoldRadial` hero header, `BubbleCard` form sections, `BubbleTextField` with icons, and the gold duration accent are all excellent. This is the gold standard for what other screens should aspire to.

---

### Library List — ★★★★☆ (Rich, slightly overloaded)

`LibraryItemRow` is the app's most visually ambitious card. Gradient foreground text on the title, `focalHighlight` shimmer, stacked badges.

**Issues:**
- The card is very dense. `PublishActionView` in the footer of every library row adds visual noise — consider moving publish actions to a swipe action or detail screen
- The gradient title text foreground is a strong statement but it reduces scannability at small sizes
- `hashColor()` for avatars is duplicated between this and `DiscoverContentRow` — should be a shared utility

---

### Discover — ★★★☆☆ (Inconsistent)

`DiscoverContentRow` does not use `heroCardStyle` — it manually recreates similar styling with a hardcoded `cornerRadius: 12`. The visual result is almost identical but the code is inconsistent and will diverge.

**Issues:**
- No `heroCardStyle` usage — hardcoded shadow + radius + overlay
- `cornerRadius: 12` not from token (should be `cardCornerRadius = 16`)
- Avatar overlapping stack is visually weaker than the reference app's version (no count, no emoji reaction)
- Charter discovery map toggle exists but map styling is stock MapKit

---

### Profile — ★★★★☆ (Strong structure, edge cases rough)

`Profile.Hero` and `Profile.HeaderContent` are well designed. The overlap of the header content over the hero is the right iOS pattern.

**Issues:**
- Account section buttons use `cornerRadius: DesignSystem.Spacing.md` (spacing token misused as radius)
- Stats bar needs icon + number + label grouped pattern (not just a number)
- Communities section feels like a list of text labels; could benefit from logo/icon thumbnails

---

### Community Manager — ★☆☆☆☆ (Placeholder)

Plain `List` with stock appearance. No `scrollContentBackground(.hidden)`, no design system surfaces, no skeletons, no empty state, no hero element. This screen is unambiguously a development stub.

---

### Sign-In — ★☆☆☆☆ (Off-brand)

Uses `Image(systemName: "car.fill")` with `.blue` color and a plain system font. Completely inconsistent with the app's identity. The car icon is likely a copy-paste artifact from a template. The `ProfileView` unauthenticated state and `SignInModalView` are both far better — the dedicated `SignInView` should be replaced with the same pattern.

---

### Checklist Execution — ★★★☆☆ (Functional but flat)

Progress tracking is present but the screen lacks the voyage/journey visual identity that checklists deserve. Raw `font(.system(size: 24, weight: .bold))` on the title.

---

## Systemic Issues

| # | Issue | Severity | Fix |
|---|---|---|---|
| 1 | Raw `.system(size:weight:)` calls bypass typography tokens | Medium | Audit all views, replace with `Typography.*` |
| 2 | `cornerRadius: 12/14/8` hardcoded throughout | Medium | Replace with `DesignSystem.Spacing.cornerRadius*` tokens |
| 3 | `hashColor()` duplicated in two views | Low | Extract to `DesignSystem.Color` extension |
| 4 | No animation constant system | Medium | Define `Animation.standard`, `Animation.spring`, `Animation.skeleton` in DS |
| 5 | No success/confirmation feedback (only errors) | High | Add `ToastView` / success state to `ErrorBanner` |
| 6 | `SignInView` is off-brand | High | Rebuild using `Profile.Hero` + primary gradient identity |
| 7 | `CommunityManagerView` unstyled | High | Apply full design system treatment |
| 8 | No tab bar customization | Medium | Define tab bar appearance in `AppearanceConfiguration` |
| 9 | Map views unstyled | Low | Add MapKit style overrides (dark map tile, teal overlay) |
| 10 | No haptic feedback system | Low | Add centralized `HapticEngine` for button/state feedback |

---

## Priority Improvements (Effort vs. Impact)

### High Impact, Low Effort
1. **Fix `SignInView`** — rebuild in 1–2 hours, eliminates the most jarring inconsistency
2. **Audit and replace raw font calls** — text search + replace, 1–2 hours
3. **Audit and replace hardcoded corner radii** — find/replace, 1–2 hours
4. **Add `ToastView` success component** — new DS component, ~3 hours

### High Impact, Medium Effort
5. **Redesign `CharterDetailView`** as a voyage experience with map preview, stats row, and journey timeline
6. **Introduce `FloatingActionButton`** system component with backdrop blur
7. **`CommunityManagerView` styling pass** — apply design system, add skeleton/empty state
8. **Composable hero card overlay badges** — `OverlayChip` component for contextual floating data

### Medium Impact, Higher Effort
9. **Social presence on hero cards** — avatar stacks with counts on charter cards
10. **Context header on detail screens** — compact mini-card for wayfinding
11. **Dark mode depth pass** — intentional dark backgrounds, edge glows, per-scheme gradient variants
