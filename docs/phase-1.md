# EXECUTIVE SUMMARY

**AnyFleet Sailing** is an offline-first iOS app for charter yacht management and crew education. Phase 1 establishes the foundation as a personal utility, enabling sailors to manage charters, create and organize checklists, practice guides, and flashcard decks for their own use.

# Phase 1: Personal Utility Foundation

## Key Differentiators

1. **Offline-first architecture** — All core functionality works without network connectivity
2. **Personal content ownership** — Users create and manage their own library of checklists, guides, and decks
3. **Charter-centric workflow** — Content is organized around charter trips with execution tracking
4. **Local data persistence** — SQLite-powered storage ensures data is always available

## VISION & CORE PRINCIPLES

**"Your personal sailing companion."** Phase 1 focuses on individual productivity, giving sailors the tools to organize their charter trips and build their personal knowledge library. All content is private by default, stored locally, and designed for offline use.

### 1. **Offline First, Always Available**
Core functionality works without internet. All data is stored locally using SQLite (GRDB).

**Implementation:**
- SQLite-powered local database (GRDB on iOS)
- All content stored on-device
- No network dependencies for core features

### 2. **Personal Content Ownership**
Users create and manage their own library of checklists, practice guides, and flashcard decks.

**Implementation:**
- Private content by default (visibility: private)
- Full CRUD operations for all content types
- Local-only storage
- Content metadata tracking (tags, descriptions, timestamps)

### 3. **Charter-Centric Organization**
Content is organized around charter trips, with execution state tracked per charter.

**Implementation:**
- Charter creation and management
- Checklist execution scoped to specific charters
- Progress tracking per charter
- Active charter detection from date ranges

### 4. **Rich Content Creation**
Users can create structured checklists and markdown-based practice guides.

**Implementation:**
- Checklists with sections and items
- Practice guides with markdown content
- Flashcard deck structure (placeholder for Phase 2)
- Content editing with rich metadata

---

## CURRENT IMPLEMENTATION

### Architecture

**Technology Stack:**
- **Platform**: iOS (SwiftUI)
- **Database**: SQLite via GRDB
- **State Management**: Swift `@Observable` macro
- **Navigation**: NavigationStack with coordinator pattern
- **Dependency Injection**: Environment-based DI container

**Key Components:**
- `AppDatabase`: GRDB database manager with migrations
- `AppDependencies`: Dependency injection container
- `AppCoordinator`: Navigation coordinator with tab-based routing
- `CharterStore`: Observable store for charter data
- `LibraryStore`: Observable store for library content

### Data Models

**Charter Model:**
- ID, name, boat name, location
- Start/end dates
- Check-in checklist association
- Created/updated timestamps
- Computed properties: days until start, duration

**Checklist Model:**
- ID, title, description
- Sections (with icons, descriptions, expand/collapse state)
- Items (with descriptions, optional/required flags, tags, estimated time)
- Checklist type (pre-charter, check-in, daily, post-charter, emergency, general, maintenance, safety, provisioning)
- Tags and metadata

**Practice Guide Model:**
- ID, title, description
- Markdown content
- Tags and metadata

**Library Model (Metadata):**
- Unified metadata for all content types
- Content type discriminator (checklist, practice guide, flashcard deck)
- Visibility settings (private, unlisted, public - for future use)
- Pinning support
- Tags, ratings, fork tracking (prepared for Phase 2)

**Checklist Execution State:**
- Per-charter execution tracking
- Item-level completion state
- Progress percentage
- Completion timestamps

### Features

#### 1. Charter Management

**Charter List View:**
- List all charters
- Sort by date
- Navigate to charter detail

**Charter Creation:**
- Form with boat name, location, dates
- Optional check-in checklist association
- Date range validation
- Crew information (future)

**Charter Detail View:**
- Charter information display
- Associated checklists
- Checklist execution access
- Practice guides access

**Active Charter Detection:**
- Home view shows active charter based on date range
- Quick access to charter details and checklists

#### 2. Library Management

