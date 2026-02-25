# Charter Discovery — Manual Testing Guide

**Scope:** CRUD, visibility, sync, and Discover tab  
**Stack:** iOS (Swift) + FastAPI backend  
**Last updated:** Feb 2026

---

## System Overview (Quick Reference)

| Concept | Details |
|---|---|
| Visibility levels | `private` (lock), `community` (person.2), `public` (globe) |
| Sync trigger | Visibility change → `needsSync = true` → `pushPendingCharters()` |
| What syncs | Only non-`private` charters are pushed to the server |
| Discover endpoint | Returns **only `public`** charters (`community` is not yet discoverable) |
| Delete strategy | Soft delete — `deleted_at` timestamp, hidden immediately |
| Geo filter | Excludes charters with no lat/lon when `near_lat`/`near_lon` provided |
| Ordering (no geo) | `start_date ASC` |
| Ordering (with geo) | `distance_km ASC` |
| Auth required | All endpoints require a valid JWT |

---

## Preconditions

- Backend running locally or on staging
- At least **two test user accounts** (User A = owner, User B = non-owner)
- Auth tokens available for both users (e.g. via Swagger `/api/v1/auth/token` or app login)
- A GPS location or a known lat/lon for geo tests (Santorini: `36.3932, 25.4615` works well)

---

## 1. Creating Charters

### 1.1 Create a private charter (default)

**Steps:**
1. Open app → Charters tab → tap `+`
2. Fill in name, dates, optional boat/destination
3. In **Charter Visibility**, confirm **Private** is pre-selected (lock icon highlighted, checkmark visible)
4. Tap Save

**Expected:**
- Charter appears in Charters tab list
- No sync activity (no iCloud icon spinner, no "Sign in to sync" banner)
- `needsSync` is `false`; no backend record created
- Charter does **not** appear in Discover tab for any user

**Edge cases:**
- Leave boat name empty → charter saves without it, row shows only charter name
- Leave destination empty → no `📍` row shown in detail view; no map thumbnail in Discover
- End date = start date → allowed (0-day duration shown as "0 days")
- End date before start date → validation error at save, no creation (`422` from API if tested directly)

---

### 1.2 Create a community charter

**Steps:**
1. Tap `+` → fill in name + dates
2. Select **Community** visibility (person.2.fill icon)
3. Confirm info hint appears: *"You can change visibility anytime in charter settings."*
4. Save

**Expected:**
- Charter appears in Charters tab
- If **signed in**: `needsSync = true` is set; `pushPendingCharters()` fires and pushes to backend (create POST)
- Backend record created with `visibility = "community"`
- Charter does **not** appear in `/api/v1/charters/discover` (only `public` is discoverable server-side)
- Charter does **not** appear in Discover tab

**Edge cases:**
- Create community charter while **signed out** → `needsAuthForSync = true` → "Sign in to sync your charters" banner visible at top of Charters tab; charter stays local
- Sign in after creating community charter while offline → banner disappears; sync fires; charter pushed to server

---

### 1.3 Create a public charter

**Steps:**
1. Tap `+` → fill in name, dates, a destination text, and enter lat/lon if testing geo
2. Select **Public** (globe icon)
3. Confirm info hint appears below picker
4. Save

**Expected:**
- Charter appears in Charters tab
- `needsSync = true`; sync fires; POST to `/api/v1/charters` with `visibility = "public"`
- Backend `serverID` written back into local record
- Charter appears in Discover tab for **any authenticated user** (including User B)
- Discovery row shows: captain avatar, destination, charter name, date range, boat (if set), urgency badge

**Edge cases:**
- Create public charter **without** a destination/coordinates → charter still syncs; appears in Discover list view; map thumbnail **not** shown in discovery row (no coordinates); geo filter will **exclude** it
- Create two public charters same day → both appear in Discover, ordered by `start_date ASC`
- Create public charter with start date in the past → `isDiscoverable` is `false` in local model (past charters are not shown as discoverable); verify expected behavior against the server (server has no date guard on `find_discoverable`, so it will still be returned by the API — this is a known edge case to address)

---

### 1.4 Validation edge cases

| Input | Expected result |
|---|---|
| Name > 200 characters | Validation error before submission |
| End date < start date | `422 Unprocessable Entity` from API |
| `latitude` > 90 or < -90 | `422` from API |
| `longitude` > 180 or < -180 | `422` from API |
| Missing `name` or `start_date` or `end_date` | `422` from API |
| Rate limit (>20 creates/minute) | `429 Too Many Requests` |

