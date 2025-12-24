# Discover Tab Product Requirements Document (PRD)

## Overview

The Discover tab will be a new core feature in AnyFleet that allows users to explore and discover published content created by the sailing community. This feature complements the existing Library tab (which shows user's own content) by providing a community-driven discovery experience.

## Problem Statement

Currently, users can only see and manage their own content in the Library tab. There's no way to discover high-quality sailing content created by other users, limiting the value proposition of the AnyFleet platform as a collaborative knowledge-sharing tool.

## Goals

1. **MVP**: Enable users to browse all published sailing content from the community
2. **Future**: Allow users to fork (copy) published content into their personal library
3. Foster a collaborative sailing knowledge ecosystem
4. Increase user engagement through content discovery

## Target Audience

- Experienced sailors looking for proven checklists and procedures
- New sailors seeking to learn from community best practices
- Content creators who want their work to reach a broader audience
- Fleet managers and charter companies seeking standardized procedures

## MVP: Content Discovery 

### Core Features

#### 1. Discover Tab Navigation
- Add "Discover" as the third tab in the main navigation bar
- Icon: `globe` (representing global community content)
- Position between Library and Charters tabs for logical flow

#### 2. Content Feed
- Display all published content from all users in reverse chronological order (newest first)
- **Works without authentication** - anyone can browse community content
- Content types supported: Checklists, Practice Guides, Flashcard Decks
- Show basic metadata: title, description, author, content type, creation date
- Include engagement metrics: view count, fork count
- **No filtering or search** - just a simple scrollable list

#### 3. Content Viewing 
- Tap any content item to view full details
- Read-only viewing experience (no editing capabilities)
- Display author information and publication metadata
- Track view counts (increment on content access)
- **Note**: May need to implement basic readers if they don't exist yet

### Technical Implementation (MVP)

#### Backend API Integration
- **Utilize existing `/api/v1/content/public` endpoint** (no changes needed)
- **No authentication required** for browsing public content
- Returns `SharedContentSummary[]` with: id, title, description, content_type, tags, public_id, author_username, view_count, fork_count, created_at
- No additional query parameters or pagination for MVP

#### iOS App Changes
- Add `DiscoverView` and `DiscoverViewModel` following existing MVVM patterns
- Create `DiscoverContentRow` component for consistent item display (reuse LibraryItemRow patterns)
- Add discover navigation path to `AppCoordinator`
- Extend `APIClient` with unauthenticated `fetchPublicContent()` method for public endpoint
- **No authentication required** for browsing content

#### Data Models
- Create `DiscoverContent` model that maps from `SharedContentSummary`
- Include fields: id, title, description, contentType, tags, publicID, authorUsername, viewCount, forkCount, createdAt

### UI/UX Design (MVP)

#### Content Item Layout (Simplified)
```
┌─────────────────────────────────────┐
│ [Icon] Title                        │
│         by Author • Date            │
│         Description preview...      │
│         [Tag1] [Tag2]               │
│         👁️ 42                      │
└─────────────────────────────────────┘
```

#### Empty State
- Encouraging message: "Discover sailing knowledge from the community"
- Subtext: "Browse checklists, guides, and flashcards shared by fellow sailors"
- Visual: Compass/compass rose or similar nautical imagery

#### Loading & Error States
- Consistent with existing Library tab patterns
- Pull-to-refresh functionality
- Error banners for network issues

### Success Metrics (MVP)

- Daily active users in Discover tab
- Content view engagement rates
- Time spent in Discover tab vs Library tab
- Click-through rates from content discovery to viewing

## Future Phase: Content Forking

### Core Features (Future)

#### 1. Fork Action
- "Fork" button on content detail view (for forkable content)
- **Requires user authentication** - prompts sign-in if not logged in
- One-tap action to copy content to user's library
- Maintain attribution to original author
- Option to customize forked content immediately

#### 2. Fork Attribution
- Track fork relationships in metadata
- Display "Forked from [Author]" in content details
- Increment fork count on original content
- Show fork lineage

#### 3. Fork Management
- Forked content appears in user's Library with special indicator
- Ability to differentiate between original and forked content
- Option to "unfork" content

### Technical Implementation (Future)

#### Backend Changes (Future)
- Add fork tracking fields to `SharedContent` model
- Create fork relationship management
- Update fork counts atomically
- Add fork permissions and validation

#### API Endpoints (Future)

```typescript
GET /api/v1/content/{public_id}
Response: Full content with view count increment
Auth: Not required

POST /api/v1/content/{public_id}/fork
Response: Forked content metadata
Auth: Required (user must be signed in)
```

#### iOS App Changes (Future)
- Add fork action to content detail views
- Create fork confirmation dialog
- Update library sync to handle forked content
- Add fork attribution display components

## Technical Architecture (MVP)

### iOS Architecture

#### New Components
- `DiscoverView` - Main discover tab view
- `DiscoverViewModel` - Business logic for content discovery
- `DiscoverContentRow` - Content item display component

#### Integration Points
- Extend `AppCoordinator` with discover navigation
- Add discover tab to `AppView.Tab` enum
- Use existing `APIClient` for backend communication (public endpoint doesn't require auth)
- **No changes to LibraryStore or ContentSyncService for MVP**

## Risks & Mitigations (MVP)

### Technical Risks
1. **API Performance**: Public content endpoint may be slow with large datasets
   - Mitigation: Start with small dataset, monitor performance, add pagination later

2. **Content Quality**: Low-quality content could harm user experience
   - Mitigation: Rely on community self-moderation initially

3. **Missing Readers**: Content readers may not exist for all content types
   - Mitigation: Implement basic readers or limit to supported types initially

### Business Risks
1. **Content Creation**: Users may not publish content if discoverability is low
   - Mitigation: Promote publishing features alongside discover launch

2. **Platform Growth**: Feature may not drive user acquisition
   - Mitigation: Measure engagement metrics, iterate based on data

## Implementation Timeline (MVP)

### MVP (4 weeks)
- Week 1: Create DiscoverView, DiscoverViewModel, and basic UI components
- Week 2: Integrate with existing APIClient and AppCoordinator
- Week 3: Add content viewing (reuse existing readers where possible)
- Week 4: Testing, polish, and launch

### Future Phase (6 weeks)
- Backend fork tracking and API endpoints
- iOS fork functionality and UI
- Integration testing and user experience polish

## Success Criteria (MVP)

- [ ] Discover tab successfully displays published content from `/api/v1/content/public`
- [ ] Users can browse content in a simple list format
- [ ] Content viewing works for supported content types
- [ ] Performance meets acceptable thresholds (<3s load times)
- [ ] Daily active users in Discover tab > 20% of total DAU
- [ ] No regressions in existing Library functionality

## Future Considerations

### Post-MVP Features
- Content filtering by type (All, Checklists, Guides, Decks)
- Search by title, description, or tags
- Content ratings and reviews
- Author profiles and following
- Curated collections/playlists
- Advanced search with filters (date ranges, popularity, etc.)
- Content recommendations based on user behavior
- Premium content and monetization features

---

*Document Version: 1.0*
*Last Updated: December 24, 2025*
*Author: AnyFleet Product Team*
