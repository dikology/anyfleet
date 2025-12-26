# Product Requirements Document: Community Library Improvements

**Product**: AnyFleet Sailing iOS App  
**Feature**: Community Library Enhancement  
**Version**: 1.0  
**Date**: December 25, 2025  
**Status**: Ready for Implementation  

---

## Executive Summary

The AnyFleet Community Library enables users to create, publish, and discover sailing content (checklists, practice guides, and flashcard decks). Current analysis reveals critical gaps in the user experience around content forking, sync behavior, and community integration. This PRD outlines improvements to create a thriving, attribution-first community where content evolves through collaboration.

**Key Objectives**:
- Enable seamless content forking and attribution tracking
- Fix sync behavior for published content updates
- Integrate Discover tab with Personal Library workflow
- Implement robust deletion and recovery patterns
- Enhance user discoverability and content quality signals

---

## Problem Statement

### Current State Issues

**1. Broken Deletion Workflow**  
Users can delete local content while it remains published on the backend, leaving orphaned public content. This creates broken links, poor UX for other users, and data inconsistency[1].

**2. Stale Published Content**  
When users edit published content locally, changes don't sync to the backend. The community sees outdated content, creating confusion about what others actually see[1].

**3. Limited Forking Integration**  
No UI exists for forking content from the Discover tab. Users can browse community content but cannot easily import or create variations[1].

**4. Abandoned Recovery Path**  
When users delete published content, there's no way to recover it short of manual recreation. This is frustrating for accidental deletions[1].

**5. Weak Attribution System**  
Fork relationships are not visualized. Users can't easily see content evolution or attribute original creators[1].

---

## Goals & Success Metrics

### Primary Goals

| Goal | Success Metric | Owner |
|------|---|---|
| Enable forking workflow | 15% of discovered content forked within 4 weeks | Product |
| Fix content sync | 100% of published content updates sync within 5 seconds | Engineering |
| Improve deletion UX | 0% orphaned public content after implementation | Engineering |
| Increase community engagement | 30% increase in content discovery interactions | Product |
| Attribution clarity | 100% of forked content shows original creator | Engineering |

### User Experience Goals

- **Zero friction**: Users never encounter broken links or stale content
- **Self-service recovery**: Users can recover accidentally deleted published content
- **Content evolution**: Users understand how their content is remixed and improved by others
- **Quality signals**: Users can identify high-quality, well-maintained content

---

## User Personas & Use Cases

### Persona 1: Captain Maria (Content Creator)

**Profile**: Experienced sailor creating detailed sailing checklists and guides for the community

**Key Use Cases**:
1. Publish a checklist, make edits based on feedback, sync changes automatically to community
2. Accidentally delete local copy of published content, fork it back from community library
3. See downstream forks of her content, track how others improve on her work
4. Receive credit and attribution when her content is forked

**Pain Points**:
- Local edits to published content feel lost (no sync feedback)
- Accidental local deletion could orphan content permanently
- Can't see how community is using/improving her content

### Persona 2: Alex (Content Discoverer)

**Profile**: Newer sailor discovering and learning from community content

**Key Use Cases**:
1. Browse Discover tab, find useful checklist, fork it to personal library
2. Customize forked content for specific charter scenario
3. See which creator originally wrote the content
4. Rate or favorite high-quality forked content

**Pain Points**:
- Switching between Discover and Library tabs is friction
- Can't easily import discovered content into personal library
- Doesn't know attribution chain of forked content

### Persona 3: Admin (Content Moderator)

**Profile**: AnyFleet staff managing community content quality

**Key Use Cases**:
1. Identify orphaned public content (deleted locally but still published)
2. Remove spam, offensive, or outdated content
3. Promote high-quality, well-forked content
4. Monitor sync failures and data consistency

**Pain Points**:
- No visibility into orphaned content
- Manual moderation tools needed for problematic content
- Sync failures hidden from admin view

---

## Feature Specifications

### Feature 1: Seamless Content Forking

**Objective**: Enable users to fork any community content into their personal library with one tap.

**Scope**: Applies to checklists, practice guides, and flashcard decks in Discover tab.

**User Workflow**:

1. User browses Discover tab and finds content from another creator
2. Taps "Fork" button on content (bottom of content detail view)
3. System creates copy in user's personal library with:
   - All content data (sections, items, markdown, etc.)
   - `forkedFromID` pointing to original content
   - Original creator attribution visible
   - New `publicID` (if user publishes the fork)
4. Navigation returns user to their Library tab showing newly forked content
5. User can edit forked content without affecting original

**Technical Details**:
- Fork creates new `LibraryModel` record with `forkedFromID` set to source content's ID
- Fork increments `forkCount` on original content (via sync system)
- Fork copies full content snapshot (Checklist, PracticeGuide, FlashcardDeck)
- No network required for fork creation (offline-first)
- Attribution update (fork count increment) queued in sync system
- Fork operation queued in sync system if content is to be published

**Success Criteria**:
- Fork completes in <500ms
- Fork works entirely offline (with sync for fork counts)
- `forkCount` increments accurately on original content
- Fork shows full attribution chain in Library view

**Acceptance Criteria**:
- [ ] Fork button visible on Discover content detail view
- [ ] Fork creates accurate copy with `forkedFromID` set
- [ ] `forkCount` increments on original content
- [ ] Forked content appears in personal Library immediately
- [ ] User can edit forked content independently
- [ ] Attribution displays original creator profile

---

### Feature 2: Automatic Sync for Published Content Updates

**Objective**: Ensure published content updates sync automatically to backend, eliminating stale community content.

**Scope**: All published content edits (checklists, guides, decks) sync to backend within 5 seconds.

**User Workflow**:

1. User has published content in personal Library
2. User edits content (adds checklist items, updates guide text, etc.)
3. `updatedAt` timestamp updates locally
4. Sync system automatically queues a "publish_update" operation
5. Within 5 seconds, content syncs to backend
6. Sync status indicator shows brief "Syncing..." then "Synced" state
7. Community Discover tab shows updated content

**Technical Details**:
- Modify `LibraryModel` tracking to detect changes to published content (`publicID` present)
- When published content is edited:
  - Update `updatedAt` timestamp
  - Queue new "publish_update" sync operation
  - Include full content payload (like initial publish)
- Backend updates existing `publicID` record with new data and `updatedAt`
- Sync queue prioritizes "publish_update" operations (high priority)

**Sync Status Indicator**:
- Show brief visual feedback in Library row (optional: spinner icon)
- Indicates "Syncing..." state temporarily
- Returns to normal view when synced
- On sync failure: Shows error badge and manual retry option

**Success Criteria**:
- Updates sync within 5 seconds of local edit
- Backend content matches local content after sync
- No user confusion about what community sees
- Works offline (queues sync, completes when online)

**Acceptance Criteria**:
- [ ] Editing published content triggers sync operation
- [ ] Sync completes within 5 seconds when online
- [ ] Sync status visible to user (brief feedback)
- [ ] Backend content updates with latest edits
- [ ] Discover tab reflects updated content
- [ ] Works correctly in offline scenarios
- [ ] Sync failure shows retry option

---

### Feature 3: Deletion with Orphaned Content Recovery

**Objective**: Prevent orphaned public content while allowing users to recover accidentally deleted published content.

**Scope**: All content deletion scenarios with proper sync handling.

**User Workflow - Standard Deletion**:

1. User deletes content from personal Library (not published)
2. Confirmation dialog shows content will be deleted
3. Content removed from local database and sync queued
4. Standard deletion complete

**User Workflow - Deletion of Published Content**:

1. User attempts to delete published content from Library
2. System shows special confirmation dialog (modal):
   - "This content is published to the community."
   - Option A: "Unpublish & Delete" (removes from community + local)
   - Option B: "Keep Published" (local copy deleted, community copy remains)
   - Option C: "Cancel"
3. Option A: Queues "unpublish" sync operation before deletion
   - Backend removes public content
   - Local content deleted
   - Both sync operations complete
4. Option B: Queues "unpublish" sync operation
   - Backend keeps content public
   - Local copy deleted
   - User can fork their own content back from Discover tab later

**User Workflow - Recovery from Accidental Deletion**:

1. User realizes they accidentally deleted published content
2. User goes to Discover tab and finds their own content
3. Taps "Fork" to restore personal copy
4. Content back in personal Library with full history

