# Sync Service Refactoring - Implementation Checklist

**Status:** Ready to Implement  
**Created:** December 24, 2024  
**Est. Time:** 2-3 days

---

## Overview

This checklist consolidates the refactoring guides into actionable tasks. Follow in order for safest implementation.

**Related Documents:**
- [iOS Refactoring Guide](./sync_service_refactoring_guide.md) - Detailed iOS changes
- [Backend Refactoring Guide](../../anyfleet-backend/docs/sync_api_refactoring_guide.md) - Backend API changes

---

## Pre-Implementation (30 minutes)

### Backup & Safety
- [ ] Commit all current changes
- [ ] Create feature branch: `git checkout -b fix/sync-service-refactoring`
- [ ] Export published content from database (if any)
- [ ] Document current behavior (screenshots/logs)

### Environment Setup
- [ ] Backend server running locally (port 8000)
- [ ] iOS simulator running
- [ ] Database accessible
- [ ] Test user authenticated

---

## Day 1: Critical Fixes (4-5 hours)

### Part 1: Create New Payload Models (1 hour)

#### iOS: Create SyncPayloads.swift
- [ ] Create file: `anyfleet/anyfleet/anyfleet/Core/Models/SyncPayloads.swift`
- [ ] Copy payload structs from refactoring guide:
  - [ ] `ContentPublishPayload`
  - [ ] `UnpublishPayload`
  - [ ] Helper extensions
- [ ] Build project, fix any import errors
- [ ] Verify no compilation errors

**Test:**
```swift
// Quick sanity test in a test file
let payload = ContentPublishPayload(
    title: "Test",
    description: nil,
    contentType: "checklist",
    contentDataJSON: "{}",
    tags: [],
    language: "en",
    publicID: "test-123"
)
let data = try JSONEncoder().encode(payload)
let decoded = try JSONDecoder().decode(ContentPublishPayload.self, from: data)
assert(decoded.publicID == "test-123")
```

### Part 2: Fix VisibilityService (1 hour)

#### Update VisibilityService.swift
- [ ] Import `SyncPayloads`
- [ ] Replace `encodeContentForSync()` method
- [ ] Update `unpublishContent()` to capture publicID before clearing
- [ ] Remove old `ContentPublishPayload` struct
- [ ] Remove `encodeChecklist()` and `encodeGuide()` helpers
- [ ] Build and fix any errors

**Test:**
- [ ] Create a checklist
- [ ] Try to publish it
- [ ] Check logs for "Publishing content" message
- [ ] Verify no crash

### Part 3: Fix ContentSyncService (1.5 hours)

#### Update ContentSyncService.swift
- [ ] Import `SyncPayloads`
- [ ] Update `enqueueUnpublish()` signature to accept publicID
- [ ] Create `UnpublishPayload` in enqueue method
- [ ] Update `handlePublish()`:
  - [ ] Remove `convertFromSnakeCase` decoder strategy
  - [ ] Update to use `contentDataJSON`
  - [ ] Add better error logging
- [ ] Update `handleUnpublish()`:
  - [ ] Decode `UnpublishPayload` from operation.payload
  - [ ] Use publicID from payload
- [ ] Add `contentNotFound` error case
- [ ] Build and fix any errors

**Test:**
- [ ] Run app
- [ ] Publish content
- [ ] Check sync_queue table for payload format
- [ ] Verify payload has proper snake_case keys

### Part 4: Fix APIClient (1 hour)

#### Update APIClient.swift
- [ ] Update `publishContent()` signature to accept `contentDataJSON: String`
- [ ] Update `PublishContentRequest` struct:
  - [ ] Change `contentData` to `contentDataJSON: String`
  - [ ] Remove custom `encode(to:)` method (use default Codable)
  - [ ] Verify CodingKeys are correct
- [ ] Remove `AnyCodable` struct entirely
- [ ] Build and fix any errors

**Test:**
- [ ] Create test request payload
- [ ] Encode it
- [ ] Print JSON to console
- [ ] Verify format matches backend expectations

### Part 5: Test End-to-End (30 minutes)

#### Manual Test Flow
- [ ] Delete app from simulator
- [ ] Clean build folder
- [ ] Install fresh app
- [ ] Sign in
- [ ] Create new checklist with some items
- [ ] Publish checklist
- [ ] Watch logs - should see:
  ```
  Publishing content: <uuid>, publicID: <slug>
  Enqueuing publish operation
  Processing 1 sync operations
  Sync succeeded for content: <uuid>
  ```
- [ ] Verify in database:
  ```sql
  SELECT id, public_id, title, content_type FROM shared_content ORDER BY created_at DESC LIMIT 1;
  ```
