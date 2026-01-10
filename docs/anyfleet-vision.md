# AnyFleet: Phased Vision & Development Roadmap

## Overview

AnyFleet is an offline-first iOS app designed to connect sailors, captains, and crew members within a vibrant sailing community. The app enables users to plan charters, share knowledge through community libraries, discover adventures, and build meaningful connections with like-minded sailors. This document outlines the strategic vision across three development phases, focusing on UX/design, usability, and best practices informed by successful community discovery platforms and sailing apps.

**Core Philosophy:**
- **Offline-first**: Users can plan and prepare without connectivity; sync happens naturally when online
- **Community-driven**: Knowledge, experiences, and connections are shared by community members for mutual benefit
- **User agency**: Users control what they share; privacy and transparency are built-in, not bolted-on
- **Location-centric**: Destinations, vessels, and crew discovery are tied to real-world geography and community affiliation

---

## Current State (Phase 1-2: Personal Utility Foundation & Community Library)

**Completed Capabilities:**
- **Home Tab**: Entry points to active charters and pinned content; foundation for future features
- **Charters Tab**: User's personal charter plans (not yet shared)
- **Library Tab**: Content creation and publishing to community library
- **Discover Tab**: Community library browsing with attribution
- **Profile Tab**: Captain profile with basic information

**Backend Foundations:**
- Authentication and profile endpoints
- Content publishing system
- Basic offline-first sync

---

## Phase 3: Social Discovery & Location Intelligence

### 3.1 Charters Tab Expansion: Shared Adventure Planning

**Vision:**
Transform the Charters tab from a personal-only view into a community discovery feed where users can see, filter, and join others' planned adventures.

#### Design Principles

1. **Privacy by Default, Sharing by Choice**
   - Users decide in settings whether their planned charters are visible to others
   - No "publish" action needed (unlike content) — simply toggle visibility
   - Natural sync when user comes online; no complex workflows

2. **Filtering & Discovery**
   - Filter by:
     - Date range (upcoming, this week, this month)
     - Destination (see planned charters to your favorite sailing grounds)
     - Community affiliation (if user is member of "Sila Vetra," see charters from that community)
     - Skill level (if provided by captain)
   - **Recommendation hint:** SailTies and Outr apps use interest-based matching; AnyFleet adds location + community layers
   
3. **Join Request Flow**
   - Users can send requests to join others' planned charters
   - Captain can review and approve
   - Once approved, requester is added to crew manifest
   - Enables organic crew assembly without pre-defined "crew finding" feature

4. **Offline Handling**
   - Users can browse cached/downloaded charters while offline
   - Join requests queued locally and sent when online
   - Graceful messaging about connectivity status

#### UX Patterns

- **Discovery Feed:** Vertical scrolling list of charter cards showing destination, date, captain, crew count, skill level tag
- **Charter Detail Modal:** Tappable card reveals full details: destination description, dates, itinerary preview, crew manifest, checklist requirements
- **Request to Join:** Primary CTA button with optional message input (crew introduces themselves)
- **Map View Alternative:** Optional secondary view showing charter destinations on map with community filter overlay

---

### 3.2 Location Intelligence & Destination Mapping

**Vision:**
When users enter a destination for their charter, the app helps them understand, explore, and connect with others planning similar trips to that location.

#### Design Principles

1. **Autocomplete & Smart Suggestions**
   - Real-time autocomplete as user types destination name
   - Suggests nearby locations (e.g., "Santorini" suggests nearby islands)
   - Ties to real-world map data for consistency
   - **Real-world reference:** Google Places API and Mapbox provide this pattern; travel apps (Airbnb, Booking.com) use refined location search with region inference

2. **Location Metadata**
   - Associate destination input with geographic coordinates and region hierarchy (country → region → harbor)
   - Enable backend to attribute charters to regions for filtering
   - Optional: Enrichment with seasonal info (e.g., "Med sailing season: May–October")

