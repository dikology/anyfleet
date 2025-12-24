# Sync Service Refactoring Guide

**Status:** Refactoring Required  
**Created:** December 24, 2024  
**Priority:** HIGH - Production Blocker

---

## Executive Summary

The current sync service implementation has critical bugs preventing proper content publishing/unpublishing. This guide provides a comprehensive refactoring plan to fix all issues and create a robust, tested sync system.

### Critical Issues Identified

1. **Payload Encoding/Decoding Mismatch** ⚠️
   - Payload stored in sync_queue uses camelCase
   - ContentSyncService decoder uses `convertFromSnakeCase` strategy
   - Result: `keyNotFound` error for `publicID`

2. **Unnecessary JSON String Encoding** ⚠️
   - `ContentPublishPayload.contentData` is stored as JSON string
   - Double encoding/decoding adds complexity and failure points
   - Should be stored as dictionary directly

3. **Unpublish Missing publicID** ⚠️
   - Item's `publicID` is cleared before sync operation processes
   - Sync fails with "missingPublicID" error
   - Need to store publicID in sync queue payload

4. **Duplicate Custom Encoding** ⚠️
   - Both `ContentPublishPayload` and `PublishContentRequest` have custom encoding
   - `AnyCodable` helper is overly complex for this use case
   - Should use standard Codable with proper strategy

5. **API Client Not Using Consistent Strategy** ⚠️
   - APIClient encoder uses `convertToSnakeCase`
   - But custom encoding in `PublishContentRequest` bypasses this
   - Inconsistent serialization logic

6. **Sync Status Not Updated After Success** ⚠️
   - API returns 201 but UI shows "pending"
   - Sync completes but local state not updated properly

---

## Part 1: Root Cause Analysis

### Issue 1: Decoder Key Strategy Mismatch

**Location:** `ContentSyncService.swift:176-178`

```swift
let contentPayload: ContentPublishPayload
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase  // ❌ WRONG
```

**Problem:** Payload is stored with camelCase keys in sync_queue:
```json
{
  "publicID": "test-123",          // camelCase
  "contentType": "checklist",       // camelCase
  "contentData": "{...}"
}
```

But decoder expects snake_case keys:
```json
{
  "public_id": "test-123",          // snake_case (expected)
  "content_type": "checklist"       // snake_case (expected)
}
```

**Evidence from logs:**
```
keyNotFound(CodingKeys(stringValue: "publicID", intValue: nil))
```

### Issue 2: Double JSON Encoding for contentData

**Location:** `VisibilityService.swift:335-338`

```swift
// Encode contentData as nested JSON string
let jsonData = try JSONSerialization.data(withJSONObject: contentData)
let jsonString = String(data: jsonData, encoding: .utf8)!  // ❌ UNNECESSARY
try container.encode(jsonString, forKey: .contentData)
```

**Problem:** 
1. Checklist is encoded to JSON
2. JSON is converted to String
3. String is encoded again in payload
4. Must be decoded as string, then parsed as JSON again

**Why this is wrong:**
- Adds complexity and failure points
- Backend expects JSONB object, not string
- Makes debugging difficult

### Issue 3: Unpublish Loses publicID

**Location:** `VisibilityService.swift:199-202`

```swift
var updated = item
updated.visibility = .private
updated.publishedAt = nil
updated.publicID = nil  // ❌ Cleared immediately
updated.publicMetadata = nil
```

Then later tries to enqueue:
```swift
if let publicID = item.publicID {  // ❌ Already nil!
    try await syncService.enqueueUnpublish(...)
}
```

**Location:** `ContentSyncService.swift:221-225`

```swift
func handleUnpublish(...) async throws {
    guard let item = libraryStore.library.first(where: { $0.id == operation.contentID }),
        let publicID = item.publicID else {  // ❌ publicID is nil now
        throw SyncError.missingPublicID
    }
```

**Problem:** publicID is cleared from item BEFORE sync happens, but sync needs it to call API.

### Issue 4: Custom Encoding Bypasses JSONEncoder Strategy

**Location:** `APIClient.swift:210-225`

```swift
// APIClient has encoder with strategy:
self.encoder.keyEncodingStrategy = .convertToSnakeCase

// But PublishContentRequest has custom encode that bypasses it:
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(title, forKey: .title)  // Manually encoding
    // ...
}
```

