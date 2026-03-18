# Community Manager — Product Requirements Document

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Status:** Draft — Ready for Review  
**Depends on:** `refactor-march.md` (Phase 3 map + avatar changes, social links)

---

## 1. Problem Statement

AnyFleet's discovery map currently only shows charters created by registered captains who authenticate via Apple Sign In. This leaves two real-world gaps:

1. **Fleet operators and sailing schools** want to publish charters on behalf of their instructors and guest skippers — people who may never sign up for the app themselves.
2. **Communities** (yacht clubs, charter companies, sailing associations) want a recognisable visual identity on the map — a community badge that appears alongside each captain's avatar so members can immediately see who they're sailing with.

The **Community Manager** role fills both gaps: it gives a trusted user the ability to manage a community's presence on the map, publish charters under virtual captain identities, and give their community a visual icon that appears as a badge.

---

## 2. Goals & Non-Goals

### 2.1 Goals

| Goal | Success Metric |
|------|---------------|
| Community managers can publish charters on behalf of any virtual captain | Charters with `virtual_captain_id` appear in discovery with correct name + avatar |
| Virtual captains can have profile pictures and social links without being app users | `VirtualCaptain` rows exist independently of `users` table |
| Community managers can upload an icon for their community | `Community.icon_url` populated via manager upload endpoint |
| Community badge appears on map pins alongside captain avatar | `CharterWithUserInfo` exposes `community_badge_url` in discovery response |
| Admin users can simultaneously hold community manager status | `community_managers` join table is role-agnostic — any user including admin can have rows |
| Admin can assign/revoke community manager status for any user | `POST/DELETE /admin/communities/{id}/managers/{user_id}` endpoints |

### 2.2 Non-Goals

- Virtual captains cannot log in to the app (no auth, no `apple_id`)
- Virtual captains cannot publish their own charters (they are always published by a manager)
- Community managers cannot moderate content platform-wide (that remains admin/moderator role)
- Phase 1 does not include moderated-join communities or manager approval workflows (Phase 4)
- This PRD does not redesign `UserRole` enum — existing `user / moderator / admin` roles are untouched; community manager status is a separate orthogonal permission

---

## 3. User Personas

### Persona A: "Fleet Manager Ines"
- Runs a charter school with 8 instructors, some of whom don't use smartphones
- Wants to publish upcoming training charters on behalf of each instructor so students can find them on the map
- Needs to keep instructor profiles with photos and Instagram links for credibility

### Persona B: "Yacht Club Commodore Björn"
- Manages a club of 40 members, many of whom already have accounts
- Wants to publish club race charters under a "RBYC" brand badge visible on map
- Uploads the club burgee as the community icon
- Is also an app admin — needs both roles simultaneously

### Persona C: "Alex (Platform Admin)"
- Approves community creation requests and assigns manager status to trusted users
- May personally manage the platform's own showcase community
- Needs a single account that works as both admin and community manager

---

## 4. Core Concepts

### 4.1 Community Manager

A **community manager** is any `User` (regardless of their `role`) who has been assigned manager rights for a specific `Community` via the `community_managers` join table. An admin can also be a community manager for one or more communities — the two permissions are orthogonal.

Capabilities:
- Publish charters on behalf of virtual captains in their community
- Create, update, delete virtual captains for their community
- Upload and update the community icon image

### 4.2 Virtual Captain

A **virtual captain** is a lightweight profile that exists only within the context of a community. It has a display name, optional profile picture, and optional social links — but no authentication credentials.

Virtual captains are owned by a community. When a charter is published under a virtual captain:
- The map pin shows the virtual captain's avatar
- The community icon appears as a badge on that pin
- The "captain" card in discovery shows the virtual captain's name and social links

### 4.3 Community Badge on Map

Per the Phase 3 map work described in `refactor-march.md` (§8b), `CharterWithUserInfo` already needs `avatar_url` added to `UserBasicInfo`. This PRD extends the discovery response further:

```
CharterWithUserInfo
├── user (UserBasicInfo)         ← real user OR virtual captain proxy
│   ├── id
│   ├── username / display_name
│   ├── avatar_url               ← Phase 3 field (real user's thumbnail)
│   └── primary_community        ← existing JSONB field
└── community_badge_url          ← NEW: community icon_url if charter is community-managed
```

When `virtual_captain_id` is set on a charter, the `user` block in discovery is synthesised from the `VirtualCaptain` row. `community_badge_url` is populated from `Community.icon_url` whenever the charter was published by a community manager (whether for a virtual captain or a real user in the community).

---

## 5. Data Model

### 5.1 New table: `virtual_captains`

```python
# models/virtual_captain.py
class VirtualCaptain(Base):
    __tablename__ = "virtual_captains"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)

    community_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("communities.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    display_name: Mapped[str] = mapped_column(String(200), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    avatar_thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Same schema as User.social_links: list of {id, platform, handle}
    social_links: Mapped[list] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    community: Mapped["Community"] = relationship("Community", back_populates="virtual_captains")
    charters: Mapped[list["Charter"]] = relationship("Charter", back_populates="virtual_captain")
```

**Constraints:**
- `display_name` must be non-empty (1–200 chars)
- Cascade delete on `community_id` — deleting a community hard-deletes all its virtual captains
- `avatar_url` / `avatar_thumbnail_url` follow the same storage conventions as `User.profile_image_url`

---

### 5.2 New table: `community_managers`

```python
# models/community.py (extend existing file)
class CommunityManager(Base):
    __tablename__ = "community_managers"
    __table_args__ = (
        UniqueConstraint("community_id", "user_id", name="uq_community_managers"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    community_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("communities.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    assigned_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
```

**Key design decision:** The `community_managers` table is entirely separate from `User.role`. A user with `role = "admin"` can have rows in `community_managers` just like a regular user. This avoids polluting the role enum and keeps the two concerns independent.

---

### 5.3 Changes to `Charter` model

Add two nullable foreign keys:

```python
# models/charter.py — new columns
virtual_captain_id: Mapped[uuid.UUID | None] = mapped_column(
    Uuid, ForeignKey("virtual_captains.id", ondelete="SET NULL"), nullable=True, index=True
)
published_by_manager_id: Mapped[uuid.UUID | None] = mapped_column(
    Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
)

# Relationships
virtual_captain: Mapped["VirtualCaptain | None"] = relationship(
    "VirtualCaptain", back_populates="charters"
)
```

**Semantics:**
- `virtual_captain_id IS NOT NULL` → charter was published on behalf of a virtual captain
- `published_by_manager_id IS NOT NULL` → charter was created by a community manager acting on behalf of someone
- Both fields can be `NULL` for regular user-created charters (backwards compatible)
- `user_id` always points to the real authenticated user who created the charter (the manager) — this preserves the ownership chain for moderation purposes

---

### 5.4 Changes to `Community` model

`Community` already has `icon_url: str | None`. No schema changes needed — only a new upload endpoint is required (§6.5).

Add the back-references for relationships:

```python
# models/community.py — additions to existing Community class
virtual_captains: Mapped[list["VirtualCaptain"]] = relationship(
    "VirtualCaptain", back_populates="community", cascade="all, delete-orphan"
)
managers: Mapped[list["CommunityManager"]] = relationship(
    "CommunityManager", foreign_keys="[CommunityManager.community_id]",
    cascade="all, delete-orphan"
)
```

---

### 5.5 Alembic Migration

