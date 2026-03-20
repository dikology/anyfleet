# Community Manager — Phase 1 Implementation Plan
## Publishing Charters on Behalf of Virtual Captains

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Status:** Ready for Development  
**Builds on:** `user-management.md` (Phase 0 — admin assign/revoke, web console)  
**PRD:** `community-manager.md`  
**Refactor references:** `refactor-march.md` (iOS + backend)

---

## 1. What Phase 0 Delivered

Phase 0 (`user-management.md`) is complete. The following are already in production:

| Artifact | Status |
|---|---|
| `CommunityManager` ORM model in `app/models/community.py` | ✅ Done |
| `CommunityManagerRepository` (`app/repositories/community_manager.py`) | ✅ Done |
| `require_community_manager` dependency in `app/api/deps.py` | ✅ Done |
| Admin endpoints: assign / revoke / list managers, user managed-communities | ✅ Done |
| Web console `/console/users` page + `AssignManagerModal` | ✅ Done |

**What is NOT done and is the scope of this document:**
- `VirtualCaptain` model, table, repository, service, and API
- `virtual_captain_id` / `published_by_manager_id` on the `Charter` model
- "Publish on behalf of" flow in charter creation/editing
- Discovery response changes (`community_badge_url`, `is_virtual_captain`, `social_links` in `UserBasicInfo`)
- Community icon upload endpoint
- `GET /communities/managed` endpoint
- All iOS counterparts to the above

---

## 2. Refactor Items That Apply to This Phase

Before touching any file in this phase, check whether each applicable refactor item from `refactor-march.md` is done. Items that directly affect the code paths we are opening:

### Backend (`refactor-march.md` backend)

| Ref | Issue | Files Touched | Action |
|-----|-------|---------------|--------|
| **A9** | Alembic double-head — `alembic upgrade head` fails with two `down_revision = None` migrations | `alembic/versions/` | **Must fix before our migration.** Run `alembic merge heads` and verify `alembic upgrade head` succeeds on a clean DB. The virtual_captains migration depends on this. |
| **A1 / P1** | `BaseRepository.count()` loads all rows into memory | `repositories/base.py` | **Fix while adding virtual captain list endpoint.** The `GET /communities/{id}/virtual-captains` endpoint will call `count()` — if not fixed, it table-scans every time. |
| **C5 / P4** | `_save_local` sync I/O — check if already fixed | `services/profile_service.py` | **Already fixed** — `profile_service` uses `aiofiles`. The new `VirtualCaptainImageService` must use the same pattern from day one; do not copy any older synchronous approach. |
| **C6** | Old profile images never deleted on re-upload | `services/profile_service.py` | **Already fixed.** Apply the same `_delete_local_file` pattern in `VirtualCaptainImageService` — never write new avatar files without deleting the old ones first. |
| **S3** | `update_charter` / `delete_charter` return 403 for non-owned IDs (existence leak) | `services/charter_service.py` | **Address when extending `create_charter`.** When a manager supplies an invalid `on_behalf_of_virtual_captain_id`, return `404` (not `403`) so we don't reveal that the captain exists but belongs to a different community. |
| **A8** | Enum columns stored as plain `String` — no DB constraint | `models/charter.py` | **Do not fix in this PR** — migrating live columns is a maintenance-window operation. New `virtual_captains.social_links` is JSONB (no enum involved). Document it and move on. |

### iOS (`refactor-march.md` iOS)

| Ref | Issue | Files Touched | Action |
|-----|-------|---------------|--------|
| **U1** | Map pins not showing avatars or community badges | `CharterMapView.swift` | **This is the feature.** Replace `CharterMapAnnotation` circle with `UserAvatarPin` as part of the discovery response changes. |
| **Step 7** | `CharterMapAnnotation` refactor (avatar pin + community badge overlay) | `CharterMapView.swift`, `DiscoverableCharter.swift` | **Build it here.** The architecture in `refactor-march.md §Step 7` is exactly right; implement `UserAvatarPin` and `CommunityBadgeOverlay`. |
| **A2** | `DiscoverableCharter.swift` god file | Already split — `Core/Models/API/` exists | ✅ **Already done.** DTOs are in `CharterAPIResponse.swift`, `CharterDiscoveryResponse.swift`, `CharterRequestPayloads.swift`. The new virtual captain types follow the same split. |
| **C6** | `CLLocationManager` created inside VM init — not injectable | `CharterDiscoveryViewModel.swift` | **Do not fix in this PR** unless the charter discovery VM is substantially restructured for VC filtering. Keep scope tight. |
| **A4** | Fallback `init()` creates duplicate `AppDependencies` | `CharterListView.swift` | **Do not fix in this PR.** The new screens (virtual captain management, "publish as" selector) must never use a fallback `init()` — set the correct pattern from the start. |
| **C1 / C2** | Force-unwrap crash sites in `LocalRepository` + `APIClient` | `LocalRepository.swift`, `APIClient.swift` | **Fix opportunistically** if you open these files. If the `APIClient` is opened to add new endpoints, fix the `EmptyResponse as! T` cast while there. |

---

## 3. Backend Implementation

### 3.1 Alembic migration

**Prerequisite:** Resolve A9 first.

```bash
alembic merge heads -m "merge_duplicate_initial"
alembic upgrade head   # must succeed on clean DB before proceeding
```

New migration: `alembic/versions/2026_03_XX_0003_add_virtual_captain_feature.py`

This migration adds:
1. `virtual_captains` table (new)
2. `virtual_captain_id` and `published_by_manager_id` columns on `charters`