- [ ] Unpublish content
- [ ] Watch logs - should see:
  ```
  Unpublishing content: <uuid>
  Enqueuing unpublish operation
  Processing 1 sync operations
  Sync succeeded for content: <uuid>
  ```
- [ ] Verify deleted in database:
  ```sql
  SELECT deleted_at FROM shared_content WHERE public_id = '<your_slug>';
  ```

**Expected Results:**
- ✅ Publish succeeds
- ✅ Unpublish succeeds
- ✅ No "keyNotFound" errors
- ✅ No "missingPublicID" errors
- ✅ API returns 201
- ✅ UI shows "Public" badge

**If tests fail:** Check logs, compare with expected format, debug payload encoding.

---

## Day 2: Backend Updates & Testing (3-4 hours)

### Part 1: Update Backend Schemas (1 hour)

#### Update app/schemas/content.py
- [ ] Add imports: `json`, `logging`
- [ ] Update `PublishContentRequest`:
  - [ ] Add `field_validator` for `content_data`
  - [ ] Add `model_validator` for structure validation
  - [ ] Add validation methods: `_validate_checklist_structure()`, etc.
- [ ] Add `ContentErrorDetail` schema
- [ ] Run backend tests: `pytest tests/`
- [ ] Fix any errors

**Test:**
```bash
# Test that schema accepts both formats
python -c "
from app.schemas.content import PublishContentRequest
import json

# Test with dict
r1 = PublishContentRequest(
    title='Test',
    content_type='checklist',
    content_data={'id': '123', 'title': 'Test', 'sections': []},
    tags=[],
    language='en',
    public_id='test-1'
)
print('Dict format: OK')

# Test with JSON string
r2 = PublishContentRequest(
    title='Test',
    content_type='checklist',
    content_data=json.dumps({'id': '123', 'title': 'Test', 'sections': []}),
    tags=[],
    language='en',
    public_id='test-2'
)
print('String format: OK')
"
```

### Part 2: Update Backend Endpoints (1 hour)

#### Update app/api/v1/content.py
- [ ] Add detailed error responses
- [ ] Update `publish_content()` endpoint
- [ ] Update `unpublish_content()` endpoint
- [ ] Add better logging
- [ ] Restart backend server
- [ ] Check logs for startup errors

**Test with curl:**
```bash
# Get auth token first
TOKEN="your_token_here"

# Test publish with JSON string (as iOS sends)
curl -X POST http://localhost:8000/api/v1/content/share \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Checklist",
    "content_type": "checklist",
    "content_data": "{\"id\":\"test-123\",\"title\":\"Test\",\"sections\":[]}",
    "tags": ["test"],
    "language": "en",
    "public_id": "test-curl-123",
    "can_fork": true
  }' | jq

# Should return 201 with response
```

### Part 3: Backend Testing (1.5 hours)

#### Create test files
- [ ] Create `tests/test_content_payloads.py`
- [ ] Copy tests from refactoring guide
- [ ] Create `tests/test_content_validation.py`
- [ ] Copy validation tests from guide
- [ ] Run tests: `pytest tests/test_content*.py -v`
- [ ] Fix any failures

**Expected:** All tests pass

### Part 4: Integration Testing (30 minutes)

#### iOS -> Backend Flow
- [ ] Start backend server
- [ ] Start iOS simulator
- [ ] Sign in to iOS app
- [ ] Create new checklist
- [ ] Publish from iOS
- [ ] Check backend logs:
  ```
  INFO: Publish content request from user: <uuid>, type: checklist, public_id: <slug>
  INFO: Content published successfully: <id>, public_id: <slug>
  ```
- [ ] Query database:
  ```sql
  SELECT 
    public_id,
    title,
    content_type,
    jsonb_pretty(content_data::jsonb) as content
  FROM shared_content
  WHERE deleted_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;
  ```
- [ ] Verify content_data is properly stored as JSONB
- [ ] Unpublish from iOS
- [ ] Verify soft deleted in database

**Expected:**
- ✅ Backend receives request
- ✅ Content stored correctly
- ✅ iOS shows success
- ✅ Unpublish works

---

## Day 3: Comprehensive Testing & Polish (2-3 hours)

### Part 1: Unit Tests (1.5 hours)

#### iOS Unit Tests
- [ ] Create `anyfleetTests/Services/ContentSyncPayloadTests.swift`
- [ ] Copy tests from refactoring guide
- [ ] Run tests: `Cmd+U`
- [ ] All tests should pass

#### iOS Integration Tests
- [ ] Create `anyfleetTests/Integration/ContentSyncIntegrationTests.swift`
- [ ] Copy tests from guide
- [ ] Run tests: `Cmd+U`
- [ ] Fix any failures

### Part 2: Edge Case Testing (1 hour)

