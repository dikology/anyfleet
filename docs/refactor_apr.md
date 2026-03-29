# AnyFleet — April 2026 Refactor & Polish Plan

**Scope:** Incremental solidification of the existing iOS app + backend toward a polished, App Store-ready product.  
**Philosophy:** No major feature additions. Refactor, polish, tighten, and make what exists feel *crafted*. Where small features dramatically improve UX or solve real captain problems, they're included — but always built on top of existing entities.  
**Audience:** Solo developer working in incremental sprints.

---

## Status Check: What's Done from March

The March refactor resolved the most dangerous issues. These are **complete**:

- [x] `CharterStore.updateCharter()` cache drift fix (Critical)
- [x] Force-unwrap crash sites eliminated (`LocalRepository`, `APIClient`)
- [x] Delete charter → unpublish from backend (iOS + backend)
- [x] `DiscoverableCharter.swift` split into focused files
- [x] `ProfileViewModel` extracted to own file with `@MainActor`
- [x] `AuthService` annotated `@MainActor`
- [x] `CharterListView` / `DiscoverView` no longer create duplicate `AppDependencies`
- [x] Map: `UserAvatarPin`, selection/callout, empty overlay
- [x] `LocationProviding` protocol injected into discovery VM
- [x] Charter list section headers use `L10n`
- [x] Key test coverage (cache drift, delete-unpublish, APIClient empty response, discovery pagination)

**Still open from March** (carried into this plan where relevant):

- [ ] `AppDependencies.makeForTesting()` discards a `CharterStore`
- [ ] Magic content-type strings in `LibraryStore`
- [ ] `FlashcardDeck` stub cleanup
- [ ] "Delete Account" button — empty action
- [ ] Profile UI decomposition into sub-components
- [ ] Persistent discovery cache in SQLite
- [ ] `LibraryListView` fallback `AppDependencies()` risk
- [ ] Body-inline sorting in charter list
- [ ] `Calendar.current` allocation in `CharterTimelineRow`

---

## Guiding Principles for This Phase

1. **Every screen should feel intentional.** No screen should read as a development stub. If it exists in the tab bar, it should be polished.
2. **Consistency is more impressive than ambition.** A cohesive app with 5 good screens beats one with 3 great screens and 2 broken ones.
3. **Solve real problems simply.** Captains need reliable offline planning, quick reference content, and confidence in what they share. Polish those paths.
4. **App Store reviewers notice:** crash-free launch, working sign-in, real content in screenshots, privacy compliance, no placeholder text, no broken flows.
5. **Engagement comes from delight, not features.** Haptic feedback, smooth animations, success confirmations, and visual personality create stickiness.

---

## Sprint Structure

Work is organized into 6 incremental sprints. Each sprint is self-contained — the app is shippable after any sprint. Earlier sprints fix the most jarring issues; later sprints add polish and engagement depth.

---

## Sprint 1: App Store Critical Path (3–4 days)

*Goal: Eliminate every flow that would embarrass you in a review or crash in a reviewer's hands.*

### 1.1 Remove dead `SignInView`

**Finding:** `SignInView` was not referenced anywhere in the app target (no navigation, no sheets). Sign-in already flows through `SignInModalView`, Profile hero, and similar. The file was unused template-style code (`car.fill` icon).

**Action:**
- Delete `Features/Auth/SignInView.swift`

**Estimated effort:** &lt; 15 minutes

### 1.2 Wire "Delete Account" to a Real Flow

**Current state:** `ProfileView` has a "Delete Account" button with an empty action closure. This is an **App Store rejection risk** — Apple requires account deletion if you offer account creation (App Store Review Guideline 5.1.1(v)).

**Action (iOS):**
- Add a two-step confirmation: tap → sheet explaining what deletion means ("Your profile, published content, and charter history will be permanently removed. This cannot be undone.") → confirm with destructive button
- Call `authService.deleteAccount()` which hits `DELETE /auth/me`
- On success: clear Keychain, clear local DB; user lands in the main shell signed out (sign-in via Profile / `SignInModalView` as today)
- On failure: show error banner

**Action (backend):**
- Add `DELETE /auth/me` endpoint (or extend existing auth routes)
- Soft-delete user (set `is_deleted = true`, anonymize PII, keep content with anonymized attribution)
- Invalidate all refresh tokens for user
- Return 204

**Estimated effort:** 3–4 hours (iOS + backend)

### 1.3 Privacy & Compliance Audit

**Action:**
- Verify App Privacy nutrition labels match actual data collection (Apple ID, email, location when used, usage data via OSLog — but OSLog doesn't leave device, so likely "Data Not Collected" for analytics)
- Ensure location permission strings in `Info.plist` clearly explain *why* ("AnyFleet uses your location to show nearby charters and sailing destinations on the map")
- Add a "Privacy Policy" and "Terms of Service" link in Profile settings (even if they link to a simple web page) — required by App Store
- Confirm no third-party SDKs are collecting data without disclosure

**Estimated effort:** 1–2 hours

### 1.4 Crash-Free Launch Audit

**Action:**
- Review the remaining force-unwrap sites (run `rg '!' --type swift` scoped to production code, filter out test files and assertions)
- Ensure first-launch experience works without network (offline-first means the app must show *something* useful on a cold start with no account)
- Test: launch → no account → browse empty charters → create first charter → fill fields → save → see it in list. This path must be flawless
- Test: launch → sign in → immediate background → foreground → no crash (state restoration)

**Estimated effort:** 2–3 hours (testing + fixing any discovered issues)

### 1.5 Staging vs Production API Endpoints

**Why this belongs in Sprint 1:** Right now every device build — TestFlight *and* App Store — hits the staging server. Staging is where you break things, run migrations, test new endpoints. Real users should never touch it. If you ship to the App Store pointing at staging, a backend migration or experiment will take down real users. This must be wired correctly before any public distribution.

**Current state — three separate hardcoded staging URLs:**

| File | Line | Problem |
|------|------|---------|
| `Services/APIClient.swift` | 114 | `URL(string: "https://anyfleet-api-staging.up.railway.app/api/v1")!` |
| `Services/AuthService.swift` | 144 | Same pattern, independent hardcode |
| `Features/Discover/AuthorProfileModal.swift` | 352 | `let baseURL = "https://anyfleet-api-staging.up.railway.app"` — completely disconnected from the other two |

The `AuthorProfileModal` URL is the most dangerous: it's not even reading from `APIClient`. If `APIClient` is updated to point at production, image URLs in `AuthorProfileModal` will still silently fetch from staging. This is the kind of bug that's invisible in testing and breaks in production.

**Target state — three environments, one source of truth:**

| Build configuration | Who uses it | API target |
|--------------------|------------|------------|
| `Debug` | Simulator / local dev | `http://127.0.0.1:8000/api/v1` |
| `Staging` | TestFlight device builds | `https://anyfleet-api-staging.up.railway.app/api/v1` |
| `Release` | App Store builds | `https://anyfleet-api.up.railway.app/api/v1` *(production — see backend section below)* |

---

#### iOS Changes

**Step 1 — Add a `Staging` build configuration in Xcode**

In Xcode: Project → Info → Configurations → `+` → Duplicate "Release" → rename to `Staging`.

Assign the `Staging` configuration to a new "Staging" scheme (Product → Scheme → New Scheme). This scheme is what you archive for TestFlight. The existing "Release" scheme archives for App Store.

**Step 2 — Add `API_BASE_URL` as a User-Defined Build Setting**

In the project's Build Settings (select the project target, not a target):
- Add → User-Defined Setting → `API_BASE_URL`
- Set per configuration:
  - `Debug`: `http://127.0.0.1:8000/api/v1`
  - `Staging`: `https://anyfleet-api-staging.up.railway.app/api/v1`
  - `Release`: `https://anyfleet-api.up.railway.app/api/v1`

**Step 3 — Inject into `Info.plist`**

Add a key to `anyfleet/Info.plist`:
```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

Xcode substitutes `$(API_BASE_URL)` at build time from the User-Defined Setting. The correct URL is now baked into the binary for each configuration.

**Step 4 — Create `AppConfiguration` as the single source of truth**

Create a new file `App/AppConfiguration.swift`:

```swift
// App/AppConfiguration.swift
enum AppConfiguration {
    /// The API base URL for the current build configuration.
    /// Value is injected via Info.plist from the API_BASE_URL build setting.
    static let apiBaseURL: URL = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            // This should never happen — it means Info.plist is misconfigured
            preconditionFailure("API_BASE_URL not set in Info.plist")
        }
        return url
    }()

    /// Just the host + scheme portion — used for constructing image/asset URLs.
    static let apiHost: String = {
        guard let components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let host = components.host
        else { return "" }
        return "\(scheme)://\(host)"
    }()

    static var isStaging: Bool {
        apiBaseURL.absoluteString.contains("staging")
    }
}
```

**Step 5 — Update `APIClient` and `AuthService` to use `AppConfiguration`**

```swift
// APIClient.swift — replace the #if targetEnvironment block
init(authService: AuthServiceProtocol, session: URLSession = .shared) {
    self.baseURL = AppConfiguration.apiBaseURL
    // ... rest unchanged
}
```

```swift
// AuthService.swift — replace the #if targetEnvironment block  
init(baseURL: String? = nil, session: URLSession = .shared) {
    self.baseURL = baseURL ?? AppConfiguration.apiBaseURL.absoluteString
    // ... rest unchanged
}
```

**Step 6 — Fix `AuthorProfileModal.createProfileImageURL`**

Replace the hardcoded string with `AppConfiguration.apiHost`:

```swift
// AuthorProfileModal.swift line ~352 — before
let baseURL = "https://anyfleet-api-staging.up.railway.app"