```python
def upgrade():
    op.create_table(
        "virtual_captains",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("community_id", sa.Uuid(),
                  sa.ForeignKey("communities.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_by", sa.Uuid(),
                  sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("display_name", sa.String(200), nullable=False),
        sa.Column("avatar_url", sa.String(500), nullable=True),
        sa.Column("avatar_thumbnail_url", sa.String(500), nullable=True),
        sa.Column("social_links", JSONB, nullable=False, server_default="[]"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_virtual_captains_community_id",
                    "virtual_captains", ["community_id"])

    op.add_column("charters",
        sa.Column("virtual_captain_id", sa.Uuid(), nullable=True))
    op.add_column("charters",
        sa.Column("published_by_manager_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_charters_virtual_captain", "charters", "virtual_captains",
        ["virtual_captain_id"], ["id"], ondelete="SET NULL")
    op.create_foreign_key(
        "fk_charters_published_by_manager", "charters", "users",
        ["published_by_manager_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_charters_virtual_captain_id",
                    "charters", ["virtual_captain_id"])
```

---

### 3.2 New model: `VirtualCaptain`

New file: `app/models/virtual_captain.py`

```python
class VirtualCaptain(Base):
    __tablename__ = "virtual_captains"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)

    community_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("communities.id", ondelete="CASCADE"),
        nullable=False, index=True
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    display_name: Mapped[str] = mapped_column(String(200), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    avatar_thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    social_links: Mapped[list] = mapped_column(
        JSONB, nullable=False, default=list, server_default="[]"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False)

    community: Mapped["Community"] = relationship(
        "Community", back_populates="virtual_captains", lazy="noload")
    charters: Mapped[list["Charter"]] = relationship(
        "Charter", back_populates="virtual_captain", lazy="noload")
```

Add to `app/models/community.py` — `Community` class:
```python
virtual_captains: Mapped[list["VirtualCaptain"]] = relationship(
    "VirtualCaptain", back_populates="community",
    cascade="all, delete-orphan", lazy="noload"
)
```

Add to `app/models/charter.py` — `Charter` class:
```python
virtual_captain_id: Mapped[uuid.UUID | None] = mapped_column(
    Uuid, ForeignKey("virtual_captains.id", ondelete="SET NULL"),
    nullable=True, index=True
)
published_by_manager_id: Mapped[uuid.UUID | None] = mapped_column(
    Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
)
virtual_captain: Mapped["VirtualCaptain | None"] = relationship(
    "VirtualCaptain", back_populates="charters", lazy="noload"
)
```

Register `VirtualCaptain` in `app/models/__init__.py` so Alembic can autogenerate.

---

### 3.3 Pydantic schemas

New file: `app/schemas/virtual_captain.py`

```python
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

class CreateVirtualCaptainRequest(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=200)
    social_links: list[SocialLinkSchema] = Field(default_factory=list, max_length=10)

class UpdateVirtualCaptainRequest(BaseModel):
    display_name: str | None = Field(None, min_length=1, max_length=200)
    social_links: list[SocialLinkSchema] | None = None
```

`SocialLinkSchema` should already exist in `app/schemas/` (used by user profile). Reuse it — do not define a second one.

Changes to `app/schemas/charter.py`:

```python
# CharterCreate — add one optional field
class CharterCreate(BaseModel):
    # ... existing fields unchanged ...
    on_behalf_of_virtual_captain_id: UUID | None = Field(
        None,
        description="Only accepted if caller is a community manager for the captain's community."
    )

# UserBasicInfo — expand for discovery
class UserBasicInfo(BaseModel):
    id: UUID
    username: str | None               # real user: username; VC: display_name
    avatar_url: str | None             # real user: profile_image_thumbnail_url; VC: avatar_thumbnail_url
    is_virtual_captain: bool = False
    social_links: list[SocialLinkSchema] = []
    model_config = {"from_attributes": True}

# CharterWithUserInfo — add badge field
class CharterWithUserInfo(CharterResponse):
    user: UserBasicInfo
    distance_km: float | None = None
    community_badge_url: str | None = None   # community icon when published_by_manager_id is set
```

**Note:** `profile_image_thumbnail_url` is the existing column name on `User`. The new `avatar_url` field in `UserBasicInfo` is a *synthesised* field — not a direct column rename. The repository mapping layer (§3.5) reads the correct source column for each case.

Similarly for `CharterUpdate`:
```python
class CharterUpdate(BaseModel):
    # ... existing fields unchanged ...
    on_behalf_of_virtual_captain_id: UUID | None = Field(
        None,
        description="Set to null to remove virtual captain attribution."
    )
```

---

### 3.4 New repository: `VirtualCaptainRepository`

New file: `app/repositories/virtual_captain.py`

```python
class VirtualCaptainRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, captain_id: UUID) -> VirtualCaptain | None:
        stmt = (select(VirtualCaptain)
                .where(VirtualCaptain.id == captain_id)
                .options(selectinload(VirtualCaptain.community)))
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_for_community(
        self, community_id: UUID, limit: int = 50, offset: int = 0
    ) -> list[VirtualCaptain]:
        stmt = (select(VirtualCaptain)
                .where(VirtualCaptain.community_id == community_id)
                .order_by(VirtualCaptain.display_name)
                .limit(limit).offset(offset))
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count_for_community(self, community_id: UUID) -> int:
        # Use SELECT COUNT(*) — not scalars().all() — per refactor A1
        stmt = (select(func.count())
                .select_from(VirtualCaptain)
                .where(VirtualCaptain.community_id == community_id))
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def create(self, community_id: UUID, created_by: UUID,
                     display_name: str, social_links: list) -> VirtualCaptain:
        vc = VirtualCaptain(
            community_id=community_id,
            created_by=created_by,
            display_name=display_name,
            social_links=social_links,
        )
        self.session.add(vc)
        await self.session.flush()
        await self.session.refresh(vc, attribute_names=["community"])
        return vc

    async def update(self, vc: VirtualCaptain,
                     display_name: str | None = None,
                     social_links: list | None = None) -> VirtualCaptain:
        if display_name is not None:
            vc.display_name = display_name
        if social_links is not None:
            vc.social_links = social_links
        await self.session.flush()
        return vc

    async def delete(self, vc: VirtualCaptain) -> None:
        await self.session.delete(vc)
        await self.session.flush()

    async def has_active_charters(self, captain_id: UUID) -> bool:
        stmt = (select(literal(1))
                .select_from(Charter)
                .where(Charter.virtual_captain_id == captain_id,
                       Charter.deleted_at.is_(None))
                .limit(1))
        result = await self.session.execute(select(sa_exists(stmt)))
        return result.scalar_one()
```