---

## 2. Charters Tab — Visibility and Sync Status

### 2.1 Visual distinction of public charters in the list

Currently `CharterRowView` does not render a visibility badge — the row shows name, boat, dates, and location uniformly. This means:

- **Expected (current):** No visual difference between private/community/public in the list row
- **Expected (future):** Public charters should show a globe icon or colored indicator — document as a gap if you want to add one

**Test steps:**
1. Create one private, one community, one public charter
2. View Charters tab list
3. Verify all three appear; note the lack of visibility indicator (open issue)

---

### 2.2 Sync status indicators

**"Sign in to sync" banner (top of Charters tab):**
- Appears when `charterSyncService.needsAuthForSync == true`
- Triggered by: creating a non-private charter while logged out
- Disappears after signing in and sync completing

**Test steps:**
1. Sign out
2. Create a public charter
3. Confirm banner: *"Sign in to sync your charters"* with iCloud icon appears at top
4. Sign in
5. Confirm banner disappears and sync runs (check backend for the created charter)

**Spinner / `isSyncing` state:**
- `CharterSyncService.isSyncing` is currently not surfaced in the UI (it exists on the service)
- **Note:** No spinner or in-progress indicator during push — document as a gap if you want to add one

---

### 2.3 Pull-to-refresh merges remote charters

**Steps:**
1. As User B, create a public charter directly via API (simulating another device)
2. Open Charters tab as User A (or User B on a second device)
3. Pull to refresh

**Expected:**
- `pullMyCharters()` fires, fetching `GET /api/v1/charters`
- New charter upserted into local DB and visible in list
- `lastSyncDate` updated

---

## 3. Discover Tab

### 3.1 Public charters appear in discovery feed

**Steps:**
1. As User A, create a public charter with destination + coordinates
2. Open app as User B → Discover tab → Charter discovery section
3. Pull to refresh if needed

**Expected:**
- User A's charter card is visible
- Card shows: User A's avatar + username, destination, charter name, date range, boat name (if set), urgency badge, map thumbnail (if has coordinates)
- Distance shown if User B has "Near Me" filter active

**Negative test:** Create a **private** charter as User A → confirm it does **not** appear for User B

---

### 3.2 Community charters do NOT appear in discovery feed

**Steps:**
1. Create a charter with `visibility = "community"` (via app or API)
2. Open Discover tab as a different user

**Expected:**
- Charter is absent from the feed
- Server-side: `GET /api/v1/charters/discover` returns only `visibility == 'public'`

---

### 3.3 Urgency badges

| Days until start | Badge | Color |
|---|---|---|
| < 0 | Past | Gray |
| 0–7 | This week | Red |
| 8–30 | This month | Orange |
| > 30 | Upcoming | Primary blue |

**Test steps:**
1. Create four public charters with start dates covering each urgency range
2. Verify badges match the table above in the discovery feed

---

### 3.4 Filters — Date range

**Steps:**
1. Open Discover tab → tap filter icon (slider.horizontal.3)
2. Select preset **"This Month"**
3. Apply

**Expected:**
- Only charters with `start_date` within the current month appear
- Active filter chip shows in horizontal scroll bar below toolbar
- Filter icon shows a blue dot badge when filter is active
- Charters outside the date range are absent

**Edge cases:**
- Set `date_from` > `date_to` → filter sheet should prevent submission or clear to defaults
- Apply **Custom Range** with past date range → empty state appears with "No Charters Found" and "Clear Filters" button
- Clear filters → all public charters reload, chips disappear, badge dot disappears

---

### 3.5 Filters — Near Me (geo proximity)

**Steps:**
1. Grant location permission to the app (Settings → AnyFleet → Location → While Using)
2. Open Discover → filter panel → enable **Near Me** toggle
3. Set radius (e.g. 100 km)
4. Apply

**Expected:**
- Only public charters with coordinates within radius appear
- Each discovery row shows "*N* km away" below urgency badge
- Results ordered nearest first
- Public charters **without** coordinates are excluded from results (geo filter excludes null lat/lon)

**Edge cases:**
- Deny location permission → "Near Me" toggle disabled or prompts permission; no geo filter applied
- Enable Near Me with no nearby public charters → empty state: *"No public charters found nearby. Try expanding your search radius."*
- Increase radius slider until a far charter enters range → chart appears in results

