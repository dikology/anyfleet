# Profile View — Current State & Redesign Plan

---

## Part 1 — Current Authenticated Profile View

### Screen Structure

The authenticated profile is a `ScrollView` with four stacked regions:

```
ScrollView
  ├── heroSection          → DesignSystem.Profile.Hero (256pt)
  ├── headerContentSection → DesignSystem.Profile.HeaderContent (overlaps hero by -48pt)
  ├── mainContent
  │    ├── [display mode]
  │    │    ├── ProfileStatsBar
  │    │    ├── CommunitiesSection
  │    │    ├── [CommunityManager link if applicable]
  │    │    └── SocialLinksDisplaySection
  │    └── [edit mode]
  │         └── ProfileEditForm
  └── accountManagementSection
```

### 1. Hero Section (`DesignSystem.Profile.Hero`)

- 256pt full-bleed container
- **Background:** `AsyncImage` from `user.profileImageUrl` if set; falls back to a `primary.opacity(0.7 → 1.0)` gradient (topLeading → bottomTrailing)
- **Overlay gradient:** `clear → clear → background.opacity(0.3) → background` — fades the hero into the scroll background at the bottom
- **Edit button:** Glass circle (40pt, `.glassPanel()`, clipped to `Circle`) with `pencil` icon, positioned top-trailing at `padding(.top, 56)`. Triggers `viewModel.startEditingProfile(user:)`
- The hero has no contextual data, no overlay chips, no social presence signals

### 2. Header Content Section (`DesignSystem.Profile.HeaderContent`)

Overlaps the hero by `-48pt` top padding. Left-aligned. Contains:

- **Avatar:** 112pt circle with 4pt `background`-colored border ring. `AsyncImage` from `profileImageThumbnailUrl`; falls back to `primary` gradient + `person.fill` placeholder. Camera picker badge (36pt glass circle, bottom-trailing, +4pt offset) for photo upload. Progress indicator during upload.
- **Username:** `.system(size: 28, weight: .bold, design: .rounded)` — **not using the Onder `largeTitle` token**. The `.rounded` design is SF Pro Rounded, not the Onder brand typeface.
- **Metadata row:** Location (mappin.circle.fill, primary), Member Since (calendar, primary), Primary Community chip — horizontal HStack. All at `.system(size: 13, weight: .medium)`.
- **Bio:** `Typography.body`, `textSecondary`, `lineSpacing(4)`. Shown below metadata row when non-empty.
- **Verification tier:** Passed in as parameter but **never rendered** — dead prop.

### 3. Stats Bar (`ProfileStatsBar`)

Uses the `DesignSystem.StatsRow` component. Shows 4 stats:

| Icon | Value | Label |
|---|---|---|
| `sailboat.fill` (primary) | `chartersCompleted` | Charters Completed |
| `map` (info) | `"—"` | Nautical Miles *(always dash — not implemented)* |
| `sun.horizon.fill` (success) | `daysAtSea` | Days at Sea |
| `person.3.fill` (communityAccent) | `communitiesJoined` | Communities Joined |

`ProfileStatsBar` is gated behind `if let stats = viewModel.captainStats` — shows nothing while loading.

### 4. Communities Section (`CommunitiesSection`)

- `FlowLayout` (custom `Layout`) of community chips
- Primary community has gold `anchor.circle.fill` icon + gold `strokeBorder` ring
- Non-primary communities render as plain `CommunityBadge(style: .pill)`
- Context menu on each chip: "Set as Primary" (non-primary only), "Leave" (destructive)
- Count badge (communityAccent capsule) in section header
- "Find Communities" button (primary, `plus.circle.fill`) always visible below chips
- Empty state: plain caption text

### 5. Community Manager Link

Shown only when `viewModel.managedCommunities` is non-empty. `NavigationLink` to `AppRoute.communityManager`. Card-style row: 40pt gold circle icon (`person.3.sequence.fill`) + title/subtitle + chevron.

### 6. Social Links (`SocialLinksDisplaySection`)

Horizontal chip row. Each chip: icon + platform name in info-tinted `cornerRadiusSmall` pill. Opens URL via `Link`. Only shown when there are active (non-empty handle) links.

### 7. Account Management Section

