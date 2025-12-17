# Architecture & Data Flow Diagrams

## Component Hierarchy

```
HomeView (Top-level SwiftUI View)
├─ ScrollView
│  └─ VStack (main layout)
│     ├─ headerSection
│     │  ├─ Greeting Text (time-based)
│     │  └─ Date Text (full format)
│     │
│     ├─ Conditional Primary Card
│     │  ├─ IF activeCharter != nil:
│     │  │  └─ activeCharterCard(charter)
│     │  │     ├─ Badge: "Active Charter"
│     │  │     ├─ Title: charter.name
│     │  │     ├─ Subtitle: charter.location (with icon)
│     │  │     └─ [Tap Handler] → chartDetail
│     │  │
│     │  └─ ELSE:
│     │     └─ createCharterCard
│     │        ├─ Icon: plus.circle.fill
│     │        ├─ Title: "Create New Charter"
│     │        ├─ Subtitle: "Start your sailing trip"
│     │        ├─ [Tap Handler] → charterCreation
│     │        └─ [Conditional Overlay] Auth Button
│     │           └─ IF showAuthPrompt: signInButton
│     │              └─ [Tap Handler] → Apple Sign In
│     │
│     └─ referenceContentSection
│        ├─ Section Title: "Reference Content"
│        │
│        ├─ Checklists Subsection
│        │  ├─ Header: "Checklists"
│        │  └─ IF isLoading:
│        │     └─ 3x loadingCard (skeleton)
│        │  └─ ELSE IF myChecklists.isEmpty:
│        │     └─ emptyCard("No checklists yet")
│        │  └─ ELSE:
│        │     └─ ForEach(myChecklists.prefix(3))
│        │        └─ referenceCard
│        │           ├─ Title: checklist.title
│        │           ├─ Subtitle: checklist.description
│        │           └─ [Tap Handler] → checklistDetail
│        │
│        └─ Guides Subsection
│           ├─ Header: "Guides"
│           └─ [Same structure as Checklists]
│              └─ [Tap Handler] → guideDetail
```

---

## State Management Flow

```
┌──────────────────────────────────────────────────────────────┐
│ HOME VIEW LIFECYCLE                                          │
└──────────────────────────────────────────────────────────────┘

1. VIEW INITIALIZATION
   ↓
   HomeView(charterStore, userStore, contentStore, appModel)
   ↓
   @StateObject creates HomeViewModel with dependencies
   ↓

2. ON APPEAR (.task)
   ↓
   viewModel.refresh()
   ├─ Set isLoading = true
   ├─ Update showAuthPrompt = !userStore.isAuthenticated
   │
   ├─ CALCULATE ACTIVE CHARTER
   │  ├─ today = Calendar.startOfDay(Date())
   │  ├─ Filter: charters where startDate ≤ today ≤ endDate
   │  ├─ Sort: by startDate descending (latest first)
   │  └─ Select: .first
   │
   ├─ IF activeCharter exists:
   │  ├─ Query latest checkin checklist
   │  │  └─ Where: type == .checkin AND charterID == activeCharter.id
   │  └─ Set activeCharterChecklistID
   │
   └─ Set isLoading = false
   
   ↓

3. RENDER PRIMARY CARD
   ├─ IF activeCharter != nil
   │  └─ Show: activeCharterCard
   │     ├─ Data: charter.name, charter.location
   │     └─ Styling: oceanGradient background
   │
   └─ ELSE
      └─ Show: createCharterCard
         ├─ Styling: oceanGradient background
         ├─ Overlay: IF showAuthPrompt, show sign-in button
         └─ Data: Static localized strings

   ↓

4. RENDER REFERENCE CONTENT
   ├─ Loop 1: Reference Cards (Checklists)
   │  ├─ IF isLoading: Show 3 skeleton cards
   │  ├─ ELSE IF isEmpty: Show empty state message
   │  └─ ELSE: Map over first 3 items
   │
   └─ Loop 2: Reference Cards (Guides)
      └─ Same pattern as Checklists

   ↓

5. USER INTERACTION
   
   Case A: Tap active charter card
   ├─ Call: viewModel.onActiveCharterTapped(charter)
   ├─ Action: appModel.navigationPath.append(.charterDetail(id))
   └─ Navigate: → CharterDetailView
   
   Case B: Tap create charter card
   ├─ Call: viewModel.onCreateCharterTapped()
   ├─ Action: appModel.navigationPath.append(.charterCreation)
   └─ Navigate: → CharterCreationView
   
   Case C: Tap auth button
   ├─ Call: viewModel.signIn()
   ├─ Action: userStore.signInWithApple()
   ├─ On Success: viewModel.refresh() (re-render)
   └─ Navigate: Back to home (authenticated)
   
   Case D: Tap checklist/guide reference card
   ├─ Call: viewModel.openChecklist(id) OR viewModel.openGuide(id)
   ├─ Action: appModel.navigationPath.append(.checklistDetail/guideDetail)
   └─ Navigate: → Detail view

```

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ DATA SOURCES                                                │
└─────────────────────────────────────────────────────────────┘