3. **Map Display**
   - Show destination on map in charter detail view
   - Optional: Show route preview if multi-day charter
   - Visual context helps users evaluate accessibility and nearby resources
   - **Design reference:** Tour booking sites (Baymard research) show maps on detail pages for 43% higher booking confidence

#### UX Patterns

- **Destination Input:** Text field with dropdown autocomplete and map preview thumbnail
- **Location Confirmation:** After selection, show map pin + brief region/harbor info
- **Related Charters:** "See X other charters going to this location" link below destination

#### Implementation Considerations

  - Location database: Initially seeded with major sailing regions/harbors; grows with user entries

- **Offline Handling:**
  - Pre-cache major locations on first launch
  - Allow offline autocomplete against cached data
  - Queue new location suggestions for server review

---

### 3.3 Vessel Database & Reviews System

**Vision:**
Build community knowledge about vessels through shared experience and structured reviews. Captains see recommendations when adding their vessel; crew learns about vessel characteristics.

#### Design Principles

1. **Lightweight Vessel Registration**
   - Captain enters vessel name when creating charter
   - App suggests existing vessels from database (if available)
   - Captain can "claim" existing vessel or create new entry
   - Vessel becomes discoverable for future charters

2. **Post-Charter Reviews**
   - After charter ends, crew and captain can leave reviews on the **Active Charter Detail** screen (or in charter tab after charter ends)
   - Reviews include:
     - Star rating (1–5)
     - Brief notes (condition, comfort, reliability, crew vibe)
     - Vessel photo upload optional
   - Reviews are published to vessel profile; attributed to reviewer

3. **Vessel Visibility**
   - Vessel profiles show:
     - Vessel specs (type, size, year) — captain-provided
     - Aggregate rating and review count
     - Recent reviews with reviewer profile link
     - Charter history (if vessel captain opts to share)
   - When adding a charter, captain sees vessel reviews and can see what others are saying

#### UX Patterns

- **Vessel Search:** Destination input in charter creation flows to "suggest vessel" with search overlay
- **Vessel Detail Page:** Modal showing specs, photos, reviews (sorted by recency, with filters for rating)
- **Post-Charter Review Form:** Simple, 2-field form (rating + optional note) in Active Charter detail after charter date ends
- **Vessel Claim Flow:** When captain adds vessel, show "Is this vessel in our database? Claim to merge your history"

#### Implementation Considerations

- **Offline Handling:**
  - Cache popular vessels locally
  - Queue review submissions for sync

---

### 3.4 Home Tab: Nearby Captains & Live Community Map

**Vision:**
Show users other active sailors in their vicinity, creating serendipitous connections and visibility into community activity.

#### Design Principles

1. **Opt-In Live Presence**
   - Users can toggle "Share My Location" in settings
   - When enabled, captain location shared with community (with privacy controls)
   - Default: location shared only with charter crew
   - Option: share with "nearby community members" (radius: 10 km, 50 km, or global)
   - **Design rationale:** Location sharing is sensitive; Outr and other social discovery apps use explicit opt-in with granular radius controls

2. **Map View in Home Tab**
   - Toggle between "Active Charters" list and "Nearby Crew Map"
   - Map shows:
     - Your location (always, if enabled)
     - Nearby captains with active charters
     - Charter destinations as pins
     - Community affiliation icons/colors if captain is in your community
   - Tapping pin shows captain profile preview + "Join Charter" CTA

3. **Community Affiliation Indicators**
   - Captains visually tagged by their communities 
   - Colors or icons distinguish communities
   - Helps identify "your people" on the map

#### UX Patterns

- **Map Toggle:** Segmented control in Home tab (List/Map view)
- **Location Permission Flow:** Onboarding asks for location access with benefit framing: "See nearby captains planning charters"
- **Captain Card on Map:** Tappable pin → popover showing captain name, community, active charter destination
- **Privacy Reassurance:** "Your location is not visible to the public. It's only shared with members of your community and people you charter with."