**Problem:** Custom `encode(to:)` implementation bypasses the encoder's key strategy.

---

## Part 2: Refactoring Plan

### Phase 1: Simplify Payload Structure (HIGH PRIORITY)

#### 1.1 Remove Double JSON Encoding

**Goal:** Store `contentData` as a proper dictionary, not as a JSON string.

**Before:**
```swift
struct ContentPublishPayload: Codable {
    let contentData: [String: Any]  // Not Codable!
    
    func encode(to encoder: Encoder) throws {
        // Custom encoding to JSON string
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try container.encode(jsonString, forKey: .contentData)
    }
}
```

**After:**
```swift
struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: AnyCodableDict  // Codable wrapper
    let tags: [String]
    let language: String
    let publicID: String
}

// Simple wrapper that handles [String: Any] correctly
struct AnyCodableDict: Codable {
    let dictionary: [String: Any]
    
    init(_ dictionary: [String: Any]) {
        self.dictionary = dictionary
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(JSONValue(dictionary))
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let jsonValue = try container.decode(JSONValue.self)
        self.dictionary = jsonValue.dictionaryValue ?? [:]
    }
}

// Recursive JSON type
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])
    
    var dictionaryValue: [String: Any]? {
        guard case .object(let dict) = self else { return nil }
        return dict.mapValues { $0.anyValue }
    }
    
    var anyValue: Any {
        switch self {
        case .string(let str): return str
        case .number(let num): return num
        case .bool(let bool): return bool
        case .null: return NSNull()
        case .array(let arr): return arr.map { $0.anyValue }
        case .object(let obj): return obj.mapValues { $0.anyValue }
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if container.decodeNil() {
            self = .null
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .number(let num): try container.encode(num)
        case .bool(let bool): try container.encode(bool)
        case .null: try container.encodeNil()
        case .array(let arr): try container.encode(arr)
        case .object(let obj): try container.encode(obj)
        }
    }
    
    init(_ value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let number = value as? Double {
            self = .number(number)
        } else if let number = value as? Int {
            self = .number(Double(number))
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if value is NSNull {
            self = .null
        } else if let array = value as? [Any] {
            self = .array(array.map { JSONValue($0) })
        } else if let dict = value as? [String: Any] {
            self = .object(dict.mapValues { JSONValue($0) })
        } else {
            self = .null
        }
    }
}
```

**Better Alternative:** Use standard JSON serialization:

```swift
struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: Data  // Store as Data directly
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
}

// When creating payload:
let checklistData = try JSONEncoder().encode(checklist)
let payload = ContentPublishPayload(
    title: item.title,
    description: item.description,
    contentType: "checklist",
    contentData: checklistData,  // Raw Data
    tags: item.tags,
    language: item.language,
    publicID: publicID
)
```

#### 1.2 Fix Decoder Key Strategy

**File:** `ContentSyncService.swift`

**Before:**
```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase  // ❌
```

**After:**
```swift
let decoder = JSONDecoder()
// Remove key strategy - use CodingKeys explicitly in structs
// OR store payload with snake_case keys from the start
```

**Decision:** Use explicit CodingKeys in ContentPublishPayload (already done above).

#### 1.3 Store publicID in Unpublish Payload

**File:** `ContentSyncService.swift`

**Create new payload type:**
```swift
struct UnpublishPayload: Codable {
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
    }
}
```

**Update enqueueUnpublish:**
```swift
func enqueueUnpublish(
    contentID: UUID,
    publicID: String  // Pass publicID explicitly
) async throws {
    AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")
    
    // Create payload with publicID
    let unpublishPayload = UnpublishPayload(publicID: publicID)
    let payloadData = try JSONEncoder().encode(unpublishPayload)
    
    try await repository.enqueueSyncOperation(
        contentID: contentID,
        operation: .unpublish,
        visibility: .private,
        payload: payloadData  // Include payload
    )
    
    await updateSyncState(contentID: contentID, status: .queued)
    await updatePendingCounts()
    
    Task {
        await syncPending()
    }
}
```

**Update VisibilityService:**
```swift
func unpublishContent(_ item: LibraryModel) async throws {
    // ...
    
    // Capture publicID BEFORE clearing
    let publicIDToUnpublish = item.publicID
    
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
        
        if let publicID = publicIDToUnpublish {  // Use captured value
            try await syncService.enqueueUnpublish(
                contentID: updated.id,
                publicID: publicID  // Pass explicitly
            )
        }
        // ...
    }
}
```

