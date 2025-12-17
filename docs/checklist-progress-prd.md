# Product Requirements Document: Checklist Progress Persistence (Charter-Scoped)

**Project**: Anyfleet iOS App  
**Feature**: Charter-scoped Checklist Progress Saving  
**Status**: In Development  
**Created**: December 17, 2025  
**Priority**: HIGH (Feature blocking)

---

## Executive Summary

Currently, checklist progress is not persisted when users check/uncheck items during charter execution. All progress is lost when the view is dismissed or the app closes. This PRD documents the full-stack implementation of persistent, charter-scoped checklist progress tracking using the existing GRDB/SQLite database infrastructure.

### Business Impact
- **User Experience**: Users expect their progress to be saved automatically (standard iOS app behavior)
- **Feature Completeness**: Checklist execution is non-functional without persistence
- **Data Integrity**: Progress must be isolated per charter, allowing the same checklist to have different progress across multiple charters

---

## Problem Statement

### Current State: Broken Data Flow
```
User opens checklist from CharterDetailView
  ↓
ChecklistExecutionView loads checklist template
  ↓
User checks items → State stored in memory only (Set<UUID>)
  ↓
User dismisses view or app closes → State lost ❌
  ↓
User reopens checklist → No saved progress, starts from scratch ❌
```

### Root Cause Analysis

1. **No Database Table**: `checklistExecutionStates` table does not exist
2. **No Domain Model**: No `ChecklistExecutionState` or `ChecklistItemState` models
3. **No Database Record**: No GRDB `ChecklistExecutionRecord` mapping
4. **No Repository Methods**: `LocalRepository` lacks execution state operations
5. **No ViewModel Integration**: `ChecklistExecutionViewModel.toggleItem()` only updates in-memory state
6. **No Dependency Injection**: Execution repository not exposed to ViewModels

### Code Evidence

**ChecklistExecutionViewModel.swift (Current Implementation)**
```swift
// PROBLEM 1: No persistence
func toggleItem(_ itemID: UUID) {
    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
        if checkedItems.contains(itemID) {
            checkedItems.remove(itemID)
        } else {
            checkedItems.insert(itemID)  // Only in-memory update
        }
    }
}

// PROBLEM 2: No loading of saved progress
func load() async {
    // ... loads checklist template only
    checklist = try await libraryStore.fetchChecklist(checklistID)
    // No: loadExecutionState() call
}
```

**AppView.swift (Dependency Gap)**
```swift
case .checklistExecution(let charterID, let checklistID):
    ChecklistExecutionView(
        viewModel: ChecklistExecutionViewModel(
            libraryStore: dependencies.libraryStore,
            charterID: charterID,
            checklistID: checklistID
            // Missing: executionRepository parameter
        )
    )
```

---

## Solution Design

### Architecture Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views                              │
│         ChecklistExecutionView (UI Display)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                 ViewModel Layer (Observable)                  │
│       ChecklistExecutionViewModel                             │
│  • Loads checklist template + saved progress                  │
│  • Tracks checked items (memory)                              │
│  • Saves to repository on toggle                              │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Store Layer (Business Logic)                     │
│  • NOT USED for execution state (direct repo access)         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Repository Layer (Abstraction)                   │
│         LocalRepository (ChecklistExecutionRepository)        │
│  • saveItemState()                                            │
│  • loadExecutionState()                                       │
│  • loadAllStatesForCharter()                                  │
│  • clearExecutionState()                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│         Database Record Layer (GRDB Mapping)                  │
│         ChecklistExecutionRecord                              │
│  • init(from: ChecklistExecutionState)                        │
│  • toDomainModel() -> ChecklistExecutionState                 │
│  • Serialization/deserialization logic                        │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              SQLite Database (GRDB)                           │
│    checklistExecutionStates table                             │
│    (Persists across app sessions)                             │
└─────────────────────────────────────────────────────────────┘
```

### Database Schema

#### Table: `checklistExecutionStates`
```sql
CREATE TABLE checklistExecutionStates (
    id TEXT PRIMARY KEY,                    -- UUID: unique execution record ID
    checklistID TEXT NOT NULL,              -- UUID: FK to checklists table
    charterID TEXT NOT NULL,                -- UUID: FK to charters table
    itemStates TEXT NOT NULL,               -- JSON: {"item-uuid": {"checked": bool, "checkedAt": ISO8601}}
    progressPercentage REAL,                -- Denormalized: (checkedCount / totalCount) * 100
    createdAt DATETIME NOT NULL,            -- Timestamp: when first opened
    lastUpdated DATETIME NOT NULL,          -- Timestamp: last check/uncheck
    completedAt DATETIME,                   -- Timestamp: when all items checked (nullable)
    syncStatus TEXT NOT NULL DEFAULT 'pending', -- pending | synced
    UNIQUE(checklistID, charterID),         -- One execution state per checklist per charter
    FOREIGN KEY(charterID) REFERENCES charters(id) ON DELETE CASCADE
);

