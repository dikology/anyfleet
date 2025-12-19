# Implementation Checklist - Library Visibility Feature

**Estimated effort:** 2-3 weeks for complete implementation  
**Priority:** HIGH - Foundational for Phase 2

---

## PHASE 1: FOUNDATION (Week 1)

### Data Model Extensions
- [x] Add `VisibilityState` enum to `LibraryModel`
  ```swift
  enum VisibilityState: Codable, Equatable {
      case `private`
      case unlisted
      case `public`(PublicMetadata)
  }
  ```
  
- [x] Add `SyncState` enum to `LibraryModel`
  ```swift
  enum SyncState: String, Codable {
      case local
      case published
      case pending
      case error
  }
  ```
  
- [x] Add visibility fields to `LibraryModel`
  - [x] `visibilityState: VisibilityState`
  - [x] `syncState: SyncState`
  - [x] `publishedAt: Date?`
  - [x] `publicID: String?` (URL slug)

### Service Layer
- [x] Create `VisibilityService` class
  - [x] `canToggleVisibility() -> Bool`
  - [x] `publishContent(_ item: LibraryModel) async throws`
  - [x] `unpublishContent(_ item: LibraryModel) async throws`
  - [x] Input validation methods

- [x] Create `AuthStateObserver` class
  - [x] Observe `AuthService` state changes
  - [x] Expose `isSignedIn` and `currentUser`
  - [x] Add to `AppDependencies`

### ViewModel Refactoring
- [x] Inject dependencies into `LibraryListViewModel`
  - [x] `visibilityService: VisibilityService`
  - [x] `authObserver: AuthStateObserver`
  
- [x] Add computed properties
  - [x] `isSignedIn: Bool`
  - [x] `localContent: [LibraryModel]`
  - [x] `publicContent: [LibraryModel]`
  - [x] `hasLocalContent: Bool`
  - [x] `hasPublicContent: Bool`

- [x] Add state properties
  - [x] `pendingPublishItem: LibraryModel?`
  - [x] `publishError: Error?`

- [x] Add action methods
  - [x] `initiatePublish(_ item: LibraryModel)`
  - [x] `confirmPublish() async`
  - [x] `cancelPublish()`
  - [x] `unpublish(_ item: LibraryModel) async`

---

## PHASE 2: UI COMPONENTS (Week 1-2)

### Reusable Components
- [ ] Create `VisibilityBadge` component
  - [ ] Handle all three visibility states
  - [ ] Show view count for public items
  - [ ] Proper color coding
  - [ ] Optional author display

- [ ] Create `PublishConfirmationModal` component
  - [ ] Title with item name
  - [ ] Explanation text
  - [ ] Info box about permanence
  - [ ] Confirm/Cancel buttons
  - [ ] Loading state handling
  - [ ] Error state display
  - [ ] Auto-dismiss on success

- [ ] Create `PublishActionView` component
  - [ ] Show [Publish] when signed in
  - [ ] Show [Unpublish] when published
  - [ ] Show disabled state with sign-in prompt when unsigned
  - [ ] Disabled styling and cursor

- [ ] Create `SignInModalView` component
  - [ ] Sign In with Apple button
  - [ ] Optional email fallback
  - [ ] Close button (✕)
  - [ ] Success callback
  - [ ] Error handling

### LibraryItemRow Refactoring
- [ ] Extract row into separate file
  - [ ] Keep structure but extract from nested struct

- [ ] Update row layout
  - [ ] Keep hero section (title, icon, type)
  - [ ] Keep metadata section (updated date)
  - [ ] NEW: Add footer section with visibility badge + publish action
  - [ ] Background color for published items

- [ ] Swipe actions
  - [ ] Keep: Delete, Edit, Pin
  - [ ] Remove: Publish (move to footer button)

- [ ] Tap behavior
  - [ ] Body: Opens content reader
  - [ ] Publish button: Shows confirmation

### LibraryListView Refactoring
- [ ] Create `ContentFilter` enum
  ```swift
  enum ContentFilter: CaseIterable {
      case all, local, public_only
  }
  ```

- [ ] Add filter picker
  - [ ] Segmented control (recommended)
  - [ ] Show above list

- [ ] Section-based list structure
  - [ ] "🔒 Local Content" section
  - [ ] "🌐 Public Content" section
  - [ ] Conditional section display based on filter

- [ ] Add sheet presentations
  - [ ] Publish confirmation modal
  - [ ] Sign-in modal

- [ ] Empty states by filter
  - [ ] All empty
  - [ ] Local empty
  - [ ] Public empty