**Update handleUnpublish:**
```swift
private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    // Decode publicID from payload
    guard let payloadData = operation.payload else {
        throw SyncError.invalidPayload
    }
    
    let unpublishPayload = try JSONDecoder().decode(UnpublishPayload.self, from: payloadData)
    
    // Use publicID from payload (not from item, which is now nil)
    try await apiClient.unpublishContent(publicID: unpublishPayload.publicID)
    
    // Update local model
    if var updated = libraryStore.library.first(where: { $0.id == operation.contentID }) {
        updated.syncStatus = .synced
        try await libraryStore.updateLibraryMetadata(updated)
    }
}
```

### Phase 2: Simplify API Client (MEDIUM PRIORITY)

#### 2.1 Remove AnyCodable Complexity

**File:** `APIClient.swift`

**Current approach:** Custom encoding with AnyCodable wrapper for dynamic JSON.

**Problem:** Over-engineered for simple use case.

**Solution:** Send contentData as Data blob, let backend decode it.

**Before:**
```swift
struct PublishContentRequest: Encodable {
    let contentData: [String: Any]  // Not Codable
    
    func encode(to encoder: Encoder) throws {
        // Complex custom encoding with AnyCodable
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}
```

**After:**
```swift
struct PublishContentRequest: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: Data  // Send as base64 string via Codable
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
}
```

**Update publishContent method:**
```swift
func publishContent(
    title: String,
    description: String?,
    contentType: String,
    contentData: Data,  // Accept Data instead of dict
    tags: [String],
    language: String,
    publicID: String,
    canFork: Bool
) async throws -> PublishContentResponse {
    let request = PublishContentRequest(
        title: title,
        description: description,
        contentType: contentType,
        contentData: contentData,
        tags: tags,
        language: language,
        publicID: publicID,
        canFork: canFork
    )
    
    return try await post("/content/share", body: request)
}
```

**OR Better:** Use JSONB-friendly encoding:

```swift
struct PublishContentRequest: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: String  // JSON string (backend will parse to JSONB)
    let tags: [String]
    let language: String
    let publicID: String
    let canFork: Bool
    
    enum CodingKeys: String, CodingKey {
        case title, description, tags, language
        case contentType = "content_type"
        case contentData = "content_data"
        case publicID = "public_id"
        case canFork = "can_fork"
    }
    
    init(
        title: String,
        description: String?,
        contentType: String,
        contentDataJSON: String,  // Pre-encoded JSON string
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool
    ) {
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentData = contentDataJSON
        self.tags = tags
        self.language = language
        self.publicID = publicID
        self.canFork = canFork
    }
}
```

#### 2.2 Consistent Error Handling

**Current:** Mix of throwing and returning optional errors.

**Improve:** Use typed errors consistently.

```swift
enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict(message: String)  // Add context
    case clientError(Int, message: String?)
    case serverError(Int, message: String?)
    case invalidResponse
    case networkError(Error)
    case decodingError(DecodingError)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .forbidden:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested resource was not found."
        case .conflict(let message):
            return "Conflict: \(message)"
        case .clientError(let code, let message):
            return "Client error (\(code)): \(message ?? "Unknown error")"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Please try again later")"
        case .invalidResponse:
            return "Invalid response from server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError:
            return true
        case .unauthorized, .forbidden, .notFound, .conflict, .clientError:
            return false
        case .invalidResponse, .decodingError:
            return false
        }
    }
}
```

### Phase 3: Backend API Alignment (HIGH PRIORITY)

#### 3.1 Backend Schema Expectations

**Current backend expects (from PRD):**
```python
class PublishContentRequest(BaseModel):
    title: str
    description: str | None
    content_type: str
    content_data: dict[str, Any]  # JSONB - expects dict, not string
    tags: list[str]
    language: str
    public_id: str
    can_fork: bool
```

**Problem:** iOS is sending `content_data` as a JSON string, but backend expects a dict.

**Solution 1:** Change backend to accept string and parse:
```python
class PublishContentRequest(BaseModel):
    content_data: str | dict[str, Any]  # Accept both
    
    @field_validator('content_data')
    def parse_content_data(cls, v):
        if isinstance(v, str):
            return json.loads(v)
        return v
```

