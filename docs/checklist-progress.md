# Checklist Progress Persistence

## Current State

### Problem
Checklist progress is **not persisted** when users check/uncheck items in a checklist execution view. All progress is lost when:
- The view is dismissed
- The app is closed
- The user navigates away

### Current Implementation

#### ChecklistExecutionViewModel
- **Location**: `anyfleet/Features/Checklist/ChecklistExecutionViewModel.swift`
- **State**: Tracks checked items in memory only (`checkedItems: Set<UUID>`)
- **Issues**:
  - `toggleItem()` only updates in-memory state (line 117-127)
  - `load()` only loads checklist template, not saved progress (line 85-112)
  - No persistence layer integration
  - No repository methods for saving/loading execution state

#### Data Flow (Broken)
```
User opens checklist from CharterDetailView
  ↓
ChecklistExecutionView loads
  ↓
ChecklistExecutionViewModel.load() → fetches checklist template only
  ↓
User checks items → toggleItem() → updates memory only
  ↓
User dismisses → state lost ❌
  ↓
User reopens → starts fresh with no saved progress ❌
```

### Missing Infrastructure

1. **Database Table**: No `checklistExecutionStates` table exists
2. **Database Record**: No `ChecklistExecutionRecord` for GRDB persistence
3. **Repository Methods**: No methods in `LocalRepository` for execution state
4. **Domain Model**: No `ChecklistExecutionState` model for charter-scoped progress

---

## Future State

### Goal
Checklist progress should be **persisted per charter** so that:
- Progress is saved immediately when items are checked/unchecked
- Progress is restored when the checklist is reopened
- Each charter maintains its own independent progress for the same checklist
- Progress persists across app restarts

### Target Implementation

#### Data Flow (Fixed)
```
User opens checklist from CharterDetailView
  ↓
ChecklistExecutionView loads
  ↓
ChecklistExecutionViewModel.load() → fetches checklist template + saved progress
  ↓
User checks items → toggleItem() → updates memory + saves to database
  ↓
User dismisses → state persisted ✅
  ↓
User reopens → restores saved progress ✅
```

### Architecture

#### Database Schema
```sql
CREATE TABLE checklistExecutionStates (
  id TEXT PRIMARY KEY,
  checklistID TEXT NOT NULL,
  charterID TEXT NOT NULL,
  itemStates TEXT,  -- JSON: { "item-uuid": { "checked": bool, "checkedAt": Date? } }
  createdAt DATETIME NOT NULL,
  lastUpdated DATETIME NOT NULL,
  completedAt DATETIME,
  syncStatus TEXT NOT NULL DEFAULT 'pending',
  UNIQUE(checklistID, charterID)
);
```

#### Domain Model
```swift
struct ChecklistExecutionState {
  let id: UUID
  let checklistID: UUID
  let charterID: UUID
  var itemStates: [UUID: ChecklistItemState]  // itemID -> state
  let createdAt: Date
  var lastUpdated: Date
  var completedAt: Date?
}

struct ChecklistItemState {
  let itemID: UUID
  var isChecked: Bool
  var checkedAt: Date?
}
```

#### Repository Interface
```swift
protocol ChecklistExecutionRepository: Sendable {
  func saveItemState(
    checklistID: UUID,
    charterID: UUID,
    itemID: UUID,
    isChecked: Bool
  ) async throws
  
  func loadExecutionState(
    checklistID: UUID,
    charterID: UUID
  ) async throws -> ChecklistExecutionState?
  
  func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState]
}
```

---

## Files That Need to Be Touched

### 1. Database Layer

#### `anyfleet/Data/Local/AppDatabase.swift`
- **Action**: Add migration `v1.2.0_createChecklistExecutionSchema`
- **Changes**:
  - Create `checklistExecutionStates` table
  - Add unique constraint on `(checklistID, charterID)`
  - Add indexes for efficient queries

