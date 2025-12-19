# Sync Service Implementation Guide

**Status:** Design Document  
**Related:** [PRD Sprint 5.2](../AnyFleet-phase-2-PRD.md#52-sync-queue-foundation), [Implementation Checklist](./implementation_checklist.md)

---

## Overview

This document details the implementation of the sync service for visibility changes (publish/unpublish). The sync service ensures that visibility state changes are reliably synced to the backend API, with proper error handling, retry logic, and UI feedback.

### Key Principles

1. **Offline-First**: Visibility changes are persisted locally immediately, then synced in background
2. **User Feedback**: Users see sync state in UI (pending, syncing, failed)
3. **Automatic Retry**: Failed syncs retry with exponential backoff (max 3 attempts)
4. **Graceful Degradation**: Failed syncs don't block user workflow
5. **Queue-Based**: All sync operations go through a queue for reliability

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    User Action                           │
│  (Toggle visibility in LibraryItemRow)                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              VisibilityService                          │
│  - Validates action                                      │
│  - Updates local database (immediate)                   │
│  - Sets syncStatus = .pending                            │
│  - Enqueues sync operation                               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              SyncQueue (GRDB Table)                     │
│  - Stores pending operations                            │
│  - Tracks retry count                                   │
│  - Stores error messages                                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              ContentSyncService                         │
│  - Background sync coordinator                          │
│  - Processes queue (FIFO)                               │
│  - Handles retries with backoff                         │
│  - Updates syncStatus on success/failure               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Backend API                                │
│  POST /api/content/share                                 │
│  DELETE /api/content/:id                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Database Schema

### Sync Queue Table

```sql
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id TEXT NOT NULL,           -- UUID of LibraryModel
    operation TEXT NOT NULL,            -- "publish", "unpublish", "update"
    visibility_state TEXT NOT NULL,     -- "private", "unlisted", "public"
    payload TEXT,                        -- JSON of content data (for publish)
    created_at DATETIME NOT NULL,
    retry_count INTEGER DEFAULT 0,
    last_error TEXT,
    synced_at DATETIME,
    
    FOREIGN KEY (content_id) REFERENCES library_content(id) ON DELETE CASCADE
);

CREATE INDEX idx_sync_queue_pending ON sync_queue(created_at) WHERE synced_at IS NULL;
CREATE INDEX idx_sync_queue_content ON sync_queue(content_id);
```

### LibraryModel Sync Status

The `LibraryModel.syncStatus` field tracks the current sync state:

```swift
enum ContentSyncStatus: String, Codable {
    case pending    // Waiting to sync
    case queued     // In sync queue
    case syncing    // Currently being synced
    case synced     // Successfully synced
    case failed     // Failed after max retries
}
```

**Note:** `syncStatus` is separate from `visibility`. A content item can be:
- `visibility: .public, syncStatus: .pending` → Published locally, waiting to sync
- `visibility: .public, syncStatus: .synced` → Published and synced to backend
- `visibility: .public, syncStatus: .failed` → Published locally but sync failed

---

## Implementation Details

### 1. VisibilityService Integration

**Current State:** `VisibilityService` immediately saves to database and sets `syncStatus = .pending`.

**Required Changes:**

```swift
// VisibilityService.swift

func publishContent(_ item: LibraryModel) async throws {
    // ... existing validation ...
    
    // Update item with public visibility
    var updated = item
    updated.visibility = .public
    updated.publishedAt = publishedAt
    updated.publicID = publicID
    updated.publicMetadata = publicMetadata
    updated.syncStatus = .pending  // ✅ Already doing this
    updated.updatedAt = Date()
    
    // Save to local database (immediate)
    try await libraryStore.updateLibraryMetadata(updated)
    
    // ✅ NEW: Enqueue sync operation
    try await syncService.enqueuePublish(
        contentID: updated.id,
        visibility: .public,
        payload: try encodeContentForSync(updated)
    )
}

func unpublishContent(_ item: LibraryModel) async throws {
    // ... existing code ...
    
    var updated = item
    updated.visibility = .private
    updated.syncStatus = .pending  // ✅ Already doing this
    
    try await libraryStore.updateLibraryMetadata(updated)
    
    // ✅ NEW: Enqueue unpublish operation
    if let publicID = item.publicID {
        try await syncService.enqueueUnpublish(
            contentID: updated.id,
            publicID: publicID
        )
    }
}
```

### 2. ContentSyncService

Create a new service to handle background syncing:

```swift
// Services/ContentSyncService.swift

@MainActor
@Observable
final class ContentSyncService {
    private let repository: LocalRepository
    private let apiClient: APIClient
    private let libraryStore: LibraryStore
    
    // Configuration
    private let maxRetries = 3
    private let baseBackoff: TimeInterval = 1.0
    private let maxBackoff: TimeInterval = 30.0
    
    // State
    var isSyncing = false
    var pendingCount: Int = 0
    var failedCount: Int = 0
    
    init(
        repository: LocalRepository,
        apiClient: APIClient,
        libraryStore: LibraryStore
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.libraryStore = libraryStore
    }
    
    // MARK: - Enqueue Operations
    
    /// Enqueue a publish operation
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws {
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: visibility,
            payload: payload
        )
        
        // Update UI state
        await updateSyncState(contentID: contentID, status: .queued)
        
        // Trigger background sync
        Task {
            await syncPending()
        }
    }
    
    /// Enqueue an unpublish operation
    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws {
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )
        
        await updateSyncState(contentID: contentID, status: .queued)
        
        Task {
            await syncPending()
        }
    }
    
    // MARK: - Sync Processing
    
    /// Process all pending sync operations
    @discardableResult
    func syncPending() async -> SyncSummary {
        guard !isSyncing else {
            return SyncSummary(attempted: 0, succeeded: 0, failed: 0)
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        var summary = SyncSummary()
        
        // Check network connectivity
        guard await isNetworkReachable() else {
            await updatePendingCounts()
            return summary
        }
        
        // Fetch pending operations
        let operations = try? await repository.getPendingSyncOperations(maxRetries: maxRetries)
        guard let operations = operations, !operations.isEmpty else {
            await updatePendingCounts()
            return summary
        }
        
        // Process each operation
        for operation in operations {
            summary.attempted += 1
            
            // Update UI: show syncing state
            await updateSyncState(contentID: operation.contentID, status: .syncing)
            
            do {
                try await processOperation(operation)
                summary.succeeded += 1
                
                // Mark as synced
                try await repository.markSyncOperationComplete(operation.id)
                await updateSyncState(contentID: operation.contentID, status: .synced)
                
            } catch {
                summary.failed += 1
                
                // Check if we should retry
                let shouldRetry = operation.retryCount < maxRetries && isRetryableError(error)
                
                if shouldRetry {
                    // Increment retry count, will retry later
                    try? await repository.incrementSyncRetryCount(
                        operation.id,
                        error: error.localizedDescription
                    )
                    await updateSyncState(contentID: operation.contentID, status: .queued)
                } else {
                    // Max retries exceeded, mark as failed
                    try? await repository.markSyncOperationFailed(
                        operation.id,
                        error: error.localizedDescription
                    )
                    await updateSyncState(contentID: operation.contentID, status: .failed)
                }
            }
        }
        
        await updatePendingCounts()
        return summary
    }
    
    // MARK: - Operation Processing
    
    private func processOperation(_ operation: SyncQueueOperation) async throws {
        switch operation.operation {
        case .publish:
            try await handlePublish(operation)
        case .unpublish:
            try await handleUnpublish(operation)
        case .update:
            try await handleUpdate(operation)
        }
    }
    
    private func handlePublish(_ operation: SyncQueueOperation) async throws {
        guard let payload = operation.payload else {
            throw SyncError.invalidPayload
        }
        
        let contentData = try JSONDecoder().decode(ContentPublishPayload.self, from: payload)
        
        // Call backend API
        let response = try await apiClient.publishContent(
            title: contentData.title,
            description: contentData.description,
            contentType: contentData.type,
            contentData: contentData.data,
            tags: contentData.tags
        )
        
        // Update local model with server response
        if var item = await libraryStore.getItem(id: operation.contentID) {
            item.publicID = response.publicID
            item.publicMetadata = PublicMetadata(
                publishedAt: response.publishedAt,
                publicID: response.publicID,
                canFork: response.canFork,
                authorUsername: response.authorUsername
            )
            item.syncStatus = .synced
            try await libraryStore.updateLibraryMetadata(item)
        }
    }
    
    private func handleUnpublish(_ operation: SyncQueueOperation) async throws {
        guard let item = await libraryStore.getItem(id: operation.contentID),
              let publicID = item.publicID else {
            throw SyncError.missingPublicID
        }
        
        // Call backend API
        try await apiClient.unpublishContent(publicID: publicID)
        
        // Update local model
        if var updated = await libraryStore.getItem(id: operation.contentID) {
            updated.syncStatus = .synced
            try await libraryStore.updateLibraryMetadata(updated)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSyncState(contentID: UUID, status: ContentSyncStatus) async {
        if var item = await libraryStore.getItem(id: contentID) {
            item.syncStatus = status
            try? await libraryStore.updateLibraryMetadata(item)
        }
    }
    
    private func updatePendingCounts() async {
        let counts = try? await repository.getSyncQueueCounts()
        pendingCount = counts?.pending ?? 0
        failedCount = counts?.failed ?? 0
    }
    
    private func isNetworkReachable() async -> Bool {
        // Use Network framework or URLSession to check connectivity
        // Implementation depends on your network checking approach
        return true // Placeholder
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are retryable
        // Validation errors are not
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError, .timeout:
                return true
            case .validationError, .unauthorized:
                return false
            }
        }
        return true
    }
}

// MARK: - Supporting Types

struct SyncSummary {
    var attempted: Int = 0
    var succeeded: Int = 0
    var failed: Int = 0
    var errors: [String] = []
}

enum SyncOperation: String, Codable {
    case publish
    case unpublish
    case update
}

struct SyncQueueOperation {
    let id: Int64
    let contentID: UUID
    let operation: SyncOperation
    let visibility: ContentVisibility
    let payload: Data?
    let retryCount: Int
    let lastError: String?
    let createdAt: Date
}

enum SyncError: LocalizedError {
    case invalidPayload
    case missingPublicID
    case networkUnreachable
    
    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid sync payload"
        case .missingPublicID:
            return "Content missing public ID"
        case .networkUnreachable:
            return "Network unreachable"
        }
    }
}
```

### 3. Background Sync Trigger

Set up automatic background syncing:

```swift
// App/AppModel.swift or similar

@Observable
final class AppModel {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    
    init(syncService: ContentSyncService) {
        self.syncService = syncService
        startBackgroundSync()
    }
    
    private func startBackgroundSync() {
        // Sync every 5 seconds when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncService.syncPending()
            }
        }
    }
    
    func applicationDidBecomeActive() {
        // Trigger immediate sync when app becomes active
        Task { @MainActor in
            await syncService.syncPending()
        }
    }
}
```

---

## UI Integration

### LibraryItemRow Sync State Display

Update `LibraryItemRow` to show sync status:

```swift
// Features/Library/LibraryItemRow.swift

struct LibraryItemRow: View {
    let item: LibraryModel
    // ... other properties ...
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ... existing hero section ...
            
            // Footer Section - Visibility Badge + Publish Action + Sync Status
            HStack(spacing: DesignSystem.Spacing.md) {
                VisibilityBadge(
                    visibility: item.visibility,
                    authorUsername: item.publicMetadata?.authorUsername
                )
                
                // ✅ NEW: Sync Status Indicator
                if item.visibility != .private {
                    SyncStatusIndicator(syncStatus: item.syncStatus)
                }
                
                Spacer()
                
                PublishActionView(
                    item: item,
                    isSignedIn: isSignedIn,
                    onPublish: onPublish,
                    onUnpublish: onUnpublish,
                    onSignInRequired: onSignInRequired
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        // ... rest of view ...
    }
}

// ✅ NEW: Sync Status Indicator Component
struct SyncStatusIndicator: View {
    let syncStatus: ContentSyncStatus
    
    var body: some View {
        Group {
            switch syncStatus {
            case .pending, .queued:
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.warning)
                    .help("Syncing...")
                
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                    .help("Syncing to server...")
                
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.success)
                    .help("Synced")
                
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.error)
                    .help("Sync failed - tap to retry")
            }
        }
    }
}
```

### Settings Tab Sync Status

Add sync status display to Settings:

```swift
// Features/Settings/SettingsView.swift

struct SettingsView: View {
    @Bindable var syncService: ContentSyncService
    
    var body: some View {
        List {
            // ... existing sections ...
            
            Section("Sync Status") {
                if syncService.isSyncing {
                    HStack {
                        ProgressView()
                        Text("Syncing...")
                    }
                } else if syncService.pendingCount == 0 && syncService.failedCount == 0 {
                    Label("All synced", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    if syncService.pendingCount > 0 {
                        Label("\(syncService.pendingCount) pending", systemImage: "clock.fill")
                    }
                    if syncService.failedCount > 0 {
                        Label("\(syncService.failedCount) failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
                
                Button("Sync Now") {
                    Task {
                        await syncService.syncPending()
                    }
                }
                .disabled(syncService.isSyncing)
            }
        }
    }
}
```

---

## Error Handling & Retry Logic

### Retry Strategy

1. **Max Retries:** 3 attempts per operation
2. **Backoff:** Exponential backoff with jitter
   - Attempt 1: Immediate retry
   - Attempt 2: 1-2 seconds delay
   - Attempt 3: 2-4 seconds delay
3. **Terminal Errors:** Don't retry for:
   - Validation errors (400)
   - Unauthorized (401)
   - Forbidden (403)
   - Not found (404) - if content was deleted

### Error Classification

```swift
private func classifyError(_ error: Error) -> ErrorCategory {
    if let apiError = error as? APIError {
        switch apiError {
        case .validationError:
            return .terminal
        case .unauthorized, .forbidden:
            return .terminal
        case .notFound:
            return .terminal  // Content may have been deleted
        case .networkError, .timeout:
            return .retryable
        case .serverError:
            return .retryable  // Server may recover
        }
    }
    
    // Network connectivity issues are retryable
    if error is URLError {
        return .retryable
    }
    
    // Unknown errors: retry once, then mark as terminal
    return .retryable
}
```

---

## API Integration

### Backend Endpoints

The sync service calls these endpoints:

```swift
// POST /api/content/share
struct PublishContentRequest: Codable {
    let title: String
    let description: String?
    let contentType: String  // "checklist", "practice_guide", "flashcard_deck"
    let contentData: [String: Any]  // Full content structure
    let tags: [String]
}

struct PublishContentResponse: Codable {
    let id: String
    let publicID: String
    let publishedAt: Date
    let authorUsername: String
    let canFork: Bool
}

// DELETE /api/content/:publicID
// No request body, just delete the shared content
```

### API Client Methods

```swift
// Services/APIClient.swift

extension APIClient {
    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String]
    ) async throws -> PublishContentResponse {
        let request = PublishContentRequest(
            title: title,
            description: description,
            contentType: contentType,
            contentData: contentData,
            tags: tags
        )
        
        return try await post("/api/content/share", body: request)
    }
    
    func unpublishContent(publicID: String) async throws {
        try await delete("/api/content/\(publicID)")
    }
}
```

---

## Testing Strategy

### Unit Tests

1. **ContentSyncService Tests**
   - Enqueue operations
   - Process operations successfully
   - Handle retry logic
   - Mark operations as failed after max retries

2. **VisibilityService Integration Tests**
   - Publish enqueues sync operation
   - Unpublish enqueues sync operation
   - Local state updated immediately

### Integration Tests

1. **End-to-End Sync Flow**
   - Publish → enqueue → sync → update status
   - Network failure → retry → success
   - Max retries → mark as failed

2. **UI State Updates**
   - Sync status updates in LibraryItemRow
   - Settings shows correct pending/failed counts

### Manual Testing Checklist

- [ ] Publish content while offline → shows pending
- [ ] Come online → syncs automatically
- [ ] Network error during sync → retries
- [ ] Max retries exceeded → shows failed state
- [ ] Tap retry on failed item → re-enqueues
- [ ] Settings shows correct sync status
- [ ] Multiple items sync in order (FIFO)

---

## Migration Path

### Phase 1: Current State
- ✅ Visibility persisted immediately
- ✅ `syncStatus` field exists
- ❌ No sync service
- ❌ No queue
- ❌ No API calls

### Phase 2: Add Sync Infrastructure
1. Create `sync_queue` table (migration)
2. Create `ContentSyncService`
3. Update `VisibilityService` to enqueue operations
4. Add background sync trigger

### Phase 3: UI Integration
1. Add `SyncStatusIndicator` component
2. Update `LibraryItemRow` to show sync status
3. Add sync status to Settings

### Phase 4: Backend Integration
1. Implement API client methods
2. Test end-to-end flow
3. Handle errors gracefully

---

## Success Criteria

✅ Users can see sync state in LibraryItemRow  
✅ Failed syncs show clear error state  
✅ Automatic retry with exponential backoff  
✅ Manual retry option for failed items  
✅ Settings shows overall sync status  
✅ Offline changes queue properly  
✅ Online sync happens automatically  
✅ No data loss on sync failures  

---

## Related Documentation

- [PRD Sprint 5.2: Sync Queue Foundation](../AnyFleet-phase-2-PRD.md#52-sync-queue-foundation)
- [Implementation Checklist](./implementation_checklist.md)
- [Library Visibility Guide](./library_visibility_guide.md)
- [UX Patterns](./visibility_ux_patterns.md)