CharterStore
├─ charters: [CharterModel]
│  ├─ id: UUID
│  ├─ name: String
│  ├─ location: String?
│  ├─ startDate: Date
│  ├─ endDate: Date
│  └─ status: CharterStatus
└─ Methods: create, update, delete, fetch

UserStore
├─ currentUser: UserModel?
├─ isAuthenticated: Bool
├─ isAuthenticating: Bool
└─ Methods: signInWithApple, signOut

ContentStore
├─ myChecklists: [ChecklistModel]
│  ├─ id: UUID
│  ├─ title: String
│  ├─ description: String?
│  ├─ type: ChecklistType (.checkin, .safety, etc.)
│  ├─ charterID: UUID? (nil = library, set = charter-scoped)
│  ├─ createdAt: Date
│  └─ updatedAt: Date
│
├─ myGuides: [GuideModel]
│  ├─ id: UUID
│  ├─ title: String
│  ├─ description: String?
│  ├─ createdAt: Date
│  └─ updatedAt: Date
│
└─ Methods: fetch, create, fork, delete

AppModel
├─ selectedTab: MainTab
├─ navigationPath: [AppPath]
└─ Methods: navigate, reset


┌─────────────────────────────────────────────────────────────┐
│ HOMEVIEWMODEL (State Calculator)                            │
└─────────────────────────────────────────────────────────────┘

refresh() Async Operation:
┌─────────────────────────────────────────────┐
│ START: isLoading = true                     │
├─────────────────────────────────────────────┤
│ 1. AUTH STATE                               │
│    showAuthPrompt = !userStore.authenticated│
├─────────────────────────────────────────────┤
│ 2. ACTIVE CHARTER CALCULATION              │
│    Input:  charterStore.charters             │
│    Filter: startDate ≤ today ≤ endDate     │
│    Sort:   by startDate (desc)              │
│    Output: activeCharter = first (or nil)   │
├─────────────────────────────────────────────┤
│ 3. CHECKIN CHECKLIST LOOKUP                │
│    IF activeCharter exists:                 │
│      Input:  contentStore.myChecklists      │
│      Filter: type == .checkin               │
│               charterID == activeCharter.id │
│      Sort:   by createdAt (desc)            │
│      Output: activeCharterChecklistID       │
│    ELSE:                                    │
│      activeCharterChecklistID = nil         │
├─────────────────────────────────────────────┤
│ END: isLoading = false                      │
└─────────────────────────────────────────────┘


┌─────────────────────────────────────────────┐
│ HOMEVIEW (Render Layer)                     │
└─────────────────────────────────────────────┘

Inputs:
  ├─ viewModel.activeCharter: CharterModel?
  ├─ viewModel.isLoading: Bool
  ├─ viewModel.showAuthPrompt: Bool
  ├─ contentStore.myChecklists: [ChecklistModel]
  └─ contentStore.myGuides: [GuideModel]

Decision Tree:
  ├─ IF activeCharter != nil:
  │  └─ Render: activeCharterCard
  │     └─ Display: charter.name, charter.location
  │        └─ Style: oceanGradient
  │           └─ Interaction: → charterDetail
  │
  └─ ELSE:
     └─ Render: createCharterCard
        ├─ Display: "Create New Charter" + description
        ├─ Style: oceanGradient
        ├─ Overlay: IF showAuthPrompt → signInButton
        └─ Interaction: 
           ├─ Tap card → charterCreation
           └─ Tap button → Apple Sign In

Reference Content:
  ├─ IF isLoading:
  │  └─ Show: 3 skeleton cards (each section)
  │     └─ Animated placeholder rectangles
  │
  ├─ ELSE IF myChecklists.isEmpty:
  │  └─ Show: Empty state message "No checklists yet"
  │
  └─ ELSE:
     └─ Show: ForEach(myChecklists.prefix(3))
        ├─ Card title: checklist.title
        ├─ Card subtitle: checklist.description
        └─ Interaction: → checklistDetail