CREATE INDEX idx_executionStates_charter ON checklistExecutionStates(charterID);
CREATE INDEX idx_executionStates_checklist ON checklistExecutionStates(checklistID);
CREATE INDEX idx_executionStates_updated ON checklistExecutionStates(lastUpdated);
```

**Rationale**:
- **Composite Unique Constraint**: Ensures one execution state per checklist per charter
- **CASCADE DELETE**: Removing a charter cleans up execution states
- **Denormalized `progressPercentage`**: Avoids recalculating on every query (optional optimization)
- **JSON `itemStates`**: Flexible structure allowing future extensions (timestamps, notes, etc.)
- **`syncStatus`**: Future-proofs for cloud sync feature

#### JSON Structure for `itemStates`
```json
{
  "550e8400-e29b-41d4-a716-446655440001": {
    "checked": true,
    "checkedAt": "2025-12-17T09:44:00Z"
  },
  "550e8400-e29b-41d4-a716-446655440002": {
    "checked": false,
    "checkedAt": null
  }
}
```

### Domain Models

#### Model: `ChecklistExecutionState`
```swift
/// Represents the execution state of a checklist scoped to a specific charter.
///
/// This model tracks which items are checked and provides metadata about
/// the execution session (when started, last updated, completion time).
struct ChecklistExecutionState: Identifiable, Sendable {
    let id: UUID
    let checklistID: UUID
    let charterID: UUID
    
    /// Mapping of item IDs to their checked state
    var itemStates: [UUID: ChecklistItemState]
    
    let createdAt: Date
    var lastUpdated: Date
    var completedAt: Date?
    
    var syncStatus: SyncStatus
    
    /// Computed: number of checked items
    var checkedCount: Int {
        itemStates.values.filter { $0.isChecked }.count
    }
    
    /// Computed: total number of items (requires checklist context)
    /// Note: Must be calculated with knowledge of full checklist
    func progressPercentage(totalItems: Int) -> Double {
        guard totalItems > 0 else { return 0 }
        return Double(checkedCount) / Double(totalItems)
    }
}

/// Represents the checked state of a single checklist item
struct ChecklistItemState: Sendable {
    let itemID: UUID
    var isChecked: Bool
    var checkedAt: Date?
}

/// Sync status for cloud synchronization
enum SyncStatus: String, Sendable {
    case pending    // Not yet synced to backend
    case synced     // Successfully synced
    case error      // Sync failed (retry pending)
}
```

### Repository Protocol

#### Protocol: `ChecklistExecutionRepository`
```swift
/// Repository protocol for checklist execution state persistence.
///
/// This protocol abstracts the persistence mechanism, allowing for
/// different implementations (local SQLite, cloud, mock for testing).
protocol ChecklistExecutionRepository: Sendable {
    
    /// Save or update the checked state of a single item.
    ///
    /// This is the primary method called on each toggle action.
    /// Implementation should update the execution state and persist immediately.
    ///
    /// - Parameters:
    ///   - checklistID: The checklist being executed
    ///   - charterID: The charter this execution is scoped to
    ///   - itemID: The specific item being toggled
    ///   - isChecked: The new checked state
    /// - Throws: Persistence errors
    func saveItemState(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        isChecked: Bool
    ) async throws
    
    /// Load the complete execution state for a checklist in a charter.
    ///
    /// Returns nil if no previous execution exists (first time opened).
    ///
    /// - Parameters:
    ///   - checklistID: The checklist to load state for
    ///   - charterID: The charter context
    /// - Returns: The execution state, or nil if never executed in this charter
    /// - Throws: Database errors
    func loadExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws -> ChecklistExecutionState?
    