**Technical Details**:
- Deletion shows different confirmation dialog based on `publicID` presence
- Published content deletion queues "unpublish" sync operation (prioritized)
- Unpublish operation removes `publicID` and `publishedAt` on backend
- Allow same user to fork their own content (no publicID conflicts)
- When user forks their own content: Preserve original creator attribution in metadata

**Backend Changes**:
- Accept "unpublish" operations as high priority
- `DELETE /content/{publicID}` endpoint removes public content
- Support self-forking: Allow `creator_id` to match fork source creator

**Success Criteria**:
- Zero orphaned public content after implementation
- Users can recover accidentally deleted published content
- Published content requires explicit unpublish action
- No data loss or inconsistency

**Acceptance Criteria**:
- [ ] Deletion shows different dialog for published vs. private content
- [ ] Published deletion queues unpublish sync operation
- [ ] Backend content removed on unpublish
- [ ] Users can fork their own deleted content back
- [ ] Self-fork preserves original creator attribution
- [ ] Sync operations complete in correct order
- [ ] No orphaned public content possible

---

### Feature 4: Attribution & Fork Chain Visualization

**Objective**: Give credit to original creators and show content evolution through fork chains.

**Scope**: All forked content displays in personal Library with visual attribution.

**User Workflow**:

1. User forks content from community library
2. In personal Library, forked item shows:
   - "Forked from: Creator Name" subtitle below title
   - Optional: Visual indicator (fork icon) alongside content type icon
3. User taps on attribution to view:
   - Original creator's profile
   - Original content in read-only mode
   - Fork chain (if any): Shows downstream versions

**Data Model Changes**:
- `LibraryModel` includes:
  - `forkedFromID`: ID of source content (null if original)
  - `originalCreatorID`: ID of original creator (populated on fork)
  - `originalCreatorName`: Display name of original creator
  - `forkChain`: Array of fork relationships (JSON) for visualization

**Fork Chain Structure** (example):
{
  "originalCreator": "Captain Maria",
  "originalCreatorID": "user-123",
  "forks": [
    {
      "level": 1,
      "forkedBy": "Alex",
      "userID": "user-456",
      "timestamp": "2025-12-15T10:30:00Z"
    },
    {
      "level": 2,
      "forkedBy": "Jamie",
      "userID": "user-789",
      "timestamp": "2025-12-20T14:22:00Z"
    }
  ]
}

**UI Components**:

**LibraryItemRow (Updated)**:
- Show "Forked from: Creator Name" subtitle if `forkedFromID` is set
- Display fork icon next to content type icon
- Tappable attribution for fork chain details

**ForkChainView (New)**:
- Show original creator at top with "Original" badge
- Hierarchical timeline of downstream forks
- Each fork shows creator name, avatar, timestamp
- Allow navigation to each version

**Discover Tab Content Detail (Updated)**:
- Show view count and fork count prominently
- If already forked by user: Show "You have a fork" with link to user's version

**Success Criteria**:
- Original creators get visible attribution
- Users understand content evolution
- Easy discovery of upstream content
- Encourages ethical content remixing

**Acceptance Criteria**:
- [ ] Forked content shows creator attribution in Library
- [ ] Attribution is tappable and navigates to source content
- [ ] Fork count visible in Discover view
- [ ] Fork chain visualization shows hierarchy
- [ ] Users can see who has forked their content
- [ ] Attribution persists through multi-level forks

---

### Feature 5: Enhanced Discover-to-Library Workflow

**Objective**: Reduce friction between discovering content and importing it into personal workflow.

**Scope**: Discover tab integration with fork, bookmark, and share actions.

**User Workflow**:

1. User browses Discover tab with segmented picker (Checklists, Guides, Decks, All)
2. Taps content to view details
3. Action buttons at bottom of detail view:
   - "Fork to Library" (primary action, blue)
   - "Share" (secondary action)
   - "Report" (tertiary action)
4. Taps "Fork to Library"
5. System shows brief "Added to Library" toast
6. Optional: "View in Library" button in toast to navigate back to Library tab

**Enhanced Discover Tab Features**:

**Content Filtering**:
- Segmented picker: All / Checklists / Guides / Decks
- Search bar to find content by title, creator, tags
- Optional: Advanced filters (popularity, recent, highly-forked)