Note: `count_for_community` uses `SELECT COUNT(*)` explicitly — this is the A1 fix applied at creation. Never use `scalars().all()` + `len()` in a new repository.

---

### 3.5 New service: `VirtualCaptainService`

New file: `app/services/virtual_captain_service.py`

This service handles business logic, authorization, and image processing. It wraps `VirtualCaptainRepository` and uses the same image pipeline as `ProfileService`.

Key methods:

**`list_captains(community_id, limit, offset) → VirtualCaptainListResponse`**
- Returns paginated list using `count_for_community` (SELECT COUNT) + `list_for_community`

**`create_captain(community_id, created_by, data) → VirtualCaptain`**
- Validates `display_name` non-empty (Pydantic handles this via `min_length=1`)
- Optional: enforce a per-community cap (e.g. 100 VCs) via application-level check — recommend configurable `settings.max_virtual_captains_per_community = 100`
- Calls `vc_repo.create(...)`

**`update_captain(community_id, captain_id, data) → VirtualCaptain`**
- Fetches by `captain_id`; returns `404` if not found OR if `vc.community_id != community_id` (opaque — no existence leak; see S3 fix)
- Calls `vc_repo.update(...)`

**`delete_captain(community_id, captain_id, force: bool = False) → None`**
- Returns `404` if not found or wrong community
- If `force=False`: calls `vc_repo.has_active_charters(captain_id)` — raises `409` if True
- If `force=True` (admin only): nullifies `charter.virtual_captain_id` by bulk UPDATE before deleting the VC
- Calls `vc_repo.delete(vc)`

**`upload_avatar(community_id, captain_id, image_data, filename) → VirtualCaptain`**
- Uses the same pipeline as `ProfileService.upload_profile_image`:
  - Validate via PIL; check size; convert colour mode
  - Generate filenames: `vc_{captain_id}_{uuid4}_{size}.jpg`
  - Save full (max 1200px) + thumbnail (square crop, max thumbnail_size px)
  - **Delete old avatar files before writing new ones** (async, best-effort, logged on failure) — using `asyncio.to_thread(path.unlink, missing_ok=True)`, same as `_delete_local_file` in `profile_service`
  - Write via `aiofiles` — never `file_path.write_bytes()` (C5 fix applied from the start)
  - Storage path: `settings.upload_dir / "virtual-captains" / filename`
- Updates `vc.avatar_url` and `vc.avatar_thumbnail_url`

**`get_managed_communities(user_id) → list[ManagedCommunityResponse]`**
- Uses `CommunityManagerRepository.list_for_user(user_id)` — already exists
- Joins with `count_for_community` per community for `virtual_captain_count`
- Returns `ManagedCommunityResponse` list (new schema — see below)

Add to `app/schemas/virtual_captain.py`:
```python
class ManagedCommunityResponse(BaseModel):
    id: UUID
    name: str
    slug: str
    icon_url: str | None
    member_count: int
    virtual_captain_count: int
    assigned_at: datetime
    model_config = {"from_attributes": True}

class VirtualCaptainListResponse(BaseModel):
    items: list[VirtualCaptainResponse]
    total: int
    limit: int
    offset: int
```

---

### 3.6 Charter service changes

File: `app/services/charter_service.py`

In `create_charter`:

```python
async def create_charter(
    self, charter_data: CharterCreate, current_user: User
) -> CharterResponse:
    # ... existing date validation ...

    virtual_captain_id: UUID | None = None
    published_by_manager_id: UUID | None = None

    if charter_data.on_behalf_of_virtual_captain_id:
        vc_repo = VirtualCaptainRepository(self.db)
        mgr_repo = CommunityManagerRepository(self.db)

        vc = await vc_repo.get_by_id(charter_data.on_behalf_of_virtual_captain_id)
        # Opaque 404 — do not reveal whether ID exists in a different community (S3 fix)
        if vc is None:
            raise HTTPException(status_code=404, detail="Virtual captain not found")
        if (current_user.role != UserRole.ADMIN
                and not await mgr_repo.is_manager(
                    community_id=vc.community_id, user_id=current_user.id)):
            raise HTTPException(status_code=404, detail="Virtual captain not found")

        virtual_captain_id = vc.id
        published_by_manager_id = current_user.id

    charter = Charter(
        user_id=current_user.id,
        virtual_captain_id=virtual_captain_id,
        published_by_manager_id=published_by_manager_id,
        # ... other fields from charter_data ...
    )
    # ... rest of existing logic ...
```

In `update_charter`: apply the same gating — a manager can update `on_behalf_of_virtual_captain_id` only on charters where `charter.published_by_manager_id == current_user.id`.

---

### 3.7 Discovery response changes

File: `app/repositories/charter.py`

The `find_discoverable` query must eager-load the virtual captain and its community when a virtual captain is present:

```python
stmt = (
    select(Charter)
    .where(...)
    .options(
        selectinload(Charter.user),
        selectinload(Charter.virtual_captain)
            .selectinload(VirtualCaptain.community),
    )
    # ... ordering ...
)
```

**This load is mandatory** — accessing `charter.virtual_captain.community.icon_url` without it will hit the async lazy-load prohibition (see `refactor-march.md` §C4 / edge case §13 in `community-manager.md`).

The mapping function that assembles `CharterWithUserInfo` from query results:

```python
def _build_user_info(charter: Charter) -> tuple[UserBasicInfo, str | None]:
    if charter.virtual_captain:
        vc = charter.virtual_captain
        user_info = UserBasicInfo(
            id=vc.id,
            username=vc.display_name,
            avatar_url=vc.avatar_thumbnail_url,
            is_virtual_captain=True,
            social_links=vc.social_links,
        )
        badge_url = vc.community.icon_url if vc.community else None
    else:
        u = charter.user
        user_info = UserBasicInfo(
            id=u.id,
            username=u.username,
            avatar_url=u.profile_image_thumbnail_url,
            is_virtual_captain=False,
            social_links=u.social_links or [],
        )
        # Show community badge when a manager published under their own identity
        badge_url = _get_primary_community_icon(u) if charter.published_by_manager_id else None
    return user_info, badge_url
```

`_get_primary_community_icon(user)` is a helper that reads `user.community_memberships` JSONB and finds the primary community's icon. It returns `None` if none is set.

---

### 3.8 New API router: `app/api/v1/community_manager.py`

New router mounted at `/communities`. Auth uses `require_community_manager(community_id_param)` (already in `deps.py`).

```
GET    /communities/managed
GET    /communities/{community_id}/virtual-captains
POST   /communities/{community_id}/virtual-captains
GET    /communities/{community_id}/virtual-captains/{captain_id}
PATCH  /communities/{community_id}/virtual-captains/{captain_id}
DELETE /communities/{community_id}/virtual-captains/{captain_id}
POST   /communities/{community_id}/virtual-captains/{captain_id}/avatar
POST   /communities/{community_id}/icon
```

**`GET /communities/managed`** — no community_id param, just `CurrentUser`:
- Calls `vc_service.get_managed_communities(current_user.id)`
- Returns `list[ManagedCommunityResponse]`

**`DELETE /communities/{community_id}/virtual-captains/{captain_id}`**:
- `require_community_manager` checks manager status
- Calls `vc_service.delete_captain(community_id, captain_id, force=False)`
- If `409` and caller has `role == "admin"`, re-call with `force=True` (admin bypass)
- Alternatively, expose `?force=true` query param gated behind `require_admin_only`

**`POST /communities/{community_id}/icon`**:
- `require_community_manager`
- Multipart image upload — same validation as avatar upload
- Updates `Community.icon_url`
- Deletes old icon file before writing new one

Register the new router in `app/main.py` (or `app/api/router.py`):
```python
from app.api.v1.community_manager import router as community_manager_router
app.include_router(community_manager_router, prefix="/api/v1")
```

---

### 3.9 Backend file-change summary

| File | Change | Why |
|------|--------|-----|
| `alembic/versions/` | Merge heads + new migration: `virtual_captains` table, `charters` columns | A9 fix + new feature |
| `app/models/virtual_captain.py` | New: `VirtualCaptain` ORM model | New feature |
| `app/models/community.py` | Add `virtual_captains` back-ref to `Community` | New feature |
| `app/models/charter.py` | Add `virtual_captain_id`, `published_by_manager_id` columns + relationship | New feature |
| `app/repositories/virtual_captain.py` | New: `VirtualCaptainRepository` (with correct COUNT) | New feature + A1 fix |
| `app/schemas/virtual_captain.py` | New: VC request/response schemas, `ManagedCommunityResponse` | New feature |
| `app/schemas/charter.py` | Extend `CharterCreate`/`Update`, `UserBasicInfo`, `CharterWithUserInfo` | New feature |
| `app/services/virtual_captain_service.py` | New: VC CRUD + avatar upload + managed communities | New feature |
| `app/services/charter_service.py` | `create_charter` + `update_charter` — VC validation + manager fields | New feature |
| `app/repositories/charter.py` | `find_discoverable` — add `selectinload` for VC + community; update mapping | New feature (C4 guard) |
| `app/repositories/base.py` | Fix `count()` → `SELECT COUNT(*)` | A1 fix |
| `app/api/v1/community_manager.py` | New router: VC CRUD + avatar + icon + managed communities endpoints | New feature |
| `app/main.py` | Register new router | New feature |
| `app/models/__init__.py` | Register `VirtualCaptain` | New feature |

---

## 4. iOS Implementation

### 4.1 New model files

**`Core/Models/VirtualCaptain.swift`** — new file:

```swift
struct VirtualCaptain: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let communityId: UUID
    let displayName: String
    let avatarURL: URL?
    let avatarThumbnailURL: URL?
    let socialLinks: [SocialLink]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, communityId = "community_id", displayName = "display_name"
        case avatarURL = "avatar_url", avatarThumbnailURL = "avatar_thumbnail_url"
        case socialLinks = "social_links", createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct ManagedCommunity: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let slug: String
    let iconURL: URL?
    let memberCount: Int
    let virtualCaptainCount: Int
    let assignedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case iconURL = "icon_url"
        case memberCount = "member_count"
        case virtualCaptainCount = "virtual_captain_count"
        case assignedAt = "assigned_at"
    }
}

struct VirtualCaptainListResponse: Codable {
    let items: [VirtualCaptain]
    let total: Int
    let limit: Int
    let offset: Int
}
```

---

### 4.2 API response model changes

File: `Core/Models/API/CharterAPIResponse.swift`

**`UserBasicAPIResponse`** — add new fields:

```swift
struct UserBasicAPIResponse: Codable {
    let id: UUID
    let username: String?
    let avatarUrl: String?              // was profile_image_thumbnail_url; unified field name from backend
    let isVirtualCaptain: Bool
    let socialLinks: [SocialLinkAPIResponse]

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarUrl = "avatar_url"
        case isVirtualCaptain = "is_virtual_captain"
        case socialLinks = "social_links"
    }
}
```

**`CharterWithUserAPIResponse`** — add `communityBadgeUrl`:

```swift
struct CharterWithUserAPIResponse: Codable {
    // ... existing fields ...
    let user: UserBasicAPIResponse
    let distanceKm: Double?
    let communityBadgeUrl: String?      // NEW

    enum CodingKeys: String, CodingKey {
        // ... existing ...
        case communityBadgeUrl = "community_badge_url"
    }
}
```