#### Implementation Considerations

- **Location Data:**
  - Send location only when user in app (use foreground location updates)
  - Stop sharing if user disables toggle
  - Clear after charter ends or explicit opt-out

---

## Phase 4: Community, Moderation & Multi-Community Support

### 4.1 Sub-Communities & Community Discovery

**Vision:**
Enable users to join sailing communities and filter content/charters by community. Communities become discovery hubs.

#### Design Principles

1. **Community Types**
   - **Local/Regional:** Geographic sailing communities (harbor-based fleets, regional sailing clubs)
   - **Skill/Interest-Based:** Communities around skill level (beginners, advanced racing, cruising culture)
   - **Affinity Groups:** Language, skill, or lifestyle communities (multilingual communities, women sailors, retirees)
   - **Brand Communities:** Official communities around sailing brands, schools, or programs

2. **Membership Model**
   - Users can join multiple communities (UI shows subscribed communities on Profile)
   - Communities can be open (auto-join) or moderated (request approval)
   - Community flag/icon shown on user profile and charter listings
   - Permissions tied to community role (member, moderator, founder)

3. **Community-Scoped Discovery**
   - Filter Discover tab by community
   - Charters filtered to show only community-member charters
   - Library content tagged by community origin
   - Language/content filter by community (e.g., "Show only content in my communities")

#### UX Patterns

- **Community Directory:** New tab or section in Discover showing join-able communities with:
  - Community name, icon/flag, description
  - Member count, activity level badge
  - "Join Community" CTA
  
- **Community Badge:** Small icon/pill on charter cards, content, and profiles showing "member of X"

- **Filter Refinement:** Discover tab adds "Communities" as top-level filter alongside existing filters (date, skill, location)

- **Profile Enhancement:** Profile shows subscribed communities with option to feature one as "primary"

#### Implementation Considerations

- **Data Model:**
  - Community entity with owner, name, icon, join policy, members list
  - Cross-reference in charters, content, users for scoped discovery

---

### 4.2 Content Sharing: Direct Links & Crew Autosharing

**Vision:**
Expand Library tab sharing options beyond public publishing. Enable direct link sharing and automatic sharing with current crew.

#### Design Principles

1. **Sharing Modes**
   - **Public:** Published to community library (current flow, no change)
   - **Unlisted:** Generate shareable link (e.g., `anyfleet.app/content/abc123`) — recipients must have link, not discoverable in library
   - **Crew Autoshare:** Automatically share with current active charter crew when content published
   - **Airdrop/Direct Share:** Export content to share via system share sheet (Files, Messages, Airdrop)

2. **Use Cases**
   - Captain creates post-charter debrief checklist → auto-shared with crew
   - User finds useful guide → shares link directly with friend via message
   - Creates content → exports via Airdrop to share offline with nearby sailor

3. **Recipient Experience**
   - Unlisted recipient can view/copy content without logging in (read-only)
   - Option to import content to their library (one-tap)
   - Attribution chain preserved and visible

#### UX Patterns

- **Content Share Sheet:** Bottom sheet or modal with radio options:
  - "Publish to Community Library"
  - "Generate Link" (shows link with copy icon)
  - "Share with Crew" (checkbox list of active charter members)
  - "Share via..." (system share sheet for Airdrop, Messages, etc.)

- **Recipient View:** Link opens minimal preview of content with "Open in App" / "Copy to My Library" CTA

- **Permission Indicator:** Content card shows sharing mode icon (globe = public, link = private, crew = crew-only)

#### Implementation Considerations

- **Security:**
  - Link tokens expire after 30 days (configurable)
  - Rate limiting to prevent enumeration
  - Recipient identity logging for future features (engagement analytics)

---

### 4.3 Attribution & Provenance Timeline

**Vision:**
Clarify content lineage when attribution chains are deep. Help users understand where knowledge comes from.

#### Design Principles

1. **Attribution Collapse**
   - When content has deep attribution chain (3+ sources), show compressed summary by default
   - Tap to open full timeline modal

