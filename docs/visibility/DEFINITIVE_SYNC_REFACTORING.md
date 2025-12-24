# Definitive Sync Service Refactoring Guide

**Status:** Ready to Implement  
**Created:** December 24, 2024  
**Priority:** HIGH - Production Blocker

---

## The Problem (In Plain English)

**What's broken:**
1. iOS encodes `contentData` as a JSON string → Backend expects a JSON object
2. Sync queue stores camelCase (`publicID`) → Decoder expects snake_case (`public_id`)
3. Unpublish doesn't store `publicID` in payload → Fails when trying to call API

**Why it's broken:**
- Too many encoding/decoding strategies fighting each other
- Double-encoding of contentData (dict → JSON string → encode again)
- Inconsistent key naming conventions

---

## The Solution (One Correct Way)

### Core Principles

1. **snake_case on the wire** - Backend is Python, uses snake_case
2. **contentData as JSON object** - Not a string, not base64
3. **Explicit CodingKeys** - No magic encoder/decoder strategies
4. **Store what you send** - Sync queue payload = API payload

### The Contract

**What iOS sends to backend:**
```json
{
  "title": "Pre-Flight Checklist",
  "description": "Safety checklist",
  "content_type": "checklist",
  "content_data": {                    ← JSON object, not string
    "id": "123-456",
    "title": "Pre-Flight Checklist",
    "sections": [...]
  },
  "tags": ["aviation", "safety"],
  "language": "en",
  "public_id": "pre-flight-checklist-abc123",
  "can_fork": true
}
```

**What backend expects:**
```python
class PublishContentRequest(BaseModel):
    content_data: dict[str, Any]  # ← Expects dict, not string
```

---

## Implementation Plan

### Step 1: Create SyncPayloads.swift

Create a **new file** with clean payload structs that use explicit snake_case mapping.

**File:** `/Users/dikology/repos/anyfleet/anyfleet/anyfleet/Core/Models/SyncPayloads.swift`

```swift
import Foundation

// MARK: - Publish Payload

/// Payload for publishing content to backend
/// Uses explicit CodingKeys to map Swift camelCase to JSON snake_case
struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]  // Will be encoded as JSON object
    let tags: [String]
    let language: String
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
        case publicID = "public_id"
    }
    
    init(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String
    ) {
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentData = contentData
        self.tags = tags
        self.language = language
        self.publicID = publicID
    }
    
    // Custom encoding to handle [String: Any]
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        try container.encode(publicID, forKey: .publicID)
        
        // Encode contentData as nested JSON object (not string!)
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
    
    // Custom decoding to handle [String: Any]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decode(String.self, forKey: .contentType)
        tags = try container.decode([String].self, forKey: .tags)
        language = try container.decode(String.self, forKey: .language)
        publicID = try container.decode(String.self, forKey: .publicID)
        
        // Decode contentData as nested JSON object
        let json = try container.decode(AnyCodable.self, forKey: .contentData)
        contentData = json.value as? [String: Any] ?? [:]
    }
}

// MARK: - Unpublish Payload

/// Payload for unpublishing content
struct UnpublishPayload: Codable {
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
    }
}

// MARK: - Helper for Dynamic JSON

/// Helper to encode/decode dynamic JSON structures
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
```

**Key Points:**
- ✅ Explicit `CodingKeys` for snake_case mapping
- ✅ `contentData` encoded as JSON object (via `AnyCodable`)
- ✅ No dependency on encoder/decoder strategies

---

### Step 2: Update VisibilityService.swift

**Remove** the old `ContentPublishPayload` struct (lines 303-355).

**Update** `encodeContentForSync`:

```swift
private func encodeContentForSync(_ item: LibraryModel) async throws -> Data {
    let contentDict: [String: Any]
    
    switch item.type {
    case .checklist:
        guard let checklist = try await libraryStore.fetchChecklist(item.id) else {
            throw PublishError.validationError("Checklist not found")
        }
        contentDict = try encodeChecklist(checklist)
        
    case .practiceGuide:
        guard let guide = try await libraryStore.fetchGuide(item.id) else {
            throw PublishError.validationError("Guide not found")
        }
        contentDict = try encodeGuide(guide)
        
    case .flashcardDeck:
        throw PublishError.validationError("Flashcard decks not yet supported")
    }
    
    guard let publicID = item.publicID else {
        throw PublishError.validationError("Missing public ID")
    }
    
    let payload = ContentPublishPayload(
        title: item.title,
        description: item.description,
        contentType: item.type.rawValue,
        contentData: contentDict,
        tags: item.tags,
        language: item.language,
        publicID: publicID
    )
    
    // Encode with NO key strategy
    let encoder = JSONEncoder()
    return try encoder.encode(payload)
}
```