```python
# alembic/versions/2026_03_XX_0001_add_community_manager_feature.py

def upgrade():
    # virtual_captains table
    op.create_table(
        "virtual_captains",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("community_id", sa.Uuid(), sa.ForeignKey("communities.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_by", sa.Uuid(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("display_name", sa.String(200), nullable=False),
        sa.Column("avatar_url", sa.String(500), nullable=True),
        sa.Column("avatar_thumbnail_url", sa.String(500), nullable=True),
        sa.Column("social_links", JSONB, nullable=False, server_default="[]"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=func.now(), nullable=False),
    )
    op.create_index("ix_virtual_captains_community_id", "virtual_captains", ["community_id"])

    # community_managers join table
    op.create_table(
        "community_managers",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("community_id", sa.Uuid(), sa.ForeignKey("communities.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("assigned_by", sa.Uuid(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=func.now(), nullable=False),
        sa.UniqueConstraint("community_id", "user_id", name="uq_community_managers"),
    )
    op.create_index("ix_community_managers_user_id", "community_managers", ["user_id"])

    # Charter additions
    op.add_column("charters", sa.Column("virtual_captain_id", sa.Uuid(), nullable=True))
    op.add_column("charters", sa.Column("published_by_manager_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_charters_virtual_captain", "charters", "virtual_captains",
        ["virtual_captain_id"], ["id"], ondelete="SET NULL"
    )
    op.create_foreign_key(
        "fk_charters_published_by_manager", "charters", "users",
        ["published_by_manager_id"], ["id"], ondelete="SET NULL"
    )
    op.create_index("ix_charters_virtual_captain_id", "charters", ["virtual_captain_id"])

def downgrade():
    op.drop_index("ix_charters_virtual_captain_id", "charters")
    op.drop_constraint("fk_charters_virtual_captain", "charters", type_="foreignkey")
    op.drop_constraint("fk_charters_published_by_manager", "charters", type_="foreignkey")
    op.drop_column("charters", "published_by_manager_id")
    op.drop_column("charters", "virtual_captain_id")
    op.drop_index("ix_community_managers_user_id", "community_managers")
    op.drop_table("community_managers")
    op.drop_index("ix_virtual_captains_community_id", "virtual_captains")
    op.drop_table("virtual_captains")
```

---

## 6. API Endpoints

### 6.1 Admin: Assign / Revoke Community Manager

These endpoints are admin-only and live under `/admin/`.

```
POST   /admin/communities/{community_id}/managers
DELETE /admin/communities/{community_id}/managers/{user_id}
GET    /admin/communities/{community_id}/managers
```

**`POST /admin/communities/{community_id}/managers`**

```python
# Request
class AssignManagerRequest(BaseModel):
    user_id: UUID

# Response — 201 Created
class CommunityManagerResponse(BaseModel):
    id: UUID
    community_id: UUID
    user_id: UUID
    assigned_by: UUID
    created_at: datetime
```

- Returns `404` if `community_id` or `user_id` do not exist
- Returns `409` if user is already a manager of this community
- Any user, including one with `role = "admin"`, can be assigned

**`DELETE /admin/communities/{community_id}/managers/{user_id}`** — 204 No Content

**`GET /admin/communities/{community_id}/managers`** — returns paginated `CommunityManagerResponse` list

---

### 6.2 Community Manager: Virtual Captain CRUD

Auth: `require_community_manager(community_id)` dependency — verifies the current user has a row in `community_managers` for this community **or** has `role = "admin"`.

```
GET    /communities/{community_id}/virtual-captains
POST   /communities/{community_id}/virtual-captains
GET    /communities/{community_id}/virtual-captains/{captain_id}
PATCH  /communities/{community_id}/virtual-captains/{captain_id}
DELETE /communities/{community_id}/virtual-captains/{captain_id}
```

**`POST /communities/{community_id}/virtual-captains`**

```python
# Request
class CreateVirtualCaptainRequest(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=200)
    social_links: list[SocialLinkSchema] = Field(default_factory=list, max_length=10)

# Response — 201 Created
class VirtualCaptainResponse(BaseModel):
    id: UUID
    community_id: UUID
    display_name: str
    avatar_url: str | None
    avatar_thumbnail_url: str | None
    social_links: list[SocialLinkSchema]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
```

**`PATCH /communities/{community_id}/virtual-captains/{captain_id}`**

```python
class UpdateVirtualCaptainRequest(BaseModel):
    display_name: str | None = Field(None, min_length=1, max_length=200)
    social_links: list[SocialLinkSchema] | None = None
```

**`DELETE /communities/{community_id}/virtual-captains/{captain_id}`**