// After
let baseURL = AppConfiguration.apiHost
```

This means image URLs now automatically follow the same environment as everything else.

**Step 7 — Remove the `#if targetEnvironment(simulator)` logic**

The simulator-vs-device distinction is now handled by the `Debug` build configuration — you only run Debug on the simulator anyway. The compile-time `#if targetEnvironment(simulator)` blocks in `APIClient` and `AuthService` can be deleted entirely.

**Step 8 — Optional: staging banner in UI**

When `AppConfiguration.isStaging` is true, show a small persistent banner at the top of the screen so it's immediately obvious which environment a build is hitting:

```swift
// AppView.swift — inside the root ZStack, above tab content
if AppConfiguration.isStaging {
    VStack {
        Text("STAGING")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.9))
        Spacer()
    }
    .ignoresSafeArea(edges: .top)
    .allowsHitTesting(false)
    .zIndex(999)
}
```

This is cheap insurance — when you or a tester opens a TestFlight build alongside the App Store build, there is no confusion about which server you're hitting.

---

#### Backend Changes

You need a production Railway deployment separate from staging. The codebase is identical — only environment variables differ.

**What to set up:**
- New Railway service: `anyfleet-api` (or `anyfleet-api-production`) using the same repo
- New Railway PostgreSQL database instance — **separate from staging**. Never share a database between staging and production.
- Production environment variables:
  - `DATABASE_URL` → production Postgres
  - `SECRET_KEY` → new, different key from staging
  - `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` → same Apple values (same app bundle)
  - `ENVIRONMENT` → `production` (disables OpenAPI docs endpoint)
  - `CORS_ORIGINS` → lock to your production domain only
- Run `alembic upgrade head` against the production database before first iOS client connects

**What NOT to do:**
- Don't point the App Store build at staging even temporarily — there's no "I'll fix it later" for data written to the wrong database
- Don't share the `SECRET_KEY` between environments — staging tokens should not be valid on production

**Estimated effort:** 2–3 hours (Xcode config: 1h, iOS code changes: 30min, Railway prod setup: 1h)

---

## Sprint 2: Visual Consistency Pass (3–4 days)

*Goal: Make every screen feel like it belongs to the same app. Audit and enforce design tokens everywhere.*

### 2.1 Typography Token Audit

**Current state:** Multiple screens use raw `.system(size:weight:)` instead of `DesignSystem.Typography.*` tokens. `CharterDetailView` and `ChecklistExecutionView` are the worst offenders.

**Action:**
- Search all `.system(size:` calls in production views
- Replace each with the closest `Typography` token (`title`, `headline`, `body`, `caption`, etc.)
- If no existing token fits, add one to `DesignSystemTypography.swift` rather than using a raw size
- Document the mapping for future reference

**Typography mapping (system UI — `DesignSystem.Typography`):**

| Token | Spec | Typical use |
|-------|------|-------------|
| `pageTitle` | 24 bold | Charter detail name, checklist execution title |
| `title` | 20 semibold | Row / card leading icons (e.g. checklist type in a link row) |
| `headline` | 17 semibold | Section titles in dense lists |
| `subheader` | 16 semibold | List row titles, section header icons |
| `dateDisplay` | 28 bold rounded | Timeline / date gutter numerals |
| `body` | 16 regular | Primary paragraph text |
| `bodyMedium` | 16 medium | Secondary icon buttons (notes, etc.) |
| `caption` | 14 regular | Secondary lines, metadata text |
| `captionSemibold` | 14 semibold | Chevrons, emphasized stats (e.g. `%` complete) |
| `captionBold` | 14 bold | Checkmark inside small controls |
| `footnote` | 12 regular | Small inline icons (warning glyph) |
| `footnoteSemibold` | 12 semibold | Badge / chip SF Symbol |
| `micro` | 11 medium | Tiny labels |
| `microRegular` / `microBold` / `microBoldMonospaced` | 11 | Sync row icons, section labels, staging banner |
| `nano` … `nanoBold` | 10 | Micro-badges, visibility segments, fork row |
| `callout` / `calloutSemibold` | 15 | Date fields, home CTAs, nav back row |
| `compact` / `compactMedium` / `compactSemibold` | 13 | Profile metadata, checklist type chips |
| `captionMedium` | 14 medium | Stat rows, publish actions |
| `lead` … `leadBold` | 18 | Library row icons, map pins, verification badge |
| `titleBold` / `titleRegular` | 20 bold / regular | Library titles, add-section row |
| `headlineRegular` | 17 regular | Toolbar back label, discovery placeholders |
| `pageTitleSemibold` / `pageTitleRegular` | 24 | Illustrated empty title vs hero icons |
| `toolbarGlyphLarge` | 28 regular | Modal trailing dismiss |
| `emptyStateHeadline` / `emptyStateTitleSemibold` | 26 bold / semibold | Empty states, form hero |
| `insetHeadline` | 22 regular | Empty library/charter lists, summary emoji |
| `symbolPlateSM` … `symbolPlateHeroLight` | 32–64 | Modal icons, empty-state circles, sign-in |
| `symbolPlate*Regular` variants | — | When Figma used `.regular` at 32 / 44 / 48 |
| `avatarInitial` / `avatarAnonymousGlyph` / `communityBadgeInitial` | scaled | Discover row avatars, community badge |

*Onder custom fonts (`display`, `largeTitle`) stay for marketing-style hero chrome; detail screens above use system tokens for legibility.*

**Estimated effort:** 1–2 hours

### 2.2 Corner Radius Token Audit

**Current state:** Hardcoded `cornerRadius: 12`, `14`, `8` scattered across views. `DiscoverContentRow` uses `12` instead of the token `cardCornerRadius = 16`.

**Action:**
- Search all `cornerRadius:` calls
- Replace with `DesignSystem.Spacing.cardCornerRadius`, `.cornerRadiusSm`, or introduce `.cornerRadiusMd` / `.cornerRadiusLg` if needed
- Fix `Profile` where `DesignSystem.Spacing.md` (a spacing token) is misused as a corner radius

**Estimated effort:** 1 hour

### 2.3 `DiscoverContentRow` — Use `heroCardStyle`

**Current state:** `DiscoverContentRow` manually recreates `heroCardStyle` with hardcoded shadow + radius + overlay. Visually close but code diverges from the system.