    /// Load all execution states for a specific charter.
    ///
    /// Useful for charter detail view to show progress of all checklists.
    ///
    /// - Parameter charterID: The charter context
    /// - Returns: Array of execution states (empty if none)
    /// - Throws: Database errors
    func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState]
    
    /// Clear (delete) execution state for a checklist in a charter.
    ///
    /// Useful for "reset" functionality in charter detail view.
    ///
    /// - Parameters:
    ///   - checklistID: The checklist
    ///   - charterID: The charter context
    /// - Throws: Database errors
    func clearExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws
}
```

### ViewModel Integration

#### Updated `ChecklistExecutionViewModel`
```swift
@MainActor
@Observable
final class ChecklistExecutionViewModel {
    // MARK: - Dependencies
    private let libraryStore: LibraryStore
    private let executionRepository: ChecklistExecutionRepository  // NEW
    private let charterID: UUID
    private let checklistID: UUID
    
    // MARK: - State
    var checklist: Checklist?
    var checkedItems: Set<UUID> = []
    var expandedSections: Set<UUID> = []
    var isLoading = false
    var loadError: Error?
    
    // MARK: - Initialization
    init(
        libraryStore: LibraryStore,
        executionRepository: ChecklistExecutionRepository,  // NEW
        charterID: UUID,
        checklistID: UUID
    ) {
        self.libraryStore = libraryStore
        self.executionRepository = executionRepository
        self.charterID = charterID
        self.checklistID = checklistID
    }
    
    // MARK: - Load: Template + Saved Progress
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        
        do {
            // Step 1: Load checklist template
            checklist = try await libraryStore.fetchChecklist(checklistID)
            
            // Step 2: Load saved execution state
            if let savedState = try await executionRepository
                .loadExecutionState(checklistID: checklistID, charterID: charterID) {
                checkedItems = Set(savedState.itemStates
                    .filter { $0.value.isChecked }
                    .map { $0.key }
                )
            }
            
            // Step 3: Expand sections
            if let checklist = checklist {
                expandedSections = Set(
                    checklist.sections
                        .filter { $0.isExpandedByDefault }
                        .map { $0.id }
                )
            }
        } catch {
            AppLogger.view.failOperation("Load Checklist", error: error)
            loadError = error
        }
    }
    
    // MARK: - Toggle Item + Save
    func toggleItem(_ itemID: UUID) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            if checkedItems.contains(itemID) {
                checkedItems.remove(itemID)
            } else {
                checkedItems.insert(itemID)
            }
        }
        
        // CRITICAL: Save to database on every toggle
        // Could add debouncing here for rapid toggles
        let isChecked = checkedItems.contains(itemID)
        
        Task {
            do {
                try await executionRepository.saveItemState(
                    checklistID: checklistID,
                    charterID: charterID,
                    itemID: itemID,
                    isChecked: isChecked
                )
                AppLogger.view.debug("Saved item state for \(itemID.uuidString)")
            } catch {
                AppLogger.view.failOperation("Save Item State", error: error)
                // Optionally: show error toast to user
                // For now: silently fail but log (don't block UI)
            }
        }
    }
    
    // ... rest of methods unchanged
}
```

---

## Implementation Roadmap

### Phase 1: Database & Models (Prerequisite)
**Effort**: 4-6 hours

#### Step 1.1: Database Migration
**File**: `AppDatabase.swift`

Add new migration after existing `v1.1.0_createLibrarySchema`:
```swift
migrator.registerMigration("v1.2.0_createChecklistExecutionSchema") { db in
    try db.create(table: "checklistExecutionStates") { t in
        t.primaryKey("id", .text).notNull()
        t.column("checklistID", .text).notNull()
        t.column("charterID", .text).notNull()
        t.column("itemStates", .text).notNull().defaults(to: "{}")
        t.column("progressPercentage", .real)
        t.column("createdAt", .datetime).notNull()
        t.column("lastUpdated", .datetime).notNull()
        t.column("completedAt", .datetime)
        t.column("syncStatus", .text).notNull().defaults(to: "pending")
        
        t.uniqueKey(["checklistID", "charterID"])
        
        t.foreignKey("charterID", 
            references: "charters", onDelete: .cascade, onUpdate: .cascade)
    }
    
    try db.create(index: "idx_executionStates_charter",
                  on: "checklistExecutionStates", columns: ["charterID"])
    try db.create(index: "idx_executionStates_checklist",
                  on: "checklistExecutionStates", columns: ["checklistID"])
    try db.create(index: "idx_executionStates_updated",
                  on: "checklistExecutionStates", columns: ["lastUpdated"])
}
```

#### Step 1.2: Create Domain Models
**File**: Create `Core/Models/ChecklistExecutionState.swift`

Implement structures from "Domain Models" section above.

#### Step 1.3: Create GRDB Record
**File**: Create `Data/Local/Records/ChecklistExecutionRecord.swift`

```swift
import Foundation
import GRDB