**Content Sorting**:
- Default: Recent (newest published first)
- Popularity: By view count
- Community favorites: By fork count
- Creator rating: By contributor reputation (future feature)

**Content Cards (Enhanced)**:
- Title with creator attribution ("by Captain Maria")
- Description preview (2-3 lines)
- Content type badge (Checklist / Guide / Deck)
- View count and fork count
- Tags displayed
- "Fork" button directly on card (quick action)

**Success Criteria**:
- Users fork community content with <3 taps
- Discover-to-Library workflow feels natural
- No navigation friction between tabs

**Acceptance Criteria**:
- [ ] Fork button visible on content cards
- [ ] Tap fork creates copy in Library immediately
- [ ] Toast provides navigation back to Library
- [ ] Search works across content titles and creators
- [ ] Filtering by content type works
- [ ] View counts and fork counts display accurately

---

### Feature 6: Sync Status Management UI

**Objective**: Give users visibility into sync state and recovery options for failed operations.

**Scope**: All sync operations (publish, unpublish, publish_update) with error handling.

**User Workflow - Successful Sync**:

1. User publishes or updates content
2. Sync status indicator shows "Syncing..." briefly
3. Indicator confirms "Synced" with checkmark
4. Content now shows as published in Library

**User Workflow - Sync Failure**:

1. User publishes content while experiencing poor connectivity
2. Sync status shows error badge (red exclamation icon)
3. User taps error badge to see details:
   - "Failed to sync content"
   - Error message (connection timeout, server error, etc.)
   - "Retry" button
4. User taps "Retry"
5. System attempts sync again
6. On success: Status updates to "Synced"

**Sync Status Indicator (Library Row)**:

- **Synced** (default): Checkmark icon, green or neutral color
- **Syncing**: Spinner icon, blue color
- **Failed**: Exclamation icon, red color (tappable)
- **Pending**: Clock icon, gray color (queued)

**Technical Details**:

- Track sync state in `LibraryModel`: `syncState` field
- Possible values: `synced`, `syncing`, `pending`, `failed`
- On sync failure: Store error message for display
- Manual retry queues operation with high priority
- Exponential backoff for automatic retries (existing)
- Maximum 3 automatic retries, then user manual retry required

**Error Handling**:

| Error Type | Message | Recovery |
|---|---|---|
| Network timeout | "Connection timeout. Check your internet." | Automatic retry when online |
| Server error | "Server error. Please try again later." | Manual retry button |
| Authentication failed | "You've been signed out. Please log in again." | Redirect to login |
| Content validation | "Content format invalid. Please review." | User must edit content |

**Success Criteria**:
- Users aware of sync state in real-time
- Failed syncs recoverable without data loss
- Clear error messages guide user action

**Acceptance Criteria**:
- [ ] Sync status displays in Library row
- [ ] Status updates correctly during sync operations
- [ ] Failed syncs show error details
- [ ] Retry button available for failed operations
- [ ] Automatic retry works for transient errors
- [ ] Maximum retry attempts respected

---

## Implementation Roadmap

### Phase 1: Core Forking & Sync (Weeks 1-2)

**Dependencies**: Minimal; builds on existing architecture

**Deliverables**:
- Implement Feature 1: Seamless Content Forking
- Implement Feature 2: Automatic Sync for Published Content Updates
- Implement Feature 3: Deletion with Recovery
- Backend endpoints: Fork creation, publish_update, unpublish

**Technical Tasks**:
- Add `forkedFromID` and `originalCreatorName` to `LibraryModel`
- Implement fork operation in `LibraryRepository`
- Add "publish_update" sync operation type
- Modify deletion flow to show different dialogs
- Backend: Create fork endpoint, update publish endpoint
- Backend: Handle unpublish on deletion

**Testing**:
- Unit tests: Fork creation, sync operations
- Integration tests: End-to-end fork and sync workflows
- UI tests: Deletion dialogs, sync status indicators

### Phase 2: Attribution & Discovery (Weeks 3-4)

**Dependencies**: Phase 1 complete

**Deliverables**:
- Implement Feature 4: Attribution & Fork Chain Visualization
- Implement Feature 5: Enhanced Discover-to-Library Workflow
- Fork button in Discover tab

