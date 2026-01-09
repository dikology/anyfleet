# Profile Design Review Summary
**Date:** January 9, 2026  
**Reviewer:** AI Design Consultant  
**Files Reviewed:**
- `anyfleet/Features/Profile/ProfileView.swift`
- `anyfleet/Features/Discover/AuthorProfileModal.swift`

---

## Executive Summary

Both profile views are well-architected with clean MVVM patterns and consistent design system usage. However, they currently serve only authentication purposes and lack the visual appeal and information depth needed for a social sailing platform. The proposed enhancements will transform these views into rich, engaging profile experiences that build trust and facilitate connections between sailors.

**Overall Assessment:** ⚠️ Functional but needs significant enhancement for production-ready user profiles.

---

## ProfileView.swift Review

### Architecture: ✅ Excellent (9/10)

**Strengths:**
- Clean `@Observable` ViewModel pattern
- Proper separation of concerns
- Good error handling with `ErrorBanner`
- Prepared for Phase 2 features (metrics, verification)
- Excellent preview setup with realistic test data
- MainActor annotations for thread safety

**Recommendations:**
- Consider splitting into multiple view files as complexity grows
- Add unit tests for ProfileViewModel business logic
- Consider view model dependency injection for better testability

---

### User Experience: ⚠️ Needs Improvement (5/10)

#### Current State
**Authenticated View:**
- ✅ Simple profile editing (username only)
- ✅ Sign out functionality
- ✅ Member since date
- ⚠️ Generic circular avatar with no customization
- ❌ No visual personality or storytelling
- ❌ Minimal user information displayed
- ❌ Hidden reputation/metrics sections (awaiting Phase 2)

**Unauthenticated View:**
- ✅ Clear welcome message
- ✅ Simple Apple Sign-In flow
- ✅ Typography-focused design
- ⚠️ Could be more engaging visually

#### Key Issues

**1. Visual Hierarchy Problem**
```swift
// Current: Circular avatar with gradient background
Circle()
    .fill(DesignSystem.Gradients.primary)
    .frame(width: 120, height: 120)
```
**Issue:** Takes up valuable space but conveys no personality or information.

**Recommendation:** Replace with hero image section (280pt height) showing user's uploaded photo with name overlay and key stats immediately visible.

**2. Information Scarcity**
Currently displays only:
- Username/email
- Created date
- (Hidden) Contribution metrics

**Missing critical information:**
- Bio/description
- Location/nationality
- Languages spoken
- Contact information
- Skills and experience
- Qualifications/certifications
- Personality indicators (hobbies, preferences)

**3. Engagement Gap**
After sign-in, users see:
- A circle
- Their email
- A sign-out button

**Problem:** No reason to return to profile, no incentive to complete it, no value provided.

**Solution:** Profile completion gamification + immediate value (e.g., "Add bio to get 3x more views")

---

### Information Architecture: ⚠️ Needs Expansion (4/10)

#### Current Structure
```
Profile
├── Avatar (circular placeholder)
├── User Info
│   ├── Username
│   ├── Email
│   └── Member Since
├── [Hidden] Reputation Section
│   ├── Verification Tier
│   └── Metrics Grid
├── [Hidden] Content Ownership
└── Account Management
    └── Sign Out
```

#### Recommended Structure
```
Profile
├── Hero Image Section (new)
│   ├── Backdrop Photo
│   ├── Name + Location
│   ├── Experience Badge
│   └── Profile Completion %
├── Stats Grid (enhanced)
│   ├── Sea Miles
│   ├── Avg Rating
│   └── Time at Sea
├── Quick Facts
│   ├── Crewing Tags
│   └── Languages
├── Bio Section (new)
│   ├── Languages
│   └── Multi-paragraph Bio
├── Qualifications (new)
│   └── Credential Cards
├── Skills (new)
│   └── Skill Pills with Proficiency
├── Experience Metrics (new)
│   ├── Sea Days
│   ├── Vessels Sailed
│   └── Preferred Roles
├── Hobbies (new)
│   └── Interest Cards
├── Contact & Social (new)
│   ├── Email (with privacy toggle)
│   ├── Telegram/WhatsApp
│   └── Social Links
└── Account Management
    ├── Privacy Settings
    └── Sign Out
```