**Solution 2:** Change iOS to send dict properly (PREFERRED):

Use proper Codable serialization that produces JSON object, not string.

#### 3.2 Test Backend Endpoint

**Create test script:**
```bash
#!/bin/bash
# test_publish.sh

ACCESS_TOKEN="your_token_here"

curl -X POST "http://localhost:8000/api/v1/content/share" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Checklist",
    "description": "Test description",
    "content_type": "checklist",
    "content_data": {
      "id": "test-123",
      "sections": [
        {
          "id": "section-1",
          "title": "Safety",
          "items": []
        }
      ]
    },
    "tags": ["test"],
    "language": "en",
    "public_id": "test-checklist-abc123",
    "can_fork": true
  }' | jq
```

### Phase 4: Comprehensive Testing (HIGH PRIORITY)

#### 4.1 Unit Tests for Payload Encoding/Decoding

**File:** `anyfleetTests/Services/ContentSyncPayloadTests.swift` (NEW)

```swift
import XCTest
@testable import anyfleet

final class ContentSyncPayloadTests: XCTestCase {
    
    func testContentPublishPayload_EncodeDecode() throws {
        // Given
        let checklist = Checklist(
            id: UUID(),
            title: "Test",
            description: "Test description",
            checklistType: .general,
            sections: [],
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
        
        let checklistData = try JSONEncoder().encode(checklist)
        
        let payload = ContentPublishPayload(
            title: "Test",
            description: "Test description",
            contentType: "checklist",
            contentData: checklistData,
            tags: ["test"],
            language: "en",
            publicID: "test-123"
        )
        
        // When - Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(payload)
        
        // Then - Should be valid JSON
        let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["title"] as? String, "Test")
        XCTAssertEqual(json?["public_id"] as? String, "test-123")
        
        // When - Decode
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(ContentPublishPayload.self, from: encodedData)
        
        // Then
        XCTAssertEqual(decodedPayload.title, "Test")
        XCTAssertEqual(decodedPayload.publicID, "test-123")
        XCTAssertEqual(decodedPayload.contentType, "checklist")
    }
    
    func testUnpublishPayload_EncodeDecode() throws {
        // Given
        let payload = UnpublishPayload(publicID: "test-456")
        
        // When - Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(payload)
        
        // Then - Should be valid JSON with snake_case key
        let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        XCTAssertEqual(json?["public_id"] as? String, "test-456")
        
        // When - Decode
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(UnpublishPayload.self, from: encodedData)
        
        // Then
        XCTAssertEqual(decodedPayload.publicID, "test-456")
    }
}
```

#### 4.2 Integration Tests for Sync Flow

**File:** `anyfleetTests/Integration/ContentSyncIntegrationTests.swift` (NEW)

```swift
import XCTest
@testable import anyfleet

@MainActor
final class ContentSyncIntegrationTests: XCTestCase {
    var dependencies: AppDependencies!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() async throws {
        // Use in-memory database
        let testDB = try AppDatabase.makeEmpty()
        mockAPIClient = MockAPIClient()
        dependencies = AppDependencies(
            database: testDB,
            apiClient: mockAPIClient
        )
    }
    
    func testPublishFlow_EndToEnd() async throws {
        // Given: User creates a checklist
        let checklist = Checklist(
            title: "Test Checklist",
            description: "Test",
            checklistType: .general,
            sections: [],
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
        
        try await dependencies.libraryStore.createChecklist(checklist)
        let item = dependencies.libraryStore.library.first!
        
        // Mock API response
        mockAPIClient.publishResponse = PublishContentResponse(
            id: UUID(),
            publicID: "test-123",
            publishedAt: Date(),
            authorUsername: "testuser",
            canFork: true
        )
        
        // When: Publish content
        try await dependencies.visibilityService.publishContent(item)
        
        // Then: Item should be enqueued
        let operations = try await dependencies.repository.getPendingSyncOperations(maxRetries: 3)
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations[0].operation, .publish)
        
        // When: Sync processes
        let summary = await dependencies.contentSyncService.syncPending()
        
        // Then: Should succeed
        XCTAssertEqual(summary.succeeded, 1)
        XCTAssertEqual(summary.failed, 0)
        
        // Then: Item should be marked as synced
        await dependencies.libraryStore.loadLibrary()
        let syncedItem = dependencies.libraryStore.library.first(where: { $0.id == item.id })
        XCTAssertEqual(syncedItem?.syncStatus, .synced)
        XCTAssertEqual(syncedItem?.visibility, .public)
    }
    
    func testUnpublishFlow_PreservesPublicID() async throws {
        // Given: Published item
        let checklist = Checklist(
            title: "Test Checklist",
            description: "Test",
            checklistType: .general,
            sections: [],
            tags: ["test"],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .synced
        )
        
        try await dependencies.libraryStore.createChecklist(checklist)
        var item = dependencies.libraryStore.library.first!
        item.visibility = .public
        item.publicID = "test-published-123"
        item.publishedAt = Date()
        try await dependencies.libraryStore.updateLibraryMetadata(item)
        
        // When: Unpublish
        try await dependencies.visibilityService.unpublishContent(item)
        
        // Then: publicID should be in sync queue payload
        let operations = try await dependencies.repository.getPendingSyncOperations(maxRetries: 3)
        XCTAssertEqual(operations.count, 1)
        
        let operation = operations[0]
        XCTAssertEqual(operation.operation, .unpublish)
        XCTAssertNotNil(operation.payload)
        
        // Decode payload
        let unpublishPayload = try JSONDecoder().decode(
            UnpublishPayload.self,
            from: operation.payload!
        )
        XCTAssertEqual(unpublishPayload.publicID, "test-published-123")
    }
}
```