---

### 4.3 Domain model changes

File: `Core/Models/DiscoverableCharter.swift`

**`CaptainBasicInfo`** — extend with community manager display fields:

```swift
struct CaptainBasicInfo: Hashable, Sendable {
    let id: UUID
    let username: String?
    let profileImageThumbnailURL: URL?
    let isVirtualCaptain: Bool            // NEW
    let socialLinks: [SocialLink]         // NEW
}
```

**`DiscoverableCharter`** — add community badge:

```swift
struct DiscoverableCharter: Identifiable, Hashable, Sendable {
    // ... existing fields ...
    let captain: CaptainBasicInfo
    let communityBadgeURL: URL?           // NEW
}
```

Mapping in `CharterWithUserAPIResponse.toDiscoverableCharter()`:

```swift
func toDiscoverableCharter() -> DiscoverableCharter {
    DiscoverableCharter(
        // ... existing mappings ...
        captain: user.toCaptainBasicInfo(),
        communityBadgeURL: communityBadgeUrl.flatMap(URL.init)
    )
}
```

---

### 4.4 Map pin overhaul (U1 from refactor-march.md)

File: `Features/Charter/Discovery/CharterMapView.swift`

Replace `CharterMapAnnotation` with `UserAvatarPin` as specified in `refactor-march.md §Step 7`. This is the primary visible payoff of the community badge work.

```swift
struct UserAvatarPin: View {
    let charter: DiscoverableCharter
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(ringColor)
                .frame(width: isSelected ? 52 : 44)

            CachedAsyncImage(url: charter.captain.profileImageThumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: isSelected ? 22 : 18))
            }
            .frame(width: isSelected ? 44 : 36)
            .clipShape(Circle())

            if let badgeURL = charter.communityBadgeURL {
                CachedAsyncImage(url: badgeURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    EmptyView()
                }
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .offset(x: 4, y: 4)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private var ringColor: Color {
        charter.communityBadgeURL != nil
            ? DesignSystem.Colors.communityAccent
            : charter.captain.urgencyColor ?? DesignSystem.Colors.primary
    }
}
```

`CachedAsyncImage` is a lightweight wrapper around `AsyncImage` backed by `NSCache<NSURL, UIImage>`. Introduce it as `Core/Views/CachedAsyncImage.swift` — this is the avatar image caching recommended in `refactor-march.md §Caching`. Reuse it on map pins, captain cards, and virtual captain rows.

**`CharterMapCallout`** update — show `isVirtualCaptain` flag so the "View Profile" button is hidden for virtual captains:

```swift
// In CharterMapCallout body:
if !charter.captain.isVirtualCaptain {
    Button("View Profile") { onViewProfile?(charter.captain.id) }
}
```

---

### 4.5 `APIClient` additions

File: `Services/APIClient.swift`

While adding these endpoints, fix the `EmptyResponse() as! T` force-cast (C2 from refactor-march.md):

```swift
// Before:
if T.self == EmptyResponse.self { return EmptyResponse() as! T }

// After (safe):
if let empty = EmptyResponse() as? T { return empty }
throw APIError.decodingFailed
```

New methods:

```swift
// MARK: — Managed Communities

func getManagedCommunities() async throws -> [ManagedCommunity] {
    return try await get("/communities/managed")
}

// MARK: — Virtual Captains

func listVirtualCaptains(communityId: UUID, limit: Int = 50, offset: Int = 0) async throws -> VirtualCaptainListResponse {
    return try await get("/communities/\(communityId)/virtual-captains?limit=\(limit)&offset=\(offset)")
}

func createVirtualCaptain(communityId: UUID, displayName: String, socialLinks: [SocialLink]) async throws -> VirtualCaptain {
    let body = CreateVirtualCaptainRequest(displayName: displayName, socialLinks: socialLinks)
    return try await post("/communities/\(communityId)/virtual-captains", body: body)
}

func updateVirtualCaptain(communityId: UUID, captainId: UUID, displayName: String?, socialLinks: [SocialLink]?) async throws -> VirtualCaptain {
    let body = UpdateVirtualCaptainRequest(displayName: displayName, socialLinks: socialLinks)
    return try await patch("/communities/\(communityId)/virtual-captains/\(captainId)", body: body)
}

func deleteVirtualCaptain(communityId: UUID, captainId: UUID) async throws {
    try await delete("/communities/\(communityId)/virtual-captains/\(captainId)")
}

func uploadVirtualCaptainAvatar(communityId: UUID, captainId: UUID, imageData: Data, filename: String) async throws -> VirtualCaptain {
    return try await uploadImage("/communities/\(communityId)/virtual-captains/\(captainId)/avatar",
                                 imageData: imageData, filename: filename)
}

func uploadCommunityIcon(communityId: UUID, imageData: Data, filename: String) async throws -> CommunityResponse {
    return try await uploadImage("/communities/\(communityId)/icon",
                                 imageData: imageData, filename: filename)
}
```

Add request types to `Core/Models/API/CharterRequestPayloads.swift` (or a new `VirtualCaptainRequestPayloads.swift`):

```swift
struct CreateVirtualCaptainRequest: Encodable {
    let displayName: String
    let socialLinks: [SocialLink]
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case socialLinks = "social_links"
    }
}

struct UpdateVirtualCaptainRequest: Encodable {
    let displayName: String?
    let socialLinks: [SocialLink]?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case socialLinks = "social_links"
    }
}
```

Extend `CharterCreateRequest` and `CharterUpdateRequest`:

```swift
// Core/Models/API/CharterRequestPayloads.swift
struct CharterCreateRequest: Encodable {
    // ... existing fields ...
    let onBehalfOfVirtualCaptainId: UUID?

    enum CodingKeys: String, CodingKey {
        // ... existing ...
        case onBehalfOfVirtualCaptainId = "on_behalf_of_virtual_captain_id"
    }
}
```