**Action:**
- Refactor `DiscoverContentRow` to use `.heroCardStyle()` modifier
- Ensure content-specific overlay elements (author attribution, fork count) work within the hero card pattern
- Match corner radius, shadow, and elevation to charter cards for visual cohesion across tabs

**Estimated effort:** 1–2 hours

### 2.4 `CommunityManagerView` — Apply Design System

**Current state:** Rated ★☆☆☆☆ in design review. Plain `List` with stock appearance, no empty state, no skeleton, no design system surfaces.

**Action:**
- Add `.scrollContentBackground(.hidden)` and apply app background
- Use `DesignSystem.SectionHeader` for section titles
- Add `SkeletonRow` loading state (charter skeleton variant works as a base)
- Add `EmptyStateView` with a community-themed message ("No communities yet. Create one from your profile.")
- Style community rows with `cardStyle()` or a compact card pattern
- Add community icon/logo thumbnail next to name

**Estimated effort:** 2–3 hours

### 2.5 Animation Constants System

**Current state:** No shared animation definitions. Spring animations are ad-hoc. Past-charter expand/collapse is abrupt.

**Action:**
- Add to `DesignSystem`:
  ```swift
  enum Motion {
      static let standard = Animation.easeInOut(duration: 0.25)
      static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
      static let springQuick = Animation.spring(response: 0.2, dampingFraction: 0.9)
      static let skeleton = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
  }
  ```
- Apply `Motion.spring` to past-charter expand/collapse with chevron rotation
- Apply `Motion.standard` to all sheet presentations and state transitions

**Estimated effort:** 1–2 hours

---

## Sprint 3: Charter Detail — The Voyage Experience (3–5 days)

*Goal: Transform the most important screen from "functional placeholder" to the emotional centerpiece of the app.*

### 3.1 Redesign `CharterDetailView`

**Current state:** Rated ★★★☆☆. Large card with `FormSummaryRow` and emoji icons (`📅`, `📍`). Raw font sizes. No visual personality. The most-viewed screen in the app feels the most unfinished.

**Action — Structure:**
- **Context header:** Compact mini-card at the top (thumbnail if available, charter name, date range, vessel) that collapses on scroll. Maintains wayfinding from the list
- **Stats row:** New `StatsRow` component — horizontal layout of icon + bold number + label groups. Show: days until departure (or "Day X of Y" if active), crew count, checklist progress percentage, destination
- **Section cards:** Replace emoji icons with tinted SF Symbols in small circles (`calendar.circle.fill`, `mappin.circle.fill`, `sailboat.circle.fill`). Use `BubbleCard` sections matching the Charter Editor's polish level
- **Map preview:** If destination has coordinates, show a small static map thumbnail. Tappable to expand to full map. Use `MKMapSnapshotter` for offline-friendly static image

**Action — Visual:**
- Apply `oceanDeep` gradient tint to the background (subtle but present)
- Use `Typography` tokens throughout — no raw font sizes
- Add `focalGoldRadial` accent on the header matching the editor
- Charter status pill at top (Upcoming / Active / Completed) with appropriate color

**Action — Interaction:**
- Primary floating action: depends on charter state
  - Upcoming: "Edit Charter" (FAB)
  - Active: "Open Checklist" (FAB) — the captain's most frequent action during a voyage
  - Completed: "View Log" or share
- This is the first use of the `FloatingActionButton` component (see 3.2)

**Estimated effort:** 4–6 hours

### 3.2 `FloatingActionButton` System Component

**Action:**
- Create a reusable `FloatingActionButton` view: large pill button, backdrop blur, spring animation on appear, shadow
- Position: bottom-center, above tab bar safe area
- Accept: label text, SF Symbol icon, action closure, optional style (primary gradient / gold accent)
- Use on `CharterDetailView` first, then extend to other view-mode screens

**Estimated effort:** 1–2 hours

### 3.3 Checklist as Voyage Timeline

**Current state:** Check-in items render as a flat list. No sense of journey or progression.

**Action:**
- On `CharterDetailView`, render checklist items with `TimelineIndicator` — numbered badges, connecting lines, completion states (empty circle → filled with checkmark)
- Group by day if dates are available
- Show completion percentage as a thin progress bar in the stats row
- Tapping a completed item shows the timestamp and any notes
- Keep the full `ChecklistExecutionView` for the interactive editing flow — the detail view shows a read-only voyage log

**Estimated effort:** 3–4 hours

---

## Sprint 4: Feedback, Haptics & Engagement Polish (2–3 days)

*Goal: Make the app feel alive. Every action should have a response — visual, tactile, or both.*

### 4.1 Success Toast / Confirmation System

**Current state:** Only errors have banner feedback. Successful actions (save charter, publish content, fork content) happen silently.

**Action:**
- Create `ToastView` component: small floating pill at the top of the screen with SF Symbol + message, auto-dismisses after 2.5s
- Variants: `.success` (green checkmark), `.info` (blue info), `.warning` (gold caution)
- Integrate into key flows:
  - Charter saved → "Charter saved" toast
  - Content published → "Published to community library" toast
  - Content forked → "Added to your library" toast
  - Profile updated → "Profile updated" toast
- Use `withAnimation(.spring)` for slide-in from top

**Estimated effort:** 2–3 hours

### 4.2 Centralized Haptic Feedback

**Current state:** Single `UIImpactFeedbackGenerator(style: .light)` in `MapFilterBar`. No other haptic feedback.

**Action:**
- Create `HapticEngine` utility:
  ```swift
  enum HapticEngine {
      static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) { ... }
      static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { ... }
      static func selection() { ... }
  }
  ```
- Add haptics to:
  - Tab switches → `.selection()`
  - Pull-to-refresh trigger → `.impact(.light)`
  - Charter created/saved → `.notification(.success)`
  - Delete confirmation → `.notification(.warning)`
  - Swipe actions revealed → `.impact(.light)`
  - Toggle switches → `.selection()`
  - Publish content → `.notification(.success)`

**Estimated effort:** 1–2 hours

### 4.3 Empty State Polish Pass

**Current state:** Some screens have `EmptyStateView`, others show nothing or generic text.

**Action:**
- Audit every list/grid screen for empty state handling
- Ensure each has: relevant SF Symbol (not generic), descriptive title, brief subtitle explaining what to do, optional primary CTA button
- Key empty states to verify:
  - Home (no charters): "Plan your first voyage" → CTA to create charter
  - Charter list (empty): "No charters yet" → CTA to create
  - Library (empty): "Your library is empty" → CTA to create checklist or guide
  - Discover (no content): "Nothing here yet. Be the first to share." (no CTA — they need to publish from Library)
  - Discovery map (no charters): "No charters in this area. Try expanding your search."
  - Community manager (no communities): "No communities. Create one from your profile."
  - Checklist execution (no items): "This checklist is empty. Add items in the editor."

**Estimated effort:** 2–3 hours

### 4.4 Loading State Consistency

**Action:**
- Verify every screen that loads data shows skeleton/shimmer during load
- Ensure `SkeletonRow` variants exist for: charter cards, library items, discover content, profile sections
- Add skeleton variant for `StatsRow` (used in profile and charter detail)
- Loading → content transition should use `.transition(.opacity)` for smooth crossfade, not abrupt state swap

**Estimated effort:** 1–2 hours

---

## Sprint 5: Dark Mode, Depth & Visual Personality (2–3 days)

*Goal: Make the dark mode feel designed, not adapted. Add visual depth that creates atmosphere.*

### 5.1 Dark Mode Depth Pass

**Current state:** Dark mode uses semantic system colors (`systemGroupedBackground`, `secondarySystemGroupedBackground`). Functional but flat — "gray on dark gray."

**Action:**
- Use `oceanDeep` as the true dark background tint instead of pure `systemGroupedBackground` for main content areas
- Add subtle border strokes to elevated cards in dark mode: `white.opacity(0.06)` or `white.opacity(0.04)` — just enough to define edges
- Hero cards with images should have extra shadow depth in dark mode so photos pop against the dark canvas
- Gold and teal accents should be slightly more saturated in dark mode to compensate for the low-contrast environment
- Test: every screen in both light and dark mode. Screenshot comparison