#### 4.3 Backend API Tests

**File:** `anyfleet-backend/tests/test_content_payloads.py` (NEW)

```python
import pytest
from uuid import uuid4
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_publish_content_with_nested_json(
    client: AsyncClient, authenticated_user_token: str
):
    """Test that backend correctly handles nested JSON in content_data."""
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "description": "Test description",
            "content_type": "checklist",
            "content_data": {  # Nested object
                "id": str(uuid4()),
                "sections": [
                    {
                        "id": str(uuid4()),
                        "title": "Safety",
                        "items": [
                            {
                                "id": str(uuid4()),
                                "title": "Check life jackets",
                                "is_required": True
                            }
                        ]
                    }
                ]
            },
            "tags": ["test", "safety"],
            "language": "en",
            "public_id": "test-nested-json-123",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["public_id"] == "test-nested-json-123"
    
    # Verify stored in database as JSONB
    # (Add database query to verify structure)


@pytest.mark.asyncio
async def test_publish_content_snake_case_keys(
    client: AsyncClient, authenticated_user_token: str
):
    """Test that backend accepts snake_case keys."""
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test",
            "content_type": "checklist",
            "content_data": {"sections": []},
            "tags": [],
            "language": "en",
            "public_id": "test-snake-case-123",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 201
```

---

## Part 3: Implementation Steps

### Step 1: Fix Critical Payload Issues (Day 1 - 4 hours)

1. **Create new payload types:**
   - [ ] Create `UnpublishPayload` struct
   - [ ] Update `ContentPublishPayload` to remove double encoding
   - [ ] Add explicit CodingKeys with snake_case mapping

2. **Update VisibilityService:**
   - [ ] Fix `unpublishContent` to capture publicID before clearing
   - [ ] Update `encodeContentForSync` to produce clean JSON
   - [ ] Remove custom JSON string encoding

3. **Update ContentSyncService:**
   - [ ] Remove `convertFromSnakeCase` strategy
   - [ ] Update `handleUnpublish` to use payload publicID
   - [ ] Update `handlePublish` to use clean contentData

4. **Test locally:**
   - [ ] Publish content and verify sync_queue payload
   - [ ] Check that sync completes successfully
   - [ ] Verify API receives correct format

### Step 2: Backend Validation (Day 1 - 2 hours)

1. **Test backend endpoint:**
   - [ ] Send sample payload from curl
   - [ ] Verify content_data is stored as JSONB
   - [ ] Check response format matches iOS expectations

2. **Add backend validation:**
   - [ ] Validate content_data structure for each content_type
   - [ ] Add better error messages for invalid payloads
   - [ ] Add logging for debugging

### Step 3: Simplify APIClient (Day 2 - 3 hours)

1. **Remove AnyCodable:**
   - [ ] Update `PublishContentRequest` to use Data or JSON string
   - [ ] Remove `AnyCodable` helper class
   - [ ] Test API calls with new format