---

### 4.6 Charter editor: "Publish As" selector

File: `Features/Charter/CharterEditorView.swift` and `CharterEditorViewModel.swift`

This section appears only when `viewModel.isCommunityManager == true` (derived from `GET /communities/managed` returning a non-empty list).

**`CharterEditorViewModel`** additions:

```swift
var managedCommunities: [ManagedCommunity] = []
var selectedVirtualCaptain: VirtualCaptain? = nil   // nil = publishing as self
var isCommunityManager: Bool { !managedCommunities.isEmpty }
var availableVirtualCaptains: [VirtualCaptain] = []
var showVirtualCaptainPicker = false

func loadManagedCommunities() async {
    do {
        managedCommunities = try await apiClient.getManagedCommunities()
    } catch {
        // Non-fatal; manager features simply don't appear if this fails
    }
}

func loadVirtualCaptains(for community: ManagedCommunity) async {
    do {
        let response = try await apiClient.listVirtualCaptains(communityId: community.id)
        availableVirtualCaptains = response.items
    } catch { /* log */ }
}
```

**`CharterEditorView`** — new "Publishing As" section inserted between the visibility control and the save button:

```swift
// In CharterEditorView body, after VisibilitySection:
if viewModel.isCommunityManager && form.visibility != .private {
    PublishingAsSection(
        selectedCaptain: viewModel.selectedVirtualCaptain,
        onChangeTapped: { viewModel.showVirtualCaptainPicker = true }
    )
    .sheet(isPresented: $viewModel.showVirtualCaptainPicker) {
        VirtualCaptainPickerSheet(
            managedCommunities: viewModel.managedCommunities,
            availableCaptains: viewModel.availableVirtualCaptains,
            selectedCaptain: $viewModel.selectedVirtualCaptain,
            onCommunitySelected: { viewModel.loadVirtualCaptains(for: $0) }
        )
    }
}
```

Visibility rules:
- When `selectedVirtualCaptain != nil` and `visibility == .private`, show a warning: "Private charters can't be published on behalf of a virtual captain" — auto-reset `selectedVirtualCaptain` to `nil` if user switches to private.
- `CharterCreateRequest.onBehalfOfVirtualCaptainId` is set from `selectedVirtualCaptain?.id`.

---

### 4.7 New screen: Virtual Captain Management

**File structure:**

```
Features/CommunityManager/
├── CommunityManagerView.swift         — top-level list of managed communities
├── CommunityManagerViewModel.swift
├── CommunityDetailView.swift          — per-community: icon, VC list, charter count
├── CommunityDetailViewModel.swift
├── VirtualCaptainEditorView.swift     — create / edit a VC
├── VirtualCaptainEditorViewModel.swift
└── Components/
    ├── VirtualCaptainRow.swift
    ├── CommunityIconSection.swift     — icon display + upload tap
    └── PublishingAsSection.swift      — charter editor component (§4.6)
```

**Entry point:** `ProfileView` — when `managedCommunities.isEmpty == false`, show a new "Community Manager" section with a navigation link to `CommunityManagerView`.

---

### 4.8 iOS file-change summary

| File | Change |
|------|--------|
| `Core/Models/VirtualCaptain.swift` | New: `VirtualCaptain`, `ManagedCommunity`, `VirtualCaptainListResponse` |
| `Core/Models/API/CharterAPIResponse.swift` | Extend `UserBasicAPIResponse`, `CharterWithUserAPIResponse` |
| `Core/Models/API/CharterRequestPayloads.swift` | Add `on_behalf_of_virtual_captain_id` to create/update; add VC request types |
| `Core/Models/DiscoverableCharter.swift` | Add `communityBadgeURL` to `DiscoverableCharter`; `isVirtualCaptain`, `socialLinks` to `CaptainBasicInfo` |
| `Core/Views/CachedAsyncImage.swift` | New: lightweight `NSCache`-backed async image view |
| `Services/APIClient.swift` | Add VC CRUD + avatar + icon + managed communities methods; fix `as! T` force-cast |
| `Features/Charter/Discovery/CharterMapView.swift` | Replace `CharterMapAnnotation` with `UserAvatarPin` + `CommunityBadgeOverlay` |
| `Features/Charter/CharterEditorView.swift` | Add `PublishingAsSection` for community managers |
| `Features/Charter/CharterEditorViewModel.swift` | Add managed community + VC picker state |
| `Features/CommunityManager/` | New: full screen stack for VC management |
| `Features/Profile/ProfileView.swift` | Add "Community Manager" section when manager |

---

## 5. UX Design

### 5.1 Publishing on Behalf of a Virtual Captain

The goal is zero friction for the common case (publishing as yourself) while making the "on behalf of" path discoverable and reversible.

**Context: the charter editor**

Regular users see no change — the editor looks exactly as before. The "Publishing As" section is strictly additive and hidden for non-managers.

**"Publishing As" section — anatomy:**