**Estimated effort:** 2–3 hours

### 5.2 Hero Card Overlay Badges

**Current state:** Hero cards use `heroImageOverlay` gradient with stacked text. No floating contextual data.

**Action:**
- Create `OverlayChip` component: small rounded pill with icon + text, frosted glass background (`ultraThinMaterial`)
- Place contextually on hero cards:
  - Charter card: days-until-departure countdown chip (top-right), crew count chip (bottom-left)
  - Library content: content type chip (checklist / guide), fork count chip if published
- Keep it subtle — one or two chips max per card. The goal is information density without clutter

**Estimated effort:** 2–3 hours

### 5.3 Tab Bar Customization

**Current state:** Default UIKit tab bar appearance. No brand personality in the navigation chrome.

**Action:**
- Configure tab bar appearance in the app's appearance setup:
  - Custom tint color (brand primary/teal for selected, muted gray for unselected)
  - In dark mode: slightly translucent dark background with subtle blur
  - Consider thin separator line at top in light mode for definition
- Ensure SF Symbol tab icons are consistent weight (all `.fill` variants or all outline — pick one and apply consistently)

**Estimated effort:** 1 hour

### 5.4 Map Overhaul: Clustering, Pin Redesign & Map Style

*This is the largest item in Sprint 5 — three interconnected problems that together make the map usable and visually polished.*

---

#### 5.4.1 Cluster Pins — Solving the Overlap Problem

**Current state:** `CharterMapView` renders one `Annotation` per `DiscoverableCharter`. When multiple captains plan charters to the same destination (Split harbor, a Seychelles anchorage, Barcelona marina), their pins stack on top of each other. Only the topmost pin is tappable. The others are unreachable without zooming in manually — and the user has no visual signal that anything is hidden.

**Why native MapKit clustering doesn't help:** SwiftUI's `Map`/`Annotation` API (used here) doesn't expose `clusteringIdentifier` or `MKClusterAnnotation`. UIKit's `MKMapView` has full cluster support, but migrating to a `UIViewRepresentable` wrapper is a large refactor. Client-side clustering is the right approach here — it works with the existing SwiftUI `Map` and gives us full control over the cluster pin appearance.

**Approach — client-side proximity grouping:**

Introduce a `CharterCluster` model computed inside `CharterMapView` (or as a pure function) from the flat `charters` array and the current map span:

```swift
struct CharterCluster: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D   // centroid of member charters
    let charters: [DiscoverableCharter]
    var isSingleton: Bool { charters.count == 1 }
}
```

The clustering algorithm groups charters whose coordinates are within a dynamic threshold. The threshold is proportional to the current `MKCoordinateSpan` (available from `MapCameraPosition`):

```swift
private func buildClusters(span: MKCoordinateSpan) -> [CharterCluster] {
    // Threshold: ~2% of the visible span — clusters split naturally when zoomed in
    let threshold = span.latitudeDelta * 0.02
    var clusters: [CharterCluster] = []

    for charter in chartersWithLocation {
        guard let coord = charter.coordinate else { continue }
        // Find existing cluster within threshold
        if let i = clusters.firstIndex(where: {
            abs($0.coordinate.latitude - coord.latitude) < threshold &&
            abs($0.coordinate.longitude - coord.longitude) < threshold
        }) {
            let existing = clusters[i]
            let centroid = CLLocationCoordinate2D(
                latitude: (existing.coordinate.latitude * Double(existing.charters.count) + coord.latitude) / Double(existing.charters.count + 1),
                longitude: (existing.coordinate.longitude * Double(existing.charters.count) + coord.longitude) / Double(existing.charters.count + 1)
            )
            clusters[i] = CharterCluster(id: existing.id, coordinate: centroid, charters: existing.charters + [charter])
        } else {
            clusters.append(CharterCluster(id: UUID(), coordinate: coord, charters: [charter]))
        }
    }
    return clusters
}
```

`CharterMapView` tracks span via `onMapCameraChange(frequency: .onEnd)` (iOS 17+) and recomputes clusters when the span changes meaningfully. Zoom in → clusters split into individual pins. Zoom out → nearby pins merge.

**Rendering:**

```swift
Map(position: $position, selection: $selectedClusterID) {
    ForEach(clusters) { cluster in
        Annotation("", coordinate: cluster.coordinate, anchor: .bottom) {
            if cluster.isSingleton {
                UserAvatarPin(charter: cluster.charters[0], isSelected: selectedClusterID == cluster.id) {
                    selectedClusterID = cluster.id
                }
            } else {
                ClusterPin(cluster: cluster, isSelected: selectedClusterID == cluster.id) {
                    selectedClusterID = cluster.id
                }
            }
        }
        .tag(cluster.id)
    }
}
```

**`ClusterPin` visual design:**

- Overlapping avatar stack: up to 3 avatars, each offset by 14pt, third one fades to a "+" count badge if more
- Count badge: gold-filled circle, top-right corner, bold number
- Ring color: community accent if all charters share the same community; brand primary otherwise
- Same bubble shape as `UserAvatarPin` (no needle — see 5.4.2)
- Selected state: scale up + shadow expansion (spring animation)

**Tapping a cluster → Charter Cluster Sheet:**

When `selectedClusterID` maps to a multi-charter cluster, show `CharterClusterSheet` instead of `CharterMapCallout`:

```swift
// CharterClusterSheet — a bottom sheet listing the charters in the cluster
struct CharterClusterSheet: View {
    let cluster: CharterCluster
    let onSelectCharter: (DiscoverableCharter) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header: "3 charters in Split · Hvar"
            // List of CharterDiscoveryRow items (or compact variant)
            // Dismiss handle
        }
        // Same material/clip shape as CharterMapCallout
    }
}
```

**Accessiblity:** `ClusterPin` accessibility label: "3 charters in this area. Double tap to see all." Individual `UserAvatarPin` unchanged.

**Estimated effort:** 4–5 hours

---

#### 5.4.2 `UserAvatarPin` Visual Overhaul

**Current state:** The pin has: outer ring → avatar circle → community badge (bottom-trailing, 22pt) → `MapPinNeedle` triangle. There are several issues:

- **The needle causes stacking confusion.** Even without overlapping pins, the downward needle of one pin overlaps the avatar of the pin next to it, making it visually ambiguous which needle belongs to which avatar.
- **5-color urgency system is opaque.** Gray (past), green (ongoing), red (imminent), orange (soon), teal (future) — a captain glancing at the map can't decode this legend intuitively. The critical information (urgency) ends up hidden in the callout anyway.
- **Community badge is too small.** 22pt at normal pin size gets lost. It's the detail that *most* differentiates community charters from independent ones, yet it's the hardest to see.
- **Variable outer ring size** (48 default, 54 when hasCommunity — the extra 6pt for the stroke) makes pin hit areas inconsistent.

**Proposed changes:**

**Remove the needle.** Replace with a centered drop shadow that gives the visual illusion of elevation without the directional pointer. This is the approach Maps.app uses for its "pin bubble" style. The anchor stays `.bottom` — the bottom edge of the bubble sits at the coordinate.

```swift
// Before: VStack { ZStack { ... } + MapPinNeedle }
// After: just the ZStack — no MapPinNeedle

var body: some View {
    Button(action: onTap) {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(pinBackgroundColor)
                .frame(width: outerSize, height: outerSize)
                .overlay(communityRingOverlay)

            avatarContent
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

            if let badgeURL = charter.communityBadgeURL {
                communityBadge(url: badgeURL)
                    .offset(x: 6, y: 6)
            }
        }
        .shadow(
            color: isSelected ? DesignSystem.Colors.primary.opacity(0.35) : .black.opacity(0.22),
            radius: isSelected ? 10 : 5,
            x: 0,
            y: isSelected ? 3 : 2
        )
        .scaleEffect(isSelected ? 1.18 : 1.0)
        .animation(DesignSystem.Motion.spring, value: isSelected)
    }
    .buttonStyle(.plain)
}
```