2. **Improve error handling:**
   - [ ] Add typed errors with context
   - [ ] Add retry logic with exponential backoff
   - [ ] Add network reachability check

### Step 4: Comprehensive Testing (Day 2-3 - 6 hours)

1. **Unit tests:**
   - [ ] Payload encoding/decoding tests
   - [ ] Sync queue operations tests
   - [ ] API client request building tests

2. **Integration tests:**
   - [ ] End-to-end publish flow
   - [ ] End-to-end unpublish flow
   - [ ] Offline queue + sync when online
   - [ ] Retry logic tests

3. **Backend tests:**
   - [ ] Payload validation tests
   - [ ] JSONB storage tests
   - [ ] Error response tests

### Step 5: Production Validation (Day 3 - 2 hours)

1. **Manual testing:**
   - [ ] Create new checklist and publish
   - [ ] Verify appears in backend database
   - [ ] Unpublish and verify deleted
   - [ ] Test offline mode
   - [ ] Test error scenarios

2. **Performance testing:**
   - [ ] Measure sync latency
   - [ ] Test with large content (100+ items)
   - [ ] Test concurrent operations

---

## Part 4: Code Changes

### File 1: ContentPublishPayload (VisibilityService.swift)

**REMOVE this entire struct and move to separate file:**

**New file:** `anyfleet/anyfleet/anyfleet/Core/Models/SyncPayloads.swift`

```swift
import Foundation

// MARK: - Publish Payload

struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentDataJSON: String  // Pre-encoded JSON
    let tags: [String]
    let language: String
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentDataJSON = "content_data"
        case tags
        case language
        case publicID = "public_id"
    }
    
    init(
        title: String,
        description: String?,
        contentType: String,
        contentDataJSON: String,
        tags: [String],
        language: String,
        publicID: String
    ) {
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentDataJSON = contentDataJSON
        self.tags = tags
        self.language = language
        self.publicID = publicID
    }
}

// MARK: - Unpublish Payload

struct UnpublishPayload: Codable {
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
    }
}

// MARK: - Helpers

extension ContentPublishPayload {
    /// Create payload from checklist
    static func from(
        checklist: Checklist,
        metadata: LibraryModel,
        publicID: String
    ) throws -> ContentPublishPayload {
        let checklistData = try JSONEncoder().encode(checklist)
        let checklistJSON = String(data: checklistData, encoding: .utf8)!
        
        return ContentPublishPayload(
            title: metadata.title,
            description: metadata.description,
            contentType: "checklist",
            contentDataJSON: checklistJSON,
            tags: metadata.tags,
            language: metadata.language,
            publicID: publicID
        )
    }
    
    /// Create payload from practice guide
    static func from(
        guide: PracticeGuide,
        metadata: LibraryModel,
        publicID: String
    ) throws -> ContentPublishPayload {
        let guideData = try JSONEncoder().encode(guide)
        let guideJSON = String(data: guideData, encoding: .utf8)!
        
        return ContentPublishPayload(
            title: metadata.title,
            description: metadata.description,
            contentType: "practice_guide",
            contentDataJSON: guideJSON,
            tags: metadata.tags,
            language: metadata.language,
            publicID: publicID
        )
    }
}
```

### File 2: VisibilityService.swift

