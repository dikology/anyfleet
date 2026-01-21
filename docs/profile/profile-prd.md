# Profile Enhancement PRD
**Product Requirements Document**  
*Version: 1.0*  
*Date: January 9, 2026*  
*Project: AnyFleet - Enhanced Profile System*

---

## Executive Summary

This PRD outlines a phased enhancement of the AnyFleet profile system, transforming it from a basic authentication-focused view into a rich, captain-centric profile experience. The enhancements are inspired by maritime crew platforms and modern professional networking apps, featuring visual storytelling through hero images, comprehensive maritime credentials, and rich biographical content.

---

## Design Review: Current State

### ProfileView.swift - Current Implementation

**Strengths:**
- ✅ Clean authentication flow with Apple Sign-In
- ✅ Well-structured MVVM architecture with `@Observable` ProfileViewModel
- ✅ Design system consistency throughout
- ✅ Profile editing functionality for username
- ✅ Prepared for Phase 2 metrics (contributionMetrics, verification tiers)
- ✅ Excellent error handling with ErrorBanner
- ✅ Good separation of authenticated/unauthenticated states

**Limitations:**
- ❌ No profile image support (uses placeholder circle with icon)
- ❌ Limited user information (only email, username, created_at)
- ❌ No biographical content (bio, location, languages)
- ❌ No contact information section (email, socials, telegram)
- ❌ No professional credentials display (certifications, qualifications)
- ❌ No experience metrics (sea time, vessel types, ratings)
- ❌ Verification badge implemented but not prominently displayed
- ❌ Stats sections (reputation, content ownership) hidden behind nil checks

### AuthorProfileModal.swift - Current Implementation

**Strengths:**
- ✅ Simple, clean modal presentation
- ✅ Proper navigation with dismiss controls
- ✅ Consistent design system usage
- ✅ "Coming Soon" placeholder for future functionality

**Limitations:**
- ❌ Minimal information display (username only)
- ❌ No visual appeal (basic avatar placeholder)
- ❌ No biographical or credential information
- ❌ No backdrop image support
- ❌ No contact/interaction options
- ❌ Not ready for public profile viewing

### Backend User Model - Current State

**Existing Fields:**
- `id` (UUID)
- `apple_id` (String)
- `email` (EmailStr)
- `username` (Optional String)
- `role` (String)
- `last_active_at` (Optional DateTime)
- `created_at` (DateTime)
- `updated_at` (DateTime)

**Missing for Enhanced Profiles:**
- Profile image/avatar URL
- Bio/description
- Location/nationality
- Languages spoken
- Contact information (social links, telegram, phone)
- Maritime experience (sea time, certifications)
- Skills and qualifications
- Privacy settings for profile visibility

---

## Vision & Goals

### Primary Goals
1. **Visual Storytelling**: Enable captains to showcase their personality and experience through rich visual profiles
2. **Trust Building**: Display credentials, experience, and community reputation prominently
3. **Connection Facilitation**: Make it easy for users to learn about and contact profile owners
4. **Progressive Enhancement**: Implement in phases without breaking existing functionality

### Success Metrics
- Profile completion rate > 70% (users filling bio, adding image, etc.)
- Profile view engagement time > 30 seconds
- Contact initiation rate from profiles > 15%
- Profile image upload rate > 50% of authenticated users

---

## Reference Design Analysis

### Reference 1: Captain Profile (Detailed View)
**Key Elements:**
- **Hero Image**: Large background photo with gradient overlay for text legibility
- **Primary Info**: Name, age, location clearly visible on hero
- **Experience Badge**: Skill level prominently displayed (Beginner, Expert, etc.)
- **Key Metrics**: Sea Miles, Average Feedback, Time at Sea in cards
- **Crewing Tags**: Pill-style badges (Novice Crew, Friendship, Voluntary, Non-smoker)
- **Bio Section**: Multi-paragraph bio with language icons
- **Qualifications**: Credential cards with issuing organization and dates
- **Skills**: Comprehensive skill tags (Line Handling, Watch Duty, Knot Tying, etc.)
- **Hobbies**: Personal interests with emoji icons
- **Experience Section**: Expandable trip history with ratings