```
┌─ Publishing As ─────────────────────────────────────────┐
│                                                         │
│  [avatar]  Yourself                          Change >   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

When a virtual captain is selected:

```
┌─ Publishing As ─────────────────────────────────────────┐
│  [⚓ club badge]                                        │
│  [vc avatar]  Marco Rossi                    Change >   │
│               RBYC Racing School                        │
└─────────────────────────────────────────────────────────┘
```

- The community name appears as a subtitle under the captain name — confirms which community they're publishing for.
- Community badge icon is shown at top-left of the section to provide colour context.
- "Change >" opens `VirtualCaptainPickerSheet`.

**`VirtualCaptainPickerSheet` — behaviour:**

1. Opens as a `.sheet` (not `.fullScreenCover`) — feels lightweight.
2. Top row: "Myself" option (avatar + "Publishing as yourself") — always present, always first.
3. If manager of a single community: flat list of that community's VCs below.
4. If manager of multiple communities: grouped by community with community icon as section header.
5. Each VC row: thumbnail + display name + (optionally) a charter count badge.
6. Selecting a VC closes the sheet immediately — no confirm button needed.
7. Selecting "Myself" resets `selectedVirtualCaptain = nil`.
8. Search field at top of the list — filters VCs by display name (client-side, no extra request).
9. "Manage Virtual Captains" link at the bottom navigates to `CommunityManagerView`.

**Visibility guard:**

When the user selects a virtual captain but then switches visibility back to `.private`, show an inline message:

> "Private charters won't appear on the map. Publishing for a virtual captain only makes sense for community or public visibility."

Auto-reset the VC selection to `nil` if the user confirms going private, so the form is consistent on save.

**On save:**

The `CharterCreateRequest.onBehalfOfVirtualCaptainId` is set. No other UX change — the charter appears in My Charters attributed to the manager (for their own editing purposes), but the discovery map shows the virtual captain.

---

### 5.2 Discovering a Charter from a Virtual Captain

**Map pin:** `UserAvatarPin` shows the virtual captain's avatar + community badge (§4.4). Visually identical to a real captain's pin with the badge overlay.

**Bottom sheet (captain card):** When the user taps a pin for a VC-published charter:

```
┌─ Charter Card ──────────────────────────────────────────┐
│  [vc avatar]  Marco Rossi                               │
│               [⚓ RBYC badge]  RBYC Racing School       │
│  ──────────────────────────────────────────────────     │
│  📍 Palma de Mallorca  ·  12–15 Jun  ·  3 days         │
│                                                         │
│  [instagram icon] @marco_skippers                       │
│                                                         │
│               [ View Charter ]                          │
└─────────────────────────────────────────────────────────┘
```

- The `is_virtual_captain: true` flag hides the "View Profile" button (virtual captains have no app profile).
- Social links are shown directly on the card (same as a real captain card) using the `social_links` field from `UserBasicInfo`.
- Community badge + name are shown as a sub-row under the captain name.

---

### 5.3 Managing Virtual Captains (Community Manager Dashboard)

**Entry point:** `ProfileView → "Community Manager" section` — appears only when `managedCommunities` is non-empty. Shows a horizontal strip of community icons with a "Manage" button.

**`CommunityManagerView` — top-level screen:**

```
┌─ Community Manager ─────────────────────────────────────┐
│  < Back                                                 │
│                                                         │
│  ┌─────────────────────────────────────────────┐        │
│  │  [⚓]  RBYC Racing School                   │  >     │
│  │       8 captains  ·  12 active charters      │        │
│  └─────────────────────────────────────────────┘        │
│                                                         │
│  ┌─────────────────────────────────────────────┐        │
│  │  [🌊]  AnyFleet Demo                        │  >     │
│  │       3 captains  ·  2 active charters       │        │
│  └─────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

**`CommunityDetailView` — per-community management:**

```
┌─ RBYC Racing School ────────────────────────────────────┐
│  < Back                                    [ + Add ]    │
│                                                         │
│  ┌─ Community Icon ─────────────────────────────┐       │
│  │  [⚓ large]   Tap to update icon             │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
│  CAPTAINS  ─────────────────────────────────────────    │
│                                                         │
│  [photo]  Marco Rossi                  3 charters  >    │
│  [photo]  Ingrid Svensson             1 charter    >    │
│  [       ]  Tom Bradley               0 charters   >    │
│  ─────────────────────────────────────────────          │
│  [ + Add Virtual Captain ]                              │
└─────────────────────────────────────────────────────────┘
```

Design notes:
- Community icon section is tappable (presents photo picker → uploads via `POST /communities/{id}/icon`).
- "+" button and the inline "Add Virtual Captain" row both open `VirtualCaptainEditorView` in create mode.
- Each captain row shows their photo (or a placeholder monogram), display name, and active charter count.
- A VC with 0 charters shows the count in muted colour.
- Swipe-left on a VC row → "Delete" destructive action — shows confirmation sheet if charters exist.

**`VirtualCaptainEditorView` — create/edit:**

```
┌─ New Captain ───────────────────────────────────────────┐
│  < Cancel                                   [ Save ]    │
│                                                         │
│  ┌─ Photo ──────────────────────────────────────┐       │
│  │  [          ]                                │       │
│  │   Tap to add a photo                         │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
│  Display Name                                           │
│  ┌──────────────────────────────────────────────┐       │
│  │  Marco Rossi                                 │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
│  SOCIAL LINKS                                           │
│  [instagram]  @marco_skippers          [ + ]   [ − ]   │
│  [ + Add Link ]                                         │
│                                                         │
│  ─────────────────────────────────────────────          │
│  [ Delete Virtual Captain ]  (edit mode only)           │
└─────────────────────────────────────────────────────────┘
```

Design notes:
- Photo tap → `PhotosPicker` (same API as user profile photo picker) → upload via `POST /communities/{id}/virtual-captains/{id}/avatar`.
- Display Name is a required `TextField` — "Save" is disabled while empty.
- Social links section is identical to the user profile `SocialLinksSection` — reuse the component.
- In create mode, "Save" calls `POST /communities/{id}/virtual-captains`, then optionally uploads the avatar if the user picked one (two sequential calls).
- In edit mode, "Save" calls `PATCH` and re-uploads avatar if changed.
- "Delete Virtual Captain" is a destructive button at the very bottom (visually separated). If the VC has active charters, show an alert: "Marco Rossi has 3 active charters. Delete or reassign them before removing this captain." No force-delete from the iOS UI — that stays admin-only.
- Avatar upload uses the same crop behaviour as user profile upload (square crop, thumbnail generated server-side).

**Error states:**
- 409 on delete → "This captain has active charters. Please delete or reassign them first."
- 404 on any action → "This captain was not found. They may have been deleted." + dismiss.
- Network errors → retry toast at the bottom of the screen (same `ErrorBanner` pattern).

---

