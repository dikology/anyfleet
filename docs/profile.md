# Profile Overhaul — Implementation Plan

> Focus: Communities + Social Links + Stats Dashboard
> Prerequisite: `ProfileViewModel` already extracted (Step 5 in refactor-march.md) ✓

---

## 1. Vision & Design Principles

Communities are discovery hubs — the connective tissue between sailors, content, and charters. A user's profile becomes a **sailing identity card**: where they sail, who they sail with, and how they engage with the platform.

### Community Types

| Type | Examples |
|---|---|
| Local/Regional | Harbor-based fleets, regional sailing clubs |
| Skill/Interest | Beginners, advanced racing, cruising culture |
| Affinity | Multilingual groups, women sailors, retirees |
| Brand | Sailing schools, equipment brands, programs |

### Membership Model

- Users join multiple communities; profile shows subscribed communities
- Communities are **open** (auto-join) or **moderated** (request approval — Phase 4)
- Community flag/icon appears on profile and charter listings
- Roles: `member`, `moderator`, `founder` — *moderator/founder assignment is out of scope now, but model must accommodate it*
- Users can designate one community as **primary** (shown prominently on profile and charter cards)

### Community Creation Flow

When a user types a community name in the edit form:
1. Live search against `/communities/search?q=` returns existing matches
2. If match exists → user selects it and joins
3. If no match → user can create it; they become a plain **member** (not founder/moderator — that designation is a Phase 4 decision)

> **Rationale:** Founding/moderating a community implies moderation responsibilities and tooling we haven't built. Creating a community just seeds the database so others can discover and join it.

---

## 2. Data Model Changes

### iOS — `UserInfo` (currently in `AuthService.swift`)

```swift
struct UserInfo: Codable {
    // existing fields unchanged
    let id: String
    let email: String
    let username: String?
    let createdAt: String
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let profileVisibility: String?

    // NEW
    var socialLinks: [SocialLink]?
    var communities: [CommunityMembership]?
    var stats: CaptainStats?
}

struct SocialLink: Codable, Identifiable {
    var id: UUID = UUID()
    let platform: SocialPlatform
    let handle: String                      // stored without prefix ("johndoe_sail")
    var url: URL? { platform.url(for: handle) }
}

enum SocialPlatform: String, Codable, CaseIterable {
    case instagram, telegram, other

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .telegram:  "Telegram"
        case .other:    "Other"
        }
    }

    var urlPrefix: String {
        switch self {
        case .instagram: "instagram.com/"
        case .telegram:  "t.me/"
        case .other:    ""
        }
    }

    var icon: String {          // SF Symbol names
        switch self {
        case .instagram: "camera"
        case .telegram:  "paperplane"
        case .other:    "link"
        }
    }

    func url(for handle: String) -> URL? {
        switch self {
        case .instagram: URL(string: "https://instagram.com/\(handle)")
        case .telegram:  URL(string: "https://t.me/\(handle)")
        case .other:    URL(string: handle.hasPrefix("http") ? handle : "https://\(handle)")
        }
    }
}

struct CaptainStats: Codable {
    let chartersCompleted: Int
    let nauticalMiles: Int              // sum of charter route distances
    let daysAtSea: Int                  // sum of charter durations
    let communitiesJoined: Int
    let regionsVisited: Int             // unique regions from charter destinations
    let contentPublished: Int
}

struct CommunityMembership: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let role: CommunityRole
    var isPrimary: Bool
}

enum CommunityRole: String, Codable {
    case member
    case moderator      // future: can pin content, manage join requests
    case founder        // future: can edit community profile, promote moderators
}

// Lightweight struct for search results / directory listing
struct CommunitySearchResult: Codable, Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let memberCount: Int
    let isOpen: Bool                    // open (auto-join) vs moderated
}
```

### iOS — `ProfileViewModel.swift` additions

```swift
// Add to existing ProfileViewModel
var socialLinks: [SocialLink] = []
var communities: [CommunityMembership] = []
var communitySearchQuery: String = ""
var communitySearchResults: [CommunitySearchResult] = []
var isSearchingCommunities: Bool = false

// Edit state mirrors
var editedSocialLinks: [SocialLink] = []
var editedCommunities: [CommunityMembership] = []
```

---

## 3. Backend Changes

### `app/models/user.py` — new columns

```python
from sqlalchemy.dialects.postgresql import JSONB

class User(Base):
    # ... existing fields ...
    social_links: Mapped[list[dict]] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )
    community_memberships: Mapped[list[dict]] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )
```

### New `Community` model

```python
class Community(Base):
    __tablename__ = "communities"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    slug: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    community_type: Mapped[str] = mapped_column(String(50), default="open")   # open | moderated
    member_count: Mapped[int] = mapped_column(Integer, default=1)
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
```

