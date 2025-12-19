# AnyFleet Sailing: Phase 1 to Phase 2 PRD

## Executive Summary

This Product Requirements Document provides a detailed roadmap for evolving AnyFleet Sailing from a personal utility (Phase 1) into a community-powered platform (Phase 2). The document structures development around **user stories tied to tiny increments**—each sprint delivers a complete end-to-end feature that users immediately experience.

**Key Principle:** Every feature increment maintains offline-first functionality, user data ownership, and backward compatibility. Complexity grows only as the platform needs it.

**Philosophy:** Build only what the platform needs at each stage. When there's 1 public checklist, we don't need filters. When there are 100K, we do.

---

## Vision Statement

**Phase 1:** "Your personal sailing companion"  
**Phase 2:** "The GitHub of sailing knowledge"

AnyFleet evolves from individual productivity into community-powered knowledge infrastructure—where sailors share procedures, contribute improvements, and collectively build standardized resources while maintaining complete offline capability and transparent attribution.

---

## Strategic Goals

| Goal | Phase 1 Success | Phase 2 Success |
|------|-----------------|-----------------|
| **User Base** | Individual sailors managing personal charters | Network effect: value increases with each user |
| **Content Ownership** | Complete local control | Users own + community benefits from sharing |
| **Data Permanence** | Local SQLite forever | Local SQLite + optional cloud sync for shared content |
| **Trust Model** | N/A (personal use) | Attribution chains, verification tiers, reputation |
| **Monetization Path** | N/A | Premium features, training bundles, API access |

---

## Phase 1: Current State (Foundation)

### Established Capabilities

- **Charter Management:** Create, organize, track charters with date ranges
- **Content Types:** Checklists (with sections/items), Practice Guides (markdown), Flashcard Decks (structure only)
- **Execution Tracking:** Per-charter checklist completion states
- **Local Storage:** SQLite via GRDB, all data on-device
- **Navigation:** Tab-based routing (Home, Charters, Library, Settings)
- **State Management:** Swift @Observable stores (CharterStore, LibraryStore)

### Phase 1 Limitations (to Address in Phase 2)

1. No sharing, forking, or community features
2. No user authentication
3. No cloud sync (all local)
4. No content discovery
5. No attribution system
6. No user profiles

---

## Technical Foundation

### Backend Stack

- **Framework:** FastAPI (Python)
- **Database:** PostgreSQL
- **Hosting:** Railway (with Docker Compose for local development)
- **API Design:** REST with JSON responses
- **Authentication:** OAuth 2.0 with PKCE (Apple Sign-In)
- **File Storage:** PostgreSQL BYTEA or external (defer for now)

### iOS Stack (No Changes)

- **Local Storage:** SQLite via GRDB
- **State Management:** Swift @Observable
- **HTTP Client:** URLSession
- **Authentication:** AuthenticationServices (ASWebAuthenticationSession for OAuth)

### Key Decision: Selective Cloud Sync

**Only shared content syncs to cloud.** Everything else stays local.

- **Private content:** 100% local, never synced
- **Shared content:** Syncs to cloud for discoverability
- **Benefits:** Reduced server load, simpler conflict resolution, user control

---

## JWT Session Management for iOS Apps

### How JWT Works in AnyFleet

1. **Apple Sign-In → Backend Exchange**
   - User taps "Sign in with Apple"
   - iOS generates `ASAuthorizationAppleIDCredential`
   - App sends `identityToken` to backend: `POST /auth/apple-signin`

2. **Backend Validates & Issues JWT**
   - Backend validates Apple's `identityToken` with Apple's key server
   - Backend creates/retrieves user record
   - Backend issues **two tokens**:
     - `access_token` (short-lived, 15 minutes): Used for API calls
     - `refresh_token` (long-lived, 7 days): Stored in Keychain, used to get new access tokens

3. **iOS Stores Tokens Securely**
   - **access_token**: Stored in memory or Keychain (short TTL, okay to lose)
   - **refresh_token**: Stored in Keychain (OS-level encryption)

4. **Making API Calls**
   - Every API request includes: `Authorization: Bearer {access_token}`
   - URLSession extension automatically attaches header

5. **Token Refresh Flow**
   ```
   Request fails with 401 (token expired)
   → App detects 401
   → App calls POST /auth/refresh with refresh_token
   → Backend returns new access_token
   → App retries original request with new token
   ```