Two destructive actions in a `VStack`:
- **Delete Account** — `accountActionButton` wrapper: `trash.fill` (error red) + text + chevron, wrapped in `.cardStyle()`. **Action is a no-op `{}`.**
- `Divider` between them (raw, unstyled)
- **Sign Out** — inline `Button` with `arrow.right.square` (error red) + text, also wrapped in `.cardStyle()`

### 8. Unauthenticated State

Vertically centered: Welcome title (`largeTitle`, bold) + subtitle (`body`, secondary) — left-aligned. Below: `sectionContainer()` panel with `SectionHeader` + `SignInWithAppleButton` (black style, 50pt height, `cornerRadiusSmall`).

---

## Part 2 — Issues & Design Debt

### Typography Violations

| Location | Current | Required |
|---|---|---|
| `HeaderContent` username | `.system(size: 28, weight: .bold, design: .rounded)` | `Typography.largeTitle` (Onder, 22pt, semibold) |
| `HeaderContent` metadata row | `.system(size: 13, weight: .medium)` | `Typography.caption` |
| `Profile.InfoRow` label | `.system(size: 14, weight: .medium)` | `Typography.caption` + `.fontWeight(.semibold)` |
| `Profile.EditForm` buttons | inline font + padding | `SecondaryButtonStyle` / `PrimaryButtonStyle` |

### Corner Radius Violations

| Location | Current | Required |
|---|---|---|
| `Profile.InfoRow` background | `RoundedRectangle(cornerRadius: 12)` | `cardCornerRadius` (16pt) |
| `Profile.EditForm` text editor | `.cornerRadius(Spacing.sm)` | `cornerRadiusSmall` (10pt) |
| `Profile.EditForm` action buttons | `.cornerRadius(Spacing.md)` | `cornerRadiusSmall` (10pt) |

### Functional Issues

1. **Delete Account is a no-op.** The `accountActionButton` for delete calls `action: {}`. Needs to wire to a confirmation modal + actual deletion flow.
2. **Verification tier not displayed.** `VerificationTier` is passed to `HeaderContent` but never rendered. Either show it as a badge beside the username or remove the parameter.
3. **Nautical miles always "—".** The `ProfileStatsBar` always renders a dash for miles. If the data isn't available, hide that stat item or show `0 nm` with a note.
4. **Nationality not shown in display mode.** `user.nationality` is only used in the edit form, never displayed. Should appear in the metadata row or a profile detail row.
5. **Profile visibility not surfaced.** `user.profileVisibility` exists but there's no UI indicator or control to change it from the profile view.
6. **`DesignSystem.Profile.EditForm` is an unused component.** The actual edit form is `ProfileEditForm` (in `Components/ProfileEditForm.swift`). The DS-namespaced `EditForm` appears to be an older, simpler version. It should be either removed or unified.

### Structural / UX Issues

7. **Account management is at the bottom of a very long scroll.** Delete Account and Sign Out are buried below stats, communities, and social links. Users looking for sign out will scroll past all their data. These actions should either float or be in a dedicated "Settings" section with a clear visual anchor.
8. **Edit mode replaces all display content in-place.** When editing, the entire `mainContent` section swaps to `ProfileEditForm`. This creates a jarring layout shift — the hero and header remain but everything below jumps. Consider a sheet-based edit experience instead.
9. **No loading state for stats.** When `viewModel.captainStats` is nil (loading), the stats bar simply doesn't appear. A skeleton `StatsRow` should be shown during load.
10. **Communities section lacks "manage" affordance in display mode.** Users can only add communities from the display view; to set-primary or leave they must long-press for a context menu — this pattern is not discoverable.

---

## Part 3 — Redesign Recommendations

### 3.1 Prioritized Fixes (Small Effort, High Quality)

1. **Fix username typography** — replace `.system(size: 28, weight: .bold, design: .rounded)` with `Typography.largeTitle` (Onder). This single change makes the profile feel brand-native instead of generic.

2. **Show verification tier badge** — add a small `Image(systemName: tier.icon).foregroundColor(tier.color)` inline after the username, with an `.accessibilityLabel`. For `trusted` and `expert` tiers this is a meaningful social signal.

3. **Fix `Profile.InfoRow` and `Profile.EditForm` corner radii** — swap hardcoded values for tokens.

4. **Nationality in display mode** — add to metadata row with `flag.fill` icon, between location and member-since. Fits the existing pattern.

5. **Hide "—" nautical miles stat** — gate the miles `StatsRow.Item` on `stats.nauticalMiles > 0`. When hidden, the three remaining stats have more breathing room and none of them are placeholder values.