> No `founder`/`moderator` assignment on creation yet — `created_by` is stored for future use but the creator gets `member` role.

### Alembic migration

```python
# alembic/versions/2026_03_15_0001_add_social_links_communities.py
def upgrade():
    op.create_table(
        "communities",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False, unique=True),
        sa.Column("slug", sa.String(100), nullable=False, unique=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("icon_url", sa.String(500), nullable=True),
        sa.Column("community_type", sa.String(50), nullable=False, server_default="open"),
        sa.Column("member_count", sa.Integer, nullable=False, server_default="1"),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.add_column("users", sa.Column("social_links", JSONB, nullable=False, server_default="[]"))
    op.add_column("users", sa.Column("community_memberships", JSONB, nullable=False, server_default="[]"))

def downgrade():
    op.drop_column("users", "social_links")
    op.drop_column("users", "community_memberships")
    op.drop_table("communities")
```

### `app/schemas/profile.py` additions

```python
class SocialLinkSchema(BaseModel):
    id: str
    platform: Literal["instagram", "telegram", "other"]
    handle: str

class CommunityMembershipSchema(BaseModel):
    id: str
    name: str
    icon_url: str | None = None
    role: Literal["member", "moderator", "founder"] = "member"
    is_primary: bool = False

class UpdateProfileRequest(BaseModel):
    # existing fields
    username: str | None = None
    bio: str | None = None
    location: str | None = None
    nationality: str | None = None
    profile_visibility: str | None = None
    # NEW
    social_links: list[SocialLinkSchema] | None = None
    community_memberships: list[CommunityMembershipSchema] | None = None
```

### New API routes (`app/routers/communities.py`)

```
GET  /communities/search?q=&limit=10     → list[CommunitySearchResult]
POST /communities                        → create community, creator joins as member
POST /communities/{id}/join              → join community (open: immediate; moderated: pending)
DELETE /communities/{id}/leave           → leave community
```

---

## 4. Stats Dashboard — Data Sources

The reference UI shows 4 stat circles. Here's what we can actually populate and how:

| Stat | Source | Availability | Notes |
|---|---|---|---|
| Total Charters | Backend `ProfileStatsResponse.total_contributions` | **Now** | Already in API |
| Nautical Miles | Backend — sum of charter route distances | **Phase 3** | Need `distance_nm` on `Charter` model |
| Days at Sea | Backend — sum of `(end_date - start_date)` per charter | **Now** | Charters already have `start_date`/`end_date`; aggregate in profile stats |
| Communities Joined | `len(user.community_memberships)` | **Now (after this work)** | Computed locally |
| Regions Visited | Backend — distinct regions from charter destinations | **Phase 3** | Needs geocoding step |
| Content Published | Backend `total_contributions` | **Now** | Already tracked |

### Phased rollout for stats

**Phase 2 (now):** Show Charters Completed, Days at Sea, and Communities Joined with real data. Days at Sea is computed from existing `start_date`/`end_date` on charters — backend aggregates and returns in profile stats. Show Nautical Miles as `—` with a subtle "coming soon" treatment — *never fake zeros*.

**Phase 3:** Add `distance_nm` to `Charter` model for nautical miles; expose aggregated stats via `GET /profile/stats` endpoint extending current `ProfileStatsResponse`.

### `CaptainStats` — iOS computation logic

```swift
// ProfileViewModel.swift
func buildStats(from contributions: ContributionMetrics?, communities: [CommunityMembership]) -> CaptainStats {
    CaptainStats(
        chartersCompleted: contributions?.totalContributions ?? 0,
        nauticalMiles: 0,           // Phase 3 — shown as "—" in UI
        daysAtSea: contributions?.daysAtSea ?? 0,  // from backend — sum of charter durations
        communitiesJoined: communities.count,
        regionsVisited: 0,          // Phase 3
        contentPublished: contributions?.createdCount ?? 0
    )
}
```

---

## 5. iOS View Decomposition

Current `ProfileView.swift` is 441 lines. Target structure:

```
Features/Profile/
├── ProfileView.swift               (~120 lines — container + state routing)
├── ProfileViewModel.swift          (~230 lines — add community/social state)
├── Components/
│   ├── ProfileHeroCard.swift       (avatar + background, name, bio, edit button)
│   ├── ProfileStatsBar.swift       (4-stat row using CaptainStats)
│   ├── CommunitiesSection.swift    (community chips + search/join flow)
│   ├── SocialLinksSection.swift    (instagram / telegram / other rows)
│   └── ProfileEditForm.swift       (extracted from DesignSystem.Profile.EditForm — adds socials + communities)
└── CommunitySearch/
    └── CommunitySearchSheet.swift  (search + create flow presented as sheet)
```

