# Sync Service Testing Guide

**After Refactoring**  
**Date:** December 24, 2024

---

## Changes Made

### iOS (anyfleet)

1. ✅ **Created `SyncPayloads.swift`** - Clean payload structs with explicit snake_case CodingKeys
2. ✅ **Updated `VisibilityService.swift`**:
   - Removed old `ContentPublishPayload` struct
   - Updated `encodeContentForSync()` to use new payloads
   - Fixed `unpublishContent()` to capture publicID before clearing
3. ✅ **Updated `ContentSyncService.swift`**:
   - Removed `decoder.keyDecodingStrategy = .convertFromSnakeCase`
   - Updated `enqueueUnpublish()` to store publicID in payload
   - Updated `handleUnpublish()` to read publicID from payload
4. ✅ **Updated `APIClient.swift`**:
   - Removed `encoder.keyEncodingStrategy = .convertToSnakeCase`
   - Updated `PublishContentRequest` to use explicit CodingKeys
   - ContentData now encoded as JSON object (not string)

### Backend (anyfleet-backend)

No changes needed - backend already expects the correct format.

---

## Pre-Test Setup

### 1. Clean Environment

```bash
# iOS: Delete app from simulator
# Xcode: Simulator > Device > Erase All Content and Settings

# Backend: Clean database
cd /Users/dikology/repos/anyfleet-backend
docker-compose down -v
docker-compose up -d db
alembic upgrade head
```

### 2. Start Backend

```bash
cd /Users/dikology/repos/anyfleet-backend
uvicorn app.main:app --reload
```

Expected output:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

### 3. Build & Run iOS App

1. Open Xcode
2. Clean Build Folder: `Cmd+Shift+K`
3. Build: `Cmd+B`
4. Run in Simulator: `Cmd+R`

---

## Test 1: Publish Checklist

### Steps

1. **Sign in** with Apple ID (or test account)
2. **Create a new checklist**:
   - Title: "Pre-Flight Safety Checklist"
   - Add 3-5 items
   - Save
3. **Publish the checklist**:
   - Long press or tap menu
   - Select "Make Public"
4. **Watch the logs** in Xcode console

### Expected Logs

```
[Auth] Publishing content: <UUID>, publicID: pre-flight-safety-checklist-abc123
[Auth] Enqueuing publish operation for content: <UUID>
[Auth] Processing 1 sync operations
[Auth] Decoding payload for publish operation: {"title":"Pre-Flight Safety Checklist","content_type":"checklist","content_data":{...},"tags":[],"language":"en","public_id":"pre-flight-safety-checklist-abc123"}
[Auth] Sync succeeded for content: <UUID>
[Auth] Content published successfully: <UUID>
```

### Verify: Sync Queue (iOS)

```bash
# Find your simulator's app database
# Path: ~/Library/Developer/CoreSimulator/Devices/<DEVICE_ID>/data/Containers/Data/Application/<APP_ID>/Library/Application Support/Database/anyfleet.sqlite

# Open database
sqlite3 <path_to_db>

# Check sync queue
SELECT 
    operation, 
    json_extract(payload, '$.public_id') as public_id,
    json_extract(payload, '$.content_type') as content_type,
    synced_at 
FROM sync_queue 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected:**
- `operation`: "publish"
- `public_id`: "pre-flight-safety-checklist-abc123"
- `content_type`: "checklist"
- `synced_at`: NOT NULL

### Verify: Backend Database

```bash
cd /Users/dikology/repos/anyfleet-backend

# Connect to database
docker exec -it anyfleet-backend-db-1 psql -U postgres -d anyfleet_db

# Query shared content
SELECT 
    public_id,
    title,
    content_type,
    deleted_at,
    jsonb_pretty(content_data::jsonb) as content
FROM shared_content
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 1;
```

**Expected:**
- `public_id`: "pre-flight-safety-checklist-abc123"
- `title`: "Pre-Flight Safety Checklist"
- `content_type`: "checklist"
- `deleted_at`: NULL
- `content`: JSON object with `id`, `title`, `sections`, etc. (NOT a string!)

### Verify: UI

- ✅ Checklist should show "Public" badge
- ✅ Sync status should be "Synced" (green checkmark)
- ✅ Published date should be visible

---

## Test 2: Unpublish Checklist

### Steps

1. **Select the published checklist** from Test 1
2. **Unpublish**:
   - Long press or tap menu
   - Select "Make Private"
3. **Watch the logs**

### Expected Logs

```
[Auth] Unpublishing content: <UUID>
[Auth] Enqueuing unpublish operation for content: <UUID>
[Auth] Processing 1 sync operations
[Auth] Sync succeeded for content: <UUID>
[Auth] Content unpublished successfully: <UUID>
```

### Verify: Sync Queue (iOS)

```sql
SELECT 
    operation, 
    json_extract(payload, '$.public_id') as public_id,
    synced_at 
FROM sync_queue 
WHERE operation = 'unpublish'
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected:**
- `operation`: "unpublish"
- `public_id`: "pre-flight-safety-checklist-abc123"  ← Must be present!
- `synced_at`: NOT NULL

### Verify: Backend Database

```sql
SELECT 
    public_id,
    title,
    deleted_at
FROM shared_content
WHERE public_id = 'pre-flight-safety-checklist-abc123';
```

**Expected:**
- `deleted_at`: NOT NULL (soft deleted)

### Verify: UI

- ✅ Checklist should show "Private" (no badge)
- ✅ Sync status should be "Synced"
- ✅ Published date should be cleared

---

## Test 3: Offline Publish

### Steps

1. **Turn off network**:
   - Mac: Settings > Network > Wi-Fi > Turn Off
   - OR Simulator: Features > Trigger iCloud Sync (sometimes helps)
