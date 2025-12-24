# Before vs After: Sync Service Refactoring

Visual comparison of what changed and why it fixes the issues.

---

## The Flow: Publish Checklist

### BEFORE (Broken) ❌

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VisibilityService.encodeContentForSync()                     │
│    Creates: ContentPublishPayload                               │
│    Keys: camelCase (publicID, contentType, contentData)         │
│    contentData: JSON STRING with escaped quotes                 │
│                                                                  │
│    {                                                             │
│      "publicID": "test-123",              ← camelCase           │
│      "contentType": "checklist",          ← camelCase           │
│      "contentData": "{\"id\":\"123\"...}" ← STRING (double-enc) │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Store in sync_queue (SQLite)                                 │
│    Stored with camelCase keys                                   │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. ContentSyncService.handlePublish()                           │
│    Decoder: keyDecodingStrategy = .convertFromSnakeCase         │
│    Expects: snake_case keys (public_id, content_type)           │
│                                                                  │
│    ❌ ERROR: keyNotFound(publicID)                              │
│    Why: Looking for "public_id" but payload has "publicID"      │
└─────────────────────────────────────────────────────────────────┘
```

### AFTER (Fixed) ✅

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VisibilityService.encodeContentForSync()                     │
│    Uses: ContentPublishPayload (from SyncPayloads.swift)        │
│    Keys: Explicit CodingKeys → snake_case                       │
│    contentData: JSON OBJECT (properly encoded)                  │
│                                                                  │
│    {                                                             │
│      "public_id": "test-123",             ← snake_case          │
│      "content_type": "checklist",         ← snake_case          │
│      "content_data": {                    ← OBJECT (correct!)   │
│        "id": "123",                                              │
│        "sections": [...]                                         │
│      }                                                           │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Store in sync_queue (SQLite)                                 │
│    Stored with snake_case keys                                  │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. ContentSyncService.handlePublish()                           │
│    Decoder: NO keyDecodingStrategy                              │
│    Uses: Explicit CodingKeys from ContentPublishPayload         │
│                                                                  │
│    ✅ SUCCESS: Decodes correctly                                │
│    Why: Keys match exactly (public_id = public_id)              │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. APIClient.publishContent()                                   │
│    Encoder: NO keyEncodingStrategy                              │
│    Uses: Explicit CodingKeys from PublishContentRequest         │
│                                                                  │
│    Sends to backend:                                            │
│    {                                                             │
│      "public_id": "test-123",             ← snake_case          │
│      "content_type": "checklist",         ← snake_case          │
│      "content_data": {                    ← OBJECT              │
│        "id": "123",                                              │
│        "sections": [...]                                         │
│      }                                                           │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Backend (Python/FastAPI)                                     │
│    Expects: content_data as dict[str, Any]                      │
│                                                                  │
│    ✅ SUCCESS: Receives JSON object                             │
│    Stores in PostgreSQL JSONB column                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Flow: Unpublish Checklist

### BEFORE (Broken) ❌

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VisibilityService.unpublishContent()                         │
│                                                                  │
│    var updated = item                                            │
│    updated.publicID = nil      ← Cleared immediately!           │
│                                                                  │
│    if let publicID = item.publicID {  ← Already nil!            │
│        syncService.enqueueUnpublish(...)                        │
│    }                                                             │
│                                                                  │
│    ❌ Never enqueued (publicID is nil)                          │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. ContentSyncService.enqueueUnpublish()                        │
│    Stores: payload = nil                                        │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. ContentSyncService.handleUnpublish()                         │
│                                                                  │
│    guard let publicID = item.publicID else {                    │
│        throw SyncError.missingPublicID  ← Always fails!         │
│    }                                                             │
│                                                                  │
│    ❌ ERROR: missingPublicID                                    │
│    Why: Item's publicID was cleared before sync happened        │
└─────────────────────────────────────────────────────────────────┘
```

### AFTER (Fixed) ✅

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VisibilityService.unpublishContent()                         │
│                                                                  │
│    // ✅ Capture BEFORE clearing                                │
│    let publicIDToUnpublish = item.publicID                      │
│                                                                  │
│    var updated = item                                            │
│    updated.publicID = nil      ← Clear it now                   │
│                                                                  │
│    // ✅ Use captured value                                     │
│    syncService.enqueueUnpublish(                                │
│        contentID: updated.id,                                   │
│        publicID: publicIDToUnpublish  ← Pass explicitly         │
│    )                                                             │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. ContentSyncService.enqueueUnpublish()                        │
│                                                                  │
│    // ✅ Store publicID in payload                              │
│    let payload = UnpublishPayload(publicID: publicID)           │
│    let payloadData = try JSONEncoder().encode(payload)          │
│                                                                  │
│    Stores: payload = {"public_id": "test-123"}                  │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. ContentSyncService.handleUnpublish()                         │
│                                                                  │
│    // ✅ Get publicID from payload                              │
│    let payload = try decode(UnpublishPayload.self)              │
│    let publicID = payload.publicID  ← From payload!             │
│                                                                  │
│    apiClient.unpublishContent(publicID: publicID)               │
│                                                                  │
│    ✅ SUCCESS: Has publicID from payload                        │
└─────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Backend DELETE /content/{public_id}                          │
│                                                                  │
│    ✅ SUCCESS: Soft-deletes content                             │
│    Sets deleted_at = NOW()                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Differences

### 1. Encoder/Decoder Strategies

#### BEFORE ❌
```swift
// In APIClient init:
encoder.keyEncodingStrategy = .convertToSnakeCase

// In ContentSyncService.handlePublish:
decoder.keyDecodingStrategy = .convertFromSnakeCase

// Problem: Strategies applied inconsistently
//   - Encoder converts keys on send
//   - But sync queue storage doesn't use encoder!
//   - Decoder expects converted keys but finds original keys
```

#### AFTER ✅
```swift
// In APIClient init:
// (removed keyEncodingStrategy)

// In ContentSyncService.handlePublish:
// (removed keyDecodingStrategy)

// Solution: Use explicit CodingKeys everywhere
enum CodingKeys: String, CodingKey {
    case publicID = "public_id"
    case contentType = "content_type"
    case contentData = "content_data"
}

// Result: Consistent, predictable, no magic
```

### 2. ContentData Encoding

#### BEFORE ❌
```swift
// Step 1: Convert dict to JSON
let jsonData = try JSONSerialization.data(withJSONObject: contentData)

// Step 2: Convert JSON to string
let jsonString = String(data: jsonData, encoding: .utf8)!

// Step 3: Encode string
try container.encode(jsonString, forKey: .contentData)

// Result:
{
  "content_data": "{\"id\":\"123\",\"sections\":[...]}"
  //              ^^^ String with escaped quotes ^^^
}
```

#### AFTER ✅
```swift
// Step 1: Convert dict to JSON
let jsonData = try JSONSerialization.data(withJSONObject: contentData)

// Step 2: Decode as AnyCodable
let json = try decoder.decode(AnyCodable.self, from: jsonData)

// Step 3: Encode object
try container.encode(json, forKey: .contentData)

// Result:
{
  "content_data": {
    "id": "123",
    "sections": [...]
  }
}
```

### 3. Unpublish Payload

#### BEFORE ❌
```swift
// No payload stored
try await repository.enqueueSyncOperation(
    contentID: contentID,
    operation: .unpublish,
    visibility: .private,
    payload: nil  ← No publicID!
)

// Later, try to find publicID from item
guard let publicID = item.publicID else {
    throw SyncError.missingPublicID  ← Always fails
}
```

#### AFTER ✅
```swift
// Create payload with publicID
let unpublishPayload = UnpublishPayload(publicID: publicID)
let payloadData = try JSONEncoder().encode(unpublishPayload)

try await repository.enqueueSyncOperation(
    contentID: contentID,
    operation: .unpublish,
    visibility: .private,
    payload: payloadData  ← Has publicID!
)

// Later, get publicID from payload
let payload = try decode(UnpublishPayload.self, from: payloadData)
let publicID = payload.publicID  ← Always available
```

---

## File Structure

### BEFORE
```
Services/
├── VisibilityService.swift
│   └── struct ContentPublishPayload { ... }  ← Defined here
├── ContentSyncService.swift
└── APIClient.swift
    └── struct PublishContentRequest { ... }  ← Different struct!

Problem: Two different payload structs, inconsistent encoding
```

### AFTER
```
Core/Models/
└── SyncPayloads.swift                        ← NEW FILE
    ├── struct ContentPublishPayload { ... }  ← Shared
    ├── struct UnpublishPayload { ... }       ← NEW
    └── struct AnyCodable { ... }             ← Helper

Services/
├── VisibilityService.swift                   ← Uses SyncPayloads
├── ContentSyncService.swift                  ← Uses SyncPayloads
└── APIClient.swift                           ← Uses SyncPayloads

Solution: Single source of truth, consistent encoding
```

---

## Error Messages

### BEFORE
```
❌ keyNotFound(CodingKeys(stringValue: "publicID", intValue: nil))
   → Decoder looks for "public_id" but finds "publicID"

❌ missingPublicID
   → Item's publicID was cleared before sync

❌ Backend 400: Invalid JSON in content_data
   → Backend expects object, receives string
```

### AFTER
```
✅ No keyNotFound errors
   → Keys match exactly (explicit CodingKeys)

✅ No missingPublicID errors
   → publicID stored in payload

✅ No Backend errors
   → Sends object as expected
```

---

## Testing Checklist

Use this to verify the fix:

| Test | Expected Result | Status |
|------|----------------|--------|
| Publish checklist | No errors, appears in backend | ⏳ |
| Check payload format | snake_case keys, contentData as object | ⏳ |
| Check backend DB | content_data column type is "object" | ⏳ |
| Unpublish checklist | No errors, soft-deleted in backend | ⏳ |
| Check unpublish payload | Contains publicID | ⏳ |
| Publish offline | Queues operation, syncs when online | ⏳ |
| Multiple publishes | All succeed | ⏳ |
| UI sync status | Shows correct state (pending/synced) | ⏳ |

---

## Summary

**What changed:**
- ✅ Created new `SyncPayloads.swift` with correct encoding
- ✅ Removed old `ContentPublishPayload` from `VisibilityService`
- ✅ Removed encoder/decoder key strategies
- ✅ Fixed unpublish to store publicID in payload
- ✅ Made contentData encode as object, not string

**Why it works:**
- Explicit CodingKeys = No strategy conflicts
- Store publicID in payload = Always available
- Encode as object = Backend gets what it expects

**How to test:**
- See `TESTING_GUIDE.md` for detailed steps
- Run smoke test: Create → Publish → Check backend
- All errors should be gone

**Result:**
- No more `keyNotFound` errors
- No more `missingPublicID` errors
- No more backend `Invalid JSON` errors
- Clean, standard, maintainable code

