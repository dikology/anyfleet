# AnyFleet Library Visibility Feature - Complete Implementation Guide

## 📋 Overview

Complete guide for implementing library content visibility (private/unlisted/public) with professional UX/UI patterns and Phase 2 backend readiness.

**Three comprehensive documents:**

1. **library_visibility_guide.md** — Architecture review + refactored code
2. **visibility_ux_patterns.md** — Visual references and interaction patterns
3. **implementation_checklist.md** — Week-by-week implementation breakdown

---

## 🎯 Quick Summary

### Current Problems ❌
- Visibility shown only as badge
- No publish action UI
- Swipe actions confusing for non-swipeable items
- No auth state observable in library
- No confirmation before permanent action
- No GRDB schema for visibility state

### What We're Building ✅
- Clear visual separation between local and public content
- Disabled-but-clear UX when not signed in
- Modal confirmation for publishing
- Sign-in modal (sheet, not navigation)
- GRDB schema with sync tracking
- Phase 2 backend-ready architecture

### Timeline
- **Effort:** 78 hours (2-3 weeks)
- **Risk:** Low (isolated, clear patterns)
- **Impact:** HIGH for Phase 2

---

## 🏗️ Architecture at a Glance

```
Views Layer
├─ LibraryListView (sectioned by visibility)
├─ LibraryItemRow (with publish action)
├─ PublishConfirmationModal
└─ SignInModalView

ViewModels & Services
├─ LibraryListViewModel (state management)
├─ VisibilityService (business logic)
└─ AuthStateObserver (auth state)

Data Models
└─ LibraryModel
   ├─ VisibilityState (enum)
   └─ SyncState (enum)

Database Layer (GRDB)
├─ library_content (extended)
├─ public_content (new)
└─ visibility_changes (new - for sync)
```

---

## 📚 Which Document to Read?

### For Architects/Lead Developers
**Read:** `library_visibility_guide.md`
- Complete code analysis
- Refactored architecture with code
- GRDB schema with migrations
- Full refactored views

### For Designers
**Read:** `visibility_ux_patterns.md`
- 14 visual reference sections
- User journey flows
- Component anatomy
- State machines
- Accessibility checklist

### For Implementers
**Read:** `implementation_checklist.md`
- Week-by-week breakdown
- Phase-by-phase tasks
- Code snippets
- Testing strategy
- Manual testing checklist

### For All
**Reference:** This README as navigation guide

---

## 🎨 Visual Design Concept

### Content Organization (New)
```
┌────────────────────────────────────┐
│ My Library [All] [Local] [Public]  │
├────────────────────────────────────┤
│                                    │
│ 🔒 LOCAL CONTENT (Not Published)  │
│ ─────────────────────────────────  │
│                                    │
│ [Item 1] [🔒 private] [Publish →] │
│ [Item 2] [🔒 private] [Publish →] │
│                                    │
├────────────────────────────────────┤
│                                    │
│ 🌐 PUBLIC CONTENT (Published)     │
│ ─────────────────────────────────  │
│                                    │
│ [Item 3] [🌐 public · 234]        │
│          [Unpublish ↓]            │
│ [Item 4] [🌐 public · 89]         │
│          [Unpublish ↓]            │
│                                    │
└────────────────────────────────────┘
```

---

## 🚀 User Flow: Publishing

### Unsigned User
```
Sees: [Publish] button disabled
      "Sign in to publish content"
      
Taps → SignInModalView (sheet)
     ↓
Signs in
     ↓
PublishConfirmationModal appears
     ↓
Taps [Share Publicly]
     ↓
⏳ Publishing... → ✓ Published!
     ↓
Item moves to Public section
```

### Signed-In User
```
Sees: [Publish] button enabled

Taps → PublishConfirmationModal
     ↓
Modal shows:
"Share Racing Tips?"
"Others can see and fork."
"ℹ️ This is permanent."
     ↓
Taps [Share Publicly]
     ↓
⏳ Publishing... → ✓ Published!
     ↓
Item moves to Public section
```

---

## 💾 Database Schema (New)

