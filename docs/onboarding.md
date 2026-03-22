# Swipe Gesture Onboarding — Implementation Plan

> Scope: `CharterListView`, `DiscoverView` (content tab), `LibraryListView`  
> Goal: Surface swipe-action discoverability on first encounter, while also addressing the UI/UX and refactoring debt identified in each view during this review.

---

## Part 1 — Swipe Action Inventory

| Screen | Swipe Direction | Actions | Status |
|---|---|---|---|
| Charter List (upcoming) | Trailing | Edit (`pencil`, gray), Delete (`trash`, red) | Implemented |
| Charter List (past) | Trailing | Delete only | Implemented — **edit is missing on past charters** |
| Library List | Trailing | Pin/Unpin (`pin`/`pin.slash`, primary), Edit (`pencil`, gray), Delete (`trash`, red) | Implemented |
| Discover Content | Trailing | Fork (`arrow.triangle.branch.fill`, primary) | Implemented |

The actions exist. The problem is discoverability — none of these screens telegraph that swipe actions are available.

---

## Part 2 — Onboarding Approach

### Decision: Animated Row Hint + Persistent Tip

The recommended pattern is a two-part first-run experience:

1. **Animated Swipe Hint** — On first appearance of a populated list, the top row gently slides left ~60pt to reveal action buttons, then springs back after ~1.2 seconds. This is the most legible gesture tutorial in native iOS — it doesn't interrupt the user or require any taps.

2. **Tip Chip** — A compact floating chip appears above the list (below the navigation bar) while the animation plays, labeling the actions available on this screen. It auto-dismisses with the animation.

### Persistence

Use `@AppStorage` per screen to record whether the hint has fired. Once shown, it never repeats.

```swift
@AppStorage("hasSeenCharterSwipeHint") private var hasSeenHint = false
@AppStorage("hasSeenLibrarySwipeHint") private var hasSeenLibraryHint = false
@AppStorage("hasSeenDiscoverSwipeHint") private var hasSeenDiscoverHint = false
```