### `ProfileHeroCard`

The existing `DesignSystem.Profile.Hero` already supports a background image via `profileImageUrl`. Extend it to accept an optional `sailingPhotoURL` separate from avatar — falls back to `DesignSystem.Gradients.heroImageOverlay`.

```swift
struct ProfileHeroCard: View {
    let user: UserInfo
    let primaryCommunity: CommunityMembership?
    let onEdit: () -> Void

    // Shows sailing background photo (or gradient fallback),
    // avatar with border, username, location, primary community badge
}
```

### `ProfileStatsBar`

4 circular progress rings matching the reference UI, using `DesignSystem.Colors`:

```swift
struct StatCircle: View {
    let value: String           // "5", "450", "—"
    let label: String           // "Charters\nCompleted"
    let color: Color
    let progress: Double        // 0.0–1.0, drives stroke dash offset
    let isPlaceholder: Bool     // true → render "—" in muted color, no ring fill
}
```

Color mapping (using existing DesignSystem tokens):
- Charters → `DesignSystem.Colors.primary` (teal)
- Miles → `DesignSystem.Colors.info` (blue)
- Days at Sea → `DesignSystem.Colors.success` (green)
- Communities → `DesignSystem.Colors.communityAccent` (gold)

### `CommunitiesSection` (profile display mode)

```swift
struct CommunitiesSection: View {
    let memberships: [CommunityMembership]
    let onSetPrimary: (String) -> Void
    let onLeave: (String) -> Void
    let onAddTapped: () -> Void     // opens CommunitySearchSheet
}
```

- Shows chips in a `FlowLayout` (wrapping horizontal layout)
- Primary community chip has a gold border + `⚓` prefix
- Each chip has a long-press context menu: "Set as Primary" / "Leave"
- "+ Find Communities" button at the bottom opens `CommunitySearchSheet`

### `CommunitySearchSheet`

Presented as a `.sheet` from `ProfileView`:

1. `TextField` with live search (debounced 300ms via `Task` + `try await Task.sleep`)
2. `List` of `CommunitySearchResult` rows — name, member count, open/moderated badge
3. If query returns 0 results and user has typed ≥ 3 chars: show "Create '\(query)' community" row
4. On selection: call `viewModel.joinCommunity(id:)` or `viewModel.createAndJoinCommunity(name:)`
5. Sheet dismisses and new chip appears in `CommunitiesSection`

### `SocialLinksSection` (edit mode)

```swift
struct SocialLinksSection: View {
    @Binding var links: [SocialLink]
}
```