**Design Principles:**
- Card-based layout with clear hierarchy
- Color coding for different information types
- Icons for quick scanning
- Generous white space
- Mobile-optimized scrolling

### Reference 2: Profile Card (Compact View)
**Key Elements:**
- **Full-Screen Backdrop**: Profile image fills entire card
- **Dark Gradient Overlay**: Ensures text legibility over photos
- **Name with Verification**: Blue checkmark for verified users
- **One-Line Bio**: Concise professional summary
- **Three Key Stats**: Rating, Earned, Rate in horizontal layout
- **Primary CTA**: "Get In Touch" button prominently placed
- **Bookmark Action**: Save for later functionality

**Design Principles:**
- Maximum visual impact
- Minimal text, maximum meaning
- Clear call-to-action
- Professional yet approachable
- Card-style presentation for discovery flow

---

## Phased Implementation Plan

## Phase 1: Foundation & Visual Enhancement
**Timeline:** Week 1-2  
**Goal:** Add core visual capabilities and essential profile fields

### Backend Changes

#### 1.1 Database Schema Updates
**New fields for `users` table:**
```sql
-- Profile visuals
profile_image_url VARCHAR(500) NULL
profile_image_thumbnail_url VARCHAR(500) NULL

-- Biographical
bio TEXT NULL
location VARCHAR(100) NULL
nationality VARCHAR(100) NULL

-- Privacy
profile_visibility VARCHAR(20) DEFAULT 'public' -- 'public', 'private', 'community'

-- Timestamps (already exist)
-- created_at, updated_at, last_active_at
```

**Migration file:** `add_profile_fields_phase1.py`

#### 1.2 Image Upload API
**Endpoint:** `POST /api/v1/profile/upload-image`
- Accept multipart/form-data with image file
- Validate image (format, size < 10MB, dimensions)
- Upload to storage (S3/Railway volumes)
- Generate thumbnail (400x400)
- Return URLs for full image and thumbnail
- Update user record with URLs

**Response:**
```json
{
  "profile_image_url": "https://...",
  "profile_image_thumbnail_url": "https://...",
  "message": "Profile image uploaded successfully"
}
```

#### 1.3 Profile Update API Enhancement
**Endpoint:** `PATCH /api/v1/profile`  
**Extend UpdateProfileRequest:**
```python
class UpdateProfileRequest(BaseModel):
    username: str | None = Field(None, min_length=1, max_length=100)
    bio: str | None = Field(None, max_length=2000)
    location: str | None = Field(None, max_length=100)
    nationality: str | None = Field(None, max_length=100)
    profile_visibility: str | None = Field(None, pattern="^(public|private|community)$")
```

**Extend UserResponse:**
```python
class UserResponse(BaseModel):
    # ... existing fields ...
    profile_image_url: str | None = None
    profile_image_thumbnail_url: str | None = None
    bio: str | None = None
    location: str | None = None
    nationality: str | None = None
    profile_visibility: str = "public"
```

### iOS App Changes

#### 1.4 Update UserInfo Model
**File:** `anyfleet/Services/AuthService.swift`

```swift
struct UserInfo: Codable {
    let id: String
    let email: String
    let username: String?
    let createdAt: String
    
    // Phase 1 additions
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let profileVisibility: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, username, bio, location, nationality
        case createdAt = "created_at"
        case profileImageUrl = "profile_image_url"
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
        case profileVisibility = "profile_visibility"
    }
}
```

#### 1.5 Image Upload Service
**New file:** `anyfleet/Services/ImageUploadService.swift`

**Features:**
- Image picker integration (PHPickerViewController)
- Image compression and resizing before upload
- Progress tracking for upload
- Error handling with retry logic
- Thumbnail caching