#### Test Scenarios
- [ ] **Offline Publish:**
  - [ ] Turn off network
  - [ ] Publish content
  - [ ] Verify queued
  - [ ] Turn on network
  - [ ] Verify syncs
  
- [ ] **Large Content:**
  - [ ] Create checklist with 50+ items
  - [ ] Publish
  - [ ] Verify succeeds
  
- [ ] **Concurrent Operations:**
  - [ ] Publish multiple items quickly
  - [ ] Verify all sync
  
- [ ] **Retry Logic:**
  - [ ] Stop backend server
  - [ ] Try to publish
  - [ ] Verify retry attempts
  - [ ] Start backend
  - [ ] Verify eventual success
  
- [ ] **Duplicate publicID:**
  - [ ] Force duplicate public_id
  - [ ] Verify 409 error
  - [ ] Verify marked as failed

### Part 3: Performance Testing (30 minutes)

#### Metrics to Check
- [ ] Measure publish latency (should be < 2 seconds)
- [ ] Measure unpublish latency
- [ ] Check sync queue processing speed
- [ ] Monitor memory usage during sync
- [ ] Check database query performance

**Tools:**
- Xcode Instruments
- Backend timing logs
- Database EXPLAIN queries

---

## Production Deployment (30 minutes)

### Pre-Deploy
- [ ] All tests passing
- [ ] No linter errors
- [ ] Code reviewed
- [ ] Changelog updated

### Deploy Backend
- [ ] Merge to main branch
- [ ] Deploy to production server
- [ ] Run migrations (if any)
- [ ] Verify health endpoint
- [ ] Check logs for startup errors

### Deploy iOS
- [ ] Archive app
- [ ] Upload to TestFlight
- [ ] Add release notes
- [ ] Deploy to internal testers
- [ ] Monitor crash reports
- [ ] After 24h, deploy to beta testers

### Post-Deploy Monitoring
- [ ] Monitor error rates
- [ ] Check sync success rate
- [ ] Review user feedback
- [ ] Monitor performance metrics

---

## Rollback Plan

### If iOS issues detected:
1. Revert to previous TestFlight build
2. Investigate logs
3. Fix issues in development
4. Re-test thoroughly
5. Re-deploy

### If Backend issues detected:
1. Roll back to previous version
2. Check database state
3. Fix issues locally
4. Re-test with curl
5. Re-deploy

---

## Success Criteria

### Technical
- ✅ All unit tests pass
- ✅ All integration tests pass
- ✅ Sync success rate > 99%
- ✅ Average sync latency < 2s
- ✅ Zero payload encoding errors
- ✅ Zero "keyNotFound" errors
- ✅ Zero "missingPublicID" errors

### User-Facing
- ✅ Published content appears in backend
- ✅ Unpublished content removed from backend
- ✅ Works offline (queues operations)
- ✅ Clear error messages
- ✅ No data loss

---

## Troubleshooting

### "keyNotFound: publicID" Error
**Cause:** Payload stored with wrong keys or decoder using wrong strategy  
**Fix:** Check ContentPublishPayload CodingKeys, remove convertFromSnakeCase

### "missingPublicID" on Unpublish
**Cause:** publicID cleared before sync operation  
**Fix:** Capture publicID before clearing, pass to enqueueUnpublish

### API Returns 400 "Invalid JSON"
**Cause:** contentData not properly formatted  
**Fix:** Check that JSON string is valid, use JSONEncoder.encode

### Backend Returns 409 Duplicate
**Cause:** publicID already exists  
**Fix:** Generate new publicID with different suffix

### Sync Never Completes
**Cause:** Background sync not triggering  
**Fix:** Check ContentSyncService.syncPending() is called, check network reachability

---

## Reference Commands

### iOS
```bash
# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild clean

# Run tests
xcodebuild test -scheme anyfleet -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# View database
sqlite3 ~/Library/Developer/CoreSimulator/Devices/<DEVICE_ID>/data/Containers/Data/Application/<APP_ID>/Library/Application\ Support/Database/anyfleet.sqlite

# Check sync queue
sqlite3 <path_to_db> "SELECT * FROM sync_queue WHERE syncedAt IS NULL;"
```

### Backend
```bash
# Run server
cd anyfleet-backend
uvicorn app.main:app --reload

# Run tests
pytest tests/ -v

# Check database
psql anyfleet_db -c "SELECT public_id, title, content_type, deleted_at FROM shared_content ORDER BY created_at DESC LIMIT 10;"

# View logs
tail -f /var/log/anyfleet-backend.log
```

---

## Next Steps

1. ✅ Review this checklist
2. ⬜ Start Day 1 implementation
3. ⬜ Complete Day 2 backend updates
4. ⬜ Finish Day 3 testing
5. ⬜ Deploy to production

Good luck! 🚀