2. **Timeline Modal**
   - Vertical timeline showing full chain: original creator → intermediate versions → current
   - Each entry shows: creator avatar, name, timestamp
   - Visual distinction between "created" (original) and "based on" (derived) entries
   - **Design reference:** C2PA provenance guidance shows tree structures for complex lineages; vertical timeline suits linear chains

3. **Editing Transparency**
   - When user edits content, new version linked to previous with "edited from" notation
   - Timeline shows edit history
   - Original author credited in timeline

#### UX Patterns

- **Attribution Preview:** Content card shows "Created by Alice · Based on 2 sources" with tap-to-expand
- **Timeline Modal:** Swipe-up modal with full chain visualization:
  ```
  ✦ Alice created this checklist · Jan 15, 2024
  ✦ Bob based this on Charlie's content · Dec 10, 2023
  ✦ Charlie's original checklist · Nov 1, 2023
  ```

#### Implementation Considerations

- **UX Handling:**
  - Compute lineage depth on client; trigger modal if >2 sources
  - Cache lineage info with content for offline access
  - Graceful fallback if source content deleted (show last-known version)

---

### 4.4 Discover Tab: Adventures & Experience Grouping

**Vision:**
Expand Discover beyond just library content to show curated adventures and multi-day experience groupings, helping users find inspiration and join structured sailing programs.

#### Design Principles

1. **Adventure vs. Charter**
   - **Charter:** User-planned, peer-organized sail trip (in Charters tab)
   - **Adventure:** Curated multi-day experience (school program, organized regatta, guided cruise) published by organization or community
   - Adventures have defined captain, crew structure, and often fee/sponsorship

2. **Experience Grouping**
   - Adventures can be grouped into collections: "Coastal Sailing Course 2024," "Summer Regatta Series," "Mentorship Program"
   - Discovery shows both individual content and adventure collections
   - Helps users find full programs, not isolated content

3. **Filtering & Personalization**
   - Filter by:
     - Content type (checklist, guide, adventure)
     - Community (if user member)
     - Skill level
     - Language
     - Season/timing
   - Personalized recommendations based on user's community, skill, and past activity

#### UX Patterns

- **Discover Feed:** Grid or list showing mixed content types:
  - Library content (guides, checklists, flashcards)
  - Adventure collections (cards with event dates, organizer, crew count)
  - Featured community content

- **Adventure Card:** Shows:
  - Title, organizer/community badge
  - Dates (start – end)
  - Skill level, language tags
  - Crew count / spots available
  - "View Details" or "Request to Join" CTA

- **Collection View:** Expanded card showing all adventures in a series with visual progression (e.g., "Module 1 → 2 → 3")

#### Implementation Considerations

- **New Entities:**
  - Adventure model with fields: title, description, dates, organizer (user/community), skill level, language, capacity, crew manifest
  - Collection model linking related adventures
  - Posts (content from adventures) auto-tagged with adventure/collection IDs

- **Admin Tooling:**
  - Separate admin panel or app to create/curate adventures and collections
  - Moderation queue for community-submitted adventures

---

### 4.5 Moderation, Flagging & Safety

**Vision:**
Build trust through transparent community moderation. Enable flagging of inappropriate content/users; provide moderation tools for community leaders.

#### Design Principles

1. **User Flagging**
   - 3-dot menu on content/profiles with "Report" option
   - Flag reasons: harassment, unsafe, misinformation, spam, copyright violation
   - Optional: detailed report message
   - User receives confirmation but not follow-up details (for reporter safety)

2. **Moderation Queue**
   - Web admin panel (existing, to be expanded) shows flagged content/users
   - Moderators can review, approve, or remove
   - Community moderators (trusted users) can moderate within their community
   - Escalation path for serious issues (safety threats, illegal content)

3. **Consequences**
   - Warnings: user notified of violation, content remains visible
   - Temporary suspension: user locked out for period (1 week, 1 month)
   - Permanent ban: account deleted, content removed
   - Appeal process: users can dispute moderation decision