Trigger: The hint fires in `.onAppear` only after the first data load resolves with ≥1 item, with a 0.8s delay (let the list settle and the user's eye land before animating).

---

## Part 3 — New Component: `SwipeHintRow`

### Spec

A view modifier that wraps a list row and can play a "peek-and-return" animation.

```swift
struct SwipeHintModifier: ViewModifier {
    @Binding var isPlaying: Bool
    let peekOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: isPlaying ? -peekOffset : 0)
            .animation(
                isPlaying
                    ? .spring(response: 0.35, dampingFraction: 0.8)
                        .delay(0.2)
                        .repeatCount(1, autoreverses: true)
                    : .default,
                value: isPlaying
            )
    }
}

extension View {
    func swipeHint(isPlaying: Binding<Bool>, peekOffset: CGFloat = 60) -> some View {
        modifier(SwipeHintModifier(isPlaying: isPlaying, peekOffset: peekOffset))
    }
}
```

Apply this modifier to **only the first visible row** in each section.

---

## Part 4 — New Component: `SwipeActionTipChip`

### Spec

A compact floating chip that describes the available swipe actions. Uses `.glassPanel()` surface, `micro` typography, SFSymbol icons per action.

```swift
struct SwipeActionTipChip: View {
    struct Action {
        let icon: String
        let label: String
        let tint: Color
    }

    let actions: [Action]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "hand.point.left.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ForEach(actions.indices, id: \.self) { i in
                if i > 0 {
                    Text("·")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: actions[i].icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(actions[i].tint)
                    Text(actions[i].label)
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text("Swipe")
                .font(DesignSystem.Typography.micro)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .glassPanel()
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
```

### Action Definitions Per Screen

**Charter List**
```swift
[
    .init(icon: "pencil", label: "Edit", tint: .gray),
    .init(icon: "trash", label: "Delete", tint: DesignSystem.Colors.error)
]
```

**Library List**
```swift
[
    .init(icon: "pin", label: "Pin", tint: DesignSystem.Colors.primary),
    .init(icon: "pencil", label: "Edit", tint: .gray),
    .init(icon: "trash", label: "Delete", tint: DesignSystem.Colors.error)
]
```

**Discover**
```swift
[
    .init(icon: "arrow.triangle.branch.fill", label: "Fork", tint: DesignSystem.Colors.primary)
]
```

---

## Part 5 — Integration Per Screen

### 5.1 CharterListView

**State additions:**
```swift
@AppStorage("hasSeenCharterSwipeHint") private var hasSeenSwipeHint = false
@State private var playSwipeHint = false
@State private var showSwipeTip = false
```

**In `charterList`:** Add `swipeHint(isPlaying: $playSwipeHint)` modifier to the first row in the upcoming section only.

**Overlay placement:** Inject the `SwipeActionTipChip` as a `VStack` overlay aligned to top, positioned just below the section header. Wrap in a `.transition(.move(edge: .top).combined(with: .opacity))`.

**Trigger in `.task` or on `onChange` of `viewModel.upcomingCharters.isEmpty`:**
```swift
.onChange(of: viewModel.upcomingCharters.isEmpty) { _, isEmpty in
    guard !isEmpty, !hasSeenSwipeHint else { return }
    Task {
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.standard) { showSwipeTip = true }
        playSwipeHint = true
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation(.standard) { showSwipeTip = false }
        hasSeenSwipeHint = true
    }
}
```

### 5.2 LibraryListView / LibraryContentList

Same pattern. `SwipeActionTipChip` positioned above the filter picker row. The hint fires on first non-empty `filteredItems` load.

### 5.3 DiscoverView

Tip appears above the content list. Fork is the only action — the single-action chip reads: "Swipe to fork any item into your library."

---

## Part 6 — View Refactoring & UI/UX Issues

### CharterListView / CharterTimelineRow

| # | Issue | Fix |
|---|---|---|
| 1 | `nameRow` uses `.system(size: 16, weight: .semibold)` | Replace with `Typography.subheader` |
| 2 | `dateGutter` uses `.system(size: 28, weight: .bold, design: .rounded)` | No token maps exactly — add a `Typography.dateDisplay` token (28pt, bold, rounded design) or use `display` (28pt Onder) |
| 3 | Sync-pending banner uses `.system(size: 14, weight: .semibold)` for the icon font | Use `Typography.caption` with `.fontWeight(.semibold)` |
| 4 | Past charter swipe actions are missing the **Edit** action | Add `.swipeActions` with Edit + Delete to the past charter `ForEach`, matching the upcoming section |
| 5 | Past section collapse chevron uses `.system(size: 11, weight: .semibold)` | Replace with `Typography.micro` + `.fontWeight(.semibold)` |
| 6 | "Upcoming" section label lacks visual weight — plain text | Wrap in a container with subtle background tint: `primary.opacity(0.06)` pill, or add a `sailboat.fill` micro icon beside the label |
| 7 | `showPast` toggle animation is `.spring(response: 0.3)` — good, but the chevron rotation is `showPast ? "chevron.up" : "chevron.down"` (symbol swap) | Replace with a single `chevron.right` + `.rotationEffect` for a smooth physical rotation |
| 8 | The past toggle button has no accessibility hint | Add `.accessibilityHint(showPast ? "Collapse past charters" : "Expand past charters")` |

### LibraryListView / LibraryContentList

| # | Issue | Fix |
|---|---|---|
| 1 | Filter picker uses `.segmented` style — functional but visually generic | Replace with a custom horizontal `ScrollView` of `micro` tab chips using `primary` underline for selection — matches brand better than system segmented control |
| 2 | `LibrarySkeletonListView` starts `animating` in `.onAppear` — correct pattern, but animation is `.linear(duration: 1.2).repeatForever(autoreverses: false)`. The `autoreverses: false` means it jumps. | Change to `autoreverses: true` for a smoother shimmer wave, or implement a proper offset-based shimmer |
| 3 | `LibraryEmptyState` has no button CTA | Per design system spec, `EmptyStateView` should have an `actionTitle` + `action` for the clear creation action. Add "Create Content" CTA. |
| 4 | Hardcoded `.padding(.bottom, 20)` in `ErrorBannerOverlay` | Replace with `DesignSystem.Spacing.xl` |

### DiscoverView / DiscoverContentRow

| # | Issue | Fix |
|---|---|---|
| 1 | `DiscoverContentRow` background + clip uses `cornerRadius: 12` — not a token | Replace with `DesignSystem.Spacing.cardCornerRadius` (16pt) |
| 2 | Overlay on the card also uses `cornerRadius: 12` | Same fix — use `cardCornerRadius` |
| 3 | Title uses `.system(size: 16, weight: .bold)` | Replace with `Typography.subheader` |
| 4 | Description uses `.system(size: 13, weight: .regular)` | Replace with `Typography.caption` |
| 5 | Relative date uses `.system(size: 11, weight: .regular)` | Replace with `Typography.micro` |
| 6 | Fork count label uses `.system(size: 11, weight: .medium)` | Replace with `Typography.micro` `.fontWeight(.medium)` |
| 7 | Content type icon has `RoundedRectangle(cornerRadius: 12)` | Use `cornerRadiusSmall` (10pt) for the tighter icon container |
| 8 | Content type badge has `RoundedRectangle(cornerRadius: 4)` | Acceptable at this scale but replace with `cornerRadiusSmall` for consistency |
| 9 | `hashColor()` private function duplicated from `LibraryItemRow` | Extract to `DesignSystem.Color.hashColor(for:)` static extension |
| 10 | `@State private var showSwipeActions = false` is declared but never used | Remove dead state |
| 11 | No skeleton state in `DiscoverView.contentTabView` | Add skeleton loading when `viewModel.isLoading && viewModel.content.isEmpty` — use `LibrarySkeletonListView` or build a `DiscoverSkeletonRow` |
| 12 | `DiscoverView` error banner uses hardcoded `.padding(.bottom, 20)` | Replace with `DesignSystem.Spacing.xl` |

---

## Part 7 — Shared Cleanup

| # | Issue | Affects | Fix |
|---|---|---|---|
| 1 | `hashColor()` is duplicated in `DiscoverContentRow` | Discover, Library | Extract to `DesignSystem.Color` extension: `static func hashColor(for string: String) -> Color` |
| 2 | `ErrorBannerOverlay` is defined inside `LibraryListView.swift` | Library | Move to `DesignSystem/Components/ErrorBannerOverlay.swift` — it's generic enough for reuse |
| 3 | Animation constants are still inline (`.spring(response: 0.3, dampingFraction: 0.7)`) | Discover row | Use standardized `Animation.spring` once those constants are defined in the DS |

---

## Part 8 — Implementation Sequence

```
Phase 1 (foundation)
  1. Extract hashColor() to DesignSystem.Color
  2. Create SwipeHintModifier + swipeHint() extension
  3. Create SwipeActionTipChip component

Phase 2 (refactor passes)
  4. CharterTimelineRow font/token fixes + missing past-charter Edit action
  5. DiscoverContentRow corner radius + typography tokens
  6. DiscoverView skeleton state

Phase 3 (onboarding wiring)
  7. Wire swipe hint to CharterListView
  8. Wire swipe hint to LibraryContentList
  9. Wire swipe hint to DiscoverView

Phase 4 (polish)
  10. Charter past-section chevron rotation animation
  11. Library filter picker → custom chip tabs
  12. ErrorBannerOverlay moved to shared DS
```

---

## Part 9 — Accessibility Considerations

- The `SwipeHintModifier` animation must be suppressed when `UIAccessibility.isReduceMotionEnabled`. Use `.withAnimation(reducedMotion ? nil : animation)` guard.
- `SwipeActionTipChip` should have `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("Swipe actions available: edit, pin, delete")` so VoiceOver users get the tip as a summary.
- Swipe actions themselves already use `Label("Edit", systemImage:)` — VoiceOver reads them correctly.
