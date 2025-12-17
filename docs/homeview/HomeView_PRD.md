# Home View PRD - Anyfleet iOS App
**Version**: 1.0  
**Status**: Active Development  
**Last Updated**: December 17, 2025

---

## Overview

The Home View is the primary dashboard for users upon app launch. It adapts dynamically based on active charter status and provides quick access to frequently used content and checklists.

### Key Value Propositions
- **One-tap access** to active charter information and checkin process
- **Smart state management** that changes card purpose based on real-time data
- **Contextual content discovery** via pinned checklists and guides
- **Seamless onboarding** with clear "create charter" prompts when needed

---

## Screen Layout

```
┌────────────────────────────────────┐
│  Good Morning, Captain             │  ← Greeting Section
│  Wednesday, Dec 17                 │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  [Sailboat Icon]                   │
│                                    │  ← PRIMARY CARD
│  Active Charter                    │  (Adaptive - see variants below)
│  Deep Blue Explorer                │
│  📍 Aegean Sea                      │
│  [Tap anywhere for details]        │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Reference Content                 │  ← REFERENCE SECTION
│  ─────────────────────             │
│  CHECKLISTS                        │
│  ├─ Pre-Departure Checkin          │
│  ├─ Galley Inventory               │
│  └─ Rigging Check                  │
│                                    │
│  GUIDES                            │
│  ├─ Aegean Navigation Guide        │
│  └─ Weather Patterns 2024          │
│                                    │
│  [Scroll for more]                 │
└────────────────────────────────────┘
```

---

## Component Specifications

### 1. Greeting Section (Header)

**Purpose**: Contextual greeting and date display  
**Behavior**: 
- Time-based greeting ("Good morning", "Good afternoon", "Good evening", "Welcome back")
- Full date format (e.g., "Wednesday, December 17, 2024")

**Styling**:
- Large title typography (AppTypography.largeTitle)
- Secondary color for date text
- Padding: screen edge padding (AppSpacing.screenPadding)

---

### 2. Primary Card (Adaptive - Core Feature)

The top card is **state-aware** and displays one of two configurations:

#### **State 1: ACTIVE CHARTER EXISTS**

**Condition**: Latest charter has `startDate <= today <= endDate`

**Content**:
```
┌──────────────────────────────┐
│ Active Charter (badge text)  │  ← Caption, white 85% opacity
│ Charter Name                 │  ← Title 2, white
│ 📍 Location Name             │  ← Body Small, white 90% opacity
│ [Optional] Dates shown?      │  ← (if relevant)
└──────────────────────────────┘
```

**Styling**:
- Background: `AppColors.oceanGradient` (blue gradient matching water theme)
- Corner radius: `AppSpacing.cardCornerRadiusLarge`
- Shadow: `shadow(color: .black.opacity(0.08), radius: 12, y: 6)`
- Padding: `AppSpacing.cardPadding`
- Minimum height: `AppSpacing.featuredCardHeight` (typically 140-160pt)

**Interaction**:
- **Tap anywhere**: Navigate to `AppPath.charterDetail(id: charterID)`
- Opens CharterDetailView showing full charter info

**Sub-Content** (if space permits):
- Optional duration indicator: "Day 3 of 7"
- Optional status badge: Active/InProgress

---

#### **State 2: NO ACTIVE CHARTER**

**Condition**: No charters with overlapping dates, OR all charters are outside current date range

**Content**:
```
┌──────────────────────────────┐
│ [Plus Circle Icon]           │  ← System icon, white, 32pt
│                              │
│ Create New Charter           │  ← Title 2, white
│ Start your next sailing trip │  ← Body Small, white 90%
│                              │
│ [Sign In] (if needed)        │  ← Optional overlay button
└──────────────────────────────┘
```

**Styling**: Same as Active Charter card (oceanGradient, shadow, etc.)

**Interaction**:
- **Tap anywhere**: Call `viewModel.onCreateCharterTapped()`
- Navigates to `AppPath.charterCreation` (handled by AppCoordinator)
- **Auth Check**: If user not authenticated, show sign-in button overlay instead of full tap action

---

### 3. Active Charter Detail Section (NEW - Inside Detail View)

*Note: This appears when user taps the active charter card and navigates to CharterDetailView*