### 5.4 Virtual Captain card in `DiscoveredCharterDetailView`

The full charter detail view (opened from a map pin or list row) should show the virtual captain the same way it shows a real captain:

- Captain section: avatar + display name + community badge row + social links
- **No "View Profile"** button — replace it with a community link row: "Part of [Community Name]" that navigates to (or previews) the community detail.
- Social links rendered as tappable chips (same `SocialLinksDisplaySection`).

---

## 6. iOS–Backend Coordination Checklist

| iOS feature | Backend endpoint | Status |
|-------------|-----------------|--------|
| `GET /communities/managed` | `app/api/v1/community_manager.py` | Needs build |
| Virtual captain list | `GET /communities/{id}/virtual-captains` | Needs build |
| Virtual captain create | `POST /communities/{id}/virtual-captains` | Needs build |
| Virtual captain edit | `PATCH /communities/{id}/virtual-captains/{id}` | Needs build |
| Virtual captain delete | `DELETE /communities/{id}/virtual-captains/{id}` | Needs build |
| Virtual captain avatar upload | `POST /communities/{id}/virtual-captains/{id}/avatar` | Needs build |
| Community icon upload | `POST /communities/{id}/icon` | Needs build |
| "Publish for" selector in charter editor | `on_behalf_of_virtual_captain_id` in `CharterCreate` | Needs build |
| Map pin avatar + community badge | `avatar_url`, `is_virtual_captain`, `community_badge_url` in discovery response | Needs build |
| Virtual captain social links on captain card | `social_links` in `UserBasicInfo` discovery response | Needs build |
| Community badge hidden for regular charters | `community_badge_url == null` when no manager involvement | Needs build |

---

## 7. Implementation Order

The order below respects dependencies between backend and iOS, and groups refactor fixes with the features that open the same files.

### Sprint A — Backend foundation (no iOS dependency)

1. **Resolve Alembic double-head** (A9) — `alembic merge heads`, verify clean upgrade.
2. **Fix `BaseRepository.count()`** (A1/P1) — one-file change, unblocks all future list queries.
3. **Run new migration** — `virtual_captains` table + `charters` columns.
4. **`VirtualCaptain` ORM model** — `app/models/virtual_captain.py` + back-refs in `community.py` + `charter.py`.
5. **`VirtualCaptainRepository`** — new file (uses correct `SELECT COUNT(*)`).
6. **Pydantic schemas** — `app/schemas/virtual_captain.py` + extend `app/schemas/charter.py`.
7. **`VirtualCaptainService`** — new file (async I/O from day one; delete-before-write for avatars).
8. **Charter service changes** — `create_charter` + `update_charter` (with opaque 404, not 403).
9. **Charter repository changes** — `find_discoverable` eager-load + `_build_user_info` mapping.
10. **New API router** — `app/api/v1/community_manager.py` + register in `main.py`.

### Sprint B — iOS foundation (depends on Sprint A being deployed or mockable)

11. **`VirtualCaptain.swift`** model file + `ManagedCommunity` + request/response types.
12. **Extend `CharterAPIResponse.swift`** — `UserBasicAPIResponse` + `CharterWithUserAPIResponse` new fields.
13. **Extend `DiscoverableCharter.swift`** — `CaptainBasicInfo` + `DiscoverableCharter` new fields.
14. **`APIClient` additions** — all VC/community endpoints; fix `as! T` force-cast (C2) while there.
15. **`CachedAsyncImage.swift`** — avatar image cache component (used by map pins and VC rows).

### Sprint C — iOS UI (depends on Sprint B)

16. **`UserAvatarPin`** + `CommunityBadgeOverlay` in `CharterMapView.swift` — map pin overhaul (U1).
17. **`CharterMapCallout`** update — hide "View Profile" for `isVirtualCaptain == true`.
18. **`VirtualCaptainPickerSheet`** — picker for charter editor.
19. **`PublishingAsSection`** + editor integration — "Publish As" in `CharterEditorView`.
20. **`CommunityManagerView` + `CommunityDetailView` + `VirtualCaptainEditorView`** — management screens.
21. **`ProfileView` update** — "Community Manager" section entry point.
22. **`DiscoveredCharterDetailView`** update — VC captain card.

---

## 8. Open Questions & Decisions Needed

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | **Maximum virtual captains per community?** The PRD leaves this open. Without a cap, a compromised manager account could flood the DB. | Add `settings.max_virtual_captains_per_community = 100` (configurable env var). Application-level check in `VirtualCaptainService.create_captain`. No DB constraint needed since it's configurable. |
| 2 | **Multiple managed communities — which badge to show when a manager publishes under their own identity?** `_get_primary_community_icon` currently uses `community_memberships` JSONB primary flag. If the manager has no primary community, badge is `null`. | Use `community_memberships` primary flag. If ambiguous (no primary set), show no badge and let the manager set a primary community in their profile. |
| 3 | **Social links on virtual captain bottom sheet card** — Should all platforms be shown, or only the first link? | Show all links as a horizontal chip row (same as user profile social section). Cap at 10 links server-side (already in schema `max_length=10`). |
| 4 | **Avatar upload — crop UX.** iOS profile uses a square crop picker. Virtual captain avatars should match. | Reuse the same crop flow. Consider extracting the crop logic into a shared `AvatarCropView` component at this point. |
| 5 | **Discovery of virtual captains by non-managers (public captains page)?** PRD defers this to a future phase. | Return only the fields exposed in `UserBasicInfo` (no dedicated `/captains/vc/{id}` route in this phase). The VC is only visible through a charter in discovery. |
| 6 | **Community manager for charters they own personally (not VC charters)** — should their own charters show a community badge? | Yes, if `published_by_manager_id == current_user.id` and the charter is NOT a VC charter, the badge derives from their primary community. This is already handled in `_build_user_info`. |

---

*Document version: 1.0 — March 2026*  
*Author: Product + Engineering*  
*Review: Required before Sprint A begins*
