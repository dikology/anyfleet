# Profile Enhancement - Quick Summary

## 🎯 What We're Building

Transforming AnyFleet profiles from basic auth views into rich, captain-centric profiles inspired by maritime crew platforms.

## 📊 Current State vs. Future State

### Current (ProfileView.swift)
- ✅ Basic username + email
- ✅ Circle avatar placeholder  
- ❌ No bio, location, images
- ❌ No credentials or experience

### Current (AuthorProfileModal.swift)
- ✅ Minimal modal with username
- ❌ No visual appeal
- ❌ "Coming soon" placeholder
- ❌ No contact options

### Future Vision
- Hero backdrop image (like reference #2)
- Rich biographical content
- Maritime credentials & qualifications
- Experience metrics (sea days, miles, vessels)
- Contact methods (email, telegram, socials)
- Skills, languages, hobbies
- Privacy controls

## 🚀 4-Phase Implementation

### Phase 1: Visual Foundation (Week 1-2)
**Backend:**
- Add fields: `profile_image_url`, `bio`, `location`, `nationality`
- Image upload API (`POST /api/v1/profile/upload-image`)
- Enhanced profile update API

**iOS:**
- Update `UserInfo` model with new fields
- Create `ImageUploadService`
- Redesign ProfileView with hero image section
- Redesign AuthorProfileModal with backdrop + gradient overlay
- Bio editor, location, nationality fields

**Key Deliverable:** Users can upload profile photo and write bio

---

### Phase 2: Credentials & Experience (Week 3-4)
**Backend:**
- New tables: `user_languages`, `user_qualifications`, `user_skills`, `user_experience_metrics`
- CRUD APIs for each credential type
- Enhanced profile response with all data

**iOS:**
- New models: `UserLanguage`, `UserQualification`, `UserSkill`, `ExperienceMetrics`
- ProfileView sections: Languages, Qualifications, Skills, Experience
- AuthorProfileModal: Display top credentials and key stats

**Key Deliverable:** Full credential management like reference #1

---

### Phase 3: Contact & Social (Week 5)
**Backend:**
- New table: `user_contact_info` (phone, telegram, whatsapp, socials)
- Privacy toggles per contact method
- API to fetch contact info respecting privacy

**iOS:**
- `ContactInfo` model
- ProfileView: Contact & social section with privacy controls
- AuthorProfileModal: "Get In Touch" action menu (email, telegram, whatsapp)

**Key Deliverable:** Easy contact initiation between users

---

### Phase 4: Polish & Advanced (Week 6)
**Backend:**
- `user_hobbies` table
- Crew preferences JSON field
- Optional analytics

**iOS:**
- Hobbies section with emoji icons
- Crew preference tags
- Skeleton loading states
- Empty state improvements
- Animations & accessibility

**Key Deliverable:** Polished, delightful profile experience

---

## 🎨 Design Reference Implementation

### Reference #1: Detailed Captain Profile
**Use for ProfileView.swift:**
- Card-based sections
- Hero with gradient overlay
- Metrics in grid layout
- Expandable credentials
- Skill pills with proficiency
- Hobbies with icons

### Reference #2: Card Profile
**Use for AuthorProfileModal.swift:**
- Full-screen backdrop image
- Dark gradient for text legibility
- Name + verification badge
- One-line bio
- 3 key stats (⭐ rating, 💰 earned, ⏱ rate)
- Prominent "Get In Touch" button
- Bookmark icon for later

---

## 📋 Quick Start Checklist

### Backend Setup (Phase 1)
- [ ] Create migration: add profile_image_url, bio, location, nationality to users
- [ ] Implement image upload endpoint (S3/Railway volumes)
- [ ] Update UserResponse schema with new fields
- [ ] Update profile PATCH endpoint to accept new fields

### iOS Setup (Phase 1)
- [ ] Update UserInfo struct with new optional fields
- [ ] Create ImageUploadService.swift
- [ ] Create ProfileHeroImage component
- [ ] Add bio TextEditor with char count
- [ ] Add location & nationality fields
- [ ] Redesign AuthorProfileModal with backdrop layout

### Testing (Phase 1)
- [ ] Upload various image formats
- [ ] Test with no image (placeholder)
- [ ] Test bio with 2000 char limit
- [ ] View another user's profile
- [ ] Test on smallest and largest iPhones

---

## 🔑 Key Technical Decisions

**Image Storage:**
- Development: Railway volumes
- Production: S3 + CDN
- Max size: 10MB
- Compression on device before upload
- Thumbnail: 400x400px
- Full image: max 2MB after compression

**Privacy:**
- Profile visibility: public, community, private
- Per-field contact privacy toggles
- Email hidden by default
- Telegram visible by default

**Performance:**
- Profile load < 1.5s
- Progressive image loading (thumbnail → full)
- Lazy load below-fold sections
- Aggressive caching

**Backward Compatibility:**
- All new fields optional in API
- Old app versions gracefully handle missing fields
- Feature flags for phased rollout

---

## 📈 Success Metrics

### Phase 1
- 50%+ upload profile image
- 70%+ fill bio
- 60%+ average completion
- < 1.5s load time

### Phase 2
- 40%+ add qualification
- 60%+ add 3+ skills
- 30%+ add languages

### Phase 3
- 50%+ add contact method
- 20%+ contact click-through
- Telegram most popular

### Phase 4
- 35%+ add hobbies
- 50% increase in profile views
- 45s+ average session time

---

## 🚨 Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Large images slow app | Compress on device, progressive loading, CDN |
| Too many fields overwhelm | Phased rollout, progress indicators, suggestions |
| Privacy concerns | Granular controls, private defaults, clear explanations |
| Storage costs | Compression, size limits, cleanup deleted images |
| Breaking old clients | Optional fields, graceful degradation, versioning |

---

## 💡 Quick Implementation Tips

1. **Start with Phase 1 backend migration first** - other phases depend on it
2. **Create realistic seed data** - makes testing much easier
3. **Use feature flags** - deploy code but enable features gradually
4. **Mock data in previews** - speeds up UI development
5. **Test privacy settings thoroughly** - critical for user trust
6. **Progressive enhancement** - basic profile works even if advanced features fail
7. **Cache aggressively** - profile images rarely change

---

## 📚 Related Files

**Backend:**
- `/Users/dikology/repos/anyfleet-backend/app/models/user.py`
- `/Users/dikology/repos/anyfleet-backend/app/schemas/auth.py`

**iOS:**
- `/Users/dikology/repos/anyfleet/anyfleet/anyfleet/Features/Profile/ProfileView.swift`
- `/Users/dikology/repos/anyfleet/anyfleet/anyfleet/Features/Discover/AuthorProfileModal.swift`
- `/Users/dikology/repos/anyfleet/anyfleet/anyfleet/Services/AuthService.swift`

**Documentation:**
- `profile-prd.md` (full detailed PRD)
- `phase-2.md` (reputation system - related)

---

## 🎬 Next Steps

1. Review and approve PRD
2. Set up Phase 1 backend migration
3. Implement image upload API
4. Update iOS UserInfo model
5. Build ImageUploadService
6. Redesign ProfileView hero section
7. Redesign AuthorProfileModal with backdrop
8. Test and iterate

---

**Questions?** See "Open Questions" section in full PRD.