4. **Community Standards**
   - Public code of conduct shown during onboarding and in settings
   - Users acknowledge understanding before creating/publishing content

#### UX Patterns

- **Report Modal:** Bottom sheet with:
  - Reason dropdown (Harassment, Unsafe, Misinformation, Spam, Copyright)
  - Optional text field for details
  - "Report Anonymously" toggle
  - "Submit" and "Cancel" buttons

- **Moderation Panel (Web Admin):** Dashboard showing:
  - Flagged content/users queue
  - Filter by reason, date, community
  - Detail view with flag reason, user history, action buttons (Approve/Remove/Suspend)
  - Audit log of actions taken

- **User Notification:** Alert when account suspended with reason and duration ("Your account is temporarily suspended until Jan 20 for Code of Conduct violation. Appeal here.")

#### Implementation Considerations

- **Data Model:**
  - Report entity with: reporter, reported_content/user, reason, status (pending, resolved, appealed)
  - Moderation action entity with: moderator, action type, reason, timestamp

- **Compliance:**
  - Privacy: reporter identity can be anonymous
  - Record keeping: all moderation actions logged for legal compliance
  - Appeal process documented

---

### 4.6 Profile: Community Affiliation & Identity

**Vision:**
Expand captain profile to reflect community membership and authority within communities.

#### Design Principles

1. **Community Display**
   - Profile shows communities user is member of (with roles: member, moderator, founder)
   - One primary community can be featured prominently
   - Community badge/icon visible on all user listings (charter cards, content, profiles)

2. **Community Credentials**
   - Users can add community-specific badges (e.g., "RYA Sailing Instructor," "Sila Vetra Mentor")
   - Communities can endorse/verify credentials of members
   - Displayed on profile with issuing community attribution

3. **Activity Heatmap**
   - Optional: show sailing activity summary (charters completed, seasons sailed in, regions visited)
   - Helps crew gauge captain's experience