- Returns `404` if captain not found in this community
- Returns `409` if the virtual captain has any non-deleted charters — manager must delete or reassign those charters first (prevents orphaned map pins)
- Admin bypass: admin can force-delete regardless of charter state (sets `virtual_captain_id = NULL` on charters)

---

### 6.3 Virtual Captain Avatar Upload

```
POST /communities/{community_id}/virtual-captains/{captain_id}/avatar
```

- Multipart form upload, same validation rules as `POST /profile/upload-image`
- Saves full + thumbnail images to storage backend
- Updates `avatar_url` and `avatar_thumbnail_url` on `VirtualCaptain`
- Deletes the old avatar files before saving new ones (same pattern as `profile_service._delete_local_file`)
- Returns `VirtualCaptainResponse`

---

### 6.4 Community Manager: Publish Charter on Behalf of Virtual Captain

Extends the existing `POST /charters` endpoint (and `PATCH /charters/{id}`) with two new optional fields. No separate endpoint needed.

```python
# schemas/charter.py — CharterCreate additions
class CharterCreate(BaseModel):
    # ... existing fields ...

    # New optional field — only accepted if caller is a community manager
    on_behalf_of_virtual_captain_id: UUID | None = Field(
        None,
        description="Virtual captain UUID. Caller must be a community manager for the captain's community."
    )
```

**Validation logic in `charter_service.create_charter`:**

1. If `on_behalf_of_virtual_captain_id` is provided:
   a. Look up `VirtualCaptain` by ID — return `404` if not found
   b. Verify caller is a manager of `virtual_captain.community_id` OR has `role = "admin"` — return `403` otherwise
   c. Set `charter.virtual_captain_id = on_behalf_of_virtual_captain_id`
   d. Set `charter.published_by_manager_id = current_user.id`
   e. Set `charter.user_id = current_user.id` (manager is the legal owner; virtual captain is display only)

2. If not provided, existing logic applies unchanged.

**Charter update (`PATCH /charters/{id}`):**
- Manager can update `on_behalf_of_virtual_captain_id` only on charters they published (i.e. `charter.published_by_manager_id == current_user.id`)
- Setting it to `null` removes the virtual captain attribution

---

### 6.5 Community Icon Upload

```
POST /communities/{community_id}/icon
```

- Auth: `require_community_manager(community_id)` (same as above)
- Multipart form upload — image only
- Saves to storage, updates `Community.icon_url`
- Deletes old icon file before saving new one
- Returns `CommunityResponse`

The `icon_url` field already exists on the `Community` model and is already returned in `CommunityResponse`. No schema change needed.

---

### 6.6 My Managed Communities

```
GET /communities/managed
```

Returns communities where the authenticated user is a manager.

```python
class ManagedCommunityResponse(BaseModel):
    id: UUID
    name: str
    slug: str
    icon_url: str | None
    member_count: int
    virtual_captain_count: int  # denormalized count for dashboard display
    assigned_at: datetime       # when current user was made manager
```

This endpoint is used by the iOS app to know which communities the user can publish charters for, and to surface the upload-icon affordance.

---

## 7. Discovery Response Changes

### 7.1 Extended `UserBasicInfo`

Building on the Phase 3 `avatar_url` addition from `refactor-march.md` §8b:

```python
# schemas/charter.py
class UserBasicInfo(BaseModel):
    id: UUID
    username: str | None          # real user: username; virtual captain: display_name
    avatar_url: str | None        # real user: profile_image_thumbnail_url; virtual captain: avatar_thumbnail_url
    is_virtual_captain: bool = False   # flag for iOS to adjust UI treatment
    social_links: list[SocialLinkSchema] = []  # exposed for captain card bottom sheet

    model_config = {"from_attributes": True}
```

### 7.2 Extended `CharterWithUserInfo`

```python
# schemas/charter.py
class CharterWithUserInfo(CharterResponse):
    user: UserBasicInfo
    distance_km: float | None = None
    community_badge_url: str | None = None  # NEW: community icon_url, set when published_by_manager_id is not null
```

