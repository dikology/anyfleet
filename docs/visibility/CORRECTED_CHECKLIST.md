# Corrected Implementation Checklist

**Based on:** [content_sharing_implementation_guide.md](./content_sharing_implementation_guide.md)  
**Replaces:** Old implementation_checklist.md sections that are outdated

---

## What's Already Done ✅

### Phase 1-2: Foundation & UI (COMPLETE)
- ✅ LibraryModel with visibility & syncStatus fields
- ✅ ContentVisibility enum (private, unlisted, public)
- ✅ ContentSyncStatus enum (pending, queued, synced, failed)
- ✅ PublicMetadata struct
- ✅ VisibilityService (local publish/unpublish)
- ✅ AuthService with Apple Sign In
- ✅ AuthStateObserver
- ✅ VisibilityBadge component
- ✅ PublishConfirmationModal component
- ✅ PublishActionView component
- ✅ SignInModalView component
- ✅ LibraryItemRow with visibility UI
- ✅ LibraryListView integration
- ✅ Database schema v1.5.0 (visibility fields)

### What Works Now:
- Users can publish/unpublish locally
- UI shows visibility badges
- Confirmation modals work
- Sign-in flow works
- Auth state properly tracked

### What Doesn't Work Yet:
- ❌ Nothing syncs to backend
- ❌ Published content not shared with others
- ❌ No retry logic for failures

---

## What You Need to Implement ⚡

### Week 1: Backend API (Priority 1)

#### Backend - Database
- [ ] Create `shared_content` table
  - [ ] Migration file `2025_12_21_0900-create_shared_content_table.py`
  - [ ] Run `alembic upgrade head`
  - [ ] Verify table exists in PostgreSQL

#### Backend - Models & Schemas
- [ ] Create `app/models/content.py`
  - [ ] SharedContent model with all fields
  - [ ] Relationship to User model
- [ ] Create `app/schemas/content.py`
  - [ ] PublishContentRequest
  - [ ] PublishContentResponse
  - [ ] SharedContentSummary
  - [ ] SharedContentDetail
- [ ] Update `app/models/user.py`
  - [ ] Add `shared_content` relationship

#### Backend - API Endpoints
- [ ] Create `app/api/v1/content.py`
  - [ ] POST `/content/share` - publish content
  - [ ] DELETE `/content/:public_id` - unpublish content
  - [ ] GET `/content/public` - list public content (optional for now)
  - [ ] GET `/content/:public_id` - get single content (optional for now)
- [ ] Update `app/api/v1/__init__.py`
  - [ ] Register content router

#### Backend - Testing
- [ ] Test POST `/content/share` with curl
- [ ] Test duplicate public_id returns 409
- [ ] Test DELETE `/content/:public_id` works
- [ ] Test unauthorized returns 401
- [ ] Verify data in database

---

### Week 1-2: iOS Sync Infrastructure (Priority 2)

#### iOS - Database Migration
- [ ] Add migration `v1.6.0_createSyncQueueTable` to `AppDatabase.swift`
  - [ ] `sync_queue` table with all columns
  - [ ] Indexes for performance
  - [ ] Foreign key to library_content
- [ ] Delete app and reinstall to test migration
- [ ] Verify sync_queue table exists (use DB browser)

#### iOS - Sync Queue Records
- [ ] Create `Data/Local/Records/SyncQueueRecord.swift`
  - [ ] FetchableRecord + PersistableRecord
  - [ ] Static methods: enqueue, fetchPending, markSynced, incrementRetry
- [ ] Update `Data/Repositories/LocalRepository.swift`
  - [ ] Add sync queue methods (5 new methods)
- [ ] Write unit tests for sync queue operations

#### iOS - API Client
- [ ] Create `Services/APIClient.swift`
  - [ ] Auth integration (auto token refresh)
  - [ ] POST publish endpoint
  - [ ] DELETE unpublish endpoint
  - [ ] Error handling (APIError enum)
  - [ ] Request/response types
- [ ] Write unit tests for APIClient

#### iOS - Content Sync Service
- [ ] Create `Services/ContentSyncService.swift`
  - [ ] enqueuePublish() method
  - [ ] enqueueUnpublish() method
  - [ ] syncPending() method (main sync loop)
  - [ ] processOperation() method
  - [ ] handlePublish() method
  - [ ] handleUnpublish() method
  - [ ] Retry logic with exponential backoff
  - [ ] Error classification (retryable vs terminal)
  - [ ] State tracking (isSyncing, pendingCount, failedCount)
- [ ] Write unit tests for ContentSyncService

#### iOS - Service Integration
- [ ] Update `Services/VisibilityService.swift`
  - [ ] Add syncService dependency
  - [ ] Call syncService.enqueuePublish() after local save
  - [ ] Call syncService.enqueueUnpublish() after local save
  - [ ] Add encodeContentForSync() helper method
- [ ] Update `App/AppDependencies.swift`
  - [ ] Add apiClient property
  - [ ] Add contentSyncService property
  - [ ] Wire up dependencies
- [ ] Add background sync timer to `App/AppModel.swift`
  - [ ] Timer triggers syncPending() every 10s
  - [ ] Trigger on app becomes active