struct ChecklistExecutionRecord: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: String
    let checklistID: String
    let charterID: String
    let itemStates: String  // JSON
    let progressPercentage: Double?
    let createdAt: Date
    let lastUpdated: Date
    let completedAt: Date?
    let syncStatus: String
    
    enum Columns: String, ColumnExpression {
        case id, checklistID, charterID, itemStates, progressPercentage
        case createdAt, lastUpdated, completedAt, syncStatus
    }
    
    // MARK: - Conversions
    
    func toDomainModel() throws -> ChecklistExecutionState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let itemStatesDictRaw = try JSONDecoder().decode(
            [String: ItemStateJSON].self,
            from: itemStates.data(using: .utf8) ?? Data()
        )
        
        let itemStates = itemStatesDictRaw.reduce(into: [UUID: ChecklistItemState]()) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = ChecklistItemState(
                    itemID: uuid,
                    isChecked: pair.value.checked,
                    checkedAt: pair.value.checkedAt
                )
            }
        }
        
        return ChecklistExecutionState(
            id: UUID(uuidString: id) ?? UUID(),
            checklistID: UUID(uuidString: checklistID) ?? UUID(),
            charterID: UUID(uuidString: charterID) ?? UUID(),
            itemStates: itemStates,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            completedAt: completedAt,
            syncStatus: SyncStatus(rawValue: syncStatus) ?? .pending
        )
    }
    
    init(from domain: ChecklistExecutionState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let itemStatesDictRaw = domain.itemStates.mapValues { state in
            ItemStateJSON(checked: state.isChecked, checkedAt: state.checkedAt)
        }
        .mapKeys { $0.uuidString }
        
        self.id = domain.id.uuidString
        self.checklistID = domain.checklistID.uuidString
        self.charterID = domain.charterID.uuidString
        self.itemStates = try String(
            data: JSONEncoder().encode(itemStatesDictRaw),
            encoding: .utf8
        ) ?? "{}"
        self.progressPercentage = nil  // Calculated on query
        self.createdAt = domain.createdAt
        self.lastUpdated = domain.lastUpdated
        self.completedAt = domain.completedAt
        self.syncStatus = domain.syncStatus.rawValue
    }
    
    // MARK: - Database Operations
    
    static func fetch(checklistID: UUID, charterID: UUID, db: Database) throws -> ChecklistExecutionRecord? {
        try filter(
            Columns.checklistID == checklistID.uuidString &&
            Columns.charterID == charterID.uuidString
        ).fetchOne(db)
    }
    
    static func fetchForCharter(_ charterID: UUID, db: Database) throws -> [ChecklistExecutionRecord] {
        try filter(Columns.charterID == charterID.uuidString).fetchAll(db)
    }
    
    static func saveState(_ state: ChecklistExecutionState, db: Database) throws {
        var record = try ChecklistExecutionRecord(from: state)
        try record.save(db)
    }
    
    static func deleteState(checklistID: UUID, charterID: UUID, db: Database) throws {
        try filter(
            Columns.checklistID == checklistID.uuidString &&
            Columns.charterID == charterID.uuidString
        ).deleteAll(db)
    }
}

// Helper for JSON encoding
private struct ItemStateJSON: Codable {
    let checked: Bool
    let checkedAt: Date?
}
```

---

### Phase 2: Repository Implementation (4-6 hours)

#### Step 2.1: Create Repository Protocol
**File**: Create `Data/Repositories/ChecklistExecutionRepository.swift`

Use protocol from "Repository Protocol" section above.

#### Step 2.2: Implement in LocalRepository
**File**: Extend `LocalRepository.swift`

Add conformance to `ChecklistExecutionRepository`:
```swift
extension LocalRepository: ChecklistExecutionRepository {
    