4. **Additional Enhancements** (from separate PRD)
   - Hero image (background photo of captain or favorite sailing scene)
   - Bio (captain's sailing story, philosophy)
   - Skills & experience (e.g., "Night Navigation," "Boat Maintenance")
   - Contact info management (email, phone, optional public link)
   - Privacy controls (what's visible to community, what's private)

#### UX Patterns

- **Primary Community:** Pinned badge at top of profile
- **Community List:** Collapsible section showing all communities with role
- **Credentials Section:** New section showing endorsed badges with issuing community
- **Privacy Settings:** Per-field toggles (Private / Community Only / Public)

---

## Cross-Phase Design Principles

### Offline-First Strategy

1. **Syncing Philosophy**
   - All user actions (joins, content creation, reviews) stored locally first
   - Sync queued and executed when network available
   - No network required for core browsing, reading, planning

2. **Conflict Resolution**
   - If user modifies content offline that was edited by another user online, show conflict UI with merge options
   - Last-write-wins for simple cases; user prompt for complex cases

3. **Cached Data**
   - Proactively cache:
     - User's charters and crew memberships
     - Popular locations and vessels
     - Frequently accessed content
   - Stale-while-revalidate for charters: show cached list, refresh in background

### Accessibility & Inclusive Design

1. **Color Contrast**
   - Community badges use both color and icon/text to distinguish (not color-only)
   - Ensure 4.5:1 contrast ratio on all text

2. **Touch Targets**
   - Buttons minimum 48×48pt
   - Swipeable elements have clear visual affordances

3. **Content Density**
   - Mobile-first: single-column layouts, ample whitespace
   - Ruthless prioritization: every element earns its space

4. **Localization Readiness**
   - Support RTL languages
   - String externalization from start
   - Plan for multilingual content filtering

### Performance & Battery

1. **Location Updates**
   - Use foreground-only location tracking (battery efficient)
   - Batch updates if possible
   - Stop tracking when app backgrounded

2. **Data Transfer**
   - Compress images before upload
   - Optimize API payloads (only necessary fields)
   - Lazy load content (pagination, infinite scroll)

3. **Offline Indicators**
   - Clear messaging: "You're offline. Changes will sync when back online"
   - Visual sync status indicator in nav bar or tab

---

## Real-World Design References

### Inspiration & Best Practices

1. **SailTies** (`sailtiesapp.com`)
   - Voyage logging with offline support ✓
   - Live map showing active sailors ✓
   - Group voyages & collections ✓
   - Privacy controls for sharing ✓

2. **Outr** (London community app)
   - Community-first discovery over profile-centric UI ✓
   - Shared experiences as connection point ✓
   - Interest-based matching with integration (Spotify, OMDb) ✓
   - Lower-pressure, quality-focused matching ✓

3. **Trip Tribe UX Research** (Group travel platform)
   - Tribes as affinity groups for travel matching ✓
   - Quiz-based compatibility matching ✓
   - Communities → Trips workflow (find group first, then trip) ✓

4. **Baymard UX Research** (Travel sites)
   - Maps on detail pages increase confidence 43% ✓
   - Prominent search/booking placement ✓
   - Detailed filtering (5–10 filters minimum) ✓

5. **Mobile-First Community Building** (BuddyBoss guidance)
   - Bottom navigation for primary features ✓
   - Gamification (badges, streaks, leaderboards) ✓
   - Progressive profiling over lengthy forms ✓
   - Push notifications for engagement ✓

6. **C2PA Provenance UX** (Content attribution)
   - Tree structures for complex lineages ✓
   - Depth vs. breadth trade-offs ✓
   - Timestamp and action tracking ✓

---

## Phasing Timeline & Priorities

### Phase 3
- Charters tab expansion (shared discovery, join requests)
- Location autocomplete & mapping
- Vessel database & post-charter reviews
- Home tab map view (nearby captains)

### Phase 4
- Sub-communities framework
- Content sharing modes (links, crew autoshare, Airdrop)
- Attribution timeline UI
- Discover adventures & collections
- Moderation & flagging system
- Enhanced profiles with community integration

### Post-Phase 4: Future Enhancements
- Gamification (badges, streak rewards, leaderboards)
- AI-powered recommendations (crew compatibility, adventure suggestions)
- Advanced analytics (captain dashboard showing fleet insights)
- Multi-platform expansion (web, Android)

---

## Success Metrics

- **Engagement:** Daily active users, session duration, features used per session
- **Community:** Number of multi-community memberships, inter-community content sharing
- **Discovery:** Charters joined via shared discovery, crew formation rate
- **Trust:** Moderation appeals vs. bans ratio, user code-of-conduct acknowledgment
- **Retention:** Week-1 retention, month-1 retention, churned user feedback
- **Offline:** Percentage of actions queued offline; sync success rate

---

## Notes for PRD, implementation and development documentation

This vision document provides a foundation for detailed PRDs on:

1. **Charters Sharing & Discovery PRD** — Charter visibility settings, join request flow, filtering UI
2. **Location Intelligence PRD** — Autocomplete API, map integration, region metadata
3. **Vessel & Reviews PRD** — Vessel database, review submission, rating aggregation
4. **Community Framework PRD** — Community CRUD, membership model, role-based permissions
5. **Moderation System PRD** — Flagging workflows, admin panel enhancements, appeal process
6. **Profile Enhancement PRD** (separate existing PRD referenced)
7. **Content Sharing Modes PRD** — Link generation, crew autoshare, share sheet integration
8. **Adventures & Collections PRD** — Adventure creation, collection grouping, experience discovery

Each PRD should reference this vision document and include:
- Detailed wireframes/user flows
- API specifications
- Data model extensions
- Testing strategy

---

**Document Version:** 1.0  
**Last Updated:** January 10, 2026  
**Status:** Ready for PRD Development