---

### Visual Design: ⚠️ Needs Enhancement (5/10)

#### Current Design Patterns
- ✅ Consistent spacing using DesignSystem.Spacing
- ✅ Proper color usage from DesignSystem.Colors
- ✅ Typography scale adherence
- ✅ Card-based layouts with `.sectionContainer()`
- ⚠️ Limited visual interest (mostly text)
- ❌ No hero images or backdrop visuals
- ❌ No color coding by category
- ❌ Limited use of icons and visual metaphors

#### Specific Issues

**1. Avatar Section (Lines 218-238)**
```swift
// Current implementation
Circle()
    .fill(DesignSystem.Gradients.primary)
    .frame(width: 120, height: 120)
    
Image(systemName: "person.fill")
    .font(.system(size: 40, weight: .medium))
```

**Issue:** 
- Takes up prime real estate
- Conveys zero information
- Not memorable or distinctive
- No way for users to customize

**Fix:** Replace with `ProfileHeroImage` component showing uploaded photo with gradient overlay and key info.

**2. Stats Section (Lines 412-430)**
Hidden behind `if let metrics = viewModel.contributionMetrics`. Good implementation but invisible until Phase 2 backend.

**Recommendation:** 
- Show with placeholder data or "0" values
- Add "Coming soon" badges
- Allow users to see structure even if data isn't populated

**3. Edit Mode UI (Lines 243-294)**
Current profile editing is functional but cramped:
- TextField in white box (lines 250-258)
- Cancel/Save buttons immediately below

**Issues:**
- No preview of how it will look
- No character counter for bio (when added)
- Can't see full context while editing

**Recommendation:**
- Inline editing with live preview
- Character counters
- Section-by-section editing vs. full-page edit mode

---

### Code Quality: ✅ Good (8/10)

**Strengths:**
- Well-structured, readable code
- Proper use of SwiftUI best practices
- Good separation into helper functions
- Consistent naming conventions
- Proper MainActor annotations

**Minor Issues:**
- Very long file (771 lines) - could be split
- Some commented-out code (lines 484-505)
- Preview data could be extracted to separate file

**Recommendations:**
```swift
// Extract to separate files:
// - ProfileViewModel.swift
// - ProfileView+Components.swift
// - ProfileView+Sections.swift
// - ProfileView+Previews.swift
```

---

## AuthorProfileModal.swift Review

### Architecture: ✅ Simple and Clean (7/10)

**Strengths:**
- Simple, focused component
- Proper modal presentation
- Clean dismiss handling
- No over-engineering

**Limitations:**
- Too simple for production use
- No data fetching logic
- No error states
- Only accepts username string (needs full profile object)

---

### User Experience: ❌ Needs Complete Redesign (2/10)

#### Current State
```
┌─────────────────────────┐
│      [✕ close]         │
│                         │
│   [Generic Avatar]      │
│                         │
│     SailorMaria         │
│                         │
│   Coming Soon Title     │
│   Coming Soon Message   │
│                         │
│     [Close Button]      │
└─────────────────────────┘
```

**Problems:**
1. No actual functionality - just a placeholder
2. Wastes modal space with empty states
3. Generic avatar (same as ProfileView issue)
4. No actionable information
5. No reason to open this modal
6. Two close buttons (redundant)

#### Required Redesign

**Inspiration:** Reference Image #2 (Natasha Romanoff card)

**New Structure:**
```
┌─────────────────────────────┐
│ [Full Backdrop Image]   [✕] │
│                             │
│   [Dark Gradient]           │
│                             │
│   Name ✓ Verified           │
│   Short bio line...         │
│                             │
│   ⭐ 4.8  💰 $45k+  ⏱ $50/hr │
│   Rating  Earned    Rate    │
│                             │
│   [Get In Touch]  [📌]      │
│                             │
└─────────────────────────────┘
```

**Benefits:**
- Immediate visual impact
- All key info at a glance
- Clear call-to-action
- Professional appearance
- Memorable

---

### Information Display: ❌ Insufficient (1/10)

**Current:** Username only  
**Needed:**
- Profile image (backdrop)
- Bio (1-2 lines)
- Key stats (rating, sea miles, experience)
- Languages
- Top qualifications (2-3)
- Top skills (5-6)
- Contact button