---

## PHASE 3: DATABASE LAYER (Week 2)

### GRDB Schema
- [ ] Create migration `2.0.0`
  - [ ] Add columns to `library_content` table
    - [ ] `visibility_state` (TEXT, default "private")
    - [ ] `sync_state` (TEXT, default "local")
    - [ ] `published_at` (DATETIME, nullable)
    - [ ] `public_id` (TEXT, nullable)
    - [ ] `author_id` (TEXT, nullable)
    - [ ] `view_count` (INTEGER, default 0)
    - [ ] `can_fork` (BOOLEAN, default true)

  - [ ] Create `public_content` table
  - [ ] Create `visibility_changes` table

### Record Types
- [ ] Update `LibraryModelRecord`
  - [ ] Add new columns
  - [ ] Add conversion logic to domain model `toDomain()`

- [ ] Create `PublicContentRecord`
  - [ ] All fields as per schema
  - [ ] FetchableRecord + PersistableRecord

- [ ] Create `VisibilityChangeRecord`
  - [ ] All fields as per schema
  - [ ] FetchableRecord + PersistableRecord

### Repository Methods
- [ ] Implement `updateVisibility(contentID, newState) async throws`
- [ ] Implement `getPendingVisibilityChanges() async throws`
- [ ] Implement `markVisibilityChangeAsSynced(_ recordID) async throws`
- [ ] Implement `markVisibilityChangeAsFailed(_ recordID, error) async throws`

---

## PHASE 4: AUTH INTEGRATION (Week 2)

### ProfileView Integration
- [ ] Ensure AuthService properly triggers observable updates
  - [ ] After sign in succeeds
  - [ ] After sign out succeeds

- [ ] Test that `AuthStateObserver` receives updates

### SignInModalView Creation
- [ ] Design modal UI
  - [ ] Sign In with Apple button
  - [ ] Proper styling
  - [ ] Close button
  - [ ] Error display

- [ ] Implement sign-in flow
  - [ ] Call `authService.handleAppleSignIn()`
  - [ ] Track loading state
  - [ ] Handle errors
  - [ ] Dismiss on success
  - [ ] Call success callback

### LibraryListView Auth Integration
- [ ] Observe `viewModel.isSignedIn`
  - [ ] Update publish button states
  - [ ] Show/hide sign-in prompts

- [ ] Connect sign-in modal
  - [ ] Show when publish tapped while unsigned
  - [ ] Dismiss after successful sign-in
  - [ ] Auto-retry publish if item was pending

---

## PHASE 5: TESTING (Week 2-3)

### Unit Tests
- [ ] `VisibilityService` tests
  - [ ] `canToggleVisibility()` returns correct auth state
  - [ ] `publishContent()` validation
  - [ ] `unpublishContent()` state changes
  - [ ] Error handling

- [ ] `LibraryListViewModel` tests
  - [ ] Filter computed properties
  - [ ] Publish/unpublish state management
  - [ ] Pending item tracking

- [ ] GRDB migration tests
  - [ ] Schema created correctly
  - [ ] Data persisted correctly

### Integration Tests
- [ ] Publish flow end-to-end
  - [ ] Local content → pending → published
  - [ ] Data persisted to GRDB

- [ ] Unpublish flow
  - [ ] Public content → private
  - [ ] Data updated in GRDB

- [ ] Filter behavior
  - [ ] "All" shows everything
  - [ ] "Local" shows only private/unlisted
  - [ ] "Public" shows only public items

### UI Tests (SwiftUI Preview)
- [ ] `LibraryItemRow` with different states
  - [ ] Private content
  - [ ] Public content
  - [ ] Unsigned user (disabled publish)
  - [ ] Signed user (enabled publish)

- [ ] `PublishConfirmationModal`
  - [ ] Initial state
  - [ ] Loading state
  - [ ] Success state
  - [ ] Error state

- [ ] `LibraryListView`
  - [ ] Empty states
  - [ ] All/Local/Public filters
  - [ ] Section visibility

---

## PHASE 6: POLISH & OPTIMIZATION (Week 3)

### Accessibility
- [ ] VoiceOver labels
  - [ ] Visibility badges
  - [ ] Publish buttons
  - [ ] Filter options
  - [ ] Error messages

- [ ] Focus management
  - [ ] Proper tab order
  - [ ] Focus visible states
  - [ ] Modal focus trap

- [ ] Color contrast
  - [ ] Visibility badges (4.5:1 minimum)
  - [ ] All text (WCAG AA)
  - [ ] Test with Color Contrast Analyzer

