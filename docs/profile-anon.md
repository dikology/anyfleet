# Anonymous User Profile Analysis

## Problem Analysis: Forking Failure with Anonymous Users

### Issue Description
Users created through Apple Sign In without providing full name information (anonymous users) experience forking failures when attempting to fork their own published content. The error manifests as "Данные не удалось прочитать, так как они имеют неверный формат" (Data could not be read because it has an incorrect format) during the JSON decoding phase.

### Root Cause Analysis

#### 1. Anonymous User Creation Process
When users sign in with Apple Sign In:

```swift
// Apple credential shows: fullName: available, email: nil
// But actual name extraction fails: givenName=nil, familyName=nil
// Backend creates user with: username=None
```

**Backend Logic (auth.py:125-131):**
```python
# Create new user
user = User(
    apple_id=apple_id,
    email=email,
    username=display_name,  # This becomes None for anonymous users
)
```

#### 2. Content Publishing Issues
When publishing content, the attribution system breaks:

**Backend Publishing (content.py:106):**
```python
return PublishContentResponse(
    author_username=current_user.username,  # None for anonymous users
    # ...
)
```

**Frontend Publishing (VisibilityService.swift:168):**
```swift
authorUsername: currentUser.username ?? currentUser.email
```

This creates inconsistency between frontend and backend attribution.

#### 3. Attribution Chain Corruption
When listing public content, the backend traverses fork attribution chains:

**Backend Attribution Logic (content.py:298):**
```python
original_author_username = original_content.user.username  # None for anonymous users
```

This propagates `None` values through the attribution chain, breaking the fork metadata.

#### 4. JSON Decoding Failure
The fork operation fails during content_data deserialization:

**Frontend Fork Logic (LibraryStore.swift:166-171):**
```swift
let checklistData = try JSONSerialization.data(withJSONObject: contentData)
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
var checklist = try decoder.decode(Checklist.self, from: checklistData)  // FAILS HERE
```

### Contributing Factors

#### Content Data Format Incompatibility
The content stored during publishing may not match the expected Checklist model format due to:
- Date encoding/decoding strategy mismatches
- Missing or extra fields in stored JSON
- Encoding differences between local storage and backend storage

#### Attribution Metadata Corruption
The `original_author_username` field being `None` may cause downstream validation or processing failures.

### Recommended Solutions

#### Short-term Fix: Handle Anonymous Users Gracefully

1. **Backend: Use Email as Fallback for Username**
```python
# In auth.py, user creation
user = User(
    apple_id=apple_id,
    email=email,
    username=display_name or f"Anonymous-{apple_id[:8]}",  # Generate fallback
)
```

2. **Frontend: Ensure Consistent Attribution**
```swift
// In VisibilityService.swift
authorUsername: currentUser.username ?? "Anonymous User"
```

#### Medium-term: Implement Profile Completion Flow

1. **Detect Anonymous Users**
```swift
struct User {
    var needsProfileCompletion: Bool {
        username?.isEmpty ?? true || username == "Anonymous-\(appleId.prefix(8))"
    }
}
```

2. **Profile Completion Prompt**
- Show in-app prompt for anonymous users to complete their profile
- Offer to set username based on Apple full name if available
- Allow manual username entry

3. **Backend Profile Update Endpoint**
```python
@router.put("/profile")
async def update_profile(
    current_user: CurrentUser,
    username: str | None = None,
    # ...
):
    # Update user profile
    # Re-attribute existing content
```

#### Long-term: Robust Attribution System

1. **Separate Author Identity from User Identity**
- Create Author model with display names
- Allow anonymous publishing with generated author names
- Maintain attribution chains independently

2. **Content Data Validation**
- Implement schema validation for content_data
- Ensure round-trip compatibility between encode/decode cycles
- Add migration logic for existing anonymous content

### Implementation Priority

1. **Immediate**: Fix attribution fallback to prevent None values
2. **Week 1**: Add profile completion detection and UI
3. **Week 2**: Implement profile update backend/frontend
4. **Month 1**: Refactor attribution system for robustness

### Testing Requirements

1. **Anonymous User Flow**: Test complete sign-in → publish → fork cycle
2. **Attribution Chain**: Verify fork attribution works across anonymous users
3. **Profile Completion**: Test profile updates re-attribute existing content
4. **Backward Compatibility**: Ensure existing anonymous content remains functional

### Monitoring

Add logging for:
- Anonymous user creation rate
- Forking success/failure rates by user type
- Attribution chain integrity checks