2. **Create and publish a checklist**
3. **Check that it's queued** (not synced yet)
4. **Turn on network**
5. **Wait for automatic sync** (or trigger by opening/closing app)

### Expected Behavior

- Checklist is marked as "Pending" while offline
- When online, sync completes automatically
- No errors logged
- Backend receives the content

---

## Test 4: Payload Inspection

### Check Payload Format

**In ContentSyncService.handlePublish, the debug log should show:**

```json
{
  "title": "Pre-Flight Safety Checklist",
  "description": null,
  "content_type": "checklist",
  "content_data": {
    "id": "abc-123",
    "title": "Pre-Flight Safety Checklist",
    "sections": [
      {
        "id": "section-1",
        "title": "Safety",
        "items": [...]
      }
    ],
    "tags": [],
    "checklist_type": "general",
    "created_at": "2024-12-24T10:00:00Z",
    "updated_at": "2024-12-24T10:00:00Z",
    "sync_status": "synced"
  },
  "tags": ["aviation"],
  "language": "en",
  "public_id": "pre-flight-safety-checklist-abc123"
}
```

**Key Points:**
- ✅ All keys are snake_case: `content_type`, `content_data`, `public_id`
- ✅ `content_data` is a JSON object (not a string!)
- ✅ No extra quotes around `content_data`

### Check Network Request

**In backend logs:**

```bash
tail -f anyfleet-backend.log
# OR if using uvicorn directly, check terminal
```

**Expected:**
```
INFO: Publish content request from user: <UUID>
INFO: Content published successfully: <ID>, public_id: pre-flight-safety-checklist-abc123
```

---

## Common Issues & Solutions

### Issue 1: "keyNotFound: publicID"

**Symptom:** Error when decoding ContentPublishPayload

**Cause:** Payload has wrong keys (camelCase instead of snake_case)

**Solution:**
- Check that `ContentPublishPayload` is imported from `SyncPayloads.swift`
- Verify CodingKeys are correct: `case publicID = "public_id"`
- Make sure encoder doesn't use `keyEncodingStrategy = .convertToSnakeCase`

### Issue 2: "missingPublicID" on unpublish

**Symptom:** Error in `handleUnpublish`

**Cause:** publicID not stored in payload

**Solution:**
- Check that `enqueueUnpublish` creates `UnpublishPayload` with publicID
- Verify payload is not nil: `SELECT payload FROM sync_queue WHERE operation = 'unpublish'`

### Issue 3: Backend returns 400 "Invalid JSON"

**Symptom:** Sync fails with 400 error

**Cause:** `content_data` sent as string instead of object

**Solution:**
- Check `AnyCodable` is encoding correctly
- Verify payload inspection shows object, not string
- Check backend logs for actual received payload

### Issue 4: Content doesn't appear in backend

**Symptom:** iOS says "Synced" but backend has no record

**Cause:** Backend error not properly caught

**Solution:**
- Check backend logs for errors
- Verify database connection
- Check auth token is valid

---

## Debugging Commands

### iOS Database

```bash
# Find simulator path
xcrun simctl get_app_container booted com.anyfleet.app data

# Or list all simulators
xcrun simctl list devices | grep Booted

# Open database
sqlite3 <path_to_db>

# Useful queries
.schema sync_queue
SELECT * FROM sync_queue ORDER BY created_at DESC LIMIT 5;
SELECT * FROM library_metadata WHERE visibility = 'public';
```

### Backend Database

```bash
# Connect
docker exec -it anyfleet-backend-db-1 psql -U postgres -d anyfleet_db

# Useful queries
\d shared_content
SELECT public_id, title, content_type, created_at, deleted_at FROM shared_content ORDER BY created_at DESC LIMIT 10;
SELECT public_id, jsonb_typeof(content_data) FROM shared_content;  -- Should return "object"
```

### Network Inspection

```bash
# Use Charles Proxy or Proxyman to inspect requests
# Or add logging in APIClient.request:

if let bodyData = urlRequest.httpBody,
   let bodyString = String(data: bodyData, encoding: .utf8) {
    print("🌐 Request body: \(bodyString)")
}
```

---

## Success Criteria

All tests pass when:

- ✅ Publish succeeds with 201 response
- ✅ Unpublish succeeds with 204 response
- ✅ No "keyNotFound" errors
- ✅ No "missingPublicID" errors
- ✅ Payload uses snake_case keys consistently
- ✅ `content_data` is JSON object (not string)
- ✅ Backend stores content correctly in JSONB column
- ✅ Offline queuing works
- ✅ UI reflects sync status accurately

---

## Rollback if Needed

If tests fail and you need to revert:

```bash
cd /Users/dikology/repos/anyfleet
git diff  # Review changes
git checkout -- anyfleet/anyfleet/Core/Models/SyncPayloads.swift
git checkout -- anyfleet/anyfleet/Services/VisibilityService.swift
git checkout -- anyfleet/anyfleet/Services/ContentSyncService.swift
git checkout -- anyfleet/anyfleet/Services/APIClient.swift
```

---

## Next Steps After Testing

1. If all tests pass:
   - Commit changes: `git commit -m "Fix sync service payload encoding"`
   - Deploy to TestFlight
   - Monitor for 24 hours

2. If tests fail:
   - Check logs and compare with expected output
   - Use debugging commands above
   - Refer to DEFINITIVE_SYNC_REFACTORING.md for details

3. Long-term improvements:
   - Add unit tests for payload encoding/decoding
   - Add integration tests for sync flow
   - Monitor production metrics

---

## Questions?

Refer to:
- **DEFINITIVE_SYNC_REFACTORING.md** - Full implementation details
- **Xcode console** - Real-time logs
- **Backend logs** - API request/response details