```swift
// REMOVE encodeContentForSync, encodeChecklist, encodeGuide
// REMOVE ContentPublishPayload struct

// REPLACE with:

private func encodeContentForSync(_ item: LibraryModel) async throws -> Data {
    let payload: ContentPublishPayload
    
    switch item.type {
    case .checklist:
        guard let checklist = try await libraryStore.fetchChecklist(item.id) else {
            throw PublishError.validationError("Checklist not found")
        }
        guard let publicID = item.publicID else {
            throw PublishError.validationError("Missing public ID")
        }
        payload = try ContentPublishPayload.from(
            checklist: checklist,
            metadata: item,
            publicID: publicID
        )
        
    case .practiceGuide:
        guard let guide = try await libraryStore.fetchGuide(item.id) else {
            throw PublishError.validationError("Guide not found")
        }
        guard let publicID = item.publicID else {
            throw PublishError.validationError("Missing public ID")
        }
        payload = try ContentPublishPayload.from(
            guide: guide,
            metadata: item,
            publicID: publicID
        )
        
    case .flashcardDeck:
        throw PublishError.validationError("Flashcard decks not yet supported")
    }
    
    return try JSONEncoder().encode(payload)
}

// UPDATE unpublishContent:
func unpublishContent(_ item: LibraryModel) async throws {
    AppLogger.auth.startOperation("Unpublish Content")
    
    guard authService.isAuthenticated else {
        AppLogger.auth.warning("Unpublish attempted without authentication")
        throw PublishError.notAuthenticated
    }
    
    // Capture publicID BEFORE clearing it
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
        // Save to local database
        try await libraryStore.updateLibraryMetadata(updated)
        
        // Enqueue with captured publicID
        try await syncService.enqueueUnpublish(
            contentID: updated.id,
            publicID: publicIDToUnpublish  // Use captured value
        )
        
        AppLogger.auth.completeOperation("Unpublish Content")
        AppLogger.auth.info("Content unpublished successfully: \(item.id)")
    } catch {
        AppLogger.auth.failOperation("Unpublish Content", error: error)
        throw PublishError.networkError(error)
    }
}
```

### File 3: ContentSyncService.swift

```swift
// UPDATE enqueueUnpublish:
func enqueueUnpublish(
    contentID: UUID,
    publicID: String  // Add publicID parameter
) async throws {
    AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")
    
    // Create payload with publicID
    let unpublishPayload = UnpublishPayload(publicID: publicID)
    let payloadData = try JSONEncoder().encode(unpublishPayload)
    
    try await repository.enqueueSyncOperation(
        contentID: contentID,
        operation: .unpublish,
        visibility: .private,
        payload: payloadData  // Include payload
    )
    
    await updateSyncState(contentID: contentID, status: .queued)
    await updatePendingCounts()
    
    Task {
        await syncPending()
    }
}

// UPDATE handlePublish:
private func handlePublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    guard let payload = operation.payload else {
        throw SyncError.invalidPayload
    }

    let decoder = JSONDecoder()
    // REMOVE: decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let contentPayload = try decoder.decode(ContentPublishPayload.self, from: payload)
    
    // Get current item
    guard var item = libraryStore.library.first(where: { $0.id == operation.contentID }) else {
        throw SyncError.contentNotFound
    }
    
    // Call backend API with JSON string
    let response = try await apiClient.publishContent(
        title: contentPayload.title,
        description: contentPayload.description,
        contentType: contentPayload.contentType,
        contentDataJSON: contentPayload.contentDataJSON,  // Pass JSON string
        tags: contentPayload.tags,
        language: contentPayload.language,
        publicID: contentPayload.publicID,
        canFork: true
    )
    
    // Update local model with server response
    item.publicMetadata = PublicMetadata(
        publishedAt: response.publishedAt,
        publicID: response.publicID,
        canFork: response.canFork,
        authorUsername: response.authorUsername ?? "Unknown"
    )
    item.syncStatus = .synced
    try await libraryStore.updateLibraryMetadata(item)
}

// UPDATE handleUnpublish:
private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    guard let payloadData = operation.payload else {
        throw SyncError.invalidPayload
    }
    
    // Decode publicID from payload
    let unpublishPayload = try JSONDecoder().decode(UnpublishPayload.self, from: payloadData)
    
    // Call backend API with publicID from payload
    try await apiClient.unpublishContent(publicID: unpublishPayload.publicID)
    
    // Update local model
    if var updated = libraryStore.library.first(where: { $0.id == operation.contentID }) {
        updated.syncStatus = .synced
        try await libraryStore.updateLibraryMetadata(updated)
    }
}

// ADD new error case:
enum SyncError: LocalizedError {
    case invalidPayload
    case missingPublicID
    case networkUnreachable
    case contentNotFound  // NEW
    
    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid sync payload"
        case .missingPublicID:
            return "Content missing public ID"
        case .networkUnreachable:
            return "Network unreachable"
        case .contentNotFound:
            return "Content not found in library"
        }
    }
}
```

### File 4: APIClient.swift