#### 1.6 Enhanced ProfileView
**File:** `anyfleet/Features/Profile/ProfileView.swift`

**Updates:**
1. Replace circular avatar with hero image section
2. Add image upload button with picker
3. Add bio text editor (expandable TextView)
4. Add location and nationality fields
5. Show profile completion percentage
6. Update editing mode to include new fields

**New UI Components:**
- `ProfileHeroImage`: Displays profile image with gradient overlay
- `ProfileImagePicker`: Button to trigger image selection
- `BioEditor`: Multi-line text editor with character count
- `ProfileCompletionBadge`: Progress indicator for profile filling

#### 1.7 Enhanced AuthorProfileModal
**File:** `anyfleet/Features/Discover/AuthorProfileModal.swift`

**Complete redesign:**
1. Full-screen backdrop image (or gradient placeholder if no image)
2. Dark gradient overlay for text legibility
3. Verification badge next to username
4. Bio displayed prominently (2-3 lines, truncated)
5. Key stats section (if metrics available)
6. "Contact" button (email composer for now)
7. Bookmark/save button (for later phases)

**Layout:**
```
┌─────────────────────────────┐
│  [Full Background Image]    │
│  ┌───────────────────────┐  │
│  │ [Dark Gradient]       │  │
│  │                       │  │
│  │ Name ✓ Verified      │  │
│  │ Bio text...          │  │
│  │                       │  │
│  │ ⭐ 4.8  💰 $45k+ ⏱ $50/hr │  │
│  │                       │  │
│  │ [Get In Touch] [📌]   │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

#### 1.8 New Localizations
**Files:** `Localizable.strings` (en, ru, Base)

```swift
// Profile Image
"profile.image.upload" = "Upload Profile Photo"
"profile.image.change" = "Change Photo"
"profile.image.remove" = "Remove Photo"
"profile.image.error" = "Failed to upload image. Please try again."

// Bio
"profile.bio.title" = "Bio"
"profile.bio.placeholder" = "Tell others about yourself, your sailing experience, and what you're passionate about..."
"profile.bio.characterLimit" = "%d / 2000 characters"

// Location
"profile.location.title" = "Location"
"profile.location.placeholder" = "e.g., Ireland, Mediterranean"

// Nationality
"profile.nationality.title" = "Nationality"
"profile.nationality.placeholder" = "e.g., Irish, American"

// Completion
"profile.completion.title" = "Profile %d%% complete"
"profile.completion.addPhoto" = "Add a profile photo"
"profile.completion.addBio" = "Write your bio"
"profile.completion.addLocation" = "Add your location"
```

---

## Phase 1 Current Limitations

### Author Profile Modal
**Issue:** AuthorProfileModal cannot display profile images or detailed information for other users because there are no backend endpoints to fetch public user profiles.

**Current State:**
- ✅ Modal displays with basic username
- ❌ No profile images (backend doesn't provide public profile access)
- ❌ No bio, location, or other profile details
- ❌ No verification status or reputation metrics

**Impact:** Users can discover content authors but cannot view their profiles, reducing engagement and trust-building.

---

## Phase 2: Professional Credentials & Experience
**Timeline:** Week 3-4  
**Goal:** Add maritime-specific credentials, skills, and experience tracking

### Backend Changes

#### 2.0 Public Profile API
**New endpoint:** `GET /api/v1/users/{username}`

**Purpose:** Allow users to view other users' public profiles, enabling the AuthorProfileModal to display profile images, bio, location, and verification status.

**Response:**
```json
{
  "id": "uuid",
  "username": "sailor123",
  "profile_image_url": "https://...",
  "profile_image_thumbnail_url": "https://...",
  "bio": "Experienced sailor...",
  "location": "Mediterranean",
  "nationality": "Italian",
  "is_verified": true,
  "verification_tier": "expert",
  "created_at": "2024-01-01T00:00:00Z",
  "stats": {
    "total_contributions": 42,
    "average_rating": 4.8,
    "total_forks": 15
  }
}
```

**Privacy Considerations:**
- Only return public profile data
- Respect user's profile_visibility setting
- Return 404 for private profiles

#### 2.1 New Tables

**`user_languages` table:**
```sql
CREATE TABLE user_languages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language VARCHAR(50) NOT NULL,
    proficiency VARCHAR(20) DEFAULT 'conversational', -- 'basic', 'conversational', 'fluent', 'native'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_user_languages_user_id ON user_languages(user_id);