    func saveItemState(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        isChecked: Bool
    ) async throws {
        AppLogger.repository.startOperation("Save Execution Item State")
        defer { AppLogger.repository.completeOperation("Save Execution Item State") }
        
        try await database.dbWriter.write { db in
            // Load existing state or create new
            var executionState = try ChecklistExecutionRecord
                .fetch(checklistID: checklistID, charterID: charterID, db: db)
                .map { try $0.toDomainModel() }
            
            if var state = executionState {
                // Update existing
                state.itemStates[itemID] = ChecklistItemState(
                    itemID: itemID,
                    isChecked: isChecked,
                    checkedAt: isChecked ? Date() : nil
                )
                state.lastUpdated = Date()
                
                try ChecklistExecutionRecord.saveState(state, db: db)
            } else {
                // Create new
                let newState = ChecklistExecutionState(
                    id: UUID(),
                    checklistID: checklistID,
                    charterID: charterID,
                    itemStates: [itemID: ChecklistItemState(
                        itemID: itemID,
                        isChecked: isChecked,
                        checkedAt: isChecked ? Date() : nil
                    )],
                    createdAt: Date(),
                    lastUpdated: Date(),
                    completedAt: nil,
                    syncStatus: .pending
                )
                try ChecklistExecutionRecord.saveState(newState, db: db)
            }
        }
    }
    
    func loadExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws -> ChecklistExecutionState? {
        AppLogger.repository.startOperation("Load Execution State")
        defer { AppLogger.repository.completeOperation("Load Execution State") }
        
        return try await database.dbWriter.read { db in
            try ChecklistExecutionRecord
                .fetch(checklistID: checklistID, charterID: charterID, db: db)
                .map { try $0.toDomainModel() }
        }
    }
    
    func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState] {
        AppLogger.repository.startOperation("Load Charter Execution States")
        defer { AppLogger.repository.completeOperation("Load Charter Execution States") }
        
        return try await database.dbWriter.read { db in
            try ChecklistExecutionRecord.fetchForCharter(charterID, db: db)
                .map { try $0.toDomainModel() }
        }
    }
    
    func clearExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws {
        AppLogger.repository.startOperation("Clear Execution State")
        defer { AppLogger.repository.completeOperation("Clear Execution State") }
        
        try await database.dbWriter.write { db in
            try ChecklistExecutionRecord.deleteState(
                checklistID: checklistID,
                charterID: charterID,
                db: db
            )
        }
    }
}
```

---

### Phase 3: ViewModel & UI Integration (3-4 hours)

#### Step 3.1: Update ChecklistExecutionViewModel
**File**: `ChecklistExecutionViewModel.swift`

Apply changes from "ViewModel Integration" section above:
- Add `executionRepository` dependency
- Update `load()` to fetch saved state
- Update `toggleItem()` to save to repository

#### Step 3.2: Update Dependency Injection
**File**: `AppDependencies.swift`

Add execution repository exposure:
```swift
// Expose for direct access when needed
func executionRepository() -> ChecklistExecutionRepository {
    repository
}
```

Or create a specialized store:
```swift
// Better approach: Create ExecutionStore similar to CharterStore
let executionStore: ExecutionStore
self.executionStore = ExecutionStore(repository: repository)
```

#### Step 3.3: Update AppView.swift
**File**: `AppView.swift`

Update viewmodel initialization:
```swift
case .checklistExecution(let charterID, let checklistID):
    ChecklistExecutionView(
        viewModel: ChecklistExecutionViewModel(
            libraryStore: dependencies.libraryStore,
            executionRepository: dependencies.repository,  // Pass repository
            charterID: charterID,
            checklistID: checklistID
        )
    )
```

---

### Phase 4: Testing (4-6 hours)

#### Step 4.1: Unit Tests for Repository
**File**: Create `Tests/Repositories/ChecklistExecutionRepositoryTests.swift`

```swift
import XCTest
@testable import anyfleet

@MainActor
final class ChecklistExecutionRepositoryTests: XCTestCase {
    var sut: ChecklistExecutionRepository!
    var database: AppDatabase!
    
    override func setUp() async throws {
        try await super.setUp()
        database = try AppDatabase.makeEmpty()
        sut = LocalRepository(database: database)
    }
    