```swift
// UPDATE publishContent method:
func publishContent(
    title: String,
    description: String?,
    contentType: String,
    contentDataJSON: String,  // Accept JSON string
    tags: [String],
    language: String,
    publicID: String,
    canFork: Bool
) async throws -> PublishContentResponse {
    let request = PublishContentRequest(
        title: title,
        description: description,
        contentType: contentType,
        contentDataJSON: contentDataJSON,  // Pass JSON string
        tags: tags,
        language: language,
        publicID: publicID,
        canFork: canFork
    )
    
    return try await post("/content/share", body: request)
}

// UPDATE PublishContentRequest:
struct PublishContentRequest: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentDataJSON: String  // JSON string
    let tags: [String]
    let language: String
    let publicID: String
    let canFork: Bool
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentDataJSON = "content_data"
        case tags
        case language
        case publicID = "public_id"
        case canFork = "can_fork"
    }
}

// REMOVE: AnyCodable struct (no longer needed)
```

### File 5: Backend API (anyfleet-backend)

**Update:** `app/schemas/content.py`

```python
from pydantic import BaseModel, Field, field_validator
import json


class PublishContentRequest(BaseModel):
    """Request to publish content."""
    
    title: str = Field(..., min_length=1, max_length=500)
    description: str | None = None
    content_type: str = Field(
        ..., pattern="^(checklist|practice_guide|flashcard_deck)$"
    )
    content_data: dict[str, Any] | str = Field(
        ..., description="Full content structure (dict or JSON string)"
    )
    tags: list[str] = Field(default_factory=list, max_length=20)
    language: str = Field(default="en", max_length=10)
    public_id: str = Field(
        ..., min_length=1, max_length=255, description="URL slug from client"
    )
    can_fork: bool = True
    
    @field_validator('content_data')
    @classmethod
    def parse_content_data(cls, v: dict | str) -> dict:
        """Parse content_data if it's a JSON string."""
        if isinstance(v, str):
            try:
                return json.loads(v)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON in content_data: {e}")
        return v
```

---

## Part 5: Testing Checklist

### Before Refactoring
- [ ] Capture current database state
- [ ] Export any published content for backup
- [ ] Document current behavior (even if buggy)

### During Refactoring
- [ ] Each file change should compile
- [ ] Run unit tests after each change
- [ ] Test locally after each major change

### After Refactoring
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual testing scenarios pass:
  - [ ] Publish new checklist
  - [ ] Unpublish checklist
  - [ ] Publish while offline
  - [ ] Sync when back online
  - [ ] Multiple items in queue
  - [ ] Retry after failure
  - [ ] Max retries exceeded
- [ ] Backend tests pass
- [ ] API responds correctly to iOS payloads

---

## Part 6: Rollout Plan

### Day 1: Fix Critical Issues
- Morning: Implement payload fixes
- Afternoon: Test locally
- Evening: Deploy to TestFlight (internal only)

### Day 2: Simplify and Test
- Morning: Remove AnyCodable, add tests
- Afternoon: Integration testing
- Evening: Deploy to TestFlight (beta)

### Day 3: Validation
- Morning: Manual testing with real content
- Afternoon: Performance testing
- Evening: Production deployment

### Rollback Plan
If critical issues arise:
1. Revert to previous version
2. Disable sync service temporarily
3. Content remains local-only until fixed

---

## Part 7: Success Metrics

### Technical Metrics
- [ ] Sync success rate > 99%
- [ ] Average sync latency < 2 seconds
- [ ] Zero payload encoding errors
- [ ] All integration tests pass

### User-Facing Metrics
- [ ] Published content appears in backend immediately
- [ ] Unpublished content removed from backend
- [ ] No data loss during offline mode
- [ ] Clear error messages for failures

---

## Appendix: Common Pitfalls

### Pitfall 1: Forgetting to Update CodingKeys
**Symptom:** `keyNotFound` error even though data exists
**Solution:** Always use explicit CodingKeys with snake_case mapping

### Pitfall 2: Storing camelCase in Database
**Symptom:** Backend can't find fields
**Solution:** Use CodingKeys to convert at boundaries

### Pitfall 3: Losing Data During State Updates
**Symptom:** publicID is nil when unpublishing
**Solution:** Capture values BEFORE mutating state

### Pitfall 4: Not Testing Payload Serialization
**Symptom:** Works in code but fails over network
**Solution:** Always test full encode -> network -> decode cycle

---

## Next Steps

1. Review this refactoring guide
2. Approve implementation approach
3. Begin Phase 1 implementation
4. Test incrementally
5. Deploy to TestFlight
6. Monitor and iterate