```

**`user_qualifications` table:**
```sql
CREATE TABLE user_qualifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    issuing_organization VARCHAR(200),
    issue_date DATE,
    expiry_date DATE NULL,
    credential_id VARCHAR(100) NULL,
    credential_url VARCHAR(500) NULL,
    description TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_user_qualifications_user_id ON user_qualifications(user_id);
```

**`user_skills` table:**
```sql
CREATE TABLE user_skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_name VARCHAR(100) NOT NULL,
    skill_category VARCHAR(50), -- 'sailing', 'navigation', 'maintenance', 'safety', 'other'
    proficiency_level INTEGER DEFAULT 1, -- 1-5 scale
    years_experience INTEGER NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_user_skills_user_id ON user_skills(user_id);
```

**`user_experience_metrics` table:**
```sql
CREATE TABLE user_experience_metrics (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_sea_days INTEGER DEFAULT 0,
    total_nautical_miles INTEGER DEFAULT 0,
    vessels_sailed INTEGER DEFAULT 0,
    preferred_vessel_types TEXT[], -- Array: ['sailboat', 'catamaran', 'yacht']
    preferred_roles TEXT[], -- Array: ['crew', 'deckhand', 'cook', 'skipper']
    emergency_training BOOLEAN DEFAULT FALSE,
    first_aid_certified BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 2.2 New API Endpoints

**Languages:**
- `GET /api/v1/profile/languages` - List user's languages
- `POST /api/v1/profile/languages` - Add a language
- `DELETE /api/v1/profile/languages/{language_id}` - Remove a language

**Qualifications:**
- `GET /api/v1/profile/qualifications` - List user's qualifications
- `POST /api/v1/profile/qualifications` - Add a qualification
- `PATCH /api/v1/profile/qualifications/{qual_id}` - Update qualification
- `DELETE /api/v1/profile/qualifications/{qual_id}` - Remove qualification

**Skills:**
- `GET /api/v1/profile/skills` - List user's skills
- `POST /api/v1/profile/skills` - Add a skill
- `PATCH /api/v1/profile/skills/{skill_id}` - Update skill proficiency
- `DELETE /api/v1/profile/skills/{skill_id}` - Remove skill

**Experience Metrics:**
- `GET /api/v1/profile/experience` - Get experience metrics
- `PATCH /api/v1/profile/experience` - Update experience metrics

#### 2.3 Enhanced User Profile Response
```python
class LanguageResponse(BaseModel):
    id: uuid.UUID
    language: str
    proficiency: str

class QualificationResponse(BaseModel):
    id: uuid.UUID
    title: str
    issuing_organization: str | None
    issue_date: date | None
    expiry_date: date | None
    credential_id: str | None
    description: str | None

class SkillResponse(BaseModel):
    id: uuid.UUID
    skill_name: str
    skill_category: str | None
    proficiency_level: int
    years_experience: int | None

class ExperienceMetricsResponse(BaseModel):
    total_sea_days: int
    total_nautical_miles: int
    vessels_sailed: int
    preferred_vessel_types: list[str]
    preferred_roles: list[str]
    emergency_training: bool
    first_aid_certified: bool

class FullProfileResponse(BaseModel):
    user: UserResponse
    languages: list[LanguageResponse]
    qualifications: list[QualificationResponse]
    skills: list[SkillResponse]
    experience: ExperienceMetricsResponse | None
```

### iOS App Changes

#### 2.2 Public Profile API Integration
**File:** `anyfleet/Services/AuthService.swift`

**Add method:**
```swift
func fetchPublicProfile(username: String) async throws -> PublicUserProfile {
    let url = URL(string: "\(baseURL)/users/\(username)")!
    let data = try await makeAuthenticatedRequest(to: url.absoluteString)
    return try JSONDecoder().decode(PublicUserProfile.self, from: data)
}
```

**New Model:** `anyfleet/Core/Models/PublicUserProfile.swift`
```swift
struct PublicUserProfile: Codable {
    let id: String
    let username: String
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let isVerified: Bool
    let verificationTier: String?
    let createdAt: String
    let stats: PublicUserStats?
}

struct PublicUserStats: Codable {
    let totalContributions: Int
    let averageRating: Double
    let totalForks: Int
}
```

#### 2.3 Enhanced AuthorProfileModal
**File:** `anyfleet/Features/Discover/AuthorProfileModal.swift`

**Update initialization to fetch real profile data:**
```swift
// Replace hardcoded AuthorProfile with API call
@State private var authorProfile: PublicUserProfile?

init(username: String) {
    self.username = username
}

// In task modifier:
authorProfile = try await authService.fetchPublicProfile(username: username)
```

#### 2.4 New Models
**File:** `anyfleet/Core/Models/ProfileModels.swift` (new file)

```swift
struct UserLanguage: Codable, Identifiable {
    let id: String
    let language: String
    let proficiency: LanguageProficiency
}

enum LanguageProficiency: String, Codable {
    case basic, conversational, fluent, native
}

struct UserQualification: Codable, Identifiable {
    let id: String
    let title: String
    let issuingOrganization: String?
    let issueDate: Date?
    let expiryDate: Date?
    let credentialId: String?
    let description: String?
}

struct UserSkill: Codable, Identifiable {
    let id: String
    let skillName: String
    let skillCategory: SkillCategory?
    let proficiencyLevel: Int // 1-5
    let yearsExperience: Int?
}

enum SkillCategory: String, Codable {
    case sailing, navigation, maintenance, safety, other
}

struct ExperienceMetrics: Codable {
    let totalSeaDays: Int
    let totalNauticalMiles: Int
    let vesselsSailed: Int
    let preferredVesselTypes: [String]
    let preferredRoles: [String]
    let emergencyTraining: Bool
    let firstAidCertified: Bool
}
```

#### 2.5 ProfileView Enhancements
**Add new sections:**

1. **Languages Section:**
   - Display languages with flags/icons
   - Proficiency level indicators
   - Add/edit languages inline

2. **Qualifications Section:**
   - Expandable cards showing each credential
   - Issuing organization logos (if available)
   - Expiry date warnings for credentials
   - Add new qualification flow

3. **Skills Section:**
   - Categorized skill tags
   - Proficiency indicators (1-5 stars)
   - Skill suggestion/autocomplete when adding
   - Popular skills in community

4. **Experience Metrics Section:**
   - Sea days counter with icon
   - Nautical miles traveled
   - Vessels sailed count
   - Preferred vessel types as tags
   - Preferred roles as tags
   - Certifications (emergency training, first aid) as badges

#### 2.6 AuthorProfileModal Enhancements
**Add sections:**
- Languages display (flags + names)
- Top qualifications (limit to 2-3 most recent)
- Key skills (top 5-6 by proficiency)
- Experience summary (sea days, miles, vessels)

---

## Phase 3: Contact Info & Social Integration
**Timeline:** Week 5  
**Goal:** Enable users to showcase contact methods and social profiles

### Backend Changes

#### 3.1 Contact Information Table
```sql
CREATE TABLE user_contact_info (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    phone VARCHAR(20) NULL,
    telegram_username VARCHAR(100) NULL,
    whatsapp_number VARCHAR(20) NULL,
    website_url VARCHAR(500) NULL,
    linkedin_url VARCHAR(500) NULL,
    instagram_handle VARCHAR(100) NULL,
    facebook_url VARCHAR(500) NULL,
    show_email BOOLEAN DEFAULT FALSE, -- Privacy control
    show_phone BOOLEAN DEFAULT FALSE,
    show_telegram BOOLEAN DEFAULT TRUE,
    show_whatsapp BOOLEAN DEFAULT FALSE,
    show_social BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 3.2 API Endpoints
- `GET /api/v1/profile/contact` - Get user's contact info
- `PATCH /api/v1/profile/contact` - Update contact info
- `GET /api/v1/users/{user_id}/contact` - Get another user's contact (respects privacy)

#### 3.3 Privacy Schema
```python
class ContactInfoRequest(BaseModel):
    phone: str | None = None
    telegram_username: str | None = None
    whatsapp_number: str | None = None
    website_url: HttpUrl | None = None
    linkedin_url: HttpUrl | None = None
    instagram_handle: str | None = None
    facebook_url: HttpUrl | None = None
    show_email: bool = False
    show_phone: bool = False
    show_telegram: bool = True
    show_whatsapp: bool = False
    show_social: bool = True
```

### iOS App Changes

#### 3.4 Contact Info Model
**File:** `anyfleet/Core/Models/ContactInfo.swift` (new file)

```swift
struct ContactInfo: Codable {
    let phone: String?
    let telegramUsername: String?
    let whatsappNumber: String?
    let websiteUrl: String?
    let linkedinUrl: String?
    let instagramHandle: String?
    let facebookUrl: String?
    let showEmail: Bool
    let showPhone: Bool
    let showTelegram: Bool
    let showWhatsapp: Bool
    let showSocial: Bool
}
```

#### 3.5 ProfileView Updates
**New section: Contact & Social**
- Email (with privacy toggle)
- Phone (with privacy toggle)
- Telegram (with privacy toggle)
- WhatsApp (with privacy toggle)
- Website link
- Social media links (LinkedIn, Instagram, Facebook)
- Privacy controls for each field

#### 3.6 AuthorProfileModal - Contact Actions
**Replace "Get In Touch" with action menu:**
- Email (if allowed)
- Telegram (if provided)
- WhatsApp (if provided)
- Copy contact info
- Share profile

**Implementation:**
- Tappable contact methods
- Deep links to Telegram/WhatsApp
- Email composer integration
- Share sheet for profile URL (future)

---

## Phase 4: Advanced Features & Polish
**Timeline:** Week 6  
**Goal:** Add hobbies, preferences, and UI refinements

### Features

#### 4.1 Hobbies & Interests
**Backend table:**
```sql
CREATE TABLE user_hobbies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hobby_name VARCHAR(100) NOT NULL,
    hobby_icon VARCHAR(50) NULL, -- emoji or SF Symbol name
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**UI:**
- Grid of hobby pills with emoji icons
- Pre-defined hobby suggestions
- Custom hobby entry

#### 4.2 Crew Tags/Preferences
**Backend fields in users table:**
```sql
ALTER TABLE users ADD COLUMN crew_preferences JSONB DEFAULT '{}';
-- Example: {"smoker": false, "dietary": "vegetarian", "availability": "weekends"}
```

**UI:**
- Lifestyle preferences (smoking, drinking, diet)
- Availability tags (weekends, summer, flexible)
- Crew role preferences (already in experience)

#### 4.3 UI Polish
1. **Skeleton Loading States:**
   - Shimmer effect while loading profile
   - Placeholder cards for missing sections

2. **Empty States:**
   - Friendly prompts to complete profile sections
   - Quick action buttons to add content

3. **Animations:**
   - Smooth transitions between edit/view modes
   - Hero image fade-in on load
   - Stat counters animate when appearing

4. **Accessibility:**
   - VoiceOver labels for all elements
   - Dynamic Type support
   - High contrast mode support
   - Reduced motion respect

#### 4.4 Profile Analytics (Optional)
**Backend events tracking:**
- Profile views count
- Contact button clicks
- Section expansion tracking
- Popular skills/qualifications

---

## Technical Specifications

### Image Upload Requirements

**Accepted formats:** JPEG, PNG, HEIC  
**Maximum file size:** 10 MB  
**Minimum dimensions:** 800x600 px  
**Recommended dimensions:** 1200x900 px  
**Aspect ratio:** Flexible, will be cropped to fit in UI  
**Processing:**
- Generate thumbnail: 400x400 px
- Compress original: max 2MB for web delivery
- Store both versions

**Storage:**
- Railway volumes (development)
- S3/CloudFront (production)
- CDN for fast delivery

### Performance Targets

**Profile Load Time:**
- Initial load: < 1.5s (with cached image)
- Hero image: Progressive loading (thumbnail → full)
- Lazy load sections below fold

**Image Upload:**
- Compress on device before upload
- Show progress indicator
- Background upload support
- Retry on failure

### Data Privacy

**Profile Visibility Levels:**
1. **Public:** Visible to all users, searchable
2. **Community:** Visible only to authenticated AnyFleet users
3. **Private:** Hidden from discover, only visible via direct link

**Contact Privacy:**
- Each contact method has individual privacy toggle
- Email hidden by default
- Phone hidden by default
- Telegram visible by default
- Social media visible by default

**Data Retention:**
- Profile images: Keep until user deletes or replaces
- Deleted images: Remove from storage within 7 days
- Account deletion: Immediate anonymization of all data

---

## Design System Components

### New Components Needed

#### 1. HeroImageView
- Full-width image with gradient overlay
- Loading skeleton
- Error state (placeholder gradient)
- Aspect ratio preservation

#### 2. ProfileMetricCard
- Icon + Label + Value
- Compact and expanded variants
- Color customization

#### 3. CredentialCard
- Title, organization, dates
- Expiry warning badge
- Expand/collapse for description
- Verification status indicator

#### 4. SkillPill
- Skill name + proficiency dots
- Category color coding
- Tap to edit inline

#### 5. ContactButton
- Icon + Label
- Availability indicator
- Disabled state for unavailable contacts

#### 6. ProfileCompletionBar
- Circular progress indicator
- Percentage text
- Actionable items list

---

## Testing Strategy

### Unit Tests
- Image upload service
- Profile data validation
- Privacy setting enforcement
- API request/response parsing

### Integration Tests
- Full profile CRUD operations
- Image upload → display flow
- Privacy controls functionality
- Contact info retrieval with privacy

### UI Tests
- Profile editing flow
- Image picker integration
- Form validation
- Modal presentation/dismissal

### Manual Testing Checklist
- [ ] Upload various image formats and sizes
- [ ] Test with no profile image (placeholder)
- [ ] Fill out all profile sections
- [ ] Edit and save profile multiple times
- [ ] Test privacy toggles for contact info
- [ ] View another user's profile (AuthorProfileModal)
- [ ] Test on various device sizes
- [ ] Test with VoiceOver
- [ ] Test with Dynamic Type (smallest and largest)
- [ ] Test offline behavior

---

## Migration & Rollout Plan

### Database Migrations
**Order:**
1. Phase 1: Add core profile fields to users table
2. Phase 2: Create credential/skill/experience tables
3. Phase 3: Create contact info table
4. Phase 4: Add hobbies and preferences

**Each migration must:**
- Include rollback script
- Handle NULL values gracefully
- Include data validation constraints
- Have appropriate indexes

### iOS App Rollout
**Backward Compatibility:**
- All new UserInfo fields are optional
- Gracefully handle missing fields from old API
- Show empty states for unpopulated sections
- Don't block app if image upload fails

**Feature Flags:**
```swift
enum ProfileFeatureFlags {
    static let imageUploadEnabled = true
    static let credentialsEnabled = false // Phase 2
    static let contactInfoEnabled = false // Phase 3
}
```

### Data Seeding for Development
**Create realistic test data:**
- 10-20 sample users with complete profiles
- Variety of images (some users with, some without)
- Mix of experience levels
- Different languages and nationalities
- Various qualifications and skills

---

## Success Criteria

### Phase 1 Success Metrics
- [ ] 50%+ of users upload a profile image within 7 days
- [ ] 70%+ of users fill out bio
- [ ] Average profile completion rate > 60%
- [ ] < 5% image upload failure rate
- [ ] Profile load time < 1.5s average

### Phase 2 Success Metrics
- [ ] 40%+ of users add at least one qualification
- [ ] 60%+ of users add at least 3 skills
- [ ] 30%+ of users add language information
- [ ] Experience metrics filled by 25%+ users

### Phase 3 Success Metrics
- [ ] 50%+ of users add at least one contact method
- [ ] Telegram most popular contact method (>70% of those who add contact)
- [ ] Contact button click-through rate > 20% on AuthorProfileModal
- [ ] Privacy toggles used by 40%+ of users

### Phase 4 Success Metrics
- [ ] 35%+ of users add hobbies
- [ ] Profile views increase by 50% after enhancements
- [ ] Average session time on profiles > 45 seconds
- [ ] Profile edit sessions > 2 per user per month

---

## Risks & Mitigations

### Risk 1: Image Upload Performance
**Concern:** Large images slow down app, consume bandwidth  
**Mitigation:**
- Compress images on device before upload
- Show thumbnail immediately, load full size progressively
- Cache aggressively
- CDN for production

### Risk 2: Profile Completion Fatigue
**Concern:** Too many fields, users abandon  
**Mitigation:**
- Phased rollout
- Clear progress indicators
- Quick actions for common items
- Pre-filled suggestions

### Risk 3: Privacy Concerns
**Concern:** Users uncomfortable sharing contact info  
**Mitigation:**
- Granular privacy controls
- Clear explanations of visibility
- Default to more private settings
- Easy to update anytime

### Risk 4: Backend Storage Costs
**Concern:** Image storage becomes expensive  
**Mitigation:**
- Image compression
- Thumbnail generation
- Size limits enforced
- Automatic cleanup of deleted images

### Risk 5: Schema Changes Breaking Existing Clients
**Concern:** Old app versions can't handle new fields  
**Mitigation:**
- All new fields optional in API
- Graceful degradation in old clients
- API versioning if needed
- Clear deprecation timeline

---

## Open Questions

1. **Image Moderation:** Do we need manual or automated review of profile images?
2. **Verification Process:** How do we verify qualifications/certifications?
3. **Profile URLs:** Should we create shareable profile URLs (anyfleet.app/@username)?
4. **Profile Search:** Should profiles be searchable by skills/location/experience?
5. **Profile Templates:** Should we offer pre-built profile templates for different roles?
6. **Multi-language Support:** Should bio support multiple languages?
7. **Profile Versions:** Should we maintain edit history?

---

## Future Enhancements (Post-Phase 4)

### Profile Discovery Feed
- Browse profiles by filters
- Match by skills and preferences
- Featured profiles section

### Profile Badges & Achievements
- Milestone badges (100 sea days, 1000 miles, etc.)
- Community awards
- Verified expert status

### Profile Sharing
- Generate shareable cards
- QR codes for in-person networking
- Export to PDF

### Profile Recommendations
- AI-suggested skills to add
- Profile completion tips
- Similar profiles to connect with

### Profile Analytics Dashboard
- View count over time
- Top sections viewed
- Contact conversion rate
- Profile strength score

---

## Appendix

### Design Mockups
- See attached reference images
- Figma link: [TBD]

### API Documentation
- Full OpenAPI spec: [TBD after implementation]

### Localization Files
- All strings to be added to Localizable.strings
- Support for en, ru, Base initially

### Related PRDs
- Community Library PRD
- Phase 2 PRD (reputation system)

---

## Changelog

**v1.0 - January 9, 2026**
- Initial PRD created
- Four-phase implementation plan defined
- Design review completed
- Technical specifications outlined