**Simplify color coding.** Only two meaningful visual states:
- Has community affiliation → `communityAccent` ring + badge
- No community → `primary` teal background

Remove the 5-level `urgencyLevel.mapPinColor` system from the pin background. Urgency is already communicated in the callout card (date display, duration pill). The map pin's job is identity, not urgency.

```swift
// Simplified pin background
private var pinBackgroundColor: Color {
    charter.communityBadgeURL != nil ? DesignSystem.Colors.communityAccent.opacity(0.2) : DesignSystem.Colors.primary.opacity(0.15)
}

// Ring (community only, always same thickness regardless of selection)
@ViewBuilder
private var communityRingOverlay: some View {
    if charter.communityBadgeURL != nil {
        Circle()
            .stroke(DesignSystem.Colors.communityAccent, lineWidth: 2.5)
    }
}
```

**Increase community badge size.** From 22pt → 28pt. At 28pt the community logo is actually legible.

**Consistent hit area.** Both sizes: unselected = 44pt outer circle, selected = 52pt (scale applied via `scaleEffect`, not frame change — this avoids layout thrashing).

**Estimated effort:** 2–3 hours

---

#### 5.4.3 Map Style & Dark Mode

**Action:**
- Apply `.mapStyle(.standard(pointsOfInterest: .excluding([.restaurant, .cafe, .hotel]), showsTraffic: false))` — already done in the codebase
- Add dark mode variant: wrap in `@Environment(\.colorScheme)` and switch to `.mapStyle(.standard(colorScheme: .dark, emphasis: .muted))` in dark mode — this subdues the map tiles so the teal/gold pins pop dramatically
- Ensure the existing `mapTopScrim` gradient reads correctly in both modes (currently uses `DesignSystem.Colors.background` which is adaptive — this is correct, no change needed)

**Estimated effort:** 30 minutes

---

## Sprint 6: Backend Alignment & Data Integrity (2–3 days)

*Goal: Fix backend gaps that undermine the iOS polish work. Make public profiles actually work.*

### 6.1 Fix Public Profile Social Links Exposure

**Current state:** `User` model stores `social_links` and `community_memberships` as JSONB. Private profile endpoints return them. But public profile endpoints (`/users/{username}`, `/users/by-id/{user_id}`) **don't populate them** — they fall back to schema defaults (empty/null).

**Action:**
- Update `users.py` route handlers to include `social_links` and `primary_community` in the response, respecting the user's `profile_visibility` setting
- If visibility is `public`: return social links and community memberships
- If visibility is `community_only`: return only to users who share a community
- If visibility is `private`: return empty

**Estimated effort:** 1–2 hours

### 6.2 Profile Stats Consistency

**Current state:** `ProfileStatsResponse` includes `communities_joined`, `days_at_sea`, `content_published`, etc. but `ProfileService.get_stats` may not fill all fields reliably.

**Action:**
- Audit `ProfileService.get_stats()` — ensure it queries actual counts from DB
- `communities_joined`: count from `community_memberships` JSONB or a join on communities
- `charters_completed`: count charters where end_date < now
- `content_published`: count from `SharedContent` where `user_id` matches
- `regions_visited`: distinct `location_place_id` or distinct location string from charters
- Return real numbers, not placeholder zeros

**Estimated effort:** 2–3 hours

### 6.3 Content Type Constants

**Current state (iOS):** `LibraryStore` uses magic strings like `"checklist"`, `"practice_guide"` for fork logic and publish routing.

**Action:**
- Create a `ContentType` enum shared between iOS and backend schema:
  ```swift
  enum ContentType: String, Codable {
      case checklist
      case practiceGuide = "practice_guide"
      case flashcardDeck = "flashcard_deck"
  }
  ```
- Replace all magic strings in `LibraryStore` with enum cases
- Backend already uses string types in schema — just ensure parity

**Estimated effort:** 1 hour

### 6.4 `FlashcardDeck` Stub Decision

**Current state:** `FlashcardDeck` is referenced in `LibraryStore`, `AppCoordinator`, routes, and models. The deck editor route shows `Text("Deck Editor: ...")` placeholder.

**Action — Choose one:**
- **Option A (recommended):** Remove all FlashcardDeck stubs. Clean up routes, store methods, and model references. Re-add when the feature is real. Reduces confusion and dead code
- **Option B:** Keep the model and store methods but hide the UI entry point. Add `#if DEBUG` around the route so it's only accessible in development

**Estimated effort:** 1–2 hours

---

## Sprint 7: Profile & AuthorModal Redesign (3–4 days)

*Goal: Turn the profile from a form-display into a captain's identity card. Fix the two-surface inconsistency between your own profile and how you appear to others.*

---

### What's Actually Wrong (Diagnoses from Code)

Reading the code reveals four distinct problems, each with a different cause:

| Problem | Where | Root cause |
|---------|-------|------------|
| Community memberships look like hashtags | `CommunitiesSection.chipsFlow` → `FlowLayout` | Chip pattern treats affiliations as tags, not identities |
| Social links look like database entries | `SocialLinksDisplaySection` chips | Text + icon chips in info-blue, same visual weight as tags |
| Stats bar shows `"—"` and `0` values | `ProfileStatsBar`, nautical miles / regions visited | Stats are always rendered even when empty; no guard on zero |
| Name bypasses the typography system | `DesignSystem.Profile.HeaderContent` line 106 | `.system(size: 28, weight: .bold, design: .rounded)` hardcoded |
| `AuthorProfileModal` has no CTAs | `AuthorProfileModal.swift` lines 203–246 | Entire action button block is commented out |
| New users see a blank teal wall | `DesignSystem.Profile.Hero.gradientBackground` | No upload prompt when `profileImageUrl == nil` |
| Edit mode replaces all content | `ProfileView.mainContent` → `if isEditingProfile { editingContent }` | Single global edit state, no per-section inline editing |

---

### 7.1 Community Rows — Replace Chips with Identity Cards

**Current state:** `CommunitiesSection` wraps memberships in a `FlowLayout` of small pill chips. Community names appear as low-weight tags. The primary community is distinguished only by a thin `communityAccent` border stroke — almost invisible. Role (member/moderator/founder) is not shown at all in display mode.

**This is wrong because:** For a captain, "I'm a moderator in RBYC Racing School" is identity, not a filter tag. The chip pattern is appropriate for interests or hashtags, not for meaningful affiliations that should signal expertise and belonging.

**Action — replace `chipsFlow` with `CommunityMembershipRow` list:**

```swift
// CommunitiesSection.swift — replace chipsFlow
private var membershipList: some View {
    VStack(spacing: DesignSystem.Spacing.sm) {
        ForEach(memberships) { membership in
            CommunityMembershipRow(
                membership: membership,
                onSetPrimary: { onSetPrimary(membership.id) },
                onLeave: { onLeave(membership.id) }
            )
        }
    }
}
```

`CommunityMembershipRow` structure:
- Height: ~60pt per row
- Leading accent: 3pt vertical teal/gold bar for primary community, invisible for others
- Community icon: 44pt circle — `CachedAsyncImage` falling back to letter monogram with `hashColor(for: membership.id)`
- Name: `Typography.body` weight semibold
- Role badge inline: "Moderator" or "Founder" as small capsule pill in `communityAccent.opacity(0.15)` with `communityAccent` text — hidden for plain member role
- Trailing: gold star icon for primary; context menu (`···`) for non-primary (set as primary / leave)
- Background: `surface` fill with `border.opacity(0.4)` stroke — same card language as the rest of the app

This makes 3 community memberships feel like 3 meaningful affiliations rather than 3 hashtags.

**Keep `FlowLayout`** in the codebase — it may be useful elsewhere (tags on content, for example). Just stop using it for community memberships.

**Estimated effort:** 2 hours