6. **Logout**
   - App deletes tokens from Keychain
   - Backend invalidates refresh_token (optional—refresh token can expire)
   - User sees sign-in screen

### Benefits for AnyFleet

- **Stateless backend:** No session storage needed (scales easily on Railway)
- **Token expiration:** If device is compromised, access only valid for 15 minutes
- **Refresh offline:** Refresh tokens can work offline if cached (though we'll block for now)
- **Single sign-on ready:** Easy to add web app later using same JWT

---

## Implementation Roadmap: Tiny User Story Sprints

### Sprint 1: Apple Sign-In & Auth Foundation (1.5 weeks)

**User Story:** "As a sailor, I can sign in with Apple so my content can be synced and shared across devices."

#### 1.1 Backend Auth Endpoints

**Dependencies:** FastAPI, PostgreSQL, PyJWT

**Tasks:**

- [ ] Set up FastAPI app with CORS, logging
- [ ] Create `users` table (id, apple_id, email, username, created_at)
- [ ] Create `POST /auth/apple-signin` endpoint
  - Accepts: `identityToken` (from iOS)
  - Validates token with Apple's API
  - Creates or retrieves user record
  - Returns: `{ access_token, refresh_token, user: { id, email, username } }`
- [ ] Create `POST /auth/refresh` endpoint
  - Accepts: `refresh_token`
  - Issues new `access_token`
  - Returns: `{ access_token }`
- [ ] Create `POST /auth/logout` endpoint (optional—just delete tokens on client)
- [ ] Create `@requires_auth` decorator for protected endpoints
- [ ] Add rate limiting: 5 sign-in attempts per IP per 15 minutes

**Database Schema:**

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apple_id VARCHAR UNIQUE NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  username VARCHAR UNIQUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  token_hash VARCHAR NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### 1.2 iOS Sign-In Flow

**Tasks:**

- [ ] Create `AuthenticationService` class
  - Method: `signInWithApple() async throws -> (accessToken, refreshToken)`
  - Uses `ASWebAuthenticationSession` for OAuth
  - Handles cancellation, network errors
- [ ] Create `TokenManager` class (Keychain wrapper)
  - Stores refresh_token in Keychain
  - Stores access_token in memory
  - Provides `getAccessToken()` method
  - Refreshes token if expired
- [ ] Create `URLSession` extension: `withAuth()`
  - Automatically attaches `Authorization: Bearer` header
  - Intercepts 401 responses
  - Calls refresh endpoint automatically
  - Retries request with new token
- [ ] Add "Sign in with Apple" button to Settings tab
- [ ] Show loading state, error messages
- [ ] On successful sign-in: store tokens, update UI to show "Signed in as [username]"

**Acceptance Criteria:**

- [ ] User taps "Sign in with Apple" → system prompt
- [ ] User completes Apple auth → tokens stored in Keychain
- [ ] Settings shows "Signed in as [username]"
- [ ] Close and reopen app → signed in state persists
- [ ] Token refresh happens transparently (user doesn't see 401)

**UI:**

**Settings Tab Addition:**
```
┌─────────────────────────┐
│ Settings                │
├─────────────────────────┤
│ Account                 │
│  Sign in with Apple  >  │
│                         │
│ (After sign-in)         │
│ Signed in as: captain   │
│  [Sign out]             │
└─────────────────────────┘
```

#### 1.3 Minimal User Profile Data

**Note:** We are NOT building a profile edit screen yet. Username is auto-generated from Apple data or randomized.

**Tasks:**

- [ ] Auto-generate username from Apple email (first part before @) or UUID-based fallback
- [ ] Store username in `users` table
- [ ] Backend endpoint: `GET /api/users/me` returns `{ id, email, username }`
- [ ] iOS: Call after sign-in, cache locally
- [ ] Show username in Settings (read-only for now)

**Acceptance Criteria:**

- [ ] User signs in → username auto-set from Apple data
- [ ] `GET /api/users/me` returns correct user data
- [ ] Username displays in Settings

---

### Sprint 2: Shared Content & Basic Sync (2 weeks)

**User Story:** "As a sailor, I can share a checklist publicly so other sailors can find and use it."

**Prerequisite:** Sprint 1 complete (auth working)

#### 2.1 Visibility Toggle in App

**Tasks:**

- [ ] Add `visibility` enum to local content (PRIVATE, PUBLIC)
- [ ] In checklist/guide detail view: add toggle button for visibility
  - Text: "Private" → [toggle] → "Public"
  - Initially disabled (grayed out) until user signs in
  - On tap: shows confirmation "Share [Title] publicly? Others can see and fork this."
- [ ] Save visibility state locally in GRDB
- [ ] Show visibility status below title: "🔒 Private" or "🌍 Public"

**Acceptance Criteria:**

- [ ] Visibility toggle appears in detail view
- [ ] Toggle disabled until signed in
- [ ] Toggling changes local visibility state
- [ ] Visibility persists across app restarts

**UI Mockup:**

```
Checklist Detail
═════════════════════════════
Pre-Charter Check          🔒 Private  [→ Public]

(content...)

(At bottom)
Last updated: 2 hours ago
Status: Ready to share
```

#### 2.2 Backend Content Sharing Endpoint

**Tasks:**

- [ ] Create `shared_content` table (id, original_checklist_id, user_id, content_data_json, created_at)
- [ ] Endpoint: `POST /api/content/share` (requires auth)
  - Input: `{ title, description, content_type, content_data, tags }`
  - Creates row in `shared_content` table
  - Stores full content as JSON (for discoverability)
  - Returns: `{ shared_content_id, public_url }`
- [ ] Endpoint: `GET /api/content/:id` (public, no auth)
  - Returns shared content with creator info
- [ ] Endpoint: `GET /api/content/public` (public, no auth)
  - Returns paginated list of all shared content
  - Minimal fields: title, creator, content_type, created_at
  - Pagination: cursor-based, 20 items per page

**Database Schema:**

```sql
CREATE TABLE shared_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR NOT NULL,
  description TEXT,
  content_type VARCHAR NOT NULL, -- 'checklist', 'guide', 'deck'
  content_data JSONB NOT NULL,   -- full content (sections, items, etc)
  tags TEXT[],                   -- array of strings
  views_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_shared_content_created ON shared_content(created_at DESC);
CREATE INDEX idx_shared_content_user ON shared_content(user_id);
```

#### 2.3 iOS Sync: Share to Cloud

**Tasks:**

- [ ] When user toggles visibility to PUBLIC:
  - Show loading spinner
  - Call `POST /api/content/share` with local content data
  - If success: store shared_content_id locally, show "✅ Shared!" toast
  - If error: show error toast, toggle back to PRIVATE
- [ ] Create "Discover" tab (4th tab, after Settings)
  - Simple list of public shared_content
  - Shows: [Content Title] by [Creator Name] — [Type] — [Relative time]
  - On tap: opens content detail view (read-only)
  - Pull to refresh
- [ ] On content detail (shared content): show "By [Creator Name]" prominently at top
- [ ] Add "Copy Link" and "Share Sheet" buttons for shared content

**Acceptance Criteria:**

- [ ] User toggles visibility → `POST /api/content/share` called
- [ ] Success: "✅ Shared!" toast, visibility updates to 🌍 Public
- [ ] Discover tab shows shared content
- [ ] Tap shared content → view full details
- [ ] Creator attribution visible

**UI Mockup:**

```
Discover Tab
═════════════════════════════
(Pull to refresh)

📋 Pre-Charter Check
   by Captain Maria
   Checklist • 2 hours ago

🧭 Weather Routing
   by Alex Smith
   Guide • 1 day ago

(More items...)
```

#### 2.4 Unshare (Toggle Back to Private)

**Tasks:**

- [ ] User can toggle shared content back to PRIVATE
- [ ] Soft delete: `DELETE FROM shared_content WHERE id = X` (or add `is_deleted` flag)
- [ ] Local content remains, just no longer public
- [ ] Show confirmation: "Unshare [Title]? It will no longer be discoverable."

**Acceptance Criteria:**

- [ ] User can toggle PUBLIC → PRIVATE
- [ ] Confirmation shown
- [ ] Content disappears from Discover tab (after refresh)
- [ ] Local copy remains unchanged

---

### Sprint 3: Forking & Attribution (2 weeks)

**User Story:** "As a sailor, I can fork someone's shared checklist to personalize it for my boat."

**Prerequisite:** Sprint 2 complete (shared content exists)

#### 3.1 Fork Button & Local Import

**Tasks:**

- [ ] On shared content detail view: add "📋 Fork to My Library" button
- [ ] On tap:
  - Show confirmation: "Copy [Title] to your library? You'll own the copy."
  - Call local fork logic: create new checklist in GRDB with all content
  - Add metadata: `forked_from_id`, `original_creator_name`
  - Show "✅ Forked to your library" toast
  - Optionally navigate to forked content detail (editable)
- [ ] Forked content stored 100% locally, starts PRIVATE
- [ ] User can edit fork immediately

**Local Storage (GRDB):**

```swift
struct Checklist: Codable {
  var id: UUID
  var title: String
  var description: String?
  var visibility: Visibility // PRIVATE, PUBLIC
  var forked_from_id: UUID?   // NEW: reference to shared_content.id
  var original_creator: String? // NEW: "Captain Maria"
  var created_at: Date
  var updated_at: Date
}
```

**Acceptance Criteria:**

- [ ] "Fork" button visible on shared content
- [ ] Tap fork → confirmation dialog
- [ ] Fork created in local library
- [ ] Forked content shows "Based on [Original Title] by [Creator]" at top
- [ ] User can edit fork without affecting original

**UI Mockup:**

```
Shared Content Detail
═════════════════════════════
🧭 Mediterranean Sailing
by Alex Smith

Based on: Atlantic Routes by Captain Maria
⭐⭐⭐⭐⭐ (42 views)

(Content preview...)

[📋 Fork to My Library]
[Share] [Copy Link]
```

#### 3.2 Attribution on Local Content

**Tasks:**

- [ ] In Library, show forked content with visual indicator:
  - Icon: small "fork" symbol or "branches" icon
  - Text: "Based on [Original] by [Creator]"
  - On tap creator name: (defer detail for now, just show name)
- [ ] Content detail: Show fork chain metadata (read-only)
  ```
  Based on: Atlantic Routes (by Captain Maria)
  ```

**Acceptance Criteria:**

- [ ] Forked content shows in library with attribution
- [ ] Attribution clickable (for future linking, now just visual)
- [ ] Original content creators credited

**UI Mockup:**

```
Library View
═════════════════════════════
My Content

📋 Pre-Charter Check
   Created 5 days ago

🧭 Mediterranean Routes
   ↳ Based on Atlantic Routes by Captain Maria
   Created 2 hours ago (forked)

(Edit/Delete actions...)
```

#### 3.3 Backend: Fork Tracking

**Tasks:**

- [ ] Create `content_forks` table (id, original_shared_content_id, fork_count, last_forked_at)
- [ ] Update `shared_content`: add `fork_count` INT
- [ ] When user forks (local only for now): increment fork_count on next sync
  - OR: Create endpoint `POST /api/content/:id/fork-notification` to increment server-side count
- [ ] Endpoint: `GET /api/content/:id/stats` 
  - Returns: `{ views_count, fork_count, created_at, creator }`

**Database Schema:**

```sql
ALTER TABLE shared_content ADD COLUMN fork_count INT DEFAULT 0;

CREATE TABLE content_forks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shared_content_id UUID NOT NULL REFERENCES shared_content(id),
  created_at TIMESTAMP DEFAULT NOW()
  -- Note: We don't track who forked (privacy). Just count.
);
```

**Acceptance Criteria:**

- [ ] Backend tracks fork count
- [ ] Fork count shown on Discover tab (e.g., "42 forks")
- [ ] Fork count accurate

---

### Sprint 4: Share & Modify Workflow (1.5 weeks)

**User Story:** "As a sailor, when I modify my forked content and re-share it, my changes are clearly attributed to me."

**Prerequisite:** Sprint 3 complete (forking works)

#### 4.1 Share Modified Fork

**Tasks:**

- [ ] User forks content, makes changes, toggles to PUBLIC
- [ ] Modified forked content now "published" to shared_content with:
  - `title`: "Mediterranean Routes [Modified]" (auto-suffix, user can edit)
  - `forked_from_id`: reference to original
  - `original_creator`: preserved
- [ ] Backend tracks lineage: Original → Fork → Published Modification
- [ ] New endpoint: `GET /api/content/:id/lineage`
  - Returns: `[ { title, creator, created_at, is_current: true/false } ]`
  - Shows chain: Original → Alex's Fork → Captain's Improvement

**Acceptance Criteria:**

- [ ] User forks, modifies, shares
- [ ] Shared modified content shows attribution chain
- [ ] Original creator credited
- [ ] Fork creator (now publisher) credited

**UI Mockup:**

```
Shared Content Detail
═════════════════════════════
🧭 Mediterranean Routes [Enhanced]
by Captain Maria

Lineage:
  Atlantic Routes (Captain Smith)
  → Mediterranean Routes (Alex)
  → Mediterranean Routes [Enhanced] (Captain Maria) ⭐ Current

Fork Count: 8
```

#### 4.2 Backend: Enhanced Fork Tracking

**Tasks:**

- [ ] Update `content_forks` table:
  ```sql
  ALTER TABLE content_forks ADD COLUMN parent_shared_content_id UUID;
  ALTER TABLE content_forks ADD COLUMN child_shared_content_id UUID;
  -- parent → child relationship
  ```
- [ ] Implement recursive query for lineage:
  ```sql
  WITH RECURSIVE lineage AS (
    SELECT id, forked_from_id, title, user_id, created_at, 1 as depth
    FROM shared_content WHERE id = $1
    UNION ALL
    SELECT sc.id, sc.forked_from_id, sc.title, sc.user_id, sc.created_at, l.depth + 1
    FROM shared_content sc
    JOIN lineage l ON sc.id = l.forked_from_id
    WHERE l.depth < 10  -- prevent infinite loops
  )
  SELECT * FROM lineage ORDER BY depth DESC;
  ```

**Acceptance Criteria:**

- [ ] Fork chain queryable
- [ ] Lineage endpoint works
- [ ] Shows complete attribution history

---

### Sprint 5: Content Modification & Sync Update (1.5 weeks)

**User Story:** "As a creator, when I update my shared content, followers see the latest version and updates sync reliably."

**Prerequisite:** Sprints 1-4 complete

#### 5.1 Update Shared Content

**Tasks:**

- [ ] User modifies local forked content that's currently shared
- [ ] Toggle to PUBLIC state → shows "Update Shared" instead of "Share"
- [ ] Call `PATCH /api/content/:id` with updated content_data
- [ ] Backend updates `shared_content.content_data` and `updated_at`
- [ ] Show "✅ Updated" toast

**Acceptance Criteria:**

- [ ] User can modify shared content
- [ ] Updates sync to backend
- [ ] New viewers see updated content
- [ ] View count doesn't reset

#### 5.2 Sync Queue (Foundation)

**Tasks:**

- [ ] Create local `sync_queue` table in GRDB:
  ```swift
  struct SyncQueueItem {
    var id: UUID
    var shared_content_id: UUID?
    var action: String // "share", "update", "unshare"
    var status: String // "pending", "synced", "failed"
    var created_at: Date
    var synced_at: Date?
    var error_message: String?
  }
  ```
- [ ] When user shares/updates/unshares: add to sync_queue
- [ ] Background sync:
  - Runs every 5 seconds when app is foreground
  - Runs via background task (5 min window) when backgrounded
  - Processes pending items in order
  - On success: mark as synced
  - On failure: retry up to 3 times, then mark failed with error
- [ ] UI: Show sync status in Settings
  - "All synced ✅"
  - "Syncing..." (spinner)
  - "3 pending" (if offline)
  - "1 failed - tap to retry"

**Acceptance Criteria:**

- [ ] Share/update/unshare added to sync_queue
- [ ] Background sync processes queue
- [ ] User sees sync status
- [ ] Offline → online: automatic retry
- [ ] Network error → retry with backoff

**UI Mockup:**

```
Settings
═════════════════════════════
Account
  Signed in as: captain
  [Sign out]

Sync Status
  ✅ All synced (last: 2 min ago)
  
  Pending items: 0
  Failed items: 0
  
  [Manual Sync Now]
```

---

## UI / UX Patterns

### Attribution Display (Non-Overwhelming)

**Goal:** Show provenance without cluttering the interface.

#### Pattern 1: List View Attribution

```
List of shared content (Discover tab)

📋 Mediterranean Routes
   by Alex Smith • 12 forks • 3 days ago

(Creator name + stats on one line, smaller font)
```

#### Pattern 2: Detail View Attribution

```
Content Detail

╔═════════════════════════════════════╗
│ 🧭 Mediterranean Routes              │
│ by Alex Smith                         │
╚═════════════════════════════════════╝

Lineage (collapsible, default closed):
  ▶ Based on Atlantic Routes (Captain Maria)
  
[Fork to My Library]  [Share]  [Copy Link]

(Content below...)
```

If user taps "▶ Based on...":

```
╔════════════════════════════════════════╗
│ Attribution Chain                       │
├────────────────────────────────────────┤
│ 1️⃣ Atlantic Routes                      │
│   by Captain Maria • 2022              │
│   ↓ forked 8 times                     │
│ 2️⃣ Mediterranean Routes                │
│   by Alex • 2024                       │
│   ↓ forked 3 times                     │
│ 3️⃣ Mediterranean Routes [Enhanced]     │
│   by You • 2 hours ago                 │
│   ← You are here                       │
╚════════════════════════════════════════╝
```

#### Pattern 3: My Library with Forks

```
My Library

📋 Pre-Charter Check
   Created 5 days ago • Private

🧭 Mediterranean Routes
   ↳ Based on Atlantic Routes (Alex)
   Forked 2 hours ago • Public
   
   [> Show lineage]  [Edit]  [Unshare]
```

### Profile Information (Minimal for Now)

**In Sprint 1-4:** We only show username on Settings tab. No profile pages yet.

**UI:**

```
Settings > Account

Signed in as: captain_maria
(UUID: a7f2-9d1c-...)

[Sign out]

(No "edit profile" yet)
```

### Share-Time Auth Flow (For Later Sprints)

**When user tries to share before signing in:**

```
Content Detail (unsigned)

[🌍 Share Publicly]  ← User taps

Modal appears:
╔════════════════════════════════════╗
│ Sign in to Share                    │
├────────────────────────────────────┤
│ Share your sailing knowledge with   │
│ the AnyFleet community.             │
│                                    │
│ [Sign in with Apple]               │
│                                    │
│ Or use locally:                    │
│ [Keep Private]                     │
╚════════════════════════════════════╝
```

If user taps "Sign in with Apple" → proceeds with auth, then shares.
If user taps "Keep Private" → dismisses modal, content stays local.

---

## Backend Tech Details

### FastAPI Structure

```
anyfleet-backend/
├── main.py                 # App entry
├── requirements.txt        # Python deps
├── docker-compose.yml      # Local PostgreSQL
├── .env.example            # Config template
├── app/
│   ├── __init__.py
│   ├── core/
│   │   ├── config.py      # Settings (JWT secret, DB URL, etc)
│   │   ├── security.py    # JWT encode/decode, auth decorators
│   │   └── database.py    # PostgreSQL connection pool
│   ├── models/
│   │   ├── user.py        # User model
│   │   ├── content.py     # Shared content model
│   │   └── schemas.py     # Pydantic schemas for API
│   ├── api/
│   │   ├── auth.py        # /auth endpoints
│   │   ├── content.py     # /api/content endpoints
│   │   └── users.py       # /api/users endpoints
│   └── services/
│       ├── apple_auth.py  # Apple token validation
│       └── content_service.py
└── tests/
    ├── test_auth.py
    └── test_content.py
```

### Key Endpoints (Sprint 1-5)

#### Auth

```
POST /auth/apple-signin
  Body: { identityToken: string }
  Response: { access_token, refresh_token, user }

POST /auth/refresh
  Body: { refresh_token: string }
  Response: { access_token }

GET /api/users/me (requires auth)
  Response: { id, email, username }
```

#### Content

```
POST /api/content/share (requires auth)
  Body: { title, description, content_type, content_data, tags }
  Response: { id, public_url }

GET /api/content/public
  Query: ?page=1&limit=20&sort=newest
  Response: [ { id, title, creator, type, views, forks, created_at } ]

GET /api/content/:id
  Response: { id, title, creator, content_data, fork_count, lineage: [...] }

PATCH /api/content/:id (requires auth, owner only)
  Body: { title, description, content_data }
  Response: { id, updated_at }

DELETE /api/content/:id (requires auth, owner only)
  Response: { success: true }
```

### Deployment to Railway

```bash
# 1. Create railway.json
{
  "build": { "builder": "dockerfile" },
  "deploy": { "startCommand": "uvicorn app.main:app --host 0.0.0.0 --port $PORT" }
}

# 2. Link Railway project
railway link

# 3. Add PostgreSQL plugin (Railway UI)
# Creates DATABASE_URL automatically

# 4. Deploy
git push

# Railway automatically:
# - Builds Docker image
# - Runs migrations
# - Deploys to public URL
```

---

## Data Migration & Backward Compatibility

### Phase 1 → Phase 2 Content Migration

- **Phase 1 content** (local checklists, guides) remains 100% functional
- **No forced migration** to cloud
- **Opt-in sharing:** User decides when/if to make content public
- **Preservation:** If user shares Phase 1 content, original creation date preserved

---

## Success Metrics

### Engagement Metrics

| Metric | Sprint 1-2 | Sprint 3-5 |
|--------|-----------|-----------|
| Users who sign in | 20% | 40%+ |
| Users who share content | 0% | 15%+ |
| Users who fork content | 0% | 10%+ |
| Avg session time (min) | 8 | 12+ |

### Technical Metrics

| Metric | Target |
|--------|--------|
| API response time (p95) | 200ms |
| Sync success rate | 99% |
| App load time | 2s (cold start) |

### Business Metrics

| Metric | Target |
|--------|--------|
| MAU Phase 2 | 10K+ (by end of Sprint 5) |
| Content items shared | 1K+ |
| Fork count | 500+ |

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Apple Sign-In fails | Low | High | Graceful error, retry, support email |
| Sync conflicts | Medium | Medium | User chooses local/cloud, clear UI |
| Slow sync on poor network | Medium | Medium | Queue mechanism, exponential backoff |
| Users don't share | High | High | Onboarding UX, in-app tutorial |
| Spam/abuse content | Medium | High | Reporting mechanism (defer Sprint 6) |

---

## Team & Timeline

### Team

- **Backend Engineer (1):** FastAPI, PostgreSQL, Railway deployment
- **iOS Engineer (1-2):** Auth integration, sync queue, UI
- **Total Duration:** 8-10 weeks for Sprints 1-5

### Milestones

- **Sprint 1:** 1.5 weeks → Auth, minimal profile
- **Sprint 2:** 2 weeks → Share & discover
- **Sprint 3:** 2 weeks → Fork & attribution
- **Sprint 4:** 1.5 weeks → Modified content sharing
- **Sprint 5:** 1.5 weeks → Sync queue & updates

**Total:** ~9 weeks from Sprint 1 start to Sprint 5 completion

---

## Questions Answered

### 1. JWT Session Management

✅ **Explained:** JWT is a stateless token that iOS stores in Keychain. Short-lived access_token (15 min) for API calls, long-lived refresh_token (7 days) to get new access tokens. Scales easily on Railway—no session storage needed.

### 2. User Profile Priority

✅ **Deprioritized:** Sprint 1 creates minimal username (auto-generated). No profile edit screen until later. Share-time: User sees simple modal to sign in before sharing.

### 3. Selective Sync

✅ **Implemented:** Only shared content syncs to cloud. Private content stays 100% local. Reduces complexity and server load significantly.

### 4. Backend Stack

✅ **Specified:** FastAPI + PostgreSQL + Railway. Docker Compose for local dev. Stateless API for easy scaling.

### 5. Complexity Increments

✅ **Restructured:** Sprints now tied to user stories, not feature domains. Example: Sprint 2 is complete end-to-end "share & discover" story. No premature filters/search—built only when needed.

### 6. UI Attribution

✅ **Designed:** Minimal patterns that don't overwhelm:
- List view: 1-line credit "by Creator • stats"
- Detail view: Creator name + collapsible lineage chain
- Library view: Fork indicator + base content link

---

## Appendix: User Story Map

```
Phase 2 User Stories (In Order)

Sprint 1: "I can sign in with Apple"
  └─ Auth works, tokens stored, minimal username

Sprint 2: "I can share a checklist publicly"
  ├─ Visibility toggle
  ├─ Share to cloud
  ├─ Discover tab
  └─ See shared content with attribution

Sprint 3: "I can fork someone's checklist"
  ├─ Fork button
  ├─ Local copy created
  ├─ Show "based on" attribution
  └─ Backend tracks fork count

Sprint 4: "I can modify my fork and re-share"
  ├─ Share modified fork
  ├─ Show lineage chain
  └─ Original creator credited

Sprint 5: "My updates sync reliably"
  ├─ Update shared content
  ├─ Sync queue (local)
  ├─ Background sync
  └─ Sync status UI
```