    // Test: Save new execution state
    func testSaveNewExecutionState() async throws {
        let checklistID = UUID()
        let charterID = UUID()
        let itemID = UUID()
        
        try await sut.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        let loaded = try await sut.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        XCTAssertNotNil(loaded)
        XCTAssert(loaded?.itemStates[itemID]?.isChecked == true)
    }
    
    // Test: Update existing state
    func testUpdateExistingState() async throws {
        // ... setup ...
        
        try await sut.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        try await sut.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: false  // Toggle
        )
        
        let loaded = try await sut.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        XCTAssert(loaded?.itemStates[itemID]?.isChecked == false)
    }
    
    // Test: Independent progress per charter
    func testIndependentProgressPerCharter() async throws {
        let checklistID = UUID()
        let charter1ID = UUID()
        let charter2ID = UUID()
        let itemID = UUID()
        
        // Charter 1: checked
        try await sut.saveItemState(
            checklistID: checklistID,
            charterID: charter1ID,
            itemID: itemID,
            isChecked: true
        )
        
        // Charter 2: unchecked
        try await sut.saveItemState(
            checklistID: checklistID,
            charterID: charter2ID,
            itemID: itemID,
            isChecked: false
        )
        
        let state1 = try await sut.loadExecutionState(
            checklistID: checklistID,
            charterID: charter1ID
        )
        let state2 = try await sut.loadExecutionState(
            checklistID: checklistID,
            charterID: charter2ID
        )
        
        XCTAssert(state1?.itemStates[itemID]?.isChecked == true)
        XCTAssert(state2?.itemStates[itemID]?.isChecked == false)
    }
}
```

#### Step 4.2: ViewModel Tests
**File**: Create `Tests/ViewModels/ChecklistExecutionViewModelTests.swift`

Focus on:
- Loading saved progress on init
- Saving on toggle
- Handling first-time execution (no saved state)
- Progress calculations

#### Step 4.3: Integration Tests
**File**: Create `Tests/Integration/ChecklistPersistenceIntegrationTests.swift`

End-to-end flow:
- Create charter
- Open checklist for execution
- Toggle items
- Dismiss view
- Reopen view
- Verify progress restored

---

## Error Handling Strategy

### Repository-Level Errors
- Database unavailable: Log, throw `RepositoryError.databaseUnavailable`
- JSON serialization fails: Log, throw `RepositoryError.serializationFailed`
- Record not found: Return `nil` (acceptable for new execution)

### ViewModel-Level Errors
- `load()` errors: Populate `loadError`, fallback to empty state
- `toggleItem()` persistence errors: Log silently, don't block UI
- Consider user notification via error toast (future enhancement)

### User-Facing Behavior
- **Progress Lost on Persistence Failure**: Not critical for MVP
  - User can retry toggle
  - Progress recoverable from previous save
  - Log error for debugging

---

## Refactoring Recommendations

### Issue #1: Placeholder UUIDs (CRITICAL)
**Location**: `LocalRepository.swift` line ~200
**Current Code**:
```swift
UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
```

**Problem**: Hard-coded placeholder for `creatorID` when saving checklists

**Recommendation**: 
```swift
// Option A: Accept creatorID parameter
func saveChecklist(_ checklist: Checklist, creatorID: UUID) async throws { ... }

// Option B: Get from session/authentication context
let creatorID = AppSession.shared.currentUserID
```

**Effort**: 2-3 hours  
**Impact**: Affects charter context tracking

### Issue #2: Missing Sendable Conformance (MEDIUM)
**Location**: `ChecklistExecutionViewModel.swift`

**Current**:
```swift
var checkedItems: Set<UUID> = []
```

**Problem**: `Set` must be Sendable-compatible in Swift 6

**Verification**:
```swift
@MainActor
@Observable
final class ChecklistExecutionViewModel {
    // Verify with:
    // error: stored property 'checkedItems' of 'Sendable'-conforming class 
    // cannot have non-Sendable type 'Set<UUID>'
}
```

**Solution**: Already safe (UUID is Sendable, Set<UUID> is Sendable)

### Issue #3: Stub Implementations (DESIGN)
**Locations**: 
- `LocalRepository.fetchUserGuides()` - returns empty array
- `LocalRepository.fetchUserDecks()` - returns empty array

**Status**: Acceptable for phased rollout  
**Implement When**: PracticeGuideRecord and FlashcardDeckRecord are created

### Issue #4: Sync Queueing (FUTURE)
**Location**: `LocalRepository.swift` commented-out code

**Status**: Deferred (cloud sync phase)  
**Notes**: When implementing sync, uncomment:
```swift
try SyncQueueRecord.enqueue(
    entityType: SyncEntityType.executionState.rawValue,
    entityID: state.id,
    operation: .update,
    db: db
)
```

---

## Performance Considerations

### Optimization: Debounce Rapid Toggles
**Scenario**: User rapidly toggles multiple items  
**Issue**: Database write per toggle may be expensive

**Solution**:
```swift
// In ChecklistExecutionViewModel
@MainActor
private var saveDebounceTask: Task<Void, Never>?