6. **Skeleton stats bar** — add a `DesignSystem.SkeletonBlock` matching `StatsRow` dimensions when `captainStats == nil`.

### 3.2 Account Management Redesign

The current account section is visually inconsistent: two card-style rows separated by a raw `Divider()` are not actually grouped as a card. Redesign as a single `sectionContainer()` that holds both items, styled as a danger zone:

```
ACCOUNT  [micro label]
"Your data is stored locally..." [caption]

sectionContainer
  ├── [trash.fill] Delete Account    [chevron]
  ├── Divider (styled, not raw)
  └── [arrow.right.square] Sign Out  [chevron]
```

Both rows inside the container get `padding(md)` with a `Divider` between them (using `border` color). The outer container gets a subtle `error.opacity(0.06)` tint to signal the destructive nature without being aggressive.

Delete Account should present a `DeleteConfirmationModal` (or a new `AccountDeletionModal`) with explicit confirmation before acting.

### 3.3 Edit Experience — Sheet vs In-Place

The current in-place edit swap creates a layout shift and forces the user to scroll back up to see the avatar/hero while editing fields below. Proposed approach:

**Move profile editing into a presented sheet** (`cardCornerRadiusLarge` top corners). The sheet contains:
- A compact `DesignSystem.Form.Hero` (140pt, `focalGoldRadial`, Onder title "Edit Profile")
- `BubbleCard` sections for: Identity (name, bio), Location & Nationality, Social Links, Communities
- Sticky `PrimaryButtonStyle` footer with Save CTA

This decouples the view-mode profile from the edit-mode completely, removes the layout shift, and matches the pattern of `CharterEditorView` — the best-executed screen in the app.

The pencil button in the hero becomes a `FloatingActionButton`-style call to present this sheet.

### 3.4 Communities Section Enhancement

- Add **role badges** for `moderator` and `admin` members beside the community chip (a small `star.fill` or `shield.fill` indicator)
- Replace the hidden context menu with visible inline actions on long-press tooltip or swipe-to-manage on the chip in edit mode
- In display mode, show a subtle `"Tap & hold to manage"` micro hint below the chips on first visit (same `@AppStorage` pattern as swipe onboarding)
- Community chips should show an **icon/logo thumbnail** when `iconURL` is available, not just the text name

### 3.5 Hero Section Enhancement

The profile hero is strong structurally but visually thin when there's no photo. Improvements:

- **No-photo state:** Replace the flat teal gradient with the `focalGoldRadial` gradient treatment (gold radial from bottom-center) — this matches the Charter Editor hero and is more distinctive
- **Photo state:** Add a `heroImageOverlay` gradient overlay (`black 15% → 50% → 75%`) so the avatar and text below always read cleanly regardless of photo content
- **Member stats chip:** Add an `OverlayChip`-style glass badge at bottom-left of the hero showing `daysAtSea` with a `sun.horizon.fill` icon — one contextual data point directly on the photo creates the "alive" effect described in the design review
- **Verification tier in hero:** For `trusted`/`expert` users, a small gradient chip with the tier name could float over the hero at bottom-right, consistent with the `VisibilityBadge` pattern

### 3.6 Profile Visibility Control

`profileVisibility` is stored but never surfaced. Add a `VisibilityBadge` to the metadata row (below username) showing the current visibility state. Tapping it presents a simple picker (public / private). This makes the feature functional and visible.

---

## Part 4 — Redesign Priority Matrix

| Improvement | Effort | Impact | Phase |
|---|---|---|---|
| Username typography token fix | XS | High | 1 |
| Verification tier badge | XS | Medium | 1 |
| DS token fixes (corners, spacing) | S | Medium | 1 |
| Nationality in display mode | XS | Low | 1 |
| Hide unavailable stats | XS | Medium | 1 |
| Skeleton stats bar | S | Medium | 1 |
| Account section redesign (grouped card, danger tint) | S | Medium | 2 |
| Delete Account modal wiring | M | High | 2 |
| Profile visibility control | M | High | 2 |
| Communities role badges + icon thumbnails | M | Medium | 2 |
| Edit experience → sheet | L | High | 3 |
| Hero `focalGoldRadial` no-photo fallback | S | High | 3 |
| Hero overlay chip (days at sea) | M | High | 3 |
| Profile visibility chip in hero | M | Medium | 3 |