#### iOS - UI Integration
- [ ] Create `Features/Library/SyncStatusIndicator.swift`
  - [ ] Icons for pending, syncing, synced, failed
  - [ ] Tooltips/help text
- [ ] Update `LibraryItemRow` to show sync status
  - [ ] Display indicator next to visibility badge
  - [ ] Only show for non-private items
  - [ ] Tap to retry on failed items (optional)

---

### Week 2: Testing & Polish (Priority 3)

#### Integration Tests
- [ ] End-to-end publish flow
  - [ ] Create content → publish → verify in sync_queue
  - [ ] Sync processes → verify backend receives
  - [ ] Backend responds → verify status = synced
- [ ] End-to-end unpublish flow
- [ ] Offline publish → come online → syncs
- [ ] Network error → retries → succeeds
- [ ] Max retries → marks as failed
- [ ] Token refresh during sync

#### Edge Cases
- [ ] Duplicate public_id → 409 → marked failed
- [ ] Backend returns 500 → retries
- [ ] Network timeout → retries
- [ ] Unpublish non-existent → 404 → marked failed
- [ ] User deletes content with pending sync → cascade delete
- [ ] App backgrounds during sync → pauses/resumes

#### Backend Tests
- [ ] Write `tests/test_content.py`
  - [ ] test_publish_content_success
  - [ ] test_publish_duplicate_public_id
  - [ ] test_unpublish_content_success
  - [ ] test_unpublish_not_owner_forbidden
  - [ ] test_list_public_content
  - [ ] test_get_content_by_public_id

---

### Week 3: Deployment (Priority 4)

#### Backend Deployment
- [ ] Deploy migration to production
- [ ] Verify table created
- [ ] Deploy new endpoints
- [ ] Test with curl in production
- [ ] Monitor logs for errors

#### iOS Deployment
- [ ] TestFlight internal build
- [ ] Test with 5-10 internal users
- [ ] Monitor crash reports
- [ ] Fix any critical bugs
- [ ] TestFlight beta build
- [ ] Test with 50-100 beta users
- [ ] Monitor sync success rate
- [ ] App Store submission

#### Monitoring
- [ ] Backend metrics (Prometheus)
  - [ ] content_published_total counter
  - [ ] sync_request_duration_seconds histogram
- [ ] iOS analytics
  - [ ] content_published event
  - [ ] sync_completed event
  - [ ] sync_failed event
- [ ] Dashboard showing:
  - [ ] Sync success rate
  - [ ] Average sync latency
  - [ ] Failed sync count
  - [ ] Retry success rate

---

## Items NOT Needed (From Old Checklist)

These were proposed in the old checklist but we're NOT implementing them:

### ❌ NOT Creating These iOS Tables:
- ~~`public_content` table~~ → Use backend's `shared_content` instead
- ~~`visibility_changes` table~~ → Replaced by `sync_queue`

### ❌ NOT Creating These iOS Records:
- ~~`PublicContentRecord`~~ → Not needed
- ~~`VisibilityChangeRecord`~~ → Using `SyncQueueRecord` instead

### ❌ NOT Adding These Columns:
- ~~`author_id` to library_content~~ → Already have `creatorID`
- ~~`visibility_state`~~ → Already have `visibility`
- ~~`sync_state`~~ → Already have `syncStatus`
- ~~`can_fork` column~~ → Store in `publicMetadata` JSON

### ❌ NOT Creating These Repository Methods:
- ~~`getPendingVisibilityChanges()`~~ → Using `getPendingSyncOperations()` instead
- ~~`markVisibilityChangeAsSynced()`~~ → Using `markSyncOperationComplete()` instead

**Reason:** The old checklist proposed a different architecture that's more complex and redundant. My guide consolidates this into a cleaner approach.

---

## Quick Reference: What's Different

| Old Checklist | New Guide | Status |
|--------------|-----------|--------|
| Create public_content table | Use backend shared_content | ✅ Better approach |
| Create visibility_changes table | Create sync_queue table | ✅ Clearer naming |
| PublicContentRecord | - | ❌ Not needed |
| VisibilityChangeRecord | SyncQueueRecord | ✅ Renamed |
| Update LibraryModelRecord columns | Already done in v1.5.0 | ✅ Complete |
| Create SignInModalView | Already exists | ✅ Complete |
| Auth integration | Already done | ✅ Complete |

---

## Success Criteria

When you're done, this should work:

1. ✅ User publishes content offline → goes to sync_queue
2. ✅ App comes online → background sync starts
3. ✅ Backend receives content → stores in shared_content
4. ✅ iOS receives response → marks as synced
5. ✅ UI shows "synced" badge
6. ✅ Network error → retries up to 3 times
7. ✅ Max retries → shows "failed" badge
8. ✅ Sync success rate > 95%
9. ✅ Zero data loss

---

## Time Estimate

- Week 1: Backend (2 days) + iOS infrastructure (3 days)
- Week 2: API client (2 days) + Testing (3 days)
- Week 3: Deployment (5 days)

**Total: 15 working days / 3 weeks**

---

## Questions?

See the main guide: [content_sharing_implementation_guide.md](./content_sharing_implementation_guide.md)

Or the quick start: [QUICK_START_CONTENT_SHARING.md](./QUICK_START_CONTENT_SHARING.md)