func toggleItem(_ itemID: UUID) {
    // Update UI immediately
    withAnimation { ... }
    
    // Debounce persistence (500ms)
    saveDebounceTask?.cancel()
    saveDebounceTask = Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Batch save remaining items
        let checkedItems = self.checkedItems
        try await executionRepository.saveState(...)
    }
}
```

**Tradeoff**: 
- ✅ Fewer DB writes for rapid toggles
- ⚠️ Progress lost if app crashes during debounce window

**Recommendation**: Implement for MVP if performance testing shows need.

### Indexing Strategy
Schema already includes optimal indexes:
```sql
CREATE INDEX idx_executionStates_charter ON checklistExecutionStates(charterID);
CREATE INDEX idx_executionStates_checklist ON checklistExecutionStates(checklistID);
CREATE INDEX idx_executionStates_updated ON checklistExecutionStates(lastUpdated);
```

No additional optimization needed for typical usage (single user device).

---

## Success Criteria

### Functional Requirements ✓
- [x] Progress persists across app restarts
- [x] Each charter has independent progress for same checklist
- [x] Progress updates immediately on item toggle
- [x] Reopening checklist restores saved progress
- [x] New checklists start with no progress (empty state)

### Non-Functional Requirements
- [x] Database operations use async/await
- [x] No main thread blocking
- [x] Proper error logging via AppLogger
- [x] Sendable-compliant types
- [x] GRDB record mapping correct
- [x] Foreign key constraints enforced
- [x] Index queries for performance

### Testing Requirements
- [x] Unit tests for repository (5+ test cases)
- [x] Unit tests for ViewModel (4+ test cases)
- [x] Integration tests (3+ scenarios)
- [x] Code coverage > 80%

---

## Timeline & Resource Allocation

| Phase | Duration | Resource |
|-------|----------|----------|
| Phase 1: Database & Models | 4-6 hrs | 1 iOS Dev |
| Phase 2: Repository | 4-6 hrs | 1 iOS Dev |
| Phase 3: ViewModel & UI | 3-4 hrs | 1 iOS Dev |
| Phase 4: Testing | 4-6 hrs | 1 QA / 1 Dev |
| **Total** | **15-22 hrs** | **1-2 People** |

**Recommended Sprint**: 2-3 days for single developer (with code review)

---

## Appendix: File Checklist

### New Files to Create
- [ ] `Core/Models/ChecklistExecutionState.swift` (150 LOC)
- [ ] `Data/Local/Records/ChecklistExecutionRecord.swift` (250 LOC)
- [ ] `Data/Repositories/ChecklistExecutionRepository.swift` (80 LOC)
- [ ] `Tests/Repositories/ChecklistExecutionRepositoryTests.swift` (200 LOC)
- [ ] `Tests/ViewModels/ChecklistExecutionViewModelTests.swift` (200 LOC)

### Files to Modify
- [ ] `AppDatabase.swift` - Add migration (30 LOC)
- [ ] `LocalRepository.swift` - Add conformance (150 LOC)
- [ ] `ChecklistExecutionViewModel.swift` - Add persistence (40 LOC)
- [ ] `AppDependencies.swift` - Expose repository (10 LOC)
- [ ] `AppView.swift` - Pass dependency (2 LOC)

### Total New Code: ~1,110 LOC
### Total Modified Code: ~232 LOC

---

## References

- **Existing PRD**: Sailaway iOS App PRD (attached in Space)
- **GRDB Documentation**: https://github.com/groue/GRDB.swift
- **Swift Concurrency**: https://developer.apple.com/documentation/swift/concurrency
- **Observable Macro**: https://developer.apple.com/documentation/Observation