---

### 7.2 Social Links — Icon Circles, Not Chips

**Current state:** `SocialLinksDisplaySection` renders active links as small horizontal chips: `Image(systemName:) + Text("Instagram")` with info-blue foreground and a thin blue-tinted rounded rectangle background. Three problems: (1) same visual pattern as the community chips above — both sections look identical; (2) the text label is redundant — the icon identifies the platform; (3) info-blue is a generic semantic color, not a brand signal.

**Action — replace chips with large branded icon circles:**

```swift
// SocialLinksDisplaySection — replace body
var body: some View {
    if !activeLinks.isEmpty {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            DesignSystem.SectionLabel(L10n.Profile.SocialLinks.title)
            HStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(activeLinks) { link in
                    if let url = link.url {
                        Link(destination: url) {
                            ZStack {
                                Circle()
                                    .fill(link.platform.brandColor.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().stroke(link.platform.brandColor.opacity(0.25), lineWidth: 1)
                                    )
                                Image(systemName: link.platform.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(link.platform.brandColor)
                            }
                        }
                        .accessibilityLabel(localizedPlatformName(link.platform))
                    }
                }
                Spacer()
            }
        }
    }
}
```

Add `brandColor` to `SocialPlatform`:
```swift
extension SocialPlatform {
    var brandColor: Color {
        switch self {
        case .instagram: return Color(red: 0.83, green: 0.18, blue: 0.57)
        case .telegram:  return Color(red: 0.18, green: 0.55, blue: 0.84)
        case .other:     return DesignSystem.Colors.info
        }
    }
}
```

Result: three icon circles replace three chip rows. Clean, brand-appropriate, takes up one horizontal line instead of three vertical ones. Tapping any circle opens the URL.

**Estimated effort:** 1 hour

---

### 7.3 Stats Bar — Show Only Real Numbers