### Performance
- [ ] Profile library loading
  - [ ] Large libraries (1000+ items)
  - [ ] Filter performance
  - [ ] Memory usage

- [ ] Database queries
  - [ ] Index visibility_state column
  - [ ] Index sync_state column
  - [ ] Pagination for large lists

- [ ] Animations
  - [ ] Smooth transitions
  - [ ] No janky list scrolling
  - [ ] Loading state UX

### Error Handling
- [ ] Network errors
  - [ ] Show clear message
  - [ ] Provide retry button
  - [ ] Save to pending queue

- [ ] Validation errors
  - [ ] Clear user messaging
  - [ ] Suggest fixes
  - [ ] Don't dismiss modal

- [ ] Sync failures
  - [ ] Mark item with error state
  - [ ] Show retry option
  - [ ] Log for debugging

### Localization
- [ ] Add new strings to L10n
- [ ] Test with Russian localization
  - [ ] Text wrapping
  - [ ] Button sizing
  - [ ] Modal layout

---

## PHASE 7: HANDOFF TO PHASE 2 BACKEND (End of Week 3)

- [ ] Visibility state properly versioned
- [ ] Public metadata ready for server
- [ ] Sync queue operational
- [ ] Update Phase 1 spec with new features
- [ ] Document database schema changes
- [ ] Create Phase 2 backend integration spec

---

## TESTING CHECKLIST - Manual Testing

### Signed-Out User
- [ ] View library with local content
  - [ ] See 🔒 private badges
  - [ ] See filter options
  - [ ] See "Local" section populated
  - [ ] No "Public" section visible

- [ ] Tap publish button
  - [ ] See sign-in modal
  - [ ] Can't proceed without signing in
  - [ ] Sign-in works
  - [ ] Modal closes

- [ ] After sign-in, retry publish
  - [ ] See confirmation modal
  - [ ] Tap confirm
  - [ ] Content moves to "Public" section
  - [ ] Badge changes to 🌐 public

### Signed-In User
- [ ] Create new content (appears as 🔒 private)
- [ ] Publish content
  - [ ] See confirmation
  - [ ] Content marked as ⏳ publishing
  - [ ] Completes to 🌐 public
  - [ ] Badge shows view count

- [ ] Unpublish content
  - [ ] See confirmation
  - [ ] Content moves back to local
  - [ ] Badge changes to 🔒 private

### Filters
- [ ] "All" shows private + public
- [ ] "Local" shows only private
- [ ] "Public" shows only public
- [ ] Switch between filters smoothly

### Error Scenarios
- [ ] Publish with empty title
  - [ ] Shows validation error
  - [ ] Doesn't dismiss modal
  - [ ] Can fix and retry

- [ ] Network error during publish
  - [ ] Shows error message
  - [ ] Retry button available
  - [ ] Marked as pending in list
  - [ ] Can retry later

- [ ] Sign-in cancelled
  - [ ] Publish action cancelled
  - [ ] Modal dismisses cleanly
  - [ ] No errors in logs

---

## DEPLOYMENT CHECKLIST

- [ ] All tests passing
- [ ] Code review completed
- [ ] No console warnings/errors
- [ ] Performance profiling shows no regressions
- [ ] Accessibility audit passed
- [ ] Localization strings complete
- [ ] Database migration tested on fresh install
- [ ] Database migration tested on upgrade
- [ ] Sign-in flow works end-to-end
- [ ] All states tested on physical device
- [ ] Screenshots updated for App Store
- [ ] Release notes prepared
- [ ] Analytics events tracked

---

## TIME BREAKDOWN

| Phase | Component | Hours |
|-------|-----------|-------|
| 1 | Models + Services | 8 |
| 1 | ViewModel updates | 6 |
| 2 | Components | 10 |
| 2 | View refactoring | 12 |
| 3 | Database | 8 |
| 4 | Auth integration | 6 |
| 5 | Testing | 16 |
| 6 | Polish | 8 |
| 7 | Handoff | 4 |
| **Total** | | **78 hours** |

**Estimate: 2-3 weeks depending on team size**

---

## SUCCESS CRITERIA

✅ Users can see clear distinction between local and public content  
✅ Publishing requires sign-in with clear UX  
✅ Confirmation modal prevents accidental publishes  
✅ Visibility state persists in GRDB  
✅ All tests passing  
✅ Accessibility audit passed  
✅ App Store ready for submission  
✅ Phase 2 backend team has clear sync interface