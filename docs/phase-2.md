# EXECUTIVE SUMMARY

**AnyFleet Sailing** is an offline-first iOS app for charter yacht management and crew education, evolving from a personal utility into a community-powered platform. The platform enables sailors of all experience levels to create, share, and improve standardized checklists, flashcard study decks, and practice guides.

# Phase 2: Community Library 

## Key Differentiators

1. **Empty-by-default philosophy** — Users own their content from day one
2. **Attribution-first model** — Contributors credited across entire chain
3. **Offline-first architecture** — Works completely without network connectivity

## VISION & CORE PRINCIPLES

**"The GitHub of sailing knowledge."** AnyFleet is the community-powered platform where sailors document procedures, share best practices, and collectively build the knowledge infrastructure for safe, confident yacht charters worldwide.

### 1. **Attribution Always**
Every contributor is credited. Every fork chain is visible. Trust is built through transparent provenance.

**Implementation:**
- Item-level attribution (who contributed each **section**)
- Fork chain visualization (original → derivative → further derivative)
- Contributor profiles with reputation signals
- Verification tiers based on community engagement

### 2. **Empty by Default, Valuable from Day One**
New users start with zero content but can immediately create or import—beginning value generation immediately.

**Implementation:**
- Onboarding paths: create OR browse → import
- One-click fork to get started
- No required onboarding completion

### 3. **Offline First, Always Sync**
Core functionality works without internet. Sync (when needed) is automatic and transparent.

**Implementation:**
- SQLite-powered local data (GRDB on iOS)
- Background sync that doesn't interrupt workflow
- Offline queue for pending actions
- Conflict resolution that favors user data

### 4. **User Ownership of Data**
Users own their content, can export anytime, can delete and stay anonymous.

**Implementation:**
- Full data export (JSON, Markdown, CSV, etc.)
- Soft deletes with anonymization
- No lock-in to any single format
- Clear GDPR compliance

### 5. **Quality Through Curation**
Ratings, verification tiers, fork counts, and community flagging surface quality.

**Implementation:**
- Upvotes and downvotes
- Verification tiers (new → contributor → trusted → expert)
- Fork count as popularity signal
- Community flagging with human review

### 6. **Incremental Value Through Community**
App becomes more valuable with each new user/template. Network effects drive growth.

---

## USER RESEARCH & PERSONAS

### 1. Captain Maria (Content Creator)

**Demographics:** Age 45-55, RYA Yachtmaster, 20+ years sailing, runs 3-5 charters/season

**Psychographics:**
- Values reputation and community recognition
- Documents procedures methodically
- Mentors younger sailors
- Active in sailing forums/clubs

**Content Behaviors:**
- Creates comprehensive checklists from decades of experience
- Documents lessons learned the hard way
- Willing to share knowledge to help others
- Values recognition in sailing community

**Use Cases:**
- Create pre-charter checklist specific to 45ft catamaran
- Document weather routing procedures
- Create "Safety in Strong Winds" practice guide
- See community use and improve her content

**Pain Points:**
- No way to share procedures with crew consistently
- Can't ensure everyone follows same process
- No credit when crew members learn from her experience
- Procedures stale because scattered across documents

**Needs:**
- Easy capture of knowledge during/after charters
- Templates customizable per yacht type and size
- Public recognition and reputation-building
- See how her content is used and improved

### 2. Alex (Active Contributor)

**Demographics:** Age 28-35, IYT Bareboat certified, 30+ charters completed, sailing coach

**Psychographics:**
- Building personal brand in sailing community
- Learns best through teaching others
- Values peer recognition
- Active on sailing subreddits

**Content Behaviors:**
- Forks captain templates and customizes for teaching
- Adds personal expertise to community content
- Creates flashcard decks for certification prep
- Contributes back improvements to originals

**Use Cases:**
- Fork Mediterranean sailing checklist
- Add sections for specific hazards in his region
- Study for RYA Advanced Skipper certification
- Track crew's progress through shared deck

**Pain Points:**
- Can't track who learned from his content
- Forked content becomes outdated as original improves
- No way to suggest improvements to others' templates
- Manual process of updating multiple "versions"

**Needs:**
- Ability to contribute back to community content
- Recognition for improvements they make
- Fork → customize → share workflow
- Learning progress tracking across decks

### 3. Jamie (Casual Consumer)

**Demographics:** Age 35-42, occasional charter guest, minimal sailing background, software engineer

**Psychographics:**
- Values efficiency and clarity
- Wants to appear competent on the boat
- Appreciates good design and UX
- Tech-literate, uses multiple productivity apps

**Content Behaviors:**
- Imports captain's simplified safety checklist
- Uses practice guides for anchoring and docking
- Studies flashcards before charter
- Rarely creates original content

**Use Cases:**
- Pre-charter study with flashcard deck
- Quick reference during charter (offline)
- Personalize captain's checklist for their specific boat
- Share learning progress with charter group

**Pain Points:**
- Information scattered across documents
- Can't bookmark or annotate shared guides
- Doesn't know what to study
- Wants to impress crew/captain

**Needs:**
- Simple, clear interface
- Offline access for boat
- Personalization without complexity
- Progress tracking

## Secondary Personas

### School/Training Operator
**Needs:** Standardized curriculum templates, certification tracking, bulk content creation  
**Use case:** Create "RYA Day Skipper" flashcard deck bundle for students

### Destination Charter Company
**Needs:** Fleet-specific checklists, regional guides, crew onboarding templates  
**Use case:** Create brand-specific templates for all boats in fleet