**Keep** the helper methods unchanged:
- `encodeChecklist(_:)` - Returns `[String: Any]`
- `encodeGuide(_:)` - Returns `[String: Any]`

**Update** `unpublishContent` to capture publicID:

```swift
func unpublishContent(_ item: LibraryModel) async throws {
    AppLogger.auth.startOperation("Unpublish Content")
    
    guard authService.isAuthenticated else {
        AppLogger.auth.warning("Unpublish attempted without authentication")
        throw PublishError.notAuthenticated
    }
    
    // ✅ Capture publicID BEFORE clearing it
    guard let publicIDToUnpublish = item.publicID else {
        throw PublishError.validationError("Cannot unpublish content without publicID")
    }
    
    AppLogger.auth.info("Unpublishing content: \(item.id)")
    
    // Update item to private
    var updated = item
    updated.visibility = .private
    updated.publishedAt = nil
    updated.publicID = nil
    updated.publicMetadata = nil
    updated.syncStatus = .pending
    updated.updatedAt = Date()
    
    do {
        try await libraryStore.updateLibraryMetadata(updated)
        
        // ✅ Pass captured publicID
        try await syncService.enqueueUnpublish(
            contentID: updated.id,
            publicID: publicIDToUnpublish
        )
        
        AppLogger.auth.completeOperation("Unpublish Content")
        AppLogger.auth.info("Content unpublished successfully: \(item.id)")
    } catch {
        AppLogger.auth.failOperation("Unpublish Content", error: error)
        throw PublishError.networkError(error)
    }
}
```

---

### Step 3: Update ContentSyncService.swift

**Update** `enqueueUnpublish` to store payload:

```swift
func enqueueUnpublish(
    contentID: UUID,
    publicID: String  // ✅ Now accepts publicID
) async throws {
    AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")
    
    // ✅ Create payload with publicID
    let unpublishPayload = UnpublishPayload(publicID: publicID)
    let payloadData = try JSONEncoder().encode(unpublishPayload)
    
    try await repository.enqueueSyncOperation(
        contentID: contentID,
        operation: .unpublish,
        visibility: .private,
        payload: payloadData  // ✅ Store payload
    )
    
    await updateSyncState(contentID: contentID, status: .queued)
    await updatePendingCounts()
    
    Task {
        await syncPending()
    }
}
```

**Update** `handlePublish` - remove decoder strategy:

```swift
private func handlePublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    guard let payload = operation.payload else {
        throw SyncError.invalidPayload
    }

    // Debug logging
    if let payloadString = String(data: payload, encoding: .utf8) {
        AppLogger.auth.debug("Decoding payload: \(payloadString)")
    }

    // ✅ Remove decoder strategy - use explicit CodingKeys
    let decoder = JSONDecoder()
    // REMOVED: decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let contentPayload = try decoder.decode(ContentPublishPayload.self, from: payload)
    
    guard var item = libraryStore.library.first(where: { $0.id == operation.contentID }) else {
        throw SyncError.missingPublicID
    }
    
    // Call backend API
    let response = try await apiClient.publishContent(
        title: contentPayload.title,
        description: contentPayload.description,
        contentType: contentPayload.contentType,
        contentData: contentPayload.contentData,
        tags: contentPayload.tags,
        language: contentPayload.language,
        publicID: contentPayload.publicID,
        canFork: true
    )
    
    // Update local model
    item.publicMetadata = PublicMetadata(
        publishedAt: response.publishedAt,
        publicID: response.publicID,
        canFork: response.canFork,
        authorUsername: response.authorUsername ?? "Unknown"
    )
    item.syncStatus = .synced
    try await libraryStore.updateLibraryMetadata(item)
}
```

**Update** `handleUnpublish` - use payload:

```swift
private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    // ✅ Get publicID from payload, not from item
    guard let payloadData = operation.payload else {
        throw SyncError.invalidPayload
    }
    
    let unpublishPayload = try JSONDecoder().decode(UnpublishPayload.self, from: payloadData)
    
    // Check if content was ever successfully published
    let hasSuccessfulPublish = try? await repository.hasSuccessfulPublishOperation(for: operation.contentID)
    
    guard hasSuccessfulPublish == true else {
        AppLogger.auth.info("Skipping unpublish for \(operation.contentID) - no successful publish found")
        return
    }

    // ✅ Use publicID from payload
    try await apiClient.unpublishContent(publicID: unpublishPayload.publicID)

    // Update local model
    if var updated = libraryStore.library.first(where: { $0.id == operation.contentID }) {
        updated.syncStatus = .synced
        try await libraryStore.updateLibraryMetadata(updated)
    }
}
```

---

### Step 4: Update APIClient.swift

**Update** `PublishContentRequest` - remove custom encoding:

```swift
struct PublishContentRequest: Encodable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let language: String
    let publicID: String
    let canFork: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
        case publicID = "public_id"
        case canFork = "can_fork"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        try container.encode(publicID, forKey: .publicID)
        try container.encode(canFork, forKey: .canFork)
        
        // ✅ Encode contentData as nested JSON object (same as SyncPayloads)
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}
```

**Update** APIClient init - remove encoder strategy:

```swift
init(authService: AuthService) {
    // ... existing code ...
    
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase  // ✅ Keep for responses
    
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    // ✅ REMOVE: self.encoder.keyEncodingStrategy = .convertToSnakeCase
    // We use explicit CodingKeys instead
}
```

**Keep** `AnyCodable` helper (same as in SyncPayloads.swift).

---

## Testing Checklist

### Before Running

- [ ] All files compile without errors
- [ ] No linter warnings
- [ ] Database is fresh (migrations run)

### Manual Test Flow

1. **Delete app from simulator**
2. **Clean build folder** (`Cmd+Shift+K`)
3. **Install fresh app**
4. **Sign in** with test account
5. **Create checklist** with some items
6. **Publish checklist**:
   - Check logs: Should see "Publishing content: <uuid>, publicID: <slug>"
   - Check sync_queue in database:
     ```sql
     SELECT id, operation, payload FROM sync_queue ORDER BY created_at DESC LIMIT 1;
     ```
   - Verify payload has snake_case keys: `public_id`, `content_type`, `content_data`
   - Verify `content_data` is a JSON object, not a string
7. **Wait for sync** (should be automatic)
8. **Check backend database**:
   ```sql
   SELECT public_id, title, content_type, 
          jsonb_pretty(content_data::jsonb) 
   FROM shared_content 
   WHERE deleted_at IS NULL 
   ORDER BY created_at DESC LIMIT 1;
   ```
9. **Unpublish checklist**:
   - Check logs: Should see "Unpublishing content: <uuid>"
   - Check sync_queue for unpublish operation with publicID payload
10. **Verify deleted**:
    ```sql
    SELECT deleted_at FROM shared_content WHERE public_id = '<your-slug>';
    ```

### Expected Results

✅ Publish succeeds with 201  
✅ Unpublish succeeds with 204  
✅ No "keyNotFound" errors  
✅ No "missingPublicID" errors  
✅ contentData stored as JSONB (not string)  
✅ UI shows "Public" badge correctly

---

## Debugging Tips

### If you see "keyNotFound: publicID"

**Check:** Sync queue payload encoding
```swift
// In ContentSyncService, add debug logging:
if let payloadString = String(data: payload, encoding: .utf8) {
    print("Payload JSON: \(payloadString)")
}
```

**Expected:**
```json
{
  "public_id": "...",     ← snake_case
  "content_type": "...",  ← snake_case
  "content_data": {...}   ← object, not string
}
```

### If you see "missingPublicID" on unpublish

**Check:** `enqueueUnpublish` is called with publicID
```swift
// In VisibilityService.unpublishContent:
print("Captured publicID: \(publicIDToUnpublish)")
```

### If backend returns 400 "Invalid JSON"

**Check:** Network request payload
```swift
// In APIClient.request, before sending:
if let bodyData = urlRequest.httpBody,
   let bodyString = String(data: bodyData, encoding: .utf8) {
    print("Request body: \(bodyString)")
}
```

**Expected:** Same format as sync queue payload

---

## Success Criteria

### Technical
- ✅ All files compile
- ✅ No linter errors
- ✅ Payload uses snake_case keys
- ✅ contentData is JSON object
- ✅ No decoder strategy conflicts

### Functional
- ✅ Publish succeeds end-to-end
- ✅ Unpublish succeeds end-to-end
- ✅ Backend stores content correctly
- ✅ UI reflects sync status

---

## Rollback Plan

If something breaks:

1. **Revert all changes:** `git checkout -- .`
2. **Disable sync:** Set `isSyncing = true` permanently
3. **Content remains local-only** until fixed
4. **No data loss** (everything in local SQLite)

---

## Time Estimate

- Step 1 (SyncPayloads): 30 min
- Step 2 (VisibilityService): 30 min
- Step 3 (ContentSyncService): 30 min
- Step 4 (APIClient): 30 min
- Testing: 45 min

**Total: ~2.5 hours**

---

## Why This Works

1. **Explicit CodingKeys** = No ambiguity about key names
2. **No encoder strategies** = No fighting between layers
3. **contentData as object** = Backend gets what it expects
4. **Store publicID in payload** = Unpublish has all data it needs
5. **Same encoding everywhere** = Sync queue = API request

This is the **standard, boring, correct way** to do iOS ↔ REST API communication. No magic, no tricks.