**Structure**:
```
┌────────────────────────────┐
│ Charter Name               │
│ Location • Dates • Status  │
│                            │
│ ┌──────────────────────┐   │
│ │ Checkin Checklist    │   │ ← Placeholder for checkin type
│ │ Latest Check-in Item │   │
│ │ Tap to begin setup   │   │
│ └──────────────────────┘   │
│                            │
│ [More content below]       │
└────────────────────────────┘
```

**Checkin Checklist Placeholder**:
- **Query Logic**: Latest checklist where:
  - `type == "checkin"` 
  - `charterID == activeCharter.id` (charter-scoped)
  - Status: library item, created/forked into user's library
  
- **Display**: Small card showing checklist name/description
- **Interaction**: Tap → Navigate to `AppPath.checklistExecution(checklistID: id, charterID: charterID)`
- **Fallback**: If no checkin checklist exists for this charter, show: "No check-in items. Create one in Library."

---

### 4. Reference Content Section

**Purpose**: Quick access to pinned/favorite checklists and guides  
**Title**: "Reference Content" (localized)

**Structure**:

#### **Checklists Subsection**
- **Title**: "Checklists" (section header, body bold, secondary color)
- **Content**: Show first 3 items from `contentStore.myChecklists`
- **Empty State**: "No checklists yet. Create your first in Library."
- **Each Item Card**:
  ```
  ┌──────────────────────────┐
  │ Checklist Title          │ ← bodyBold, primary color
  │ Short description text.. │ ← caption, secondary, 2 lines max
  └──────────────────────────┘
  ```
- **Interaction**: Tap card → `viewModel.openChecklist(checklist.id)` → navigates to ChecklistDetailView

#### **Guides Subsection**
- **Title**: "Guides" (same styling as Checklists)
- **Content**: Show first 3 items from `contentStore.myGuides`
- **Empty State**: "No guides yet. Create your first in Library."
- **Each Item Card**: Same as Checklists
- **Interaction**: Tap → `viewModel.openGuide(guide.id)` → navigates to GuideDetailView

**Styling**:
- Section spacing: `AppSpacing.md`
- Card background: `AppColors.cardBackground`
- Card shadow: `shadow(color: .black.opacity(0.06), radius: 8, y: 4)`
- Card corner radius: `AppSpacing.cardCornerRadius`
- Card padding: `AppSpacing.md`

**Loading State**:
- Show placeholder shimmer/skeleton cards while `viewModel.isLoading == true`
- 3 cards × 2 sections = 6 skeleton cards max

**Scroll Behavior**:
- Entire screen is wrapped in `ScrollView`
- Safe area inset at bottom for tab bar clearance
- Reference section scrolls under the tab bar

---

## State Management

### HomeViewModel Properties

```swift
@Observable
final class HomeViewModel {
    // MARK: - State
    var activeCharter: CharterModel?
    var isLoading: Bool = false
    var showAuthPrompt: Bool = false
    var activeCharterChecklistID: UUID?
    
    // MARK: - Dependencies
    private let appModel: AppModel
    private let charterStore: CharterStore
    private let userStore: UserStore
    private let contentStore: ContentStore
    
    // MARK: - Initialization & Data Refresh
    func refresh() async
    
    // MARK: - Actions
    func onCreateCharterTapped()
    func onActiveCharterTapped(_ charter: CharterModel)
    func openChecklist(_ id: UUID)
    func openGuide(_ id: UUID)
    func signIn() async
}
```

### Data Fetching Pipeline

**On View Load (.task)**:
1. Check if user authenticated → Set `showAuthPrompt` accordingly
2. Load active charter:
   ```swift
   let today = Calendar.current.startOfDay(for: Date())
   activeCharter = charterStore.charters
       .filter { $0.startDate <= today && $0.endDate >= today }
       .sorted { $0.startDate > $1.startDate }
       .first
   ```
3. If active charter exists, fetch latest checkin checklist:
   ```swift
   activeCharterChecklistID = contentStore.myChecklists
       .filter { $0.type == .checkin && $0.charterID == activeCharter?.id }
       .sorted { $0.createdAt > $1.createdAt }
       .first?.id
   ```
4. Refresh content store (checklists + guides)
5. Set `isLoading = false`

---

## Navigation Map