- One row per `SocialPlatform.allCases`
- Prefix label (`instagram.com/`, `t.me/`, link icon for other) + `TextField` for handle
- Empty handle = link not saved (don't send to backend)
- Tapping a saved link opens the URL in `SafariServices`

### `ProfileEditForm` — extended

The existing `DesignSystem.Profile.EditForm` handles username/bio/location/nationality. Add two new sections below it:
1. `SocialLinksSection` (edit mode)
2. Community management (inline chips + "Add" button → sheet)

---

## 6. Community Badge — Cross-Feature Token

The community badge appears on profile chips, charter cards, and map pins. Define a shared view:

```swift
// DesignSystem/Components/CommunityBadge.swift
struct CommunityBadge: View {
    let name: String
    let iconURL: URL?
    var style: Style = .pill     // .pill (full text), .icon (small square icon only)
}
```

Uses `DesignSystem.Colors.communityAccent` (already defined as `gold`) for border/text. This token is already documented as "Community badge, pending sync state" in the DesignSystem — we're fulfilling that intent.

---

## 7. Discover Tab Integration (Phase 3 scope, design now)

Adding communities as a filter layer on the Discover tab:

- Top of Discover: existing category chips gain a **"My Communities"** chip at position 0
- When "My Communities" is active, charter list filters to `charter.communityId IN user.communityIds`
- Backend: `GET /charters/discover?community_ids=id1,id2&...` (extend existing endpoint)
- Map pins for community-member captains show a small gold community badge overlay

> Spec this interface now so the backend `charter.py` discovery endpoint is designed with community filtering in mind, even if the UI lands in Phase 3.

---

## 8. Implementation Sequence

### Backend (do first — iOS blocks on API)

1. **Alembic migration** — add `social_links`, `community_memberships` columns + `communities` table
2. **Community CRUD** — `POST /communities`, `GET /communities/search`, `POST /communities/{id}/join`, `DELETE /communities/{id}/leave`
3. **Profile schema** — extend `UpdateProfileRequest` + `UserResponse` to include `social_links` and `community_memberships`
4. **Stats endpoint** — extend `GET /profile/stats` to include `communities_joined` count and `days_at_sea` (sum of `(end_date - start_date).days` across user's charters)
5. **Profile service fix** — async file I/O (aiofiles) + orphaned image cleanup (already specced in refactor-march.md Step 3)

### iOS

6. **Models** — add `SocialLink`, `CommunityMembership`, `CommunityRole`, `CaptainStats`, `CommunitySearchResult` to `Core/Models/` (or move `UserInfo` there from `AuthService.swift` while we're at it)
7. **ProfileViewModel** — add community/social state + `joinCommunity`, `createAndJoinCommunity`, `leaveCommunity`, `setPrimaryCommunity`, `searchCommunities` methods
8. **API client** — add community endpoints to `APIClientProtocol`
9. **ProfileHeroCard** — extract from `DesignSystem.Profile.Hero`, add sailing background support
10. **ProfileStatsBar** — new component with 4 stat circles
11. **CommunitiesSection** — chips display + long-press menu
12. **CommunitySearchSheet** — search + create flow
13. **SocialLinksSection** — 3 platform rows
14. **ProfileEditForm** — wire new sections into existing edit flow
15. **ProfileView** — refactor to use new components (reduce from 441 → ~120 lines)
16. **CommunityBadge** — shared token in `DesignSystem/Components/`
17. **Charter cards** — add primary community badge (small gold pill) below captain name

---

## 9. Tests

### Backend

```python
# CRITICAL — community creation is idempotent on name
async def test_create_community_duplicate_name_returns_existing(client, auth_headers):
    r1 = await client.post("/communities", json={"name": "Med Sailors"}, headers=auth_headers)
    r2 = await client.post("/communities", json={"name": "Med Sailors"}, headers=auth_headers)
    assert r1.json()["id"] == r2.json()["id"]

# HIGH — join increments member_count
async def test_join_community_increments_member_count(client, auth_headers, community_id):
    before = (await client.get(f"/communities/{community_id}")).json()["member_count"]
    await client.post(f"/communities/{community_id}/join", headers=auth_headers)
    after = (await client.get(f"/communities/{community_id}")).json()["member_count"]
    assert after == before + 1

# HIGH — social links round-trip through profile update
async def test_social_links_persist_through_profile_update(client, auth_headers):
    links = [{"id": str(uuid4()), "platform": "instagram", "handle": "test_sailor"}]
    await client.patch("/profile", json={"social_links": links}, headers=auth_headers)
    profile = (await client.get("/profile/me", headers=auth_headers)).json()
    assert profile["social_links"][0]["handle"] == "test_sailor"

# MEDIUM — profile image cleanup (already specced in refactor-march.md)
async def test_upload_profile_image_deletes_old_file(client, auth_headers, tmp_path, monkeypatch):
    # see refactor-march.md §569–580
```

### iOS

```swift
// CRITICAL — joining a community adds chip and updates primary if first
func testJoinFirstCommunitySetsPrimary() async throws {
    let vm = ProfileViewModel(apiClient: MockAPIClient())
    await vm.joinCommunity(id: "c1", name: "Med Sailors")
    XCTAssertEqual(vm.communities.first?.isPrimary, true)
}

// HIGH — community search debounce fires once per pause
func testCommunitySearchDebounceCoalescesRapidInput() async throws {
    let vm = ProfileViewModel(apiClient: MockAPIClient())
    vm.communitySearchQuery = "Me"
    vm.communitySearchQuery = "Med"
    vm.communitySearchQuery = "Med S"
    try await Task.sleep(for: .milliseconds(350))
    XCTAssertEqual(vm.apiClient.searchCallCount, 1)
}

// HIGH — leaving only community clears primary flag
func testLeaveOnlyCommunityNoLongerPrimary() async throws {
    let vm = makeVMWithCommunity(id: "c1", isPrimary: true)
    await vm.leaveCommunity(id: "c1")
    XCTAssertTrue(vm.communities.isEmpty)
}
```

---

## 10. Open Questions

| # | Question | Decision |
|---|---|---|
| 1 | Should community icons be uploaded by creators, or auto-generated (e.g. initials avatar)? | **Start with initials avatar** — reduce scope, add upload in Phase 4 |
| 2 | How do we handle moderated community join requests in the UI? | **Out of scope** — all communities treated as open until Phase 4 approval workflow |
| 3 | Do we show community member count on profile chips, or just on search results? | **Search results only** — chips are compact; add count on community detail screen in Phase 4 |
| 4 | Nautical miles — source of truth: user-entered on charter, GPS track, or route planner estimate? | **Phase 3 decision** — for now show `—` placeholder |
| 5 | Should `created_by` ever be surfaced to the UI before founder roles are built? | **No** — store it silently for future use |
| 6 | Other social link: handle or full URL? | **Full URL** (user enters `https://...`); instagram and telegram are handles only |