**Technical Tasks**:
- Build `ForkChainView` component
- Update `LibraryItemRow` to display attribution
- Add fork button to `DiscoverContentDetailView`
- Implement Discover tab search and filtering
- Backend: Return fork chain data with content queries

**Testing**:
- UI tests: Attribution displays correctly
- Integration tests: Fork chain queries
- Usability testing: Discover workflow

### Phase 3: Sync Management & Polish (Week 5)

**Dependencies**: Phases 1-2 complete

**Deliverables**:
- Implement Feature 6: Sync Status Management UI
- Error handling and recovery workflows
- Polish and optimization

**Technical Tasks**:
- Add sync status UI components
- Implement error display and retry logic
- Add exponential backoff for auto-retries
- Performance optimization for large content libraries

**Testing**:
- Error scenario testing: Network failures, server errors
- Retry logic verification
- Performance testing with large libraries

### Phase 4: Monitoring & Admin Tools (Week 6+)

**Scope**: Post-launch monitoring and admin features

**Deliverables**:
- Admin dashboard for orphaned content detection
- Content moderation tools
- Sync failure monitoring
- Analytics dashboard for community library usage

---

## Technical Considerations

### Backend API Changes

**New Endpoints**:

POST /content/fork
- Input: sourceContentID, sourceCreatorID
- Output: Forked LibraryModel with publicID
- Behavior: Creates copy, increments forkCount

PUT /content/{publicID}
- Input: Full content payload
- Output: Updated content
- Behavior: Updates existing published content
- Used for: Sync updates to already-published content

DELETE /content/{publicID}
- Input: publicID
- Output: Success confirmation
- Behavior: Removes public content, marks sync as complete

**Modified Endpoints**:

POST /content/publish
- May also be used for "publish_update" (new sync type)
- Backend logic determines insert vs. update based on publicID presence

### Data Model Changes

**LibraryModel** (SQLite):
ALTER TABLE library ADD COLUMN forkedFromID TEXT;
ALTER TABLE library ADD COLUMN originalCreatorID TEXT;
ALTER TABLE library ADD COLUMN originalCreatorName TEXT;
ALTER TABLE library ADD COLUMN forkCount INTEGER DEFAULT 0;
ALTER TABLE library ADD COLUMN syncState TEXT DEFAULT 'synced';
ALTER TABLE library ADD COLUMN syncError TEXT;

**Sync Queue**:
-- Add new operation type
-- publish_update (for updating existing public content)
-- Operations: publish, unpublish, publish_update

### Offline-First Considerations

- All fork operations work entirely offline
- Sync operations queue and complete when online
- Deletion with unpublish requires sync on next online state
- Conflict resolution: Last-write-wins for published content updates

### Performance Considerations

- Fork operation: <500ms (copy local data only)
- Sync batch operations when >5 queued operations
- Pagination in Discover tab (lazy load content)
- Cache fork counts and view counts in `LibraryModel`

---

## Success Metrics & KPIs

### Engagement Metrics

| Metric | Baseline | Target | Timeline |
|---|---|---|---|
| Fork rate (% of discovered content forked) | 0% | 15% | 4 weeks |
| Discover tab visits | TBD | +30% | 4 weeks |
| Content creation rate | TBD | +20% | 8 weeks |
| User retention | TBD | +10% | 8 weeks |

### Quality Metrics

| Metric | Target | Timeline |
|---|---|---|
| Orphaned content count | 0 | Week 2 (post-launch) |
| Sync success rate | >99% | Week 2 |
| Average fork chain depth | >1.5 | 8 weeks |
| Content updates per published item | >1 | 4 weeks |

### User Experience Metrics

| Metric | Target |
|---|---|
| Fork completion rate (started → completed) | >90% |
| Sync failure recovery rate | >95% |
| User satisfaction (NPS) | >50 |
| Discover-to-Library conversion | >25% |

---

## Risks & Mitigations

### Risk 1: Sync Complexity

**Risk**: Managing multiple sync operation types and states could introduce bugs or data inconsistency.

**Mitigation**:
- Comprehensive unit and integration tests for all sync flows
- Staging environment testing before production launch
- Exponential backoff to prevent cascading failures
- Sync state validation on every operation