---

### 3.6 List view vs Map view

**Steps:**
1. Open Discover → tap map icon (top-right)
2. Verify charters with coordinates appear as pins
3. Tap a pin → charter detail sheet opens
4. Tap list icon → returns to list view

**Expected:**
- Map view shows pins only for charters with `latitude` + `longitude`
- Charters without coordinates are absent from map (not a bug — expected)
- Progress spinner shows at top of map during loading
- Tapping pin opens `DiscoveredCharterDetailView`

---

### 3.7 Pagination ("Load More")

**Steps:**
1. Ensure > 20 public charters exist in the database
2. Open Discover tab (default `limit=20`)
3. Scroll to bottom → tap **"Load More"**

**Expected:**
- Next page loads (offset increments by 20)
- `hasMore` is false after the last page; "Load More" button disappears
- Total count in API response `total` matches across pages
- No duplicate charter cards across pages

---

### 3.8 Discovery empty states

| Condition | Expected message |
|---|---|
| No public charters exist | "No public charters are available right now. Check back soon!" |
| Filters active, no matches | "No charters match your current filters. Try adjusting your date range or location." |
| Near Me active, none nearby | "No public charters found nearby. Try expanding your search radius." |

---

## 4. Editing Charters

### 4.1 Edit charter fields

**Steps:**
1. Charters tab → swipe left on a charter → tap **Edit** (pencil icon)
2. Modify name, boat, dates, destination, visibility
3. Save

**Expected:**
- Changes reflected immediately in Charters tab list
- If visibility changed to non-private: `needsSync = true`; sync fires; `PUT /api/v1/charters/{id}` sent
- If visibility changed from public → private: charter disappears from Discover tab for other users immediately after server update

### 4.2 Change visibility from private to public

**Steps:**
1. Open editor for a private charter
2. Change visibility to **Public**
3. Save

**Expected:**
- `needsSync = true` set
- If no `serverID` yet: charter is **created** on server (POST)
- If `serverID` exists: charter is **updated** on server (PUT)
- Charter appears in Discover tab

### 4.3 Change visibility from public to private

**Steps:**
1. Open editor for a public charter that is currently synced
2. Change visibility to **Private**
3. Save

**Expected:**
- `PUT /api/v1/charters/{id}` with `visibility = "private"`
- Charter removed from `GET /api/v1/charters/discover` results immediately
- Other users can no longer see it in the Discover tab
- `GET /api/v1/charters/{id}` by a non-owner returns `404`

### 4.4 Edit other user's charter (authorization)

**Steps:**
1. Get the ID of User A's charter
2. As User B, send `PUT /api/v1/charters/{id}` with a name change

**Expected:** `403 Forbidden`

### 4.5 Edit charter with invalid dates

**Steps:**
1. Open editor → set end date to before start date
2. Attempt save

**Expected:**
- `422 Unprocessable Entity` from API (or local validation before submit)
- Charter not updated; original data preserved

---

## 5. Deleting Charters

### 5.1 Delete own charter (swipe action)

**Steps:**
1. Charters tab → swipe left on a charter → tap **Delete** (red trash icon)
2. Confirm if prompted

**Expected:**
- Charter removed from list immediately
- `DELETE /api/v1/charters/{id}` returns `204 No Content`
- Backend: `deleted_at` timestamp set (soft delete)
- Charter disappears from Discover tab for all users immediately

### 5.2 Deleted charter excluded from discovery

**Steps:**
1. Create a public charter, confirm it appears in Discover
2. Delete it as the owner
3. Check Discover tab (pull to refresh)

**Expected:**
- Charter absent from `GET /api/v1/charters/discover`
- No `404` errors for existing detail views — they should gracefully handle the missing charter

### 5.3 Delete other user's charter (authorization)

**Steps:**
1. Get the ID of User A's charter
2. As User B, send `DELETE /api/v1/charters/{id}`

**Expected:** `403 Forbidden`

### 5.4 Delete non-existent charter

**Steps:**
1. Send `DELETE /api/v1/charters/{random-uuid}` as any authenticated user

**Expected:** `404 Not Found`

### 5.5 Deleted charter not returned in user list

**Steps:**
1. Delete a charter
2. Send `GET /api/v1/charters` as the owner

**Expected:**
- Deleted charter absent from `items`
- `total` count decremented