```

---

## Navigation Graph

```
                          ┌─────────────────────────────────────┐
                          │      HOME VIEW (Tab Root)           │
                          └─────────────────────────────────────┘
                                      │
                    ┌───────────┬─────┴─────┬────────────┐
                    │           │           │            │
                    ▼           ▼           ▼            ▼
          ┌──────────────┐  ┌──────────┐  ┌────────┐  ┌─────────────┐
          │ Charter Card │  │Auth Prompt│  │Ref.    │  │Reference    │
          │Active/Create │  │Sign In   │  │Content │  │Content Tap  │
          └──────────────┘  │Button    │  │Items   │  │(Checklists) │
            │ │              └──────────┘  └────────┘  └─────────────┘
            │ │                              │ │          │ │
            │ │                              │ │          ▼ ▼
            ▼ ▼                              ▼ ▼      ┌──────────────┐
        ┌─────────────┐                ┌──────────┐   │ChecklistDetail
        │  (IF nil)   │                │Reference │   │      or
        │   Create    │                │Content   │   │  GuideDetail
        │   Charter   │                │ Tapped   │   └──────────────┘
        │ Creation    │                └──────────┘
        │   Flow      │                      │
        └─────────────┘                      ├─→ checklistDetail(id)
            │                                ├─→ guideDetail(id)
            ▼                                └─→ checklistExecution(id, charterID)
        ┌──────────────┐
        │CharterCreate │
        │   View       │
        │ [Complete]   │
        │   Flow       │
        └──────────────┘

        ┌──────────────┐
        │  (IF != nil) │
        │   Charter    │
        │   Detail     │
        │   View       │
        │              │
        │  Contains:   │
        │  ├─ Charter  │
        │  │  Info     │
        │  │           │
        │  └─ Checkin  │
        │     Checklist│
        │     Card     │
        │     (Placeholder)
        │              │
        └──────────────┘
                │
                ├─→ ChecklistExecution(checklistID, charterID)
                │   Execute checkin checklist
                │
                └─→ [More Detail View Content]

┌──────────────────┐
│   Sign In Flow   │
│                  │
│ 1. User taps     │
│    sign-in button│
│                  │
│ 2. Apple Sign In │
│    Sheet appears │
│                  │
│ 3. Auth succeeds │
│    or cancelled   │
│                  │
│ 4. If success:   │
│    viewModel     │
│    .refresh()    │
│                  │
│ 5. HomeView      │
│    re-renders    │
│    with user data│
│                  │
└──────────────────┘

```

---

## Timing Diagram

```
TIME AXIS →

USER LAUNCHES APP
        │
        ▼
   HomeView Init
        │
        ├─ Create HomeViewModel with 4 stores
        ├─ Store in @StateObject
        └─ Render body (activeCharter = nil, isLoading = false)
        │
        ▼
   FIRST RENDER
   Show: createCharterCard (empty state)
        │
        ▼
   .task { await viewModel.refresh() }
        │
        ├─ isLoading = true
        ├─ [Re-render: show skeleton cards]
        │
        ├─ Fetch: activeCharter from charterStore
        ├─ Fetch: activeCharterChecklistID from contentStore
        ├─ Calculate: showAuthPrompt from userStore
        │
        └─ isLoading = false
        │
        ▼
   SECOND RENDER
   Case A: If activeCharter found
           └─ Show: activeCharterCard
   
   Case B: If no activeCharter
           └─ Show: createCharterCard

        │
        ├─ In both cases:
        │  └─ Show: reference content (checklists + guides)
        │
        ▼
   USER INTERACTION - TAP ACTIVE CHARTER
        │
        ├─ viewModel.onActiveCharterTapped(charter)
        ├─ appModel.navigationPath.append(.charterDetail(id))
        │
        └─ NavigationStack redirects to CharterDetailView
           └─ [Navigation complete]

   USER INTERACTION - TAP SIGN IN BUTTON
        │
        ├─ viewModel.signIn()
        ├─ userStore.signInWithApple()
        │
        ├─ Apple Sign In sheet appears
        │ (User signs in or cancels)
        │
        ├─ IF success:
        │  └─ viewModel.refresh()
        │     └─ isLoading = true (again)
        │        └─ [Re-render with loading state]
        │        └─ Fetch: updated data
        │        └─ isLoading = false
        │        └─ [Re-render: show data]
        │
        └─ IF cancelled:
           └─ Return to home (no change)

```

---

## Edge Case Handling

```
┌─────────────────────────────────────────────┐
│ EDGE CASE: Charter Ends TODAY               │
└─────────────────────────────────────────────┘

Scenario:
  Charter: startDate = Dec 10, endDate = Dec 17 (today)
  Time: 3:00 PM

Filter Logic:
  startDate (Dec 10) ≤ today (Dec 17) ✓
  endDate (Dec 17) ≥ today (Dec 17) ✓
  → Charter INCLUDED (still active)

Behavior:
  ✓ Show activeCharterCard (correct)
  ✓ User can still tap and view details
  ✓ User can complete checkin today


┌─────────────────────────────────────────────┐
│ EDGE CASE: Multiple Overlapping Charters    │
└─────────────────────────────────────────────┘