### Risk 2: Fork Chain Data Explosion

**Risk**: Deeply nested fork chains could grow exponentially, impacting performance and UI.

**Mitigation**:
- Limit fork chain depth display to 5 levels in UI (show "...and X more forks")
- Lazy-load fork chain details on demand
- Implement periodic cleanup of orphaned fork references

### Risk 3: User Confusion on Forking Own Content

**Risk**: Users might not understand that forking their own deleted content recreates it.

**Mitigation**:
- Clear messaging in deletion dialog explaining recovery option
- In-app guidance when user forks their own content
- Docs/help articles explaining fork recovery workflow

### Risk 4: Attribution Accuracy

**Risk**: Fork metadata could become incorrect if data is corrupted or sync fails.

**Mitigation**:
- Validate `originalCreatorID` and `originalCreatorName` on fork creation
- Sync priority ensures attribution syncs before other content
- Regular data integrity checks in backend

### Risk 5: Backend Load from Publish Updates

**Risk**: Syncing content updates to backend could create excessive database writes.

**Mitigation**:
- Batch publish_update operations (max 5 per sync cycle)
- Use database indexing on `publicID` for fast updates
- Monitor backend performance during initial rollout
- Rate limit publish_update operations per user if needed

---

## Open Questions & Future Scope

### Questions for Stakeholder Review

1. **Self-Forking**: Should users be able to fork their own deleted content, or should deletion of published content show a "Keep Published" option?
   - *Current Recommendation*: Support both workflows

2. **Fork Notifications**: Should original creators be notified when their content is forked?
   - *Potential Future Feature*: Fork notifications + reputation system

3. **Content Versioning**: Should publish_update create explicit versions, or just update in-place?
   - *Current Recommendation*: Update in-place (simpler) with version history in future

4. **Fork Ownership**: If user A forks user B's content and publishes, who owns the forked content?
   - *Current Recommendation*: User A owns fork, attribution shows user B

5. **Content Takedown**: Should authors be able to DMCA their own forked content from other users' libraries?
   - *Future Scope*: Content rights management system

### Future Features (Not In This PRD)

- **Contributor Reputation**: Rating system for content creators based on fork count, up / downvotes
- **Sync Notifications**: Notify users when their forked content is updated upstream
- **Content Moderation**: Admin tools to flag, review, and remove problematic content
- **Advanced Search**: Elasticsearch or similar for full-text search across all community content
- **Flashcard Deck Implementation**: Full feature completion (currently placeholder)
- **Content Export/Import**: Download content as files, import from external sources

---

## Appendix: User Stories

### Story 1: Fork and Customize

**As a** newer sailor exploring community content  
**I want to** fork a detailed pre-race checklist and customize it for my specific boat  
**So that** I can use proven content as a starting point without starting from scratch

**Acceptance Criteria**:
- [ ] I can see "Fork" button on content in Discover tab
- [ ] Forked content appears in my Library immediately
- [ ] I can edit forked content without affecting the original
- [ ] Original creator name is displayed in my Library

---

### Story 2: Publish and Update

**As a** content creator who published a guide  
**I want to** make edits to my published guide and have them appear automatically in the community  
**So that** my content stays accurate and helpful as I learn more

**Acceptance Criteria**:
- [ ] Editing published content shows sync indicator
- [ ] Community sees my updates within 5 seconds
- [ ] I get feedback when sync completes
- [ ] If sync fails, I can manually retry

---

### Story 3: Accidental Deletion Recovery

**As a** content creator who accidentally deleted local copy of published content  
**I want to** recover my content by forking it from the community library  
**So that** I don't lose my work permanently

**Acceptance Criteria**:
- [ ] I can see my own published content in Discover tab
- [ ] I can fork my own content back to my Library
- [ ] Forked copy has full content with no data loss
- [ ] Original community copy is unaffected

---

### Story 4: Track Content Evolution

**As a** original content creator  
**I want to** see downstream forks of my content and understand how others are using it  
**So that** I can learn from community variations and feel appreciated for my contribution

**Acceptance Criteria**:
- [ ] Content details show fork count prominently
- [ ] I can view fork chain showing who has forked my content
- [ ] I can navigate to downstream fork versions
- [ ] I see attribution when my content is forked
