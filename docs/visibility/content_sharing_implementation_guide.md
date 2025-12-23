# Content Sharing & Sync Queue Implementation Guide

**Status:** Implementation Roadmap  
**Last Updated:** December 20, 2024  
**Related:** [Sync Service Implementation](./sync_service_implementation.md), [PRD Sprint 2.2-2.4](../AnyFleet-phase-2-PRD.md#22-backend-content-sharing-endpoint)

---

## Executive Summary

This guide provides a comprehensive roadmap for implementing content sharing and sync queue functionality across the AnyFleet iOS app and backend. It consolidates insights from multiple documents, identifies inconsistencies, and provides a clear implementation path.

### Current State

✅ **Implemented:**
- LibraryModel with visibility & syncStatus fields
- VisibilityService (local-only publish/unpublish)
- AuthService with Apple Sign In
- UI components (VisibilityBadge, PublishConfirmationModal, etc.)
- Database schema with visibility fields

❌ **Not Implemented:**
- Sync queue (database table + service)
- ContentSyncService for background syncing
- Backend API endpoints for content sharing
- API client methods in iOS app
- Retry logic and error handling
- Network reachability checks

---

## Part 1: Architecture & Data Flow

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                 iOS App (Offline-First)             │
├─────────────────────────────────────────────────────┤
│                                                     │
│  User Action (Publish/Unpublish)                   │
│           ↓                                         │
│  VisibilityService                                  │
│    • Validates action                               │
│    • Updates local DB immediately                   │
│    • Sets syncStatus = .pending                     │
│    • Enqueues to sync_queue ⬅ NEW                  │
│           ↓                                         │
│  sync_queue table (GRDB) ⬅ NEW                     │
│    • Stores operation & payload                     │
│    • Tracks retry count                             │
│           ↓                                         │
│  ContentSyncService (background) ⬅ NEW             │
│    • Processes queue every 5s                       │
│    • Calls backend API                              │
│    • Updates syncStatus (synced/failed)             │
│    • Retries with exponential backoff               │
│           ↓                                         │
│  APIClient (authenticated requests) ⬅ NEW          │
│    • POST /api/v1/content/share                     │
│    • DELETE /api/v1/content/:publicID               │
│           ↓                                         │
└─────────────────────────────────────────────────────┘
           ↓ HTTPS
┌─────────────────────────────────────────────────────┐
│              Backend API (FastAPI)                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  POST /api/v1/content/share ⬅ NEW                  │
│    • Validates auth token                           │
│    • Stores content in shared_content table         │
│    • Returns publicID & metadata                    │
│                                                     │
│  DELETE /api/v1/content/:publicID ⬅ NEW            │
│    • Validates ownership                            │
│    • Soft deletes shared content                    │
│                                                     │
│  GET /api/v1/content/public ⬅ FUTURE               │
│    • Returns paginated public content               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Data Models

#### iOS - LibraryModel (Already Exists)
```swift
struct LibraryModel {
    let id: UUID
    var title: String
    var description: String?
    var type: ContentType // checklist, flashcard_deck, practice_guide
    var visibility: ContentVisibility // private, unlisted, public
    var syncStatus: ContentSyncStatus // pending, queued, synced, failed
    var publishedAt: Date?
    var publicID: String? // URL slug (e.g., "safety-checklist-a1b2c3d4")
    var publicMetadata: PublicMetadata?
    // ... other fields
}

struct PublicMetadata: Codable {
    let publishedAt: Date
    let publicID: String
    let canFork: Bool
    let authorUsername: String
}

enum ContentSyncStatus: String, Codable {
    case pending    // Waiting to sync
    case queued     // In sync queue (not currently used, can merge with pending)
    case synced     // Successfully synced to backend
    case failed     // Failed after max retries
}
```

#### Backend - shared_content Table (To Be Created)
```sql
CREATE TABLE shared_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Metadata
    title VARCHAR(500) NOT NULL,
    description TEXT,
    content_type VARCHAR(50) NOT NULL,  -- 'checklist', 'practice_guide', 'flashcard_deck'
    tags TEXT[],                        -- Array of tags
    language VARCHAR(10) DEFAULT 'en',
    
    -- Content (full structure as JSON)
    content_data JSONB NOT NULL,        -- Full checklist/guide/deck structure
    
    -- Publishing metadata
    public_id VARCHAR(255) UNIQUE NOT NULL,  -- URL slug from iOS
    can_fork BOOLEAN DEFAULT TRUE,
    forked_from_id UUID REFERENCES shared_content(id),
    
    -- Stats
    view_count INTEGER DEFAULT 0,
    fork_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,  -- Soft delete
    
    -- Indexes
    CONSTRAINT valid_content_type CHECK (content_type IN ('checklist', 'practice_guide', 'flashcard_deck'))
);

CREATE INDEX idx_shared_content_user ON shared_content(user_id);
CREATE INDEX idx_shared_content_public_id ON shared_content(public_id);
CREATE INDEX idx_shared_content_created ON shared_content(created_at DESC);
CREATE INDEX idx_shared_content_type ON shared_content(content_type);
CREATE INDEX idx_shared_content_tags ON shared_content USING GIN(tags);
```

#### iOS - sync_queue Table (To Be Created)
```sql
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id TEXT NOT NULL,           -- UUID of LibraryModel
    operation TEXT NOT NULL,            -- 'publish' or 'unpublish'
    visibility_state TEXT NOT NULL,     -- 'private', 'unlisted', 'public'
    payload TEXT,                       -- JSON of ContentPublishPayload (for publish)
    created_at DATETIME NOT NULL,
    retry_count INTEGER DEFAULT 0,
    last_error TEXT,
    synced_at DATETIME,
    
    FOREIGN KEY (content_id) REFERENCES library_content(id) ON DELETE CASCADE
);

CREATE INDEX idx_sync_queue_pending ON sync_queue(created_at) WHERE synced_at IS NULL;
CREATE INDEX idx_sync_queue_content ON sync_queue(content_id);
```

---

## Part 2: Required Changes & Refactoring

### 2.1 iOS App Changes

#### A. Database Migration (Priority: HIGH)

**File:** `anyfleet/anyfleet/anyfleet/Data/Local/AppDatabase.swift`

**Action:** Add new migration `v1.6.0_createSyncQueueTable`

```swift
migrator.registerMigration("v1.6.0_createSyncQueueTable") { db in
    AppLogger.database.debug("Running migration: v1.6.0_createSyncQueueTable")
    
    try db.create(table: "sync_queue") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("content_id", .text).notNull()
        t.column("operation", .text).notNull()
        t.column("visibility_state", .text).notNull()
        t.column("payload", .text) // JSON
        t.column("created_at", .datetime).notNull()
        t.column("retry_count", .integer).notNull().defaults(to: 0)
        t.column("last_error", .text)
        t.column("synced_at", .datetime)
        
        t.foreignKey(["content_id"], references: "library_content", onDelete: .cascade)
    }
    
    // Partial index for pending items only
    try db.execute(sql: """
        CREATE INDEX idx_sync_queue_pending 
        ON sync_queue(created_at) 
        WHERE synced_at IS NULL
    """)
    
    try db.create(index: "idx_sync_queue_content", on: "sync_queue", columns: ["content_id"])
    
    AppLogger.database.info("Migration v1.6.0_createSyncQueueTable completed successfully")
}
```

#### B. Create SyncQueueRecord (NEW FILE)

**File:** `anyfleet/anyfleet/anyfleet/Data/Local/Records/SyncQueueRecord.swift`

```swift
import Foundation
@preconcurrency import GRDB

/// Database record for sync queue operations
nonisolated struct SyncQueueRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sync_queue"
    
    var id: Int64?
    var contentID: String
    var operation: String // "publish" or "unpublish"
    var visibilityState: String
    var payload: String? // JSON
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    var syncedAt: Date?
    
    enum Columns: String, ColumnExpression {
        case id, contentID = "content_id", operation, visibilityState = "visibility_state"
        case payload, createdAt = "created_at", retryCount = "retry_count"
        case lastError = "last_error", syncedAt = "synced_at"
    }
}

// MARK: - Database Operations

extension SyncQueueRecord {
    /// Enqueue a new operation
    @discardableResult
    nonisolated static func enqueue(
        contentID: UUID,
        operation: SyncOperation,
        visibility: ContentVisibility,
        payload: Data?,
        db: Database
    ) throws -> SyncQueueRecord {
        let payloadString = payload.flatMap { String(data: $0, encoding: .utf8) }
        
        var record = SyncQueueRecord(
            id: nil,
            contentID: contentID.uuidString,
            operation: operation.rawValue,
            visibilityState: visibility.rawValue,
            payload: payloadString,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil,
            syncedAt: nil
        )
        
        try record.insert(db)
        return record
    }
    
    /// Fetch pending operations (not synced, under max retries)
    nonisolated static func fetchPending(maxRetries: Int, db: Database) throws -> [SyncQueueRecord] {
        try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount < maxRetries)
            .order(Columns.createdAt.asc)
            .fetchAll(db)
    }
    
    /// Mark operation as synced
    nonisolated static func markSynced(id: Int64, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET synced_at = ? WHERE id = ?",
            arguments: [Date(), id]
        )
    }
    
    /// Increment retry count and store error
    nonisolated static func incrementRetry(id: Int64, error: String, db: Database) throws {
        try db.execute(
            sql: "UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?",
            arguments: [error, id]
        )
    }
    
    /// Get counts for UI display
    nonisolated static func getCounts(db: Database) throws -> (pending: Int, failed: Int) {
        let pending = try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount < 3)
            .fetchCount(db)
        
        let failed = try SyncQueueRecord
            .filter(Columns.syncedAt == nil)
            .filter(Columns.retryCount >= 3)
            .fetchCount(db)
        
        return (pending, failed)
    }
}
```

#### C. Update LocalRepository (MODIFY EXISTING)

**File:** `anyfleet/anyfleet/anyfleet/Data/Repositories/LocalRepository.swift`

**Add these methods:**

```swift
// MARK: - Sync Queue Operations

extension LocalRepository {
    /// Enqueue a sync operation
    func enqueueSyncOperation(
        contentID: UUID,
        operation: SyncOperation,
        visibility: ContentVisibility,
        payload: Data?
    ) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.enqueue(
                contentID: contentID,
                operation: operation,
                visibility: visibility,
                payload: payload,
                db: db
            )
        }
    }
    
    /// Get pending sync operations
    func getPendingSyncOperations(maxRetries: Int) async throws -> [SyncQueueOperation] {
        try await database.dbWriter.read { db in
            let records = try SyncQueueRecord.fetchPending(maxRetries: maxRetries, db: db)
            return records.map { record in
                SyncQueueOperation(
                    id: record.id!,
                    contentID: UUID(uuidString: record.contentID)!,
                    operation: SyncOperation(rawValue: record.operation)!,
                    visibility: ContentVisibility(rawValue: record.visibilityState)!,
                    payload: record.payload?.data(using: .utf8),
                    retryCount: record.retryCount,
                    lastError: record.lastError,
                    createdAt: record.createdAt
                )
            }
        }
    }
    
    /// Mark operation as synced
    func markSyncOperationComplete(_ operationID: Int64) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.markSynced(id: operationID, db: db)
        }
    }
    
    /// Increment retry count
    func incrementSyncRetryCount(_ operationID: Int64, error: String) async throws {
        try await database.dbWriter.write { db in
            try SyncQueueRecord.incrementRetry(id: operationID, error: error, db: db)
        }
    }
    
    /// Get sync queue counts
    func getSyncQueueCounts() async throws -> (pending: Int, failed: Int) {
        try await database.dbWriter.read { db in
            try SyncQueueRecord.getCounts(db: db)
        }
    }
}
```

#### D. Create ContentSyncService (NEW FILE)

**File:** `anyfleet/anyfleet/anyfleet/Services/ContentSyncService.swift`

**Status:** NEW - Complete implementation needed

See the detailed implementation in [Part 3: Step-by-Step Implementation](#part-3-step-by-step-implementation).

#### E. Update VisibilityService (MODIFY EXISTING)

**File:** `anyfleet/anyfleet/anyfleet/Services/VisibilityService.swift`

**Changes Required:**

```swift
@MainActor
@Observable
final class VisibilityService {
    private let libraryStore: LibraryStore
    private let authService: AuthService
    private let syncService: ContentSyncService  // ⬅ NEW: Add dependency
    
    init(
        libraryStore: LibraryStore,
        authService: AuthService,
        syncService: ContentSyncService  // ⬅ NEW
    ) {
        self.libraryStore = libraryStore
        self.authService = authService
        self.syncService = syncService  // ⬅ NEW
    }
    
    func publishContent(_ item: LibraryModel) async throws {
        // ... existing validation code ...
        
        // Update item with public visibility
        var updated = item
        updated.visibility = .public
        updated.publishedAt = publishedAt
        updated.publicID = publicID
        updated.publicMetadata = publicMetadata
        updated.syncStatus = .pending
        updated.updatedAt = Date()
        
        // Save to local database (immediate)
        try await libraryStore.updateLibraryMetadata(updated)
        
        // ⬅ NEW: Enqueue sync operation
        let payload = try encodeContentForSync(updated)
        try await syncService.enqueuePublish(
            contentID: updated.id,
            visibility: .public,
            payload: payload
        )
        
        AppLogger.auth.info("Content published locally and enqueued for sync: \(item.id)")
    }
    
    func unpublishContent(_ item: LibraryModel) async throws {
        // ... existing code to update local state ...
        
        var updated = item
        updated.visibility = .private
        updated.syncStatus = .pending
        updated.updatedAt = Date()
        
        try await libraryStore.updateLibraryMetadata(updated)
        
        // ⬅ NEW: Enqueue unpublish operation
        if let publicID = item.publicID {
            try await syncService.enqueueUnpublish(
                contentID: updated.id,
                publicID: publicID
            )
        }
        
        AppLogger.auth.info("Content unpublished locally and enqueued for sync: \(item.id)")
    }
    
    // ⬅ NEW: Helper method to encode content for sync
    private func encodeContentForSync(_ item: LibraryModel) throws -> Data {
        // Fetch full content based on type
        let payload: ContentPublishPayload
        
        switch item.type {
        case .checklist:
            guard let checklist = try await libraryStore.getChecklist(id: item.id) else {
                throw PublishError.validationError("Checklist not found")
            }
            payload = ContentPublishPayload(
                title: item.title,
                description: item.description,
                contentType: "checklist",
                contentData: try encodeChecklist(checklist),
                tags: item.tags,
                language: item.language
            )
            
        case .practiceGuide:
            guard let guide = try await libraryStore.getGuide(id: item.id) else {
                throw PublishError.validationError("Guide not found")
            }
            payload = ContentPublishPayload(
                title: item.title,
                description: item.description,
                contentType: "practice_guide",
                contentData: try encodeGuide(guide),
                tags: item.tags,
                language: item.language
            )
            
        case .flashcardDeck:
            throw PublishError.validationError("Flashcard decks not yet supported")
        }
        
        return try JSONEncoder().encode(payload)
    }
    
    private func encodeChecklist(_ checklist: Checklist) throws -> [String: Any] {
        // Convert Checklist to JSON-serializable dict
        let data = try JSONEncoder().encode(checklist)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as! [String: Any]
    }
    
    private func encodeGuide(_ guide: PracticeGuide) throws -> [String: Any] {
        let data = try JSONEncoder().encode(guide)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as! [String: Any]
    }
}

// Supporting type for API payload
struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case title, description, contentType = "content_type"
        case contentData = "content_data", tags, language
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        
        // Encode contentData as nested JSON
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try container.encode(jsonString, forKey: .contentData)
    }
}
```

#### F. Create APIClient (NEW FILE)

**File:** `anyfleet/anyfleet/anyfleet/Services/APIClient.swift`

**Status:** NEW - Complete implementation needed

This should follow the pattern from `automatic-parakeet/sailaway/sailaway/Services/APIClient.swift` but adapted for anyfleet.

See detailed implementation in [Part 3](#part-3-step-by-step-implementation).

#### G. Update AppDependencies (MODIFY EXISTING)

**File:** `anyfleet/anyfleet/anyfleet/App/AppDependencies.swift`

```swift
final class AppDependencies: Sendable {
    let database: AppDatabase
    let repository: LocalRepository
    let charterStore: CharterStore
    let libraryStore: LibraryStore
    let authService: AuthService
    let authStateObserver: AuthStateObserver
    let apiClient: APIClient  // ⬅ NEW
    let contentSyncService: ContentSyncService  // ⬅ NEW
    let visibilityService: VisibilityService
    
    init(
        database: AppDatabase? = nil,
        authService: AuthService? = nil
    ) {
        self.database = database ?? .shared
        self.repository = LocalRepository(database: self.database)
        self.charterStore = CharterStore(repository: self.repository)
        self.libraryStore = LibraryStore(repository: self.repository)
        
        let auth = authService ?? AuthService()
        self.authService = auth
        self.authStateObserver = AuthStateObserver(authService: auth)
        
        // ⬅ NEW: Initialize API client and sync service
        self.apiClient = APIClient(authService: auth)
        self.contentSyncService = ContentSyncService(
            repository: self.repository,
            apiClient: self.apiClient,
            libraryStore: self.libraryStore
        )
        
        // ⬅ MODIFIED: Pass syncService to VisibilityService
        self.visibilityService = VisibilityService(
            libraryStore: self.libraryStore,
            authService: auth,
            syncService: self.contentSyncService
        )
    }
}
```

### 2.2 Backend API Changes

#### A. Create Content Models (NEW FILE)

**File:** `anyfleet-backend/app/models/content.py`

```python
"""Content sharing models."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SharedContent(Base):
    """Shared content model for user-published content."""

    __tablename__ = "shared_content"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Metadata
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    content_type: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )  # 'checklist', 'practice_guide', 'flashcard_deck'
    tags: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    language: Mapped[str] = mapped_column(String(10), nullable=False, default="en")

    # Content
    content_data: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False
    )  # Full structure

    # Publishing metadata
    public_id: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    can_fork: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    forked_from_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("shared_content.id"), nullable=True
    )

    # Stats
    view_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    fork_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )  # Soft delete

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="shared_content")
    forked_from: Mapped["SharedContent | None"] = relationship(
        "SharedContent", remote_side=[id], backref="forks"
    )

    def __repr__(self) -> str:
        return f"<SharedContent(id={self.id}, title={self.title}, type={self.content_type})>"
```

**Also update:** `anyfleet-backend/app/models/user.py`

```python
# Add to User model:
shared_content: Mapped[list["SharedContent"]] = relationship(
    "SharedContent", back_populates="user", cascade="all, delete-orphan"
)
```

#### B. Create Content Schemas (NEW FILE)

**File:** `anyfleet-backend/app/schemas/content.py`

```python
"""Content sharing schemas."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class PublishContentRequest(BaseModel):
    """Request to publish content."""

    title: str = Field(..., min_length=1, max_length=500)
    description: str | None = None
    content_type: str = Field(
        ..., pattern="^(checklist|practice_guide|flashcard_deck)$"
    )
    content_data: dict[str, Any] = Field(..., description="Full content structure")
    tags: list[str] = Field(default_factory=list, max_length=20)
    language: str = Field(default="en", max_length=10)
    public_id: str = Field(..., min_length=1, max_length=255, description="URL slug from client")
    can_fork: bool = True


class PublishContentResponse(BaseModel):
    """Response after publishing content."""

    id: UUID
    public_id: str
    published_at: datetime
    author_username: str | None
    can_fork: bool

    model_config = {"from_attributes": True}


class SharedContentSummary(BaseModel):
    """Summary of shared content for listings."""

    id: UUID
    title: str
    description: str | None
    content_type: str
    tags: list[str]
    public_id: str
    author_username: str | None
    view_count: int
    fork_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class SharedContentDetail(BaseModel):
    """Full shared content with data."""

    id: UUID
    title: str
    description: str | None
    content_type: str
    content_data: dict[str, Any]
    tags: list[str]
    public_id: str
    can_fork: bool
    author_username: str | None
    view_count: int
    fork_count: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
```

#### C. Create Content Endpoints (NEW FILE)

**File:** `anyfleet-backend/app/api/v1/content.py`

```python
"""Content sharing endpoints."""

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.api.middleware import limiter
from app.database import get_db
from app.models.content import SharedContent
from app.schemas.content import (
    PublishContentRequest,
    PublishContentResponse,
    SharedContentDetail,
    SharedContentSummary,
)

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/share",
    response_model=PublishContentResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/minute")
async def publish_content(
    request: Request,
    content: PublishContentRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PublishContentResponse:
    """
    Publish content to make it publicly available.

    This endpoint:
    1. Validates the content payload
    2. Checks for duplicate public_id
    3. Stores the content in shared_content table
    4. Returns publication metadata
    """
    logger.info(f"Publish content request from user: {current_user.id}")

    # Check if public_id already exists
    result = await db.execute(
        select(SharedContent).where(SharedContent.public_id == content.public_id)
    )
    existing = result.scalar_one_or_none()

    if existing is not None:
        logger.warning(f"Duplicate public_id: {content.public_id}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Content with public_id '{content.public_id}' already exists",
        )

    # Create shared content
    shared_content = SharedContent(
        user_id=current_user.id,
        title=content.title,
        description=content.description,
        content_type=content.content_type,
        content_data=content.content_data,
        tags=content.tags,
        language=content.language,
        public_id=content.public_id,
        can_fork=content.can_fork,
    )

    db.add(shared_content)
    await db.commit()
    await db.refresh(shared_content)

    logger.info(
        f"Content published successfully: {shared_content.id}, public_id: {shared_content.public_id}"
    )

    return PublishContentResponse(
        id=shared_content.id,
        public_id=shared_content.public_id,
        published_at=shared_content.created_at,
        author_username=current_user.username,
        can_fork=shared_content.can_fork,
    )


@router.delete("/{public_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("20/minute")
async def unpublish_content(
    request: Request,
    public_id: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> None:
    """
    Unpublish (soft delete) shared content.

    Only the owner can unpublish their content.
    """
    logger.info(
        f"Unpublish request for public_id: {public_id} from user: {current_user.id}"
    )

    # Find content
    result = await db.execute(
        select(SharedContent).where(
            SharedContent.public_id == public_id,
            SharedContent.deleted_at.is_(None),
        )
    )
    content = result.scalar_one_or_none()

    if content is None:
        logger.warning(f"Content not found: {public_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Content not found",
        )

    # Check ownership
    if content.user_id != current_user.id:
        logger.warning(
            f"User {current_user.id} attempted to unpublish content owned by {content.user_id}"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only unpublish your own content",
        )

    # Soft delete
    from datetime import datetime
    content.deleted_at = datetime.now()
    await db.commit()

    logger.info(f"Content unpublished successfully: {public_id}")


@router.get("/public", response_model=list[SharedContentSummary])
async def list_public_content(
    db: Annotated[AsyncSession, Depends(get_db)],
    content_type: str | None = None,
    limit: int = 20,
    offset: int = 0,
) -> list[SharedContentSummary]:
    """
    List public content (for discovery).

    Optional filters:
    - content_type: Filter by type (checklist, practice_guide, flashcard_deck)
    - limit: Max results (default 20, max 100)
    - offset: Pagination offset
    """
    logger.debug(
        f"List public content request: type={content_type}, limit={limit}, offset={offset}"
    )

    # Clamp limit
    limit = min(limit, 100)

    # Build query
    query = select(SharedContent).where(SharedContent.deleted_at.is_(None))

    if content_type:
        query = query.where(SharedContent.content_type == content_type)

    query = query.order_by(SharedContent.created_at.desc()).limit(limit).offset(offset)

    result = await db.execute(query)
    contents = result.scalars().all()

    # Load users for username
    summaries = []
    for content in contents:
        await db.refresh(content, ["user"])
        summaries.append(
            SharedContentSummary(
                id=content.id,
                title=content.title,
                description=content.description,
                content_type=content.content_type,
                tags=content.tags or [],
                public_id=content.public_id,
                author_username=content.user.username,
                view_count=content.view_count,
                fork_count=content.fork_count,
                created_at=content.created_at,
            )
        )

    logger.info(f"Returning {len(summaries)} public content items")
    return summaries


@router.get("/{public_id}", response_model=SharedContentDetail)
async def get_content(
    public_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SharedContentDetail:
    """
    Get full content by public_id.

    This endpoint is public (no auth required).
    Increments view_count.
    """
    logger.debug(f"Get content request: {public_id}")

    result = await db.execute(
        select(SharedContent).where(
            SharedContent.public_id == public_id,
            SharedContent.deleted_at.is_(None),
        )
    )
    content = result.scalar_one_or_none()

    if content is None:
        logger.warning(f"Content not found: {public_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Content not found",
        )

    # Increment view count
    content.view_count += 1
    await db.commit()
    await db.refresh(content, ["user"])

    logger.info(f"Returning content: {public_id}, view_count: {content.view_count}")

    return SharedContentDetail(
        id=content.id,
        title=content.title,
        description=content.description,
        content_type=content.content_type,
        content_data=content.content_data,
        tags=content.tags or [],
        public_id=content.public_id,
        can_fork=content.can_fork,
        author_username=content.user.username,
        view_count=content.view_count,
        fork_count=content.fork_count,
        created_at=content.created_at,
        updated_at=content.updated_at,
    )
```

#### D. Create Database Migration (NEW FILE)

**File:** `anyfleet-backend/alembic/versions/2025_12_21_0900-create_shared_content_table.py`

```python
"""create shared_content table

Revision ID: 2025_12_21_0900
Revises: 8e87f7bc8e38
Create Date: 2025-12-21 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '2025_12_21_0900'
down_revision: Union[str, None] = '8e87f7bc8e38'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create shared_content table
    op.create_table(
        'shared_content',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('title', sa.String(length=500), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('content_type', sa.String(length=50), nullable=False),
        sa.Column('tags', postgresql.ARRAY(sa.String()), nullable=True),
        sa.Column('language', sa.String(length=10), nullable=False, server_default='en'),
        sa.Column('content_data', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('public_id', sa.String(length=255), nullable=False),
        sa.Column('can_fork', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('forked_from_id', sa.Uuid(), nullable=True),
        sa.Column('view_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('fork_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['forked_from_id'], ['shared_content.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('public_id'),
        sa.CheckConstraint("content_type IN ('checklist', 'practice_guide', 'flashcard_deck')", name='valid_content_type')
    )
    
    # Create indexes
    op.create_index('idx_shared_content_user', 'shared_content', ['user_id'])
    op.create_index('idx_shared_content_public_id', 'shared_content', ['public_id'])
    op.create_index('idx_shared_content_created', 'shared_content', ['created_at'], postgresql_ops={'created_at': 'DESC'})
    op.create_index('idx_shared_content_type', 'shared_content', ['content_type'])
    op.create_index('idx_shared_content_tags', 'shared_content', ['tags'], postgresql_using='gin')


def downgrade() -> None:
    # Drop indexes
    op.drop_index('idx_shared_content_tags', table_name='shared_content')
    op.drop_index('idx_shared_content_type', table_name='shared_content')
    op.drop_index('idx_shared_content_created', table_name='shared_content')
    op.drop_index('idx_shared_content_public_id', table_name='shared_content')
    op.drop_index('idx_shared_content_user', table_name='shared_content')
    
    # Drop table
    op.drop_table('shared_content')
```

#### E. Update API Router (MODIFY EXISTING)

**File:** `anyfleet-backend/app/api/v1/__init__.py`

```python
"""API v1 router."""

from fastapi import APIRouter

from app.api.v1 import auth, content  # ⬅ Add content import

api_router = APIRouter()

# Include routers
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(content.router, prefix="/content", tags=["Content"])  # ⬅ NEW
```

---

## Part 3: Step-by-Step Implementation

### Phase 1: Backend Foundation (Week 1, Days 1-2)

**Goal:** Get backend API working and tested

#### Step 1.1: Create Database Migration
```bash
cd anyfleet-backend

# Create migration file
alembic revision -m "create shared_content table"

# Edit the generated file with the migration code from Part 2.2.D
# Run migration
alembic upgrade head

# Verify in PostgreSQL
psql anyfleet_db -c "\d shared_content"
```

#### Step 1.2: Create Models & Schemas
- Create `app/models/content.py`
- Create `app/schemas/content.py`
- Update `app/models/user.py` to add relationship
- Update `app/models/__init__.py` to import SharedContent

#### Step 1.3: Create API Endpoints
- Create `app/api/v1/content.py`
- Update `app/api/v1/__init__.py`

#### Step 1.4: Test Backend Manually
```bash
# Start server
uvicorn app.main:app --reload

# Test with curl (need auth token first)

# Option 1: Use test endpoint (development only)
# This bypasses Apple validation and creates a test user
curl -X POST "http://localhost:8000/api/v1/auth/test-signin?email=test@example.com"

# This returns:
# {
#   "access_token": "eyJ...",
#   "refresh_token": "eyJ...",
#   "token_type": "bearer",
#   "expires_in": 1800,
#   "user": {...}
# }
#
# Copy the access_token for use in subsequent requests

# Option 2: Use real Apple Sign-in (requires iOS app)
# 1. Sign in with Apple in the iOS app
# 2. Copy the identity_token from the app logs
# 3. Use it in the curl command:
curl -X POST http://localhost:8000/api/v1/auth/apple-signin \
  -H "Content-Type: application/json" \
  -d '{"identity_token": "YOUR_REAL_APPLE_IDENTITY_TOKEN"}'

# 2. Publish content
curl -X POST http://localhost:8000/api/v1/content/share \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @test_content.json

# 3. Get public content
curl http://localhost:8000/api/v1/content/public

# 4. Get specific content
curl http://localhost:8000/api/v1/content/pre-charter-safety-abc12345

# 5. Unpublish
curl -X DELETE http://localhost:8000/api/v1/content/pre-charter-safety-abc12345 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Sample test_content.json:**
```json
{
  "title": "Pre-Charter Safety Checklist",
  "description": "Essential safety checks before departure",
  "content_type": "checklist",
  "content_data": {
    "sections": [
      {
        "id": "uuid-here",
        "title": "Safety Equipment",
        "items": [
          {
            "id": "uuid-here",
            "title": "Check life jackets",
            "isRequired": true
          }
        ]
      }
    ]
  },
  "tags": ["safety", "pre-charter"],
  "language": "en",
  "public_id": "pre-charter-safety-abc12345",
  "can_fork": true
}
```

### Phase 2: iOS Sync Infrastructure (Week 1, Days 3-5)

**Goal:** Get sync queue and service working locally (without API calls)

#### Step 2.1: Database Migration
- Add `v1.6.0_createSyncQueueTable` migration to `AppDatabase.swift`
- Test migration: Delete app, rebuild, verify table created

#### Step 2.2: Create Records & Repository Methods
- Create `SyncQueueRecord.swift`
- Add sync queue methods to `LocalRepository.swift`
- Write unit tests for repository methods

#### Step 2.3: Create ContentSyncService (Stub)
**File:** `anyfleet/anyfleet/anyfleet/Services/ContentSyncService.swift`

```swift
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentSyncService {
    private let repository: LocalRepository
    private let apiClient: APIClient?  // Optional for now
    private let libraryStore: LibraryStore
    
    // Configuration
    private let maxRetries = 3
    
    // State
    var isSyncing = false
    var pendingCount: Int = 0
    var failedCount: Int = 0
    
    init(
        repository: LocalRepository,
        apiClient: APIClient?,
        libraryStore: LibraryStore
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.libraryStore = libraryStore
        AppLogger.auth.info("ContentSyncService initialized")
    }
    
    // MARK: - Enqueue Operations
    
    func enqueuePublish(
        contentID: UUID,
        visibility: ContentVisibility,
        payload: Data
    ) async throws {
        AppLogger.auth.info("Enqueuing publish operation for content: \(contentID)")
        
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .publish,
            visibility: visibility,
            payload: payload
        )
        
        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()
        
        // Trigger sync (will implement in next phase)
        Task {
            await syncPending()
        }
    }
    
    func enqueueUnpublish(
        contentID: UUID,
        publicID: String
    ) async throws {
        AppLogger.auth.info("Enqueuing unpublish operation for content: \(contentID)")
        
        try await repository.enqueueSyncOperation(
            contentID: contentID,
            operation: .unpublish,
            visibility: .private,
            payload: nil
        )
        
        await updateSyncState(contentID: contentID, status: .queued)
        await updatePendingCounts()
        
        Task {
            await syncPending()
        }
    }
    
    // MARK: - Sync Processing (Stub for now)
    
    func syncPending() async -> SyncSummary {
        guard !isSyncing else {
            return SyncSummary()
        }
        
        guard apiClient != nil else {
            AppLogger.auth.warning("API client not available, skipping sync")
            await updatePendingCounts()
            return SyncSummary()
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        var summary = SyncSummary()
        
        // TODO: Implement actual sync logic in Phase 3
        AppLogger.auth.debug("Sync pending (stub implementation)")
        
        await updatePendingCounts()
        return summary
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
}

// MARK: - Supporting Types

struct SyncSummary {
    var attempted: Int = 0
    var succeeded: Int = 0
    var failed: Int = 0
}

enum SyncOperation: String, Codable {
    case publish
    case unpublish
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

#### Step 2.4: Update VisibilityService
- Add `syncService` dependency
- Update `publishContent()` to enqueue
- Update `unpublishContent()` to enqueue
- Add `encodeContentForSync()` helper

#### Step 2.5: Update AppDependencies
- Add `apiClient` property (nil for now)
- Add `contentSyncService` property
- Pass `syncService` to `VisibilityService`

#### Step 2.6: Test Enqueuing
- Run app, publish content
- Verify sync_queue has records
- Verify syncStatus is `.queued`

### Phase 3: iOS API Client (Week 2, Days 1-2) -- 23 dec --

**Goal:** Connect iOS to backend

#### Step 3.1: Create APIClient

**File:** `anyfleet/anyfleet/anyfleet/Services/APIClient.swift`

```swift
import Foundation

/// API client for authenticated requests to backend
actor APIClient {
    private let baseURL: URL
    private let authService: AuthService
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(authService: AuthService) {
        // Environment-based URL
        #if DEBUG
        self.baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
        #else
        self.baseURL = URL(string: "https://api.anyfleet.app/api/v1")!
        #endif
        
        self.authService = authService
        self.session = URLSession.shared
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Content Endpoints
    
    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
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
    
    func unpublishContent(publicID: String) async throws {
        try await delete("/content/\(publicID)")
    }
    
    // MARK: - HTTP Methods
    
    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }
    
    private func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(method: "DELETE", path: path, body: EmptyBody())
    }
    
    private func request<T: Decodable, B: Encodable>(
        method: String,
        path: String,
        body: B
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Get access token (will refresh if needed)
        guard let accessToken = await authService.getAccessToken() else {
            throw APIError.unauthorized
        }
        
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Encode body
        if !(body is EmptyBody) {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        // Perform request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try decoder.decode(T.self, from: data)
            
        case 401:
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        case 409:
            throw APIError.conflict
            
        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)
            
        case 500...599:
            throw APIError.serverError
            
        default:
            throw APIError.invalidResponse
        }
    }
}

// MARK: - Request/Response Types

struct PublishContentRequest: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        try container.encode(publicID, forKey: .publicID)
        try container.encode(canFork, forKey: .canFork)
        
        // Encode contentData as nested JSON
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}

struct PublishContentResponse: Codable {
    let id: UUID
    let publicID: String
    let publishedAt: Date
    let authorUsername: String?
    let canFork: Bool
}

// Helper for dynamic JSON
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

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case clientError(Int)
    case serverError
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Resource already exists"
        case .clientError(let code):
            return "Client error: \(code)"
        case .serverError:
            return "Server error"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct EmptyBody: Codable {}
struct EmptyResponse: Codable {}
```

#### Step 3.2: Update ContentSyncService with Real Sync Logic

Replace the stub `syncPending()` with:

```swift
func syncPending() async -> SyncSummary {
    guard !isSyncing else {
        return SyncSummary()
    }
    
    guard let apiClient = apiClient else {
        AppLogger.auth.warning("API client not available")
        await updatePendingCounts()
        return SyncSummary()
    }
    
    isSyncing = true
    defer { isSyncing = false }
    
    var summary = SyncSummary()
    
    // Check network connectivity (basic check)
    guard await isNetworkReachable() else {
        AppLogger.auth.warning("Network unreachable, skipping sync")
        await updatePendingCounts()
        return summary
    }
    
    // Fetch pending operations
    let operations = try? await repository.getPendingSyncOperations(maxRetries: maxRetries)
    guard let operations = operations, !operations.isEmpty else {
        await updatePendingCounts()
        return summary
    }
    
    AppLogger.auth.info("Processing \(operations.count) sync operations")
    
    // Process each operation
    for operation in operations {
        summary.attempted += 1
        
        await updateSyncState(contentID: operation.contentID, status: .syncing)
        
        do {
            try await processOperation(operation, apiClient: apiClient)
            summary.succeeded += 1
            
            // Mark as synced
            try await repository.markSyncOperationComplete(operation.id)
            await updateSyncState(contentID: operation.contentID, status: .synced)
            
            AppLogger.auth.info("Sync succeeded for content: \(operation.contentID)")
            
        } catch {
            summary.failed += 1
            AppLogger.auth.error("Sync failed for content: \(operation.contentID), error: \(error)")
            
            // Check if we should retry
            let shouldRetry = operation.retryCount < maxRetries && isRetryableError(error)
            
            if shouldRetry {
                // Increment retry count
                try? await repository.incrementSyncRetryCount(
                    operation.id,
                    error: error.localizedDescription
                )
                await updateSyncState(contentID: operation.contentID, status: .pending)
            } else {
                // Max retries exceeded or terminal error
                await updateSyncState(contentID: operation.contentID, status: .failed)
            }
        }
    }
    
    await updatePendingCounts()
    AppLogger.auth.info("Sync complete: \(summary.succeeded) succeeded, \(summary.failed) failed")
    return summary
}

private func processOperation(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    switch operation.operation {
    case .publish:
        try await handlePublish(operation, apiClient: apiClient)
    case .unpublish:
        try await handleUnpublish(operation, apiClient: apiClient)
    }
}

private func handlePublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
    guard let payload = operation.payload else {
        throw SyncError.invalidPayload
    }
    
    let contentPayload = try JSONDecoder().decode(ContentPublishPayload.self, from: payload)
    
    // Get current item to ensure we have latest publicID
    guard var item = await libraryStore.getItem(id: operation.contentID),
          let publicID = item.publicID else {
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
        publicID: publicID,
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

private func handleUnpublish(_ operation: SyncQueueOperation, apiClient: APIClient) async throws {
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

private func isNetworkReachable() async -> Bool {
    // Basic check: try to connect to backend
    // You can use Network framework for more sophisticated checks
    return true // For now, assume reachable
}

private func isRetryableError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
        switch apiError {
        case .networkError, .serverError:
            return true
        case .unauthorized, .forbidden, .notFound, .conflict, .clientError:
            return false
        case .invalidResponse:
            return true
        }
    }
    
    // Network errors from URLSession
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            return true
        default:
            return false
        }
    }
    
    return true // Unknown errors: retry once
}
```

#### Step 3.3: Update AppDependencies

```swift
// Initialize API client with auth service
self.apiClient = APIClient(authService: auth)

// Pass apiClient to ContentSyncService
self.contentSyncService = ContentSyncService(
    repository: self.repository,
    apiClient: self.apiClient,  // No longer optional
    libraryStore: self.libraryStore
)
```

#### Step 3.4: Add Background Sync Trigger

**File:** `anyfleet/anyfleet/anyfleet/App/AppModel.swift` (or in `anyfleetApp.swift`)

```swift
@Observable
final class AppModel {
    private let syncService: ContentSyncService
    private var syncTimer: Timer?
    
    init(dependencies: AppDependencies) {
        self.syncService = dependencies.contentSyncService
        startBackgroundSync()
    }
    
    private func startBackgroundSync() {
        // Sync every 10 seconds when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
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
    
    deinit {
        syncTimer?.invalidate()
    }
}
```

### Phase 4: End-to-End Testing (Week 2, Days 3-5)

**Goal:** Test complete flow and fix bugs

#### Test Scenarios

1. **Happy Path - Publish**
   - [ ] User signs in
   - [ ] User creates checklist
   - [ ] User taps Publish
   - [ ] Sees confirmation modal
   - [ ] Confirms
   - [ ] Content marked as pending
   - [ ] Sync service processes queue
   - [ ] Backend receives request
   - [ ] Content marked as synced
   - [ ] Badge shows "Public"

2. **Happy Path - Unpublish**
   - [ ] User has published content
   - [ ] User taps Unpublish
   - [ ] Sees confirmation
   - [ ] Confirms
   - [ ] Content marked as pending
   - [ ] Sync service processes
   - [ ] Backend soft deletes
   - [ ] Content marked as private

3. **Offline Publish**
   - [ ] Turn off network
   - [ ] Publish content
   - [ ] Content marked as pending
   - [ ] Sync fails (network error)
   - [ ] Turn on network
   - [ ] Background sync retries
   - [ ] Success

4. **Duplicate PublicID**
   - [ ] Publish content (succeeds)
   - [ ] Force-queue same operation again
   - [ ] Sync attempts
   - [ ] Backend returns 409 Conflict
   - [ ] Marked as failed (terminal error)
   - [ ] UI shows error state

5. **Max Retries Exceeded**
   - [ ] Mock network to always fail
   - [ ] Publish content
   - [ ] Retry 1, 2, 3 times
   - [ ] After 3 retries, marked as failed
   - [ ] UI shows failed badge
   - [ ] User can manually retry

6. **Token Expiration During Sync**
   - [ ] Expire access token
   - [ ] Trigger sync
   - [ ] APIClient refreshes token
   - [ ] Retry request succeeds

---

## Part 4: Testing Strategy

### 4.1 Unit Tests

#### iOS Tests

**File:** `anyfleetTests/Services/ContentSyncServiceTests.swift`

```swift
import XCTest
@testable import anyfleet

final class ContentSyncServiceTests: XCTestCase {
    var sut: ContentSyncService!
    var mockRepository: MockRepository!
    var mockAPIClient: MockAPIClient!
    var mockLibraryStore: MockLibraryStore!
    
    override func setUp() async throws {
        mockRepository = MockRepository()
        mockAPIClient = MockAPIClient()
        mockLibraryStore = MockLibraryStore()
        sut = ContentSyncService(
            repository: mockRepository,
            apiClient: mockAPIClient,
            libraryStore: mockLibraryStore
        )
    }
    
    func testEnqueuePublish_Success() async throws {
        // Given
        let contentID = UUID()
        let payload = Data()
        
        // When
        try await sut.enqueuePublish(
            contentID: contentID,
            visibility: .public,
            payload: payload
        )
        
        // Then
        XCTAssertEqual(mockRepository.enqueuedOperations.count, 1)
        XCTAssertEqual(mockRepository.enqueuedOperations[0].contentID, contentID)
        XCTAssertEqual(sut.pendingCount, 1)
    }
    
    func testSyncPending_SuccessfulPublish() async throws {
        // Given
        let operation = SyncQueueOperation(
            id: 1,
            contentID: UUID(),
            operation: .publish,
            visibility: .public,
            payload: validPayload(),
            retryCount: 0,
            lastError: nil,
            createdAt: Date()
        )
        
        mockRepository.pendingOperations = [operation]
        mockAPIClient.publishResponse = PublishContentResponse(
            id: UUID(),
            publicID: "test-content-123",
            publishedAt: Date(),
            authorUsername: "testuser",
            canFork: true
        )
        
        // When
        let summary = await sut.syncPending()
        
        // Then
        XCTAssertEqual(summary.attempted, 1)
        XCTAssertEqual(summary.succeeded, 1)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertTrue(mockRepository.markedSynced.contains(1))
    }
    
    func testSyncPending_NetworkError_Retries() async throws {
        // Given
        let operation = SyncQueueOperation(
            id: 1,
            contentID: UUID(),
            operation: .publish,
            visibility: .public,
            payload: validPayload(),
            retryCount: 0,
            lastError: nil,
            createdAt: Date()
        )
        
        mockRepository.pendingOperations = [operation]
        mockAPIClient.shouldFail = true
        mockAPIClient.failureError = .networkError(URLError(.notConnectedToInternet))
        
        // When
        let summary = await sut.syncPending()
        
        // Then
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(mockRepository.incrementedRetries.count, 1)
        XCTAssertFalse(mockRepository.markedSynced.contains(1))
    }
    
    func testSyncPending_TerminalError_NoRetry() async throws {
        // Given
        let operation = SyncQueueOperation(
            id: 1,
            contentID: UUID(),
            operation: .publish,
            visibility: .public,
            payload: validPayload(),
            retryCount: 0,
            lastError: nil,
            createdAt: Date()
        )
        
        mockRepository.pendingOperations = [operation]
        mockAPIClient.shouldFail = true
        mockAPIClient.failureError = .conflict
        
        // When
        let summary = await sut.syncPending()
        
        // Then
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(mockRepository.incrementedRetries.count, 0)
        // Should mark as failed instead
    }
    
    func testSyncPending_MaxRetriesExceeded() async throws {
        // Given
        let operation = SyncQueueOperation(
            id: 1,
            contentID: UUID(),
            operation: .publish,
            visibility: .public,
            payload: validPayload(),
            retryCount: 3,  // Already at max
            lastError: "Network error",
            createdAt: Date()
        )
        
        mockRepository.pendingOperations = [operation]
        
        // When
        let summary = await sut.syncPending()
        
        // Then
        XCTAssertEqual(summary.attempted, 0)  // Shouldn't even attempt
    }
    
    private func validPayload() -> Data {
        let payload = ContentPublishPayload(
            title: "Test",
            description: nil,
            contentType: "checklist",
            contentData: [:],
            tags: [],
            language: "en"
        )
        return try! JSONEncoder().encode(payload)
    }
}
```

#### Backend Tests

**File:** `anyfleet-backend/tests/test_content.py`

```python
import pytest
from uuid import uuid4
from httpx import AsyncClient

from app.models.content import SharedContent


@pytest.mark.asyncio
async def test_publish_content_success(
    client: AsyncClient, authenticated_user_token: str
):
    """Test successful content publishing."""
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test Checklist",
            "description": "A test checklist",
            "content_type": "checklist",
            "content_data": {
                "sections": [
                    {
                        "id": str(uuid4()),
                        "title": "Section 1",
                        "items": []
                    }
                ]
            },
            "tags": ["test"],
            "language": "en",
            "public_id": "test-checklist-abc123",
            "can_fork": True
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["public_id"] == "test-checklist-abc123"
    assert "id" in data
    assert "published_at" in data


@pytest.mark.asyncio
async def test_publish_content_duplicate_public_id(
    client: AsyncClient, authenticated_user_token: str
):
    """Test publishing with duplicate public_id returns 409."""
    # First publish
    await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test 1",
            "content_type": "checklist",
            "content_data": {"sections": []},
            "public_id": "duplicate-id-123",
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    # Second publish with same public_id
    response = await client.post(
        "/api/v1/content/share",
        json={
            "title": "Test 2",
            "content_type": "checklist",
            "content_data": {"sections": []},
            "public_id": "duplicate-id-123",
        },
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_unpublish_content_success(
    client: AsyncClient, authenticated_user_token: str, db_session
):
    """Test successful content unpublishing."""
    # Create content first
    content = SharedContent(
        user_id=uuid4(),
        title="Test",
        content_type="checklist",
        content_data={"sections": []},
        public_id="test-unpublish-123"
    )
    db_session.add(content)
    await db_session.commit()
    
    # Unpublish
    response = await client.delete(
        f"/api/v1/content/{content.public_id}",
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 204
    
    # Verify soft deleted
    await db_session.refresh(content)
    assert content.deleted_at is not None


@pytest.mark.asyncio
async def test_unpublish_not_owner_forbidden(
    client: AsyncClient, authenticated_user_token: str, db_session
):
    """Test unpublishing content owned by another user returns 403."""
    # Create content owned by different user
    content = SharedContent(
        user_id=uuid4(),  # Different user
        title="Test",
        content_type="checklist",
        content_data={"sections": []},
        public_id="test-forbidden-123"
    )
    db_session.add(content)
    await db_session.commit()
    
    # Try to unpublish
    response = await client.delete(
        f"/api/v1/content/{content.public_id}",
        headers={"Authorization": f"Bearer {authenticated_user_token}"}
    )
    
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_public_content(client: AsyncClient, db_session):
    """Test listing public content."""
    # Create some content
    for i in range(3):
        content = SharedContent(
            user_id=uuid4(),
            title=f"Test {i}",
            content_type="checklist",
            content_data={"sections": []},
            public_id=f"test-{i}"
        )
        db_session.add(content)
    await db_session.commit()
    
    # List (no auth required)
    response = await client.get("/api/v1/content/public")
    
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 3


@pytest.mark.asyncio
async def test_get_content_by_public_id(client: AsyncClient, db_session):
    """Test getting content by public_id."""
    content = SharedContent(
        user_id=uuid4(),
        title="Test Content",
        description="Test description",
        content_type="checklist",
        content_data={"sections": []},
        public_id="test-get-123",
        view_count=5
    )
    db_session.add(content)
    await db_session.commit()
    
    # Get content (no auth required)
    response = await client.get(f"/api/v1/content/{content.public_id}")
    
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test Content"
    assert data["public_id"] == "test-get-123"
    assert data["view_count"] == 6  # Incremented
```

### 4.2 Integration Tests

#### iOS Integration Tests

Test full flow from UI to database:

```swift
@MainActor
final class PublishFlowIntegrationTests: XCTestCase {
    var dependencies: AppDependencies!
    var viewModel: LibraryListViewModel!
    
    override func setUp() async throws {
        // Use in-memory database
        let testDB = try AppDatabase.makeEmpty()
        dependencies = AppDependencies(database: testDB)
        viewModel = LibraryListViewModel(
            libraryStore: dependencies.libraryStore,
            visibilityService: dependencies.visibilityService,
            authObserver: dependencies.authStateObserver,
            coordinator: AppCoordinator(dependencies: dependencies)
        )
    }
    
    func testPublishFlow_EndsInSyncQueue() async throws {
        // Given: User is signed in
        // Mock auth service to return signed-in state
        
        // Given: User has created a checklist
        let checklist = Checklist(
            title: "Test Checklist",
            description: "Test",
            sections: []
        )
        try await dependencies.libraryStore.createChecklist(checklist)
        
        await viewModel.loadLibrary()
        let item = viewModel.library.first!
        
        // When: User publishes
        viewModel.initiatePublish(item)
        await viewModel.confirmPublish()
        
        // Then: Item is in sync queue
        let operations = try await dependencies.repository.getPendingSyncOperations(maxRetries: 3)
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations[0].contentID, item.id)
        XCTAssertEqual(operations[0].operation, .publish)
        
        // Then: Item syncStatus is pending/queued
        await viewModel.loadLibrary()
        let updatedItem = viewModel.library.first(where: { $0.id == item.id })
        XCTAssertNotEqual(updatedItem?.syncStatus, .synced)
    }
}
```

### 4.3 Edge Cases

| Scenario | Expected Behavior | Test Status |
|----------|------------------|-------------|
| Publish while offline | Enqueued, syncs when online | [ ] |
| Unpublish while offline | Enqueued, syncs when online | [ ] |
| Duplicate public_id | Backend returns 409, marked failed | [ ] |
| Token expires during sync | Auto-refresh, retry succeeds | [ ] |
| Backend returns 500 | Retries up to 3 times | [ ] |
| Network timeout | Retries up to 3 times | [ ] |
| Invalid content_data | Backend returns 400, marked failed | [ ] |
| Unpublish non-existent content | Backend returns 404, marked failed | [ ] |
| Unpublish someone else's content | Backend returns 403, marked failed | [ ] |
| Max retries exceeded | Marked as failed, shows in UI | [ ] |
| Queue has 100+ operations | Processes in batches (FIFO) | [ ] |
| App backgrounded during sync | Sync pauses, resumes on foreground | [ ] |
| User deletes content with pending sync | Cascade delete removes queue entry | [ ] |
| Conflicting operations in queue | Last operation wins | [ ] |

---

## Part 5: Rollout & Deployment

### 5.1 Deployment Sequence

#### Week 1: Backend Deployment

1. **Deploy Backend Changes**
   ```bash
   # On production server
   cd anyfleet-backend
   git pull origin main
   
   # Run migration
   alembic upgrade head
   
   # Restart server
   systemctl restart anyfleet-backend
   
   # Verify health
   curl https://api.anyfleet.app/health
   ```

2. **Verify Backend**
   - Test `/api/v1/content/share` with curl
   - Check database has `shared_content` table
   - Monitor logs for errors

#### Week 2: iOS Beta Rollout

1. **Internal Testing (Days 1-2)**
   - Deploy to TestFlight (internal track)
   - Test with 5-10 internal users
   - Monitor crash reports
   - Check backend logs for errors

2. **Beta Testing (Days 3-5)**
   - Deploy to TestFlight (beta track)
   - 50-100 beta testers
   - Collect feedback
   - Monitor sync success rate

3. **Production Release (Week 3)**
   - Submit to App Store
   - Phased rollout (10% → 50% → 100%)
   - Monitor analytics

### 5.2 Monitoring

#### iOS Monitoring

```swift
// Add analytics events
AppLogger.analytics.event("content_published", metadata: [
    "content_type": item.type.rawValue,
    "sync_status": item.syncStatus.rawValue
])

AppLogger.analytics.event("sync_completed", metadata: [
    "succeeded": summary.succeeded,
    "failed": summary.failed,
    "duration_ms": duration
])
```

#### Backend Monitoring

```python
# Add metrics
from prometheus_client import Counter, Histogram

content_published_total = Counter(
    'content_published_total', 
    'Total content published',
    ['content_type']
)

sync_duration = Histogram(
    'sync_request_duration_seconds',
    'Sync request duration'
)

@router.post("/share")
async def publish_content(...):
    with sync_duration.time():
        # ... publish logic ...
        content_published_total.labels(
            content_type=content.content_type
        ).inc()
```

### 5.3 Rollback Plan

#### If iOS has critical bugs:
1. Disable background sync via feature flag
2. Users can still publish/unpublish locally
3. Fix bug, deploy hotfix

#### If Backend has critical bugs:
1. Backend returns 503 Service Unavailable
2. iOS sync service backs off
3. Fix bug, redeploy backend
4. iOS retries automatically

---

## Part 6: Future Enhancements

### 6.1 Optimization

- **Batch sync operations:** Process multiple operations in a single API call
- **Delta sync:** Only sync changes, not full content
- **Compression:** Compress large content_data payloads
- **CDN:** Serve public content from CDN

### 6.2 Features

- **Discover tab:** Browse public content in iOS app
- **Fork content:** Allow users to fork public content
- **Search:** Full-text search in shared content
- **Comments:** Allow comments on shared content
- **Ratings:** Star ratings for content

---

## Appendix A: File Checklist

### iOS Files

**New Files:**
- [ ] `anyfleet/anyfleet/anyfleet/Data/Local/Records/SyncQueueRecord.swift`
- [ ] `anyfleet/anyfleet/anyfleet/Services/ContentSyncService.swift`
- [ ] `anyfleet/anyfleet/anyfleet/Services/APIClient.swift`

**Modified Files:**
- [ ] `anyfleet/anyfleet/anyfleet/Data/Local/AppDatabase.swift` (add migration)
- [ ] `anyfleet/anyfleet/anyfleet/Data/Repositories/LocalRepository.swift` (add sync methods)
- [ ] `anyfleet/anyfleet/anyfleet/Services/VisibilityService.swift` (add enqueue calls)
- [ ] `anyfleet/anyfleet/anyfleet/App/AppDependencies.swift` (add services)
- [ ] `anyfleet/anyfleet/anyfleet/App/AppModel.swift` (add background sync)

**Test Files:**
- [ ] `anyfleetTests/Services/ContentSyncServiceTests.swift`
- [ ] `anyfleetTests/Services/APIClientTests.swift`
- [ ] `anyfleetTests/Integration/PublishFlowIntegrationTests.swift`

### Backend Files

**New Files:**
- [ ] `anyfleet-backend/app/models/content.py`
- [ ] `anyfleet-backend/app/schemas/content.py`
- [ ] `anyfleet-backend/app/api/v1/content.py`
- [ ] `anyfleet-backend/alembic/versions/2025_12_21_0900-create_shared_content_table.py`

**Modified Files:**
- [ ] `anyfleet-backend/app/models/user.py` (add relationship)
- [ ] `anyfleet-backend/app/api/v1/__init__.py` (register router)

**Test Files:**
- [ ] `anyfleet-backend/tests/test_content.py`

---

## Appendix B: Environment Configuration

### iOS Configuration

**Debug:**
- API Base URL: `http://127.0.0.1:8000/api/v1`
- Sync interval: 10 seconds
- Max retries: 3

**Production:**
- API Base URL: `https://api.anyfleet.app/api/v1`
- Sync interval: 30 seconds
- Max retries: 3

### Backend Configuration

**.env:**
```bash
# Database
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/anyfleet_db

# JWT
JWT_SECRET_KEY=your-secret-key
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30

# Apple Sign In
APPLE_CLIENT_ID=com.yourcompany.anyfleet
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_PRIVATE_KEY_PATH=/path/to/AuthKey_XXXXX.p8

# CORS
CORS_ORIGINS=["http://localhost:3000", "capacitor://localhost"]

# Rate Limiting
RATE_LIMIT_ENABLED=true
```

---

## Summary

This guide provides a complete implementation roadmap for content sharing with sync queue functionality. The phased approach ensures:

1. ✅ **Backend Foundation First:** API endpoints ready before iOS integration
2. ✅ **iOS Local Testing:** Sync queue works locally before network calls
3. ✅ **Gradual Integration:** API client tested independently, then integrated
4. ✅ **Comprehensive Testing:** Unit tests, integration tests, edge cases
5. ✅ **Safe Rollout:** Internal → Beta → Production with rollback plan

**Estimated Timeline:**
- Week 1: Backend API + iOS sync infrastructure
- Week 2: iOS API client + end-to-end testing
- Week 3: Beta testing + production deployment

**Key Success Metrics:**
- Sync success rate > 95%
- Average sync latency < 2 seconds
- Failed syncs retry successfully > 90%
- Zero data loss during network failures