**Library List View:**
- Unified view of all content (checklists, guides, decks)
- Filter by content type (all, checklists, guides, decks)
- Empty state with onboarding message
- Swipe actions: edit, delete, pin/unpin

**Content Creation:**
- Create new checklists
- Create new practice guides
- Create new flashcard decks (placeholder)
- All content starts as private

**Content Editing:**

*Checklist Editor:*
- Full checklist structure editing
- Add/remove/reorder sections
- Add/remove/reorder items within sections
- Section-level metadata (title, icon, description)
- Item-level metadata (title, description, optional/required, tags, estimated time)
- Checklist type selection
- Tags management

*Practice Guide Editor:*
- Markdown editor
- Title and description
- Tags management
- Markdown preview (via parser)

**Content Reading:**

*Checklist Reader:*
- Read-only view of checklist structure
- Section expansion/collapse
- Item details display

*Practice Guide Reader:*
- Markdown rendering
- Custom markdown parser
- Headings, paragraphs, lists, bold text
- Wiki-style link support

#### 3. Checklist Execution

**Execution View:**
- Load checklist for specific charter
- Section-based organization
- Item-level checkboxes
- Progress tracking (percentage complete)
- Per-charter state persistence
- Visual progress indicator
- Item descriptions and guidance
- Optional vs required item distinction

**Execution State:**
- Stored per charter
- Item-level completion tracking
- Progress calculation
- Last updated timestamp
- Completion timestamp

#### 4. Home View

**Primary Features:**
- Time-based greeting (morning, day, evening, night)
- Active charter card (if charter is active)
- Create charter card (if no active charter)
- Pinned library items grid
- Quick navigation to content

**Pinned Content:**
- Display up to 6 pinned items
- Grid layout
- Content type icons
- Quick access to readers

#### 5. Design System

**Components:**
- `ActionCard`: Primary action cards with icons and CTAs
- `ErrorBanner`: Error state display
- `FormKit`: Form input components
- `InfoPill`: Badge/pill components
- `SelectableCard`: Selectable card components
- `EmptyStateHero`: Empty state displays

**Design Tokens:**
- Colors: Primary, secondary, background, surface, text, borders, shadows, gradients
- Typography: Large title, title, headline, body, caption
- Spacing: xs, sm, md, lg, xl, screen padding, card padding
- Custom font: ONDER-REGULAR

**Styling:**
- Consistent corner radii
- Shadow system (weak, medium, strong)
- Gradient support (ocean theme)
- Hero card styling with elevation

### Database Schema

**Tables:**
1. `charters` - Charter information
2. `library_content` - Unified metadata for all content types
3. `checklists` - Full checklist content (sections/items as JSON)
4. `practice_guides` - Full practice guide content (markdown)
5. `checklistExecutionStates` - Per-charter execution state

**Migrations:**
- v1.0.0: Initial charter schema
- v1.1.0: Library content schema
- v1.2.0: Checklist execution schema
- v1.3.0: Pinned content support
- v1.4.0: Practice guides table

### Navigation Structure

**Tab-Based Navigation:**
- Home tab: Dashboard with active charter and pinned content
- Charters tab: Charter list and management
- Library tab: Content library and management

**Navigation Routes:**
- Charter routes: create, detail, checklist execution
- Library routes: editor (checklist/guide/deck), reader (checklist/guide)
- Cross-tab navigation support

### Localization

**Supported Languages:**
- English (en)
- Russian (ru)

**Localization Service:**
- Language switching support
- String resources in `.strings` files
- `L10n` helper for type-safe string access

### Error Handling

**Error Types:**
- `AppError`: Base error type
- Repository errors
- Store operation errors

**Error Display:**
- Error banners in UI
- Logging via `AppLogger`
- User-friendly error messages

---

## USER FLOWS

### Flow 1: Create and Execute Checklist

1. User navigates to Library tab
2. Taps "+" → "New Checklist"
3. Creates checklist with sections and items
4. Saves checklist (stored locally)
5. Creates or selects a charter
6. Associates checklist with charter (check-in checklist)
7. Opens charter detail
8. Taps "Execute Checklist"
9. Completes items, tracks progress
10. Progress saved per charter