**Current state:** `ProfileStatsBar` always renders 4 stats: charters completed, nautical miles (`"—"`, always blank because the field isn't computed yet), days at sea, communities joined. A stats row where 2 of 4 items are clearly placeholder (`"—"`, `0`) signals that the app is unfinished, which is the opposite of the impression we want.

**Action — filter to meaningful values only:**

```swift
// ProfileStatsBar.swift — replace items computed property
private var items: [DesignSystem.StatsRow.Item] {
    var result: [DesignSystem.StatsRow.Item] = []
    if stats.chartersCompleted > 0 {
        result.append(.init(id: "charters", systemImage: "sailboat.fill",
            value: "\(stats.chartersCompleted)",
            label: L10n.Profile.Stats.chartersCompleted, tint: DesignSystem.Colors.primary))
    }
    if stats.daysAtSea > 0 {
        result.append(.init(id: "days", systemImage: "sun.horizon.fill",
            value: "\(stats.daysAtSea)",
            label: L10n.Profile.Stats.daysAtSea, tint: DesignSystem.Colors.success))
    }
    if stats.communitiesJoined > 0 {
        result.append(.init(id: "communities", systemImage: "person.3.fill",
            value: "\(stats.communitiesJoined)",
            label: L10n.Profile.Stats.communitiesJoined, tint: DesignSystem.Colors.communityAccent))
    }
    if stats.contentPublished > 0 {
        result.append(.init(id: "content", systemImage: "doc.text.fill",
            value: "\(stats.contentPublished)",
            label: L10n.Profile.Stats.contentPublished, tint: DesignSystem.Colors.info))
    }
    return result
}

var body: some View {
    if !items.isEmpty {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DesignSystem.SectionLabel(L10n.Profile.Stats.dashboardLabel)
            DesignSystem.StatsRow(items: items)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius, style: .continuous)
                        .stroke(DesignSystem.Colors.border.opacity(0.4), lineWidth: 1)
                )
        }
    }
    // When all stats are 0: section disappears entirely. New user sees no stats row.
}
```

Remove nautical miles from the list entirely until the backend computes it — it will always be `"—"` otherwise. Add it back when it's real data.

**Estimated effort:** 30 minutes

---

### 7.4 Typography & Token Audit in Profile Components

**Current state:** Several raw font/corner radius values inside profile components:

| Location | Problem | Fix |
|----------|---------|-----|
| `DesignSystem.Profile.HeaderContent` line 106 | `.system(size: 28, weight: .bold, design: .rounded)` | `Typography.title.bold()` or new `Typography.profileName` token |
| `DesignSystem.Profile.InfoRow` line 316 | `cornerRadius: 12` hardcoded | `Spacing.cardCornerRadius` |
| `DesignSystem.Profile.MetricsCard` implicit | No changes needed — not used in the current active view path | — |

**Action:**
- Add `static let profileName = Font.system(size: 28, weight: .bold, design: .rounded)` to `DesignSystemTypography` as a named token so it can be changed in one place
- Replace the raw value with the new token

**Estimated effort:** 30 minutes

---

### 7.5 Hero Section: Upload Prompt for New Users

**Current state:** When `user.profileImageUrl == nil`, `DesignSystem.Profile.Hero` shows `gradientBackground` — a plain teal-to-teal gradient. The existing edit button (pencil in glass circle, top-right) is the only hint that the hero area can be personalized. New users have no signal that they can add a sailing photo here.

**The hero image is the single biggest visual differentiator between a blank profile and an expressive one.** Encouraging this early is high-leverage.

**Action — add a centered photo prompt when no image:**

```swift
// DesignSystem+Profile.swift — heroBackgroundView (no-photo branch)
} else {
    ZStack {
        gradientBackground
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text("Add a sailing photo")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
```

This is a passive prompt — it doesn't open the picker itself (tapping the hero currently does nothing). The pencil button and the camera icon on the avatar remain the edit entry points. But the prompt makes the empty state feel *intentional* rather than unfinished.

Optional improvement: make the full hero area tappable when no photo is present (trigger `onEditTap` on tap). This would need an `onHeroTap` callback added to `Hero` alongside `onEditTap`.

**Estimated effort:** 1 hour

---

### 7.6 Restore `AuthorProfileModal` Action Buttons

**Current state:** The action button block in `AuthorProfileModal` is entirely commented out (lines 203–246). The modal shows: full-bleed photo background, gradient overlay, avatar, name, bio, location badge, stats row — and then nothing actionable at the bottom except "close." There is nowhere for a user to go after learning about an author.

The commented-out `MFMailComposeViewController` email CTA is the wrong primitive anyway — it requires the user's device to have email configured and forces a system sheet. Most sailors will tap it and see an error about no email accounts.

**Action — restore with appropriate CTAs:**

```swift
// AuthorProfileModal.swift — replace commented block with:
HStack(spacing: DesignSystem.Spacing.md) {
    // Social icon circles (if available)
    if let links = author.socialLinks, !links.isEmpty {
        socialIconsRow(links: links)
    }
    Spacer()
    // Primary CTA: always present
    Button(action: { /* navigate to their charters in discovery */ }) {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "map.fill")
            Text("View Charters")
                .fontWeight(.semibold)
        }
        .font(DesignSystem.Typography.body)
        .foregroundColor(DesignSystem.Colors.onPrimary)
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Gradients.primary)
        )
        .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 10, y: 4)
    }
}
.padding(.horizontal, DesignSystem.Spacing.lg)
```

The `socialIconsRow` uses the same 44pt brand-colored icon circles from §7.2.

**Extend `AuthorProfile` to carry social links:**

```swift
struct AuthorProfile {
    // ... existing fields ...
    let socialLinks: [SocialLink]?        // add
    let primaryCommunityName: String?     // add
}
```

Populate from `GET /users/{username}` response. This requires Sprint 6.1 (social links on public profile) to be completed first — so this item has a dependency.

For "View Charters": the action opens the Charter Discovery tab with `captainID` filter applied. The `CharterDiscoveryFilters` struct would need a `captainID: UUID?` field, and the discovery endpoint would need `?captain_id=` query param filtering. This is a separate small backend addition — mark as dependent.

**In the meantime** (before those prerequisites): "View Charters" can deep-link to the discovery tab without filtering, which still creates forward momentum from the profile.

**Estimated effort:** 2–3 hours (including `AuthorProfile` extension + social icons row)

---

### 7.7 Edit Mode: Per-Section Inline Editing (Optional, Higher Effort)

**Current state:** Tapping the edit button triggers `viewModel.isEditingProfile = true`, which replaces the *entire* main content area with `ProfileEditForm`. The hero stays fixed, but the stats, communities, social links — everything — disappears and is replaced by a form. This is jarring: the user loses scroll context and the transition implies the whole profile is a monolithic form rather than composed sections.

**Approach — inline section editing** (phased, start with just bio/location):

Phase 1 (low effort):
- Add a small `pencil.circle` icon next to the bio text. Tapping it opens a dedicated edit sheet (`.sheet(isPresented:)`) for just bio + location + name
- Communities and social links retain their existing interactive elements (community context menu, tap-to-edit social links inline)
- Keep the global `isEditingProfile` toggle for the full form as fallback — just hide the pencil button on the Hero since the edit-per-section handles it

Phase 2 (medium effort, defer):
- True inline editing: each section header gets an edit icon, tapping it expands the section into edit-mode in place with spring animation
- Bio becomes a `TextEditor` where the text was
- Location becomes a `TextField` where the label was
- Social links section expands its icon circles into text fields with spring animation

Phase 1 is the immediate win — it gives the profile a more modern "tap to edit in place" feel without the complexity of Phase 2.

**Estimated effort:** Phase 1: 2 hours. Phase 2: 4–6 hours, defer.

---

### Sprint 7 Summary

| # | Change | File(s) | Effort |
|---|--------|---------|--------|
| 7.1 | Community rows replace chip flow | `CommunitiesSection.swift` | 2h |
| 7.2 | Social icon circles replace chips | `SocialLinksSection.swift`, `SocialPlatform` | 1h |
| 7.3 | Stats bar filters zero values | `ProfileStatsBar.swift` | 30m |
| 7.4 | Typography token for profile name | `DesignSystem+Profile.swift`, `DesignSystemTypography.swift` | 30m |
| 7.5 | Hero photo prompt for new users | `DesignSystem+Profile.swift` | 1h |
| 7.6 | Restore AuthorModal action buttons | `AuthorProfileModal.swift`, `AuthorProfile` struct | 2–3h |
| 7.7 | Inline edit mode (Phase 1) | `ProfileView.swift`, new edit sheet | 2h |

**Total: ~9–10 hours across 1.5–2 days**

Dependencies: 7.6 (social links on AuthorProfile) requires Sprint 6.1 to complete first.

---

## Incremental Feature Additions (Build on Existing Entities)

These are small features that use existing data models and screens but add real value for captains. They don't require new backend entities or major architecture changes.

---

### F1: Charter Sharing via System Share Sheet

**Problem it solves:** Captains want to tell crew about a charter. Right now there's no way to share charter details outside the app.

**Implementation:**
- Add a share button to `CharterDetailView` toolbar
- Generate a formatted text summary: charter name, dates, destination, vessel, captain name
- Use `ShareLink` (iOS 16+) or `UIActivityViewController`
- Include a deep link URL if/when deep linking is implemented; otherwise just formatted text
- This requires zero backend changes — it's a client-only feature

**Estimated effort:** 1–2 hours

### F2: Quick-Create Charter from Home

**Problem it solves:** The home screen CTA says "Plan your first voyage" but requires navigating to Charters tab → tap + → fill form. Too many steps for a spontaneous plan.

**Implementation:**
- Home "create charter" ActionCard directly opens `CharterEditorView` via the coordinator (`.sheet` presentation)
- After save, navigate to Charter tab with the new charter selected
- The editor already works as a standalone sheet — just wire the presentation

**Estimated effort:** 30 minutes

### F3: Charter Duplication

**Problem it solves:** Captains often repeat similar trips (same route, same vessel, different dates). Re-entering everything is tedious.

**Implementation:**
- Add "Duplicate" to charter swipe actions or detail view menu
- Create a copy with: same name + " (Copy)", same vessel, same destination, same checklist template, dates cleared
- Open the editor immediately so captain can adjust dates
- Pure client-side: `CharterStore.duplicateCharter()` copies the model and saves

**Estimated effort:** 2–3 hours

### F4: Content Preview Before Publishing

**Problem it solves:** Captains publish checklists/guides but don't know how they'll look to others in the Discover feed. This creates anxiety about sharing.

**Implementation:**
- Add a "Preview" button in the publish confirmation flow
- Show the content rendered as a `DiscoverContentRow` card — exactly as others will see it
- Include attribution display ("By [Captain Name]") and content type badge
- Builds confidence and catches formatting issues before they're public

**Estimated effort:** 2–3 hours

### F5: Voyage Countdown on Home Screen

**Problem it solves:** Captains are excited about upcoming trips. A countdown creates anticipation and daily engagement — a reason to open the app.

**Implementation:**
- On the home hero charter card (when there's an upcoming charter), add an `OverlayChip` showing "X days to go" or "Departing tomorrow!" or "Sailing now"
- Use the countdown as a dynamic, emotional element — change color as departure approaches (gold → teal → green)
- If charter is active: show "Day X of Y" with a thin progress indicator
- Zero backend changes — computed from charter dates on the client

**Estimated effort:** 1–2 hours

### F6: Offline Indicator — Global Sync Status

**Problem it solves:** Offline-first is a core philosophy, but users have no clear signal of their connectivity/sync state. They might edit offline without realizing, then wonder why crew doesn't see changes.

**Implementation:**
- Add a subtle sync indicator: small dot or icon in the navigation bar or tab bar
  - Green: all synced
  - Gold: changes pending sync (queued operations)
  - Gray: offline
- Tappable: opens a brief overlay showing "3 changes waiting to sync" or "All up to date"
- Read from `SyncQueueService` pending count + network reachability

**Estimated effort:** 2–3 hours

---

### F7: Nearby Captains Strip on Home

**Problem it solves:** Captains often sail in the same waters but have no idea who else from the community is planning a trip to the same region. This creates a missed connection — a chance to meet at anchor, share routes, or join forces. The Home screen is the right place to surface this because it's already personalized around the captain's own active/next charter.

**Key insight on privacy:** This feature does NOT require GPS tracking or location sharing. It uses charter *destination coordinates* that captains have already entered into their own charters. Visibility follows the existing charter visibility rules — only charters marked community or public appear. No new privacy surface.

**What it looks like:**

Below the hero charter card (when an active or next charter exists), a new `NearbyCaptainsStrip` section appears:

```
Captains sailing nearby              [see all on map →]
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│  🏴  │ │  👤  │ │  🏴  │ │  👤  │
│ Marco│ │ Nina │ │Alexey│ │+5more│
│Split │ │Hvar  │ │Split │ │      │
└──────┘ └──────┘ └──────┘ └──────┘
```

- Each card: avatar (52pt) with community ring if applicable, virtual captain badge ("VC" mini pill) if applicable, captain name (1 line), destination below name
- Up to 5 captains shown; last card shows "+N more" that links to the discovery map filtered to that region
- Section hidden entirely when `nearbyCaptains.isEmpty` — no empty state, absence is graceful
- Skeleton row while loading (3 placeholder cards)

**iOS changes:**

Add to `HomeViewModel`:
```swift
private(set) var nearbyCaptains: [NearbyCaption] = []
private(set) var isLoadingNearbyCaptains = false

func loadNearbyCaptains() async {
    // Use active charter's coordinates, or next charter's if no active
    guard let charter = activeCharter ?? nextCharter,
          let lat = charter.latitude,
          let lon = charter.longitude else { return }
    isLoadingNearbyCaptains = true
    defer { isLoadingNearbyCaptains = false }
    do {
        let result = try await apiClient.nearbyCharters(lat: lat, lon: lon, radiusKm: 150)
        // Map to NearbyCaption, deduplicate by captain, exclude self
        nearbyCaptains = result.items
            .map { NearbyCaption(from: $0) }
            .filter { $0.captainID != authService.currentUser?.id }
            .uniqued(by: \.captainID)
            .prefix(5)
            .asArray()
    } catch {
        // Silently ignore — this is ambient info, not critical
    }
}
```

The `NearbyCaption` model:
```swift
struct NearbyCaption: Identifiable {
    let id: UUID             // charter id (for uniqueness)
    let captainID: UUID
    let username: String
    let avatarURL: URL?
    let isVirtualCaptain: Bool
    let communityName: String?
    let communityBadgeURL: URL?
    let charterDestination: String?
    let distanceKm: Double?
}
```

Add `NearbyCaptainsStrip` sub-view to `HomeView`. Wire `loadNearbyCaptains()` inside the existing `.task { await viewModel.refresh() }` — or separately to avoid blocking the hero card.

Tapping a captain card: open `AuthorProfileModal` (already exists in the Discover tab, can be reused) passing the captain's user ID.

**Backend changes:**

The existing `GET /charters/discover` endpoint already supports `near_lat`, `near_lon`, `radius_km`. We can reuse it with a small radius and then deduplicate captains on the client. No new endpoint strictly required — just a new `APIClient` call wrapper that targets the discovery endpoint with location params and returns the full response.

If the discovery endpoint becomes too heavy for this ambient query, extract a lightweight `GET /charters/nearby-captains?lat=&lon=&radius_km=&limit=10` that returns only captain info (no full charter payload) — add to `app/api/v1/charters.py` using the existing `charter.py` repository's geo-filter logic.

**Overlap with Sprint 5.4 (map):** The "see all on map" link from the strip opens the Charter Discovery tab with the map view pre-filtered to the relevant region. This is a `coordinator.switchToDiscovery(mapView: true, region: ...)` call — requires a small addition to `AppCoordinator`.

**Estimated effort:** 4–5 hours (iOS: 3h, backend: 1h if reusing discover endpoint)

---

## Remaining March Debt (Scoped into This Plan)

These items from the March checklist are carried forward and assigned to the appropriate sprint context.

| Item | Sprint | Action |
|------|--------|--------|
| `AppDependencies.makeForTesting()` discards `CharterStore` | Sprint 6 | Fix or document single test pattern |
| `LibraryListView` fallback `AppDependencies()` risk | Sprint 2 | Audit and fix alongside consistency pass |
| Body-inline sorting in charter list | Sprint 2 | Move to computed property on VM |
| `Calendar.current` in `CharterTimelineRow` | Sprint 2 | Cache as static property |
| Onboarding swipe hints exist but no first-launch onboarding | Post-sprints | Defer — swipe hints are sufficient for now |
| Persistent discovery cache | Post-sprints | Nice-to-have, not blocking for polish |

---

## App Store Review Considerations

### Requirements (Must-Have Before Submission)

| # | Requirement | Status | Sprint |
|---|------------|--------|--------|
| 1 | Account deletion functional | Missing | Sprint 1 |
| 2 | Privacy policy URL accessible in-app | Missing | Sprint 1 |
| 3 | No placeholder text/icons visible to users | Audit other surfaces | Sprint 1 |
| 4 | All permission usage descriptions accurate | Needs audit | Sprint 1 |
| 5 | Crash-free cold launch on all supported devices | Needs testing | Sprint 1 |
| 6 | No broken navigation paths (dead-end screens) | Needs audit | Sprint 1 |
| 7 | App functions in airplane mode (offline-first) | Needs testing | Sprint 1 |

### Recommendations (Improves Review Outcome)

| # | Recommendation | Rationale |
|---|---------------|-----------|
| 1 | Pre-populate with sample data for review | Reviewers won't create charters — have a "demo" charter visible or well-designed empty states |
| 2 | Include a "What's New" or onboarding flow | Helps reviewers understand the app's value quickly |
| 3 | App Store screenshots should show the best screens | Charter Editor (★★★★★), Home with active charter, Library with content, Discover feed |
| 4 | Description should emphasize offline-first and privacy | Apple values both; differentiate from generic social apps |
| 5 | Keep the app under 200MB | Check asset sizes, remove unused resources |
| 6 | Support Dynamic Type at least partially | Apple looks for accessibility effort |
| 7 | Metadata keyword strategy | "sailing", "captain", "crew", "voyage planner", "offshore checklist", "sailing community" |

### Review Rejection Risks (Known)

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Missing account deletion | **High** — guaranteed rejection | Sprint 1 fix |
| Empty "Delete Account" could be tested by reviewer | **High** | Sprint 1 fix |
| No privacy policy link | Medium | Sprint 1 fix |
| Minimal content for reviewer to interact with | Medium | Seed demo content or excellent empty states (Sprint 4) |

---

## Quality Metrics & Definition of Done

After completing all 6 sprints, the app should meet:

- **Zero force-unwraps** in production code paths
- **Every screen uses design tokens** — no raw font sizes, no hardcoded corner radii
- **Every list screen** has: loading skeleton, empty state, error banner, pull-to-refresh
- **Every user action** has feedback: toast, haptic, or animation (never silent)
- **Dark mode** feels intentional on every screen (not just "adapted")
- **App Store review checklist** is green across all "Must-Have" items
- **No placeholder screens** — CommunityManager, SignIn, CharterDetail all polished

---

## Sprint Summary & Time Estimates

| Sprint | Focus | Estimated Days | Key Deliverable |
|--------|-------|---------------|-----------------|
| 1 | App Store Critical Path | 3–4 | SignIn rebuilt, Delete Account works, privacy/crash audit |
| 2 | Visual Consistency | 3–4 | Typography + radius audit, CommunityManager styled, animations |
| 3 | Charter Detail Redesign | 3–5 | Voyage experience with stats, timeline, FAB, map preview |
| 4 | Feedback & Engagement | 2–3 | Toast system, haptics, empty states, loading polish |
| 5 | Dark Mode & Visual Depth | 4–5 | Dark mode pass, overlay badges, tab bar, **map overhaul (clustering, pin redesign, style)** |
| 6 | Backend Alignment | 2–3 | Public profile fix, stats accuracy, content types, stub cleanup |
| 7 | **Profile & AuthorModal Redesign** | 1.5–2 | Community rows, social icon circles, real stats, upload prompt, restored modal CTAs |
| Features | F1–F7 incremental | 4–6 | Share, quick-create, duplicate, preview, countdown, sync status, **nearby captains on Home** |

**Total estimate: ~24–32 working days** (5–6.5 weeks at a comfortable pace)

---

## Recommended Execution Order

1. **Sprint 1 first** — non-negotiable for App Store submission
2. **Sprint 2 next** — establishes consistency baseline that makes all later work easier
3. **Sprint 6** can interleave with Sprint 2 (backend work while waiting for iOS builds)
4. **Sprint 3** is the biggest visual payoff — do it while motivation is high
5. **Sprint 4 + 5** are pure polish — can be done in any order
6. **Sprint 7 after Sprint 6** — §7.1–7.5 can be done any time; §7.6 (`AuthorProfileModal` social links) depends on Sprint 6.1 completing the public profile endpoint fix
7. **Features F1–F7** sprinkle in between sprints as palette cleansers — small wins keep momentum

---

## What This Plan Does NOT Include

- New backend entities (communities moderation, adventures, vessel database)
- Phase 3–4 features from the vision doc (shared charter discovery, join requests, location intelligence)
- Push notifications infrastructure
- Analytics SDK integration
- Multi-platform (Android, web)
- Gamification (badges, streaks, leaderboards)
- AI-powered recommendations

These are all valid future work. This plan is about making what exists feel finished, consistent, and worthy of a captain's trust.

---

*Document version: 1.0 — April 2026*  
*Based on: March 2026 Refactor Review, Design Review, Vision Document, Refactoring Prompt, Designer Prompt*  
*Re-validate line numbers and endpoint names against the repo before each sprint.*