#### `anyfleet/Data/Local/Records/ChecklistExecutionRecord.swift` ⭐ **NEW FILE**
- **Action**: Create new GRDB record type
- **Purpose**: Map between database and domain model
- **Methods**:
  - `init(from: ChecklistExecutionState)` - domain → record
  - `toDomainModel() -> ChecklistExecutionState` - record → domain
  - `static func fetch(checklistID:charterID:db:)` - query by IDs
  - `static func fetchForCharter(_:db:)` - query all for charter
  - `static func saveState(_:db:)` - save/update state

### 2. Domain Models

#### `anyfleet/Core/Models/ChecklistExecutionState.swift` ⭐ **NEW FILE**
- **Action**: Create domain model
- **Purpose**: Represent execution state in business logic
- **Properties**: As defined in Future State section above

### 3. Repository Layer

#### `anyfleet/Data/Repositories/ChecklistExecutionRepository.swift` ⭐ **NEW FILE**
- **Action**: Create protocol defining execution state operations
- **Purpose**: Abstract persistence interface

#### `anyfleet/Data/Repositories/LocalRepository.swift`
- **Action**: Add implementation of `ChecklistExecutionRepository`
- **Changes**:
  - Implement `saveItemState(checklistID:charterID:itemID:isChecked:)`
  - Implement `loadExecutionState(checklistID:charterID:)`
  - Implement `loadAllStatesForCharter(_:)`
  - Use `ChecklistExecutionRecord` for database operations

### 4. ViewModel Layer

#### `anyfleet/Features/Checklist/ChecklistExecutionViewModel.swift`
- **Action**: Add persistence integration
- **Changes**:
  - Add `repository: ChecklistExecutionRepository` dependency
  - In `load()`: After loading checklist, fetch saved state and populate `checkedItems`
  - In `toggleItem()`: After updating memory, call `repository.saveItemState()`
  - Add `saveProgress()` method for batch saves (optional optimization)
  - Handle loading errors gracefully (fallback to empty state)

### 5. Dependency Injection

#### `anyfleet/App/AppDependencies.swift`
- **Action**: Ensure repository is available
- **Changes**:
  - Verify `LocalRepository` conforms to `ChecklistExecutionRepository`
  - Pass repository to `ChecklistExecutionViewModel` (via factory or direct injection)

#### `anyfleet/App/AppView.swift`
- **Action**: Update view model initialization
- **Changes**:
  - Pass repository to `ChecklistExecutionViewModel` when creating from route
  - Access via `@Environment(\.appDependencies)`

### 6. Testing

#### `anyfleet/anyfleetTests/ChecklistExecutionViewModelTests.swift` ⭐ **NEW FILE**
- **Action**: Create unit tests
- **Tests**:
  - Loading saved progress
  - Saving progress on toggle
  - Handling missing saved state (first time)
  - Multiple charters with same checklist (independent progress)

#### `anyfleet/anyfleetTests/ChecklistExecutionRecordTests.swift` ⭐ **NEW FILE**
- **Action**: Create database record tests
- **Tests**:
  - Record serialization/deserialization
  - Database queries
  - Unique constraint enforcement

---

## Implementation Order

1. **Database Schema** (AppDatabase.swift migration)
2. **Domain Model** (ChecklistExecutionState.swift)
3. **Database Record** (ChecklistExecutionRecord.swift)
4. **Repository Protocol** (ChecklistExecutionRepository.swift)
5. **Repository Implementation** (LocalRepository.swift)
6. **ViewModel Integration** (ChecklistExecutionViewModel.swift)
7. **Dependency Injection** (AppView.swift, AppDependencies.swift)
8. **Tests** (Test files)

---

## Notes

- **Performance**: Consider debouncing saves if users toggle items rapidly
- **Sync**: Future sync implementation should use `syncStatus` field
- **Completion**: Track `completedAt` when all items are checked
- **Migration**: Existing users will start with empty progress (acceptable)
- **Error Handling**: Persistence failures should not block UI, but should be logged

