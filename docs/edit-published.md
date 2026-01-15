# Edit Published Content Issues & Solutions

## Problems Identified

### 1. JSON Serialization Inconsistencies
**Issue**: Published content edits failed with "data has invalid format" when loading from discover.

**Root Causes**:
- **Missing Section Properties**: `LibraryStore.triggerPublishUpdate()` omitted `isExpandedByDefault` and `sortOrder` from section data, creating inconsistent JSON structure compared to initial publish
- **Nil Value Handling**: Using `item.estimatedMinutes as Any` and `item.itemDescription as Any` cast nil values to problematic Foundation objects that couldn't be properly serialized/deserialized
- **Date Decoding**: Missing `dateDecodingStrategy = .iso8601` in `DiscoverContentReaderViewModel.parseChecklist()`

**Evidence**: Debug logs showed different JSON structures between initial publish and publish updates.

### 2. Database Persistence Issues
**Issue**: Published items appeared private after publish-edit cycle, indicating visibility wasn't properly persisted.

**Root Causes**:
- **`SyncQueueService.handlePublish()` Incomplete Updates**: Only set `publicMetadata` but failed to update `visibility = .public`, `publicID`, and `publishedAt` in database
- **Memory-Only Storage**: Changes were applied in-memory but not persisted to database, causing loss

**Evidence**: Debug logs showed items fetched with `visibility: private, publicID: nil` despite successful backend publishing.

### 3. Content Loading Failures
**Issue**: Published content couldn't be loaded in discover section after edits.

**Root Cause**: Date decoding strategy mismatch between encoding (ISO8601) and decoding (default Gregorian).

## Prevention Measures

1. **Type Safety**: Use proper Swift types instead of `Any` for JSON construction
2. **Consistency Checks**: Ensure publish and update operations produce identical JSON structures
3. **Database Verification**: Test database state, not just in-memory state
4. **Integration Tests**: Full publish-edit-publish cycles to catch regressions
5. **Debug Logging**: Maintain visibility into serialization and persistence operations

## Test Coverage 

### 1. Publish-Edit-Publish Cycle Test

### 2. JSON Structure Consistency Test

### 3. Discover Content Parsing Test