### 7.3 Repository: Synthesising Virtual Captain Info

When `charter.virtual_captain_id IS NOT NULL`, the charter discovery query must eager-load the `virtual_captain` relationship and its parent community's `icon_url`. The `UserBasicInfo` block is then built from the `VirtualCaptain` row:

```python
# repositories/charter.py — find_discoverable result mapping (pseudocode)
def _to_charter_with_user_info(charter: Charter) -> CharterWithUserInfo:
    if charter.virtual_captain:
        vc = charter.virtual_captain
        user_info = UserBasicInfo(
            id=vc.id,
            username=vc.display_name,
            avatar_url=vc.avatar_thumbnail_url,
            is_virtual_captain=True,
            social_links=vc.social_links,
        )
        badge_url = vc.community.icon_url  # requires community eager-loaded
    else:
        u = charter.user
        user_info = UserBasicInfo(
            id=u.id,
            username=u.username,
            avatar_url=u.profile_image_thumbnail_url,
            is_virtual_captain=False,
            social_links=u.social_links,
        )
        # Still show community badge if manager published under their own identity
        badge_url = _get_primary_community_icon(u) if charter.published_by_manager_id else None

    return CharterWithUserInfo(
        **charter.__dict__,
        user=user_info,
        community_badge_url=badge_url,
    )
```

**Query change:** Add `selectinload(Charter.virtual_captain).selectinload(VirtualCaptain.community)` to `find_discoverable` when either field is present. This avoids the async lazy-load trap documented in `refactor-march.md` §C4.

---

## 8. Permission Matrix