```sql
-- Add to library_content table
visibility_state TEXT (private, unlisted, public)
sync_state TEXT (local, pending, published, error)
published_at DATETIME
public_id TEXT (URL slug)
author_id TEXT (user attribution)
view_count INTEGER
can_fork BOOLEAN

-- New: public_content table
CREATE TABLE public_content (
    id, public_id, content_id, content_type,
    title, description, author_username,
    published_at, view_count, can_fork,
    updated_at, synced_at
)

-- New: visibility_changes table (for sync)
CREATE TABLE visibility_changes (
    id, content_id, from_state, to_state,
    created_at, synced, sync_error
)
```

---

## ✨ Key Features

### 1. Visual Distinction
- Section headers: "🔒 LOCAL" vs "🌐 PUBLIC"
- Different badge colors and icons
- Author attribution on public items
- View count on public items

### 2. Progressive Disclosure
- Publish action only visible to signed-in users
- Clear disabled state with sign-in prompt when unsigned
- Modal confirmation prevents accidents

### 3. Persistent State
- GRDB tracks visibility_state and sync_state
- Sync queue for Phase 2 backend integration
- Error recovery with retry capability

### 4. Phase 2 Ready
- Public metadata separated for discovery
- Author attribution automatic
- Sync audit trail for conflict resolution
- Fork permissions tracked

---

## 📅 Implementation Timeline

| Week | Phase | Focus | Deliverables |
|------|-------|-------|--------------|
| 1 | Foundation | Models, Services, Components | Data enums, VisibilityService, reusable components |
| 2 | Database & Auth | Schema, Migrations, Modal | GRDB schema, SignInModal, unit tests |
| 3 | Polish & Deploy | Testing, Accessibility, Handoff | Accessibility audit, performance, Phase 2 spec |

**Total: 78 hours across 2-3 weeks**

---

## 🔄 Architecture Decisions

### Why Section-Based List?
- More discoverable than filtering only
- Better for small-to-medium libraries
- Easier progressive enhancement
- Filtering layers on top

### Why Modal for Sign-In?
- Keeps users in library context
- Auto-retry publish after sign-in
- Better UX than navigation push
- Standard iOS pattern

### Why Confirmation Modal?
- Publishing is permanent
- Prevents accidental publishes
- Shows implications clearly
- Better UX than swipe action

### Why Separate Public Table?
- Enables community features
- Easier backend sync
- Cleaner data model
- Ready for Phase 2 APIs

### Why Visibility Changes Log?
- Audit trail for sync
- Error recovery
- Conflict resolution
- Analytics ready

---

## ✅ Success Criteria

- [ ] Users clearly see which content is local vs public
- [ ] Publishing requires sign-in with clear UX
- [ ] All permanent actions require confirmation
- [ ] Visibility state persists in GRDB
- [ ] Sync state tracked for Phase 2
- [ ] All tests passing (78+ tests)
- [ ] Accessibility audit passed (WCAG AA)
- [ ] App Store ready for submission
- [ ] Backend team has clear integration spec

---

## 🔐 Security & Privacy

✅ Must be authenticated to publish  
✅ Must confirm with explicit modal  
✅ Sync failures tracked (no silent failures)  
✅ Author attribution automatic  
✅ Can unpublish anytime  
✅ Audit trail for conflict resolution  

---

## 🧪 Testing Strategy

### Unit Tests (20+)
- Service layer business logic
- ViewModel computed properties
- Data model conversions

### Integration Tests (15+)
- End-to-end publish flow
- GRDB persistence
- Filter behavior

### UI Tests (10+)
- Component rendering
- State transitions
- Error display

### Manual Testing
- User flows (signed-in/out)
- Error scenarios
- Device testing
- Accessibility

**Total: 78+ tests**

---

## 🚀 Phase 2 Backend Integration

This architecture prepares for:

**Sync Service**
```swift
BackendSyncService {
    func syncVisibilityChanges() async throws
    func fetchPublicContent() async throws
    func submitView(publicID: String) async throws
}
```

**API Contract**
```
POST /api/v1/content/publish
  Input: { content_id, content_type, title, description }
  Returns: { public_id (slug), published_at, can_fork }

GET /api/v1/content/public
  Returns: [PublicContent] with view counts

PATCH /api/v1/content/{id}/unpublish
  Marks content as private
```

---

## 📖 Document Navigation

### Start Here (Choose Your Path)