| Action | Destination | Path |
|--------|-------------|------|
| Tap Active Charter Card | Charter Detail View | `AppPath.charterDetail(id: UUID)` |
| Tap Create Charter Card | Charter Creation Flow | `AppPath.charterCreation` |
| Tap Checklist Item | Checklist Detail View | `AppPath.checklistDetail(id: UUID)` |
| Tap Guide Item | Guide Detail View | `AppPath.guideDetail(id: UUID)` |
| Tap Checkin Checklist | Checklist Execution | `AppPath.checklistExecution(checklistID: UUID, charterID: UUID)` |
| Tap Sign In Button | Apple Sign In | (Handled by userStore.signInWithApple()) |

---

## Data Model Dependencies

### CharterModel
- `id: UUID`
- `name: String`
- `location: String?`
- `startDate: Date`
- `endDate: Date`
- `status: CharterStatus`

### ChecklistModel
- `id: UUID`
- `title: String`
- `description: String?`
- `type: ChecklistType` (enum: .checkin, .safety, .maintenance, etc.)
- `charterID: UUID?` (nil for library, set when forked to charter scope)
- `createdAt: Date`

### GuideModel
- `id: UUID`
- `title: String`
- `description: String?`
- `createdAt: Date`

---

## Localization Keys

| Key | English | Purpose |
|-----|---------|---------|
| `L10n.Greeting.morning` | "Good morning" | Time-based greeting |
| `L10n.Greeting.day` | "Good afternoon" | |
| `L10n.Greeting.evening` | "Good evening" | |
| `L10n.Greeting.night` | "Welcome back" | |
| `L10n.Charter.activeCharter` | "Active Charter" | Card badge |
| `L10n.Charter.createCharter` | "Create New Charter" | Create card title |
| `L10n.Charter.createCharterDescription` | "Start your next sailing trip" | Create card subtitle |
| `L10n.Home.referenceContent` | "Reference Content" | Section title |
| `L10n.Home.checklistsTitle` | "Checklists" | Subsection title |
| `L10n.Home.guidesTitle` | "Guides" | Subsection title |
| `L10n.Home.noChecklists` | "No checklists yet" | Empty state |
| `L10n.Home.noGuides` | "No guides yet" | Empty state |
| `L10n.Auth.signInWithApple` | "Sign in to continue" | Auth button |

---

## Edge Cases & Error Handling

### 1. Multiple Active Charters
**Scenario**: User has overlapping charters (should not happen, but edge case)  
**Behavior**: Select the **latest start date** (most recent charter)  
**Implementation**: `.sorted { $0.startDate > $1.startDate }.first`

### 2. Charter Dates Edge Case
**Scenario**: Charter ends today at 11:59 PM, it's currently 1:00 PM  
**Behavior**: Charter is still active (include in filtering)  
**Implementation**: Use `startDate <= today && endDate >= today` (inclusive)

### 3. No Checkin Checklist for Active Charter
**Scenario**: Active charter exists but no checkin-type checklist has been created  
**Behavior**: Show placeholder text instead of card  
**Text**: "No check-in items. Create one in Library."

### 4. User Not Authenticated
**Scenario**: User launches app before signing in  
**Behavior**: 
  - Show create charter card as usual
  - Overlay sign-in button on card
  - Tapping card shows auth prompt instead of navigating
  - `showAuthPrompt = true` triggers overlay button display

### 5. Network Failure During Refresh
**Scenario**: `refresh()` fails to fetch charters/content  
**Behavior**: 
  - Set `isLoading = false`
  - Show cached data if available
  - Log error for debugging
  - Do NOT show error alert (maintain ambient experience)

### 6. Empty Reference Content
**Scenario**: User has no checklists or guides  
**Behavior**: Show empty state cards with encouraging message  
**Visual**: Gray placeholder cards with text

---

## Performance Considerations

### Lazy Loading
- Use `LazyVStack` for reference content section if list grows beyond 10 items
- Implement pagination: Show 3 items, "Show More" button for additional

### Caching Strategy
- CharterStore and ContentStore should cache locally
- Refresh on every HomeView appear (`.onAppear` or `.task`)
- Use `.equatable` protocols to prevent unnecessary re-renders

### Image Loading (Future)
- If charter/checklist/guide cards display images, use `AsyncImage` with placeholders
- Implement blurhash or skeleton loaders