### Flow 2: Create Practice Guide

1. User navigates to Library tab
2. Taps "+" → "New Practice Guide"
3. Enters title, description
4. Writes markdown content
5. Adds tags
6. Saves guide (stored locally)
7. Can pin guide for quick access
8. Opens guide from library to read

### Flow 3: Manage Charters

1. User navigates to Charters tab
2. Views list of all charters
3. Taps "+" to create new charter
4. Enters charter details (name, boat, location, dates)
5. Optionally selects check-in checklist
6. Saves charter
7. Views charter detail
8. Accesses associated checklists and guides

### Flow 4: Home Dashboard

1. User opens app (Home tab)
2. Sees greeting based on time of day
3. If active charter exists: sees charter card
4. If no active charter: sees "Create Charter" card
5. Sees pinned library items (if any)
6. Taps charter card → navigates to charter detail
7. Taps pinned item → navigates to content reader

---

## TECHNICAL IMPLEMENTATION DETAILS

### Dependency Injection

**AppDependencies:**
- Centralized dependency container
- Provides: database, repository, stores, services
- Environment-based access throughout app
- Test-friendly initialization

**Dependencies:**
- `AppDatabase`: Shared database instance
- `LocalRepository`: Repository implementation
- `CharterStore`: Charter state management
- `LibraryStore`: Library content state management
- `LocalizationService`: Language management

### Repository Pattern

**Repositories:**
- `CharterRepository`: Charter CRUD operations
- `LibraryRepository`: Library content CRUD operations
- `ChecklistExecutionRepository`: Execution state operations
- `LocalRepository`: Unified repository implementation

**Benefits:**
- Separation of concerns
- Testability
- Future cloud sync integration point

### State Management

**Observable Stores:**
- `@Observable` macro (Swift 5.9+)
- Automatic change tracking
- Main actor isolation
- In-memory caching with database sync

**Store Responsibilities:**
- Maintain in-memory state
- Coordinate with repositories
- Provide computed properties
- Handle business logic

### Database Layer

**GRDB Integration:**
- Type-safe database access
- Migration system
- Record types for database mapping
- Transaction support

**Record Types:**
- `CharterRecord`
- `ChecklistRecord`
- `ChecklistExecutionRecord`
- `LibraryModelRecord`
- `PracticeGuideRecord`

### Markdown Processing

**MarkdownParser:**
- Custom parser for practice guides
- Supports: headings, paragraphs, lists, bold text
- Wiki-style link resolution
- Block-based rendering

---

## LIMITATIONS & KNOWN GAPS

### Phase 1 Limitations

1. **No Cloud Sync:**
   - All data is local-only
   - No multi-device support
   - No backup/restore

2. **No Community Features:**
   - No content sharing
   - No forking
   - No attribution
   - No ratings/voting

3. **Flashcard Decks:**
   - Structure defined but not fully implemented
   - No flashcard review interface
   - No spaced repetition system

4. **Content Discovery:**
   - No search functionality
   - No content browsing
   - No recommendations

5. **User Accounts:**
   - No authentication
   - No user profiles
   - No multi-user support

6. **Advanced Features:**
   - No content export
   - No import from external sources
   - No templates or starter content
   - No content versioning

### Technical Debt

1. **Error Handling:**
   - Some error handling could be more comprehensive
   - User-facing error messages need refinement

2. **Performance:**
   - Large checklist loading could be optimized
   - Cache management could be improved

3. **Testing:**
   - Unit tests exist but coverage could be expanded
   - UI tests not yet implemented

4. **Accessibility:**
   - Some accessibility improvements needed
   - VoiceOver support could be enhanced

---

## CONCLUSION

Phase 1 delivers a solid foundation for personal charter and content management. The app provides essential tools for sailors to organize their trips and build their personal knowledge library, all while working completely offline. The architecture is designed to seamlessly extend into Phase 2's community features.

The focus on offline-first architecture, local data ownership, and personal productivity sets the stage for Phase 2's evolution into a community-powered platform while maintaining the core principles of reliability and user control.