---

### Visual Design: ⚠️ Generic Placeholder (3/10)

**Current Issues:**
- Standard NavigationStack appearance
- Generic system icons
- No brand personality
- Looks like an error state
- "Coming Soon" messaging is discouraging

**Recommendation:** Complete visual overhaul using design reference #2 as template.

---

## Comparative Analysis

### ProfileView vs. AuthorProfileModal

Both views should show similar information but with different purposes:

| Aspect | ProfileView (Own) | AuthorProfileModal (Others) |
|--------|-------------------|------------------------------|
| **Purpose** | Manage own profile, settings | Learn about others, initiate contact |
| **Edit Mode** | ✅ Full editing | ❌ Read-only |
| **Detail Level** | ⭐⭐⭐⭐⭐ Comprehensive | ⭐⭐⭐ Key highlights |
| **Privacy** | Show all fields | Respect privacy settings |
| **Actions** | Edit, Sign Out, Settings | Contact, Bookmark, Share |
| **Image** | Hero with edit button | Full backdrop (immersive) |
| **Stats** | All metrics | Top 3-4 metrics |
| **Contact** | Not shown (it's you!) | Prominent CTA |

**Current Issue:** AuthorProfileModal shows even less than ProfileView (just username).

**Solution:** ProfileView should be comprehensive; AuthorProfileModal should be curated highlights.

---

## Critical Missing Features

### Priority 1: Must Have for MVP
1. **Profile Image Upload**
   - Image picker integration
   - Upload to backend storage
   - Display in both views
   - Placeholder gradient if none

2. **Bio/Description**
   - Multi-line text editor
   - 2000 character limit
   - Display with proper formatting
   - Required for meaningful profiles

3. **Basic Contact Info**
   - Email visibility toggle
   - Telegram username
   - Display in AuthorProfileModal
   - Privacy controls

4. **Location/Nationality**
   - Simple text fields
   - Display in header area
   - Helps with discovery

### Priority 2: Should Have for Launch
5. **Languages**
   - Multi-select or tags
   - Proficiency levels
   - Critical for sailing crews

6. **Skills**
   - Tag-based system
   - Proficiency indicators
   - Common skills suggestions

7. **Experience Metrics**
   - Sea days counter
   - Nautical miles
   - Vessels sailed
   - Manual entry for now

8. **Qualifications**
   - Certification cards
   - Issuing organization
   - Expiry dates

### Priority 3: Nice to Have
9. **Hobbies**
10. **Crew Preferences**
11. **Profile Analytics**
12. **Verification System**

---

## Technical Debt & Concerns

### 1. Commented-Out Code (ProfileView.swift)
**Lines 484-505:** Commented account action buttons

```swift
// Privacy settings button
//                accountActionButton(
//                    icon: "lock.fill",
//                    label: L10n.Profile.privacySettings,
//                    iconColor: DesignSystem.Colors.primary,
//                    action: { } // TODO: Navigate to privacy settings
//                )
```

**Issue:** Clutters codebase, unclear if planned or abandoned.

**Recommendation:** 
- If planned: Create GitHub issues and remove comments
- If abandoned: Delete entirely
- If uncertain: Move to Phase 4 backlog

### 2. TODO Comments (ProfileView.swift)
**Lines 24, 168, 169, 488, 496, 504, 512**

All marked with "TODO: Phase 2" or "TODO: Implement"

**Recommendation:**
- Convert to GitHub issues with proper labels
- Link to PRD phases
- Set up project board to track

### 3. File Size
**ProfileView.swift: 771 lines**

Manageable now, but will exceed 1500+ lines after enhancements.

**Recommendation:**
- Split into:
  - `ProfileView.swift` (main view)
  - `ProfileViewModel.swift` (view model)
  - `ProfileView+Sections.swift` (section builders)
  - `ProfileComponents/` (reusable components)

### 4. No Loading States
Neither view handles loading of profile data from network.

**Current:** Assumes data is always available
**Problem:** Network delays, errors not handled at view level

**Recommendation:**
- Add skeleton loading states
- Progress indicators for image uploads
- Retry buttons for failures

### 5. No Empty States
What happens when:
- User has no bio?
- User has no qualifications?
- User has no skills?

**Current:** Section doesn't appear (if let checks)
**Problem:** Users don't know what's missing

**Recommendation:**
- Show empty state prompts
- "Add your first qualification" with quick action
- Profile completion checklist

---

## Backend Compatibility Review

### Current UserInfo Model
```swift
struct UserInfo: Codable {
    let id: String
    let email: String
    let username: String?
    let createdAt: String
}
```

### Backend User Model (from anyfleet-backend)
```python
class User(Base):
    id: Mapped[uuid.UUID]
    apple_id: Mapped[str]
    email: Mapped[str]
    username: Mapped[str | None]
    role: Mapped[str]
    last_active_at: Mapped[datetime | None]
    created_at: Mapped[datetime]
    updated_at: Mapped[datetime]
```

### Compatibility Issues
1. ❌ No profile image fields on backend
2. ❌ No bio field
3. ❌ No location/nationality
4. ❌ No contact info tables
5. ❌ No credentials tables
6. ✅ Username is optional (good)
7. ✅ Created_at exists (good)

**Impact:** All Phase 1-4 features require backend schema changes.

**Recommendation:** 
- Start with backend migrations
- Update API schemas
- Test with mock data
- Then update iOS models

---

## Accessibility Review

### Current State: ⚠️ Partial Support

**Good:**
- ✅ Semantic HTML/SwiftUI structures
- ✅ System fonts (Dynamic Type compatible)
- ✅ Proper button semantics
- ✅ Standard navigation patterns

**Needs Improvement:**
- ⚠️ No explicit accessibility labels on images
- ⚠️ No VoiceOver hints for actions
- ⚠️ No accessibility traits specified
- ❌ Unverified with VoiceOver
- ❌ Untested at largest Dynamic Type sizes
- ❌ No high contrast mode testing

### Required Accessibility Additions

```swift
// Image accessibility
profileImage
    .accessibilityLabel("Profile photo")
    .accessibilityHint("Double tap to change photo")
    .accessibilityAddTraits(.isButton)

// Stats accessibility
StatCard(...)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Rating: \(rating) out of 5 stars, based on \(count) reviews")

// Edit button
Button("Edit") { ... }
    .accessibilityLabel("Edit profile")
    .accessibilityHint("Opens profile editor")
```

---

## Performance Considerations

### Current Performance: ✅ Good

**Strengths:**
- No heavy computations
- Efficient SwiftUI body evaluations
- Proper state management

**Potential Issues with Enhancements:**
1. **Image Loading:** Large profile images could slow initial load
2. **Scrolling Performance:** Many sections with rich content
3. **Network Calls:** Multiple endpoints for different sections
4. **Image Upload:** Large files, slow networks

### Recommended Optimizations

```swift
// 1. Lazy loading for below-fold sections
ScrollView {
    LazyVStack {
        // Only renders visible sections
    }
}

// 2. Progressive image loading
AsyncImage(url: thumbnailURL) { image in
    image.resizable()
}
.onAppear {
    loadFullResolution()
}

// 3. Image caching
let imageCache = NSCache<NSString, UIImage>()

// 4. Debounced search/autocomplete
@Published var searchText = ""
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
```

---

## Security & Privacy Review

### Current State: ⚠️ Basic

**Good:**
- ✅ Apple Sign-In (secure authentication)
- ✅ Keychain storage for tokens
- ✅ HTTPS API calls

**Missing:**
1. ❌ No privacy controls (who can see profile?)
2. ❌ No visibility toggles for contact info
3. ❌ No data export functionality
4. ❌ No account deletion (commented out)
5. ❌ No image moderation system
6. ❌ No abuse reporting

### Required Privacy Features

**Profile Visibility Levels:**
- Public: Anyone can see
- Community: Only authenticated AnyFleet users
- Private: Hidden from discovery, link-only

**Field-Level Privacy:**
- Email: Hidden by default
- Phone: Hidden by default
- Telegram: Visible by default
- Social: Visible by default

**User Controls:**
```swift
struct PrivacySettings {
    var profileVisibility: ProfileVisibility = .community
    var showEmail: Bool = false
    var showPhone: Bool = false
    var showTelegram: Bool = true
    var showSocial: Bool = true
    var allowProfileIndexing: Bool = true
    var showLastActive: Bool = false
}
```

---

## Localization Review

### Current State: ✅ Well-Structured

**Strengths:**
- All strings in Localizable.strings
- Support for en, ru, Base
- Proper L10n usage throughout
- No hardcoded strings

**Needed Additions for Enhancements:**
- ~50-70 new localization keys for new fields
- All three language files need updates
- Consider bio multi-language support
- Date formatting localization

---

## Recommendations Summary

### Immediate Actions (Before Starting Implementation)

1. **Create GitHub Issues**
   - Convert all TODOs to tracked issues
   - Link issues to PRD phases
   - Assign priorities

2. **Set Up Backend First**
   - Create database migrations
   - Implement image upload API
   - Update user endpoints
   - Generate seed data

3. **Refactor Existing Code**
   - Split ProfileView into multiple files
   - Remove commented code
   - Extract preview data

4. **Design System Additions**
   - Create HeroImageView component
   - Create ProfileCard component
   - Create FlowLayout for tags
   - Document new patterns

### Implementation Order

**Week 1: Backend Foundation**
- Database migrations
- Image upload API
- Profile update endpoints
- Test data seeding

**Week 2: iOS Foundation**
- Update UserInfo model
- ImageUploadService
- ProfileHeroImage component
- Basic bio editing

**Week 3: ProfileView Enhancement**
- Redesign header section
- Add bio section
- Add location/nationality
- Profile completion indicator

**Week 4: AuthorProfileModal Redesign**
- Backdrop image layout
- Stats display
- Contact button
- Privacy-aware display

**Weeks 5-6: Advanced Features**
- Credentials
- Skills
- Experience metrics
- Contact info
- Polish & testing

### Testing Strategy

**Unit Tests:**
- ✅ ProfileViewModel business logic
- ✅ Image upload service
- ✅ Data validation
- ✅ Privacy settings enforcement

**UI Tests:**
- ✅ Profile editing flow
- ✅ Image upload
- ✅ Modal presentation
- ✅ Privacy toggles

**Manual Tests:**
- ✅ VoiceOver complete flow
- ✅ Dynamic Type (smallest & largest)
- ✅ Various image formats/sizes
- ✅ Slow network simulation
- ✅ Offline behavior

### Success Criteria

**Code Quality:**
- [ ] No commented-out code
- [ ] All files < 500 lines
- [ ] 80%+ test coverage
- [ ] Zero linter errors
- [ ] All strings localized

**User Experience:**
- [ ] Profile completion rate > 70%
- [ ] Image upload success rate > 95%
- [ ] Profile load time < 1.5s
- [ ] Contact click-through > 20%
- [ ] Average session time > 45s

**Accessibility:**
- [ ] VoiceOver complete profile creation
- [ ] Works at largest Dynamic Type
- [ ] Passes color contrast checks
- [ ] All images have labels
- [ ] Touch targets ≥ 44x44pt

---

## Conclusion

Both `ProfileView.swift` and `AuthorProfileModal.swift` are well-architected and maintainable, but they're currently in "MVP authentication" state rather than "production social profile" state. 

**ProfileView** needs expansion from a basic account management screen into a comprehensive profile showcase with hero images, credentials, experience, and rich biographical content.

**AuthorProfileModal** needs a complete visual redesign from a placeholder to an immersive, card-style profile viewer that makes a strong first impression and facilitates easy contact.

The proposed 4-phase implementation plan in the PRD provides a realistic path to transform these views while maintaining code quality and backward compatibility. Starting with backend schema changes and image upload in Phase 1 will establish the foundation for all subsequent enhancements.

**Estimated Effort:**
- Backend: 40 hours (migrations, APIs, storage)
- iOS: 60 hours (UI, components, integration)
- Testing: 20 hours (unit, UI, manual)
- **Total: ~120 hours (3 weeks for 1 developer)**

**Risk Level:** Medium
- Clear requirements ✅
- Good existing architecture ✅
- Multiple backend migrations ⚠️
- Image storage/handling complexity ⚠️
- No breaking changes to existing users ✅

**Recommendation:** Approve PRD and proceed with Phase 1 implementation.
