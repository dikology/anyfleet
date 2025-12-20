# Quick Start: Content Sharing Implementation

**For the full detailed guide, see:** [content_sharing_implementation_guide.md](./content_sharing_implementation_guide.md)

---

## TL;DR

You need to implement:
1. **Backend API** for content sharing (NEW - not implemented)
2. **iOS sync queue** to reliably sync changes (NEW - not implemented)
3. **iOS API client** to call backend (NEW - not implemented)

**Current State:** ✅ Local publish/unpublish works, but nothing syncs to backend yet.

---

## Critical Issues Found

### 1. Documentation Inconsistencies

❌ **Problem:** Multiple docs describe slightly different architectures
- `sync_service_implementation.md` describes a detailed sync queue
- `PRD.md` mentions simpler API calls
- `implementation_checklist.md` has some items marked done that aren't

✅ **Solution:** Follow the comprehensive guide which consolidates all approaches

### 2. Missing Backend Implementation

❌ **Problem:** Backend has ZERO content sharing endpoints
- No `/api/v1/content/share` endpoint
- No `shared_content` database table
- Only auth endpoints exist

✅ **Solution:** Implement backend first (Week 1) before iOS sync service

### 3. iOS Sync Queue Not Implemented

❌ **Problem:** iOS app has no sync queue
- No `sync_queue` database table
- No `ContentSyncService`
- `VisibilityService` just saves locally

✅ **Solution:** Add sync queue in migration `v1.6.0` and create `ContentSyncService`

---

## 3-Week Implementation Plan

### Week 1: Backend + iOS Foundation

**Backend (Days 1-2):**
1. Create `shared_content` table migration
2. Create content models & schemas
3. Create `/api/v1/content/share` and `/api/v1/content/:id` endpoints
4. Test with curl

**iOS (Days 3-5):**
1. Add `sync_queue` table migration
2. Create `SyncQueueRecord` and repository methods
3. Update `VisibilityService` to enqueue operations
4. Test: Publish → verify sync_queue has entry

### Week 2: API Integration

**iOS (Days 1-3):**
1. Create `APIClient` with auth
2. Create `ContentSyncService` with full sync logic
3. Add background sync timer
4. Update `AppDependencies`

**Testing (Days 4-5):**
1. End-to-end tests
2. Offline scenarios
3. Error handling
4. Retry logic

### Week 3: Deployment

1. Backend to production
2. iOS TestFlight (internal)
3. Beta testing
4. App Store submission

---

## Quick File Reference

### New iOS Files to Create

```
anyfleet/anyfleet/anyfleet/
├── Data/Local/Records/
│   └── SyncQueueRecord.swift          ⬅ NEW
├── Services/
│   ├── ContentSyncService.swift       ⬅ NEW
│   └── APIClient.swift                ⬅ NEW
```

### iOS Files to Modify

```
anyfleet/anyfleet/anyfleet/
├── Data/
│   ├── Local/AppDatabase.swift        ⬅ Add migration v1.6.0
│   └── Repositories/LocalRepository.swift  ⬅ Add sync queue methods
├── Services/
│   └── VisibilityService.swift        ⬅ Add enqueue calls
└── App/
    ├── AppDependencies.swift          ⬅ Add APIClient & ContentSyncService
    └── AppModel.swift                 ⬅ Add background sync timer
```

### New Backend Files to Create

```
anyfleet-backend/
├── app/
│   ├── models/
│   │   └── content.py                 ⬅ NEW
│   ├── schemas/
│   │   └── content.py                 ⬅ NEW
│   └── api/v1/
│       └── content.py                 ⬅ NEW
└── alembic/versions/
    └── 2025_12_21_0900-create_shared_content_table.py  ⬅ NEW
```

### Backend Files to Modify

```
anyfleet-backend/app/
├── models/
│   └── user.py                        ⬅ Add shared_content relationship
└── api/v1/
    └── __init__.py                    ⬅ Register content router
```

---

## Critical Code Snippets

### 1. iOS Sync Queue Migration

```swift
// In AppDatabase.swift
migrator.registerMigration("v1.6.0_createSyncQueueTable") { db in
    try db.create(table: "sync_queue") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("content_id", .text).notNull()
        t.column("operation", .text).notNull()  // "publish" or "unpublish"
        t.column("visibility_state", .text).notNull()
        t.column("payload", .text)  // JSON
        t.column("created_at", .datetime).notNull()
        t.column("retry_count", .integer).notNull().defaults(to: 0)
        t.column("last_error", .text)
        t.column("synced_at", .datetime)
        
        t.foreignKey(["content_id"], references: "library_content", onDelete: .cascade)
    }
    
    try db.execute(sql: """
        CREATE INDEX idx_sync_queue_pending 
        ON sync_queue(created_at) 
        WHERE synced_at IS NULL
    """)
}
```