| Action | Regular User | Community Manager (own community) | Admin |
|--------|-------------|----------------------------------|-------|
| View virtual captains | ✅ (public) | ✅ | ✅ |
| Create virtual captain | ❌ | ✅ | ✅ |
| Update virtual captain | ❌ | ✅ | ✅ |
| Delete virtual captain | ❌ | ✅ (if no active charters) | ✅ (force) |
| Upload virtual captain avatar | ❌ | ✅ | ✅ |
| Upload community icon | ❌ | ✅ | ✅ |
| Publish charter on behalf of virtual captain | ❌ | ✅ (own community's VCs only) | ✅ |
| Assign community manager | ❌ | ❌ | ✅ |
| Revoke community manager | ❌ | ❌ | ✅ |
| Be a community manager | — | — | ✅ (can be assigned) |

---

## 9. `require_community_manager` Dependency

This is a new FastAPI dependency factory (analogous to `require_admin` in `api/deps.py`):

```python
# api/deps.py — new dependency
def require_community_manager(community_id_param: str = "community_id"):
    """
    Dependency factory. Verifies the current user is either:
      a) a manager of the target community (row in community_managers), OR
      b) has role = "admin" (admins can act on all communities)
    """
    async def _check(
        community_id: UUID = Path(..., alias=community_id_param),
        current_user: User = Depends(get_current_user),
        db: DatabaseSession = Depends(get_db),
    ) -> UUID:
        if current_user.role == UserRole.ADMIN:
            return community_id
        repo = CommunityManagerRepository(db)
        if not await repo.is_manager(community_id=community_id, user_id=current_user.id):
            raise HTTPException(
                status_code=403,
                detail="You are not a manager of this community"
            )
        return community_id

    return Depends(_check)
```

---

## 10. File Storage

Virtual captain avatars and community icons follow the same storage conventions as user profile images (`profile_service.py`):

- **Local dev:** `settings.upload_dir / "virtual-captains" / {captain_id}_{size}.jpg`
- **S3 (production):** Same bucket, `virtual-captains/{captain_id}_{size}.jpg`
- Both full-size and thumbnail are generated and stored (same resize pipeline)
- Old files are deleted before new uploads (async, best-effort, logged on failure)

A new `VirtualCaptainImageService` (or an extension of `ProfileService`) handles this. It should call `asyncio.to_thread` for local disk I/O — not `write_bytes()` directly, per the async I/O fix in `refactor-march.md` §C5.

---

## 11. Schemas Summary

### New files

```
app/models/virtual_captain.py        VirtualCaptain ORM model
app/repositories/virtual_captain.py  VirtualCaptainRepository
app/schemas/virtual_captain.py       CreateVirtualCaptainRequest, UpdateVirtualCaptainRequest, VirtualCaptainResponse
app/services/virtual_captain_service.py  Business logic + avatar upload
app/api/v1/community_manager.py      All community manager endpoints
```

### Modified files

```
app/models/charter.py          + virtual_captain_id, published_by_manager_id columns
app/models/community.py        + CommunityManager model, back-references
app/schemas/charter.py         + on_behalf_of_virtual_captain_id in CharterCreate/Update
                                + community_badge_url in CharterWithUserInfo
                                + is_virtual_captain, social_links in UserBasicInfo
app/services/charter_service.py  + validate virtual captain ownership, set manager fields
app/repositories/charter.py    + eager-load virtual_captain + community in find_discoverable
app/api/deps.py                + require_community_manager dependency factory
app/api/v1/admin.py            + assign/revoke manager endpoints
app/models/enums.py            (no change — community manager is not a UserRole value)
```

---

## 12. iOS–Backend Coordination

| iOS feature | Backend action | Status |
|-------------|---------------|--------|
| "Publish for" captain selector when creating charter | `on_behalf_of_virtual_captain_id` in `CharterCreate` + `GET /communities/managed` | Needs build |
| Virtual captain card in discovery bottom sheet | `is_virtual_captain`, `social_links` in `UserBasicInfo` | Needs build |
| Community badge on map pin | `community_badge_url` in `CharterWithUserInfo` | Needs build |
| Community icon upload in manager settings | `POST /communities/{id}/icon` | Needs build |
| Virtual captain management screen | Full CRUD + avatar upload endpoints | Needs build |
| Admin assigns manager in web console | `POST /admin/communities/{id}/managers` | Needs build |

---

## 13. Edge Cases & Constraints

| Case | Handling |
|------|---------|
| Manager tries to publish for a virtual captain in a community they don't manage | `403 Forbidden` |
| Virtual captain is deleted while active charters exist | `409 Conflict` — manager must delete charters first; admin can force |
| Community is deleted | Cascade: all virtual captains deleted, `virtual_captain_id` on charters set to `NULL` (pin becomes ownerless; filtered out of discovery by the `deleted_at` or `visibility` check) |
| Manager's account is deleted | `published_by_manager_id` set to `NULL` (SET NULL FK); charters remain visible under virtual captain identity |
| Admin assigns themselves as community manager | Allowed — `user_id = admin_user_id` row created in `community_managers` |
| Same user assigned manager twice | `409 Conflict` from unique constraint `uq_community_managers` |
| Charter discovery: `virtual_captain.community` not eagerly loaded | Causes async lazy-load crash — `selectinload` chain is mandatory (see §7.3) |

---

## 14. Open Questions

1. **Captain card UI:** Should the iOS captain bottom sheet treat virtual captains differently (e.g. no "View Profile" button)? If yes, `is_virtual_captain` flag in `UserBasicInfo` enables this.

2. **Multiple communities per charter:** Should a manager be able to tag a charter with a community even when not publishing on behalf of a virtual captain (i.e. publishing under their own real-user identity but still showing the badge)? Current design supports this via `published_by_manager_id` — the `community_badge_url` is derived from their primary managed community. Needs product decision on which community to use if they manage several.

3. **Virtual captain public page:** Should virtual captains have a discoverable page at e.g. `/captains/vc/{id}`? Phase 1 can skip this — virtual captain info is only surfaced through charter discovery. Revisit if the feature gains traction.

4. **Community manager self-service:** Should a community manager be able to promote another member to co-manager without admin involvement? Deferred to Phase 4.

5. **Max virtual captains per community:** Should there be a cap (e.g. 50) to prevent abuse? Recommend `CHECK` constraint or application-level guard with a configurable setting.

---

*Document version: 1.0 — March 2026*  
*Author: Product + Engineering*  
*Review: Required before development begins*