### Accessibility
- Ensure all text meets WCAG color contrast ratios (4.5:1 min)
- Tab order: Greeting → Active/Create Card → Checklists → Guides
- Add `accessibilityLabel` and `accessibilityHint` to cards
- VoiceOver: "Active charter, Deep Blue Explorer, Aegean Sea. Double tap to view details."

---

## Refactoring Notes (From Code Review)

### Critical Issues to Fix

1. **Extract HomeIncrementalDebugView from AppView**
   - Currently embedded inside AppView.swift
   - Should be HomeView.swift with clean state initialization
   - Pass only ViewModel, not individual stores

2. **Unify Design Token References**
   - Old code: `AppSpacing`, `AppColors`, `AppTypography`
   - New code: `DesignSystem.Spacing`, `DesignSystem.Colors`
   - Choose one pattern and apply consistently

3. **Fix HomeView Initialization**
   - Currently: `init(viewModel: HomeViewModel)`
   - But then passes to ViewModel as `@State`
   - Should be: `@StateObject private var viewModel: HomeViewModel`
   - Initialization: Handle in ViewModel, not in View

4. **Implement Charter Filtering Logic in ViewModel**
   - Date overlap calculation must be in `refresh()` method
   - Not in view layer
   - Testable separately

5. **Add Missing Properties to HomeViewModel**
   - `activeCharterChecklistID: UUID?`
   - Calculated during refresh, used in detail view

6. **Restore Auth Prompt Overlay**
   - Old code shows sign-in button on create card
   - New code missing this feature
   - Add conditional `.overlay(alignment: .bottomTrailing) { ... }`

### Architectural Improvements

1. **Separate CharterDetailView Component**
   - Active charter card should link to dedicated detail view
   - Not just inline expansion
   - Follow container/presenter pattern

2. **Create PinnedContentCard Component**
   - Reuse for both Checklists and Guides subsections
   - DRY principle: avoid code duplication

3. **Implement ActiveCharterView Component**
   - Extracted from primary card
   - Show when `activeCharter != nil`
   - Includes checkin checklist sub-section

4. **Add Error Boundary**
   - Wrap refresh() in try-catch
   - Log to analytics
   - Show silent fallback UI

---

## Testing Checklist

- [ ] Display greeting based on current time (test all 4 time ranges)
- [ ] Show active charter card when charter dates include today
- [ ] Show create charter card when no active charters
- [ ] Tap active charter card → Navigate to ChartDetail with correct ID
- [ ] Tap create charter card → Navigate to CharterCreation
- [ ] Tap checklist item → Navigate to ChecklistDetail with correct ID
- [ ] Tap guide item → Navigate to GuideDetail with correct ID
- [ ] Tap checkin checklist → Navigate to ChecklistExecution with both IDs
- [ ] Show loading state while refreshing
- [ ] Show empty state when no checklists/guides
- [ ] Handle multiple active charters (select latest)
- [ ] Handle network error during refresh (show cached data)
- [ ] Show sign-in prompt when not authenticated
- [ ] Verify date boundary conditions (charter ends today at 11:59 PM)
- [ ] Accessibility: Tab through all interactive elements in order
- [ ] Accessibility: VoiceOver labels are descriptive
- [ ] Safe area: Tab bar doesn't overlap content at bottom

---

## Success Metrics

1. **User Engagement**
   - CTR on active charter card (target: >70% for active users)
   - CTR on create charter card (target: >40% for inactive users)

2. **Onboarding**
   - Time to first charter creation from app launch (target: <2 min)
   - Auth conversion rate (target: >60% on first visit)

3. **Content Discovery**
   - CTR on reference content items (target: >25%)
   - Avg items viewed per session (target: >1.5)

4. **Performance**
   - View load time (target: <500ms on 5G, <1s on LTE)
   - Refresh time (target: <2s)

---

## Release Notes

**v1.0 - Initial Release**
- ✅ Adaptive charter card (active/create states)
- ✅ Reference content section (checklists + guides)
- ✅ Authentication prompt for signed-out users
- ✅ Charter detail navigation
- ✅ Checklist execution from active charter
- ⏳ Pinned content customization (future)
- ⏳ Charter statistics dashboard (future)