Scenario:
  Charter 1: Dec 15-20
  Charter 2: Dec 17-25  ← Overlaps with 1
  Today: Dec 18

Both charters have today in range!

Solution:
  Sort by startDate DESC (latest first)
  → Charter 2 (Dec 17) > Charter 1 (Dec 15)
  → Return: Charter 2 (most recent start)

Behavior:
  ✓ Show most recent charter (most likely intent)
  ✓ User can navigate to Charters tab for full list


┌─────────────────────────────────────────────┐
│ EDGE CASE: No Checkin Checklist              │
└─────────────────────────────────────────────┘

Scenario:
  Active charter exists
  No checklist with type == .checkin

Result:
  activeCharterChecklistID = nil

In CharterDetailView:
  If activeCharterChecklistID != nil:
    Show: CheckinChecklistCard → tap to execute
  Else:
    Show: Empty message "No check-in items"
         + "Create one in Library"

Behavior:
  ✓ Graceful fallback
  ✓ User can navigate to Library


┌─────────────────────────────────────────────┐
│ EDGE CASE: Network Error on Refresh         │
└─────────────────────────────────────────────┘

Scenario:
  refresh() called
  API call fails (network down)

Current Implementation:
  ✓ No error alert (ambient experience)
  ✓ Set isLoading = false
  ✓ Show cached data (previous state)
  ✓ Log error: AppLogger.home.error(...)

Behavior:
  ✓ User doesn't see error
  ✓ App continues working with cached data
  ✓ Retry on next screen visit or pull-to-refresh


┌─────────────────────────────────────────────┐
│ EDGE CASE: User Not Authenticated            │
└─────────────────────────────────────────────┘

Scenario:
  User hasn't signed in with Apple
  No charters/content available

Behavior:
  showAuthPrompt = true

On HomeView:
  ├─ Show: createCharterCard
  ├─ Overlay: Sign In button (visible)
  └─ Tap button → Apple Sign In

After Sign In:
  showAuthPrompt = false
  refresh() → fetch charters/content
  Re-render with data


┌─────────────────────────────────────────────┐
│ EDGE CASE: Empty Reference Content           │
└─────────────────────────────────────────────┘

Scenario:
  User has no checklists AND no guides

Behavior:
  myChecklists.isEmpty = true
  myGuides.isEmpty = true

On HomeView:
  Checklists section:
    → Empty state card: "No checklists yet"
  
  Guides section:
    → Empty state card: "No guides yet"

User sees:
  ✓ Clear message
  ✓ Can navigate to Library to create content
  ✓ Home still visually complete

```

---

## State Transitions Diagram

```
                    ┌─────────────────────────┐
                    │   NOT LOADING STATE     │
                    │  isLoading = false      │
                    │ (Normal rendering)      │
                    └─────────────────────────┘
                              ▲
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    │                   │
        ┌───────────▼──────────┐    ┌───┴──────────────────┐
        │   ACTIVE CHARTER     │    │   NO ACTIVE CHARTER  │
        │   Found              │    │   (createMode)       │
        │                      │    │                      │
        │ activeCharter != nil │    │ activeCharter == nil │
        │                      │    │                      │
        │ Display:             │    │ Display:             │
        │ ├─ Charter name      │    │ ├─ "Create Charter"  │
        │ ├─ Location          │    │ ├─ Plus icon         │
        │ └─ Gradient card     │    │ └─ Auth prompt (if)  │
        │                      │    │                      │
        │ Tap: → CharterDetail │    │ Tap: → CharterCreate │
        └───────────┬──────────┘    └────────┬─────────────┘
                    │                        │
                    └────────────┬────────────┘
                                 │
                        User interacts
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   LOADING STATE         │
                    │  isLoading = true       │
                    │ (Show skeletons)        │
                    └─────────────────────────┘
                                 │
                        refresh() completes
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   NOT LOADING STATE     │
                    │  isLoading = false      │
                    │ (Normal rendering)      │
                    └─────────────────────────┘

```

---

## Thread Safety

```
HomeView is @MainActor
  └─ All state updates on main thread

HomeViewModel is @Observable @MainActor
  └─ viewModel.refresh() is @MainActor
  └─ All properties thread-safe (main thread only)

Async Operations:
  ├─ viewModel.refresh() — async but @MainActor
  │  └─ Executes on main thread (thread-safe)
  │
  └─ viewModel.signIn() — async but @MainActor
     └─ Executes on main thread (thread-safe)

Environment Stores:
  ├─ charterStore @Observable (thread-safe access)
  ├─ userStore @Observable (thread-safe access)
  ├─ contentStore @Observable (thread-safe access)
  └─ All accessed from @MainActor context

✓ No thread safety concerns
✓ No data races possible
✓ All UI updates on main thread guaranteed
```