### 2. iOS VisibilityService Update

```swift
// Add dependency
private let syncService: ContentSyncService

// In publishContent():
try await libraryStore.updateLibraryMetadata(updated)

// ⬅ NEW: Enqueue for sync
let payload = try encodeContentForSync(updated)
try await syncService.enqueuePublish(
    contentID: updated.id,
    visibility: .public,
    payload: payload
)
```

### 3. Backend Endpoint

```python
@router.post("/share", response_model=PublishContentResponse)
async def publish_content(
    content: PublishContentRequest,
    current_user: CurrentUser,
    db: AsyncSession,
):
    # Check duplicate public_id
    existing = await db.execute(
        select(SharedContent).where(SharedContent.public_id == content.public_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(409, "Duplicate public_id")
    
    # Create shared content
    shared = SharedContent(
        user_id=current_user.id,
        title=content.title,
        content_type=content.content_type,
        content_data=content.content_data,
        public_id=content.public_id,
        # ... other fields
    )
    
    db.add(shared)
    await db.commit()
    
    return PublishContentResponse(...)
```

---

## Testing Checklist

### Backend Tests
- [ ] POST /content/share returns 201
- [ ] Duplicate public_id returns 409
- [ ] Unauthorized returns 401
- [ ] DELETE /content/:id soft deletes
- [ ] Can't delete others' content (403)
- [ ] GET /content/public returns list
- [ ] GET /content/:id increments view_count

### iOS Tests
- [ ] Enqueue publish adds to sync_queue
- [ ] Sync processes queue items
- [ ] Network error triggers retry
- [ ] Max retries marks as failed
- [ ] Terminal error (409) doesn't retry
- [ ] Background timer triggers sync
- [ ] Offline → online syncs automatically

### Integration Tests
- [ ] Publish flow: UI → DB → Queue → API → Backend
- [ ] Unpublish flow works
- [ ] Token refresh during sync works
- [ ] Conflicting operations handled

---

## Common Pitfalls

### ❌ DON'T: Try to implement iOS sync service before backend
**Why:** You'll have nowhere to sync to, can't test properly

### ❌ DON'T: Skip the sync queue and call API directly from VisibilityService
**Why:** Network failures will block the UI and you'll lose operations

### ❌ DON'T: Use the same `syncStatus` for both queue state and network state
**Why:** Confuses "pending in queue" vs "syncing to network" vs "synced"

### ❌ DON'T: Retry all errors indefinitely
**Why:** Validation errors (400, 409) will never succeed, waste resources

### ✅ DO: Implement backend first, test with curl
### ✅ DO: Test iOS sync queue locally before adding API calls
### ✅ DO: Classify errors as retryable vs terminal
### ✅ DO: Add comprehensive logging and monitoring

---

## Key Decisions Made

### 1. Offline-First Architecture
- ✅ Users can publish/unpublish offline
- ✅ Changes sync in background
- ✅ UI never blocks on network

### 2. Exponential Backoff with Max Retries
- ✅ Retry network errors up to 3 times
- ✅ Don't retry validation/auth errors
- ✅ Show failed state after 3 attempts

### 3. FIFO Queue Processing
- ✅ Process operations in order they were created
- ✅ One operation at a time (no parallel syncing)
- ✅ Prevents race conditions

### 4. Soft Delete for Unpublish
- ✅ Backend soft-deletes (sets `deleted_at`)
- ✅ Can potentially restore later
- ✅ Keeps analytics history

---

## Environment Setup

### Backend Local Dev

```bash
cd anyfleet-backend

# Create .env
cat > .env << EOF
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/anyfleet_db
JWT_SECRET_KEY=your-dev-secret
APPLE_CLIENT_ID=com.yourcompany.anyfleet
EOF

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

### iOS Local Dev

1. Point to local backend:
   ```swift
   // In APIClient.swift
   #if DEBUG
   self.baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
   #endif
   ```

2. Sign in with test account
3. Publish content
4. Check backend logs

---

## Success Metrics

- **Sync Success Rate:** > 95%
- **Average Sync Latency:** < 2 seconds
- **Failed Syncs Retry Success:** > 90%
- **Zero Data Loss:** 100% (all operations queued locally first)

---

## Next Steps

1. **Read the full guide:** [content_sharing_implementation_guide.md](./content_sharing_implementation_guide.md)
2. **Start with backend:** Follow Phase 1 in the guide
3. **Test backend with curl:** Verify endpoints work
4. **Implement iOS sync queue:** Follow Phase 2
5. **Connect iOS to backend:** Follow Phase 3
6. **Test end-to-end:** Follow Phase 4

---

## Questions?

Common questions answered in the full guide:
- How to handle token refresh during sync?
- What if the same content is published twice?
- How to show sync status in UI?
- How to manually retry failed syncs?
- How to clear the sync queue?

See the full guide for detailed answers and code examples.