**I'm the Architect/Lead Dev:**
1. Read `library_visibility_guide.md` (complete)
2. Reference `visibility_ux_patterns.md` for design
3. Use `implementation_checklist.md` for sprint planning

**I'm the Designer:**
1. Study `visibility_ux_patterns.md` (all sections)
2. Review `library_visibility_guide.md` (Parts 3.1-3.4)
3. Create Figma designs from specifications

**I'm the Developer:**
1. Read `library_visibility_guide.md` (Parts 1, 2, 4)
2. Reference `visibility_ux_patterns.md` for component specs
3. Follow `implementation_checklist.md` phase-by-phase

**I'm QA/Product:**
1. Review `visibility_ux_patterns.md` (user flows)
2. Use `implementation_checklist.md` (testing section)
3. Execute manual testing checklist

---

## 💡 Key Insights

### Problem → Solution Mapping

| Problem | Solution | Where |
|---------|----------|-------|
| Can't distinguish local/public | Section-based list + badges | Guide Part 3.1 |
| No publish UX | Modal confirmation | Patterns section 7 |
| Unclear why disabled | Clear disabled state + help text | Patterns section 5 |
| Auth not observable | AuthStateObserver | Guide Part 2.1 |
| Business logic mixed in views | VisibilityService | Guide Part 2.3 |
| No persistence | GRDB schema + migration | Guide Part 4 |
| Not Phase 2 ready | Sync state + audit log | Guide Part 4 |

---

## 📊 Effort Breakdown

| Component | Hours | Notes |
|-----------|-------|-------|
| Models + Services | 14 | Data enums, VisibilityService, AuthStateObserver |
| UI Components | 22 | Badges, modals, row refactoring |
| Database | 8 | Migrations, records, repository methods |
| Auth Integration | 6 | Sign-in modal, auth flow |
| Testing | 16 | Unit + integration + UI + manual |
| Polish | 8 | Accessibility, performance, localization |
| Handoff | 4 | Documentation, backend spec |
| **Total** | **78** | **2-3 weeks** |

---

## 🎓 Best Practices Applied

✅ **Separation of Concerns**
- Views, ViewModels, Services, Models, Database layers

✅ **Observable Pattern**
- @Observable macro for reactive state management

✅ **GRDB Best Practices**
- Migrations, records, type-safe queries

✅ **SwiftUI Patterns**
- Reusable components, sheet presentations, modals

✅ **iOS HIG Compliance**
- Touch targets (44pt), focus management, colors

✅ **Accessibility**
- VoiceOver labels, color contrast, focus order

✅ **Error Handling**
- Validation, network errors, sync failures

✅ **Localization Ready**
- All strings in L10n, tested with Russian

---

## ✨ What Makes This Better

| Aspect | Current | Proposed |
|--------|---------|----------|
| Local/Public distinction | Badge only | Sectioned + badges |
| Disabled publish | Hidden | Clearly disabled |
| Publish action | Swipe (wrong) | Modal (correct) |
| Auth state | Not observable | Observable |
| Business logic | Mixed | VisibilityService |
| Sync tracking | None | SyncState + audit |
| Phase 2 ready | No | Yes ✅ |
| Testability | Medium | High |
| Maintainability | Medium | High |

---

## 🎉 When You're Done

Users will be able to:
- ✅ See exactly which content is private vs public
- ✅ Understand they need to sign in to publish
- ✅ Get clear confirmation before publishing
- ✅ See their published content with attribution
- ✅ Sync visibility state to backend (Phase 2)

---

## 📞 Questions?

**"How should the UI look?"**
→ Read `visibility_ux_patterns.md` sections 1-8

**"What code changes?"**
→ Read `library_visibility_guide.md` part 2

**"How do I build this?"**
→ Follow `implementation_checklist.md` week-by-week

**"What about the database?"**
→ Read `library_visibility_guide.md` part 4

**"How does this enable Phase 2?"**
→ Read `library_visibility_guide.md` final section

---

## 🚤 Ready to Build?

1. Share `library_visibility_guide.md` with architecture review team
2. Share `visibility_ux_patterns.md` with design team
3. Start Week 1 with `implementation_checklist.md` Phase 1
4. Reference 3 generated images for UI direction
5. Execute phase-by-phase with clear success criteria