---

## 6. Authentication Edge Cases

| Scenario | Expected |
|---|---|
| Create charter without auth token | `401 Unauthorized` |
| List charters without auth | `401 Unauthorized` |
| Discover charters without auth | `401 Unauthorized` |
| Create community/public charter while signed out | Local charter created; `needsAuthForSync = true`; banner shown |
| Create private charter while signed out | No sync attempted; no banner |

---

## 7. Known Gaps / Gaps to Track

| Gap | Description |
|---|---|
| No visibility badge in CharterRowView | List rows do not show lock/globe icon; users can't see visibility at a glance |
| No sync in-progress indicator | `isSyncing` state exists on service but not surfaced in UI |
| Community visibility not discoverable server-side | `find_discoverable` queries only `public`; community charters sync but never appear in Discover |
| Past public charters in server discover | Backend has no date guard — past public charters returned by `/discover`; client `isDiscoverable` checks `isUpcoming` but only for local rendering |
| `update_charter` with end date before current start date | Returns `400` or `403` (non-deterministic) — test `400` path explicitly |

---

## 8. API Quick Reference

```
POST   /api/v1/charters                     Create charter
GET    /api/v1/charters                     List own charters (limit, offset)
GET    /api/v1/charters/{id}                Get charter (owner or public only)
PUT    /api/v1/charters/{id}                Update charter (owner only)
DELETE /api/v1/charters/{id}                Soft delete (owner only)
GET    /api/v1/charters/discover            Discover public charters
  ?date_from=ISO8601
  &date_to=ISO8601
  &near_lat=float
  &near_lon=float
  &radius_km=float   (default 50)
  &limit=int         (default 20, max 100)
  &offset=int
```

Rate limits: `20/min` for create/update/delete, `30/min` for read/discover.

---

## 9. Incremental Test Checklist

Use this list to track coverage as you add automated tests:

### Backend (`tests/test_charters.py`) — already covered
- [x] Create with `public` visibility
- [x] Create with invalid dates (`422`)
- [x] Default visibility is `private`
- [x] List own charters
- [x] Get by ID
- [x] Get non-existent → `404`
- [x] Update charter
- [x] Update non-owner → `403`
- [x] Delete (soft)
- [x] Delete non-owner → `403`
- [x] Discover only public
- [x] Discover with date filter
- [x] Discover with geo filter
- [x] Discover excludes deleted
- [x] Discover pagination
- [x] Get public charter as non-owner → `200`
- [x] Get private charter as non-owner → `404`
- [x] Change private → public (appears in discover)
- [x] Change public → private (removed from discover)
- [x] Distance calculation
- [x] Geo filter excludes no-location charters
- [x] Results ordered by distance
- [x] Auth required for all endpoints
- [x] Missing required fields → `422`
- [x] Invalid coordinates → `422`

### Backend — missing / to add
- [ ] Update charter with end_date < start_date → `400` (currently returns `400` or `403`, assert `400`)
- [ ] Community charter does NOT appear in `/discover`
- [ ] Past public charter behavior in `/discover` (add date guard or assert current behavior)
- [ ] Discover with combined date + geo filter
- [ ] Discover `offset` beyond total → empty items, correct `total`
- [ ] `limit` capped at 100 (send `limit=200` → returns max 100)
- [ ] Discover `radius_km` = 0 → only charters at exact point (or empty)
- [ ] Rate limit headers present on `429` response

### iOS (`anyfleetTests/`) — to add
- [ ] `CharterSyncService`: private charter not pushed when `pushPendingCharters()` called
- [ ] `CharterSyncService`: `needsAuthForSync = true` when unauthenticated with pending non-private charter
- [ ] `CharterSyncService`: `needsAuthForSync = false` after successful push
- [ ] `CharterSyncService`: community charter pushed (POST) on first sync
- [ ] `CharterSyncService`: public charter updated (PUT) after visibility change when `serverID` set
- [ ] `CharterStore.updateVisibility`: sets `needsSync = true`
- [ ] `CharterDiscoveryViewModel`: filters applied correctly to API query params
- [ ] `CharterDiscoveryViewModel`: `hasMore` false after last page
- [ ] `CharterDiscoveryViewModel`: error banner shown on network failure
- [ ] `CharterListViewModel`: deleted charter removed from local array
- [ ] `CharterVisibility.isDiscoverable`: false for past charters regardless of visibility
