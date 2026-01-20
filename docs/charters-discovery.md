# Charters Discovery Feature: Phased Implementation Plan

## Executive Summary

This document outlines the phased implementation plan for transforming the Charters tab from a personal-only planning tool into a community discovery platform. The implementation focuses initially on **discoverability** and **map view**, deferring join requests for future phases.

**Priority:** Phase 3.1 of AnyFleet Vision Roadmap  
**Scope:** iOS app + Backend API  
**Timeline:** 3 phases with incremental delivery

---

## Current State Analysis

### iOS App (anyfleet)
- **Local-only charter planning** with `CharterModel` and `CharterStore`
- **Offline-first architecture** using GRDB local database
- **Existing models:**
  - `CharterModel`: id, name, boatName, location, startDate, endDate, checkInChecklistID
  - `CharterStore`: In-memory cache with repository pattern
  - `CharterListView`: Personal charter list with create/edit/delete
- **No sync infrastructure** for charters (exists for content)

### Backend (anyfleet-backend)
- **Python/FastAPI** with PostgreSQL + SQLAlchemy
- **Existing models:** User, SharedContent, RefreshToken
- **No Charter model** - needs to be created
- **Content sync pattern** can be adapted for charters
- **Alembic migrations** for schema management

### Gap Analysis
| Capability | Current State | Required for Discovery |
|------------|---------------|------------------------|
| Charter backend model | ❌ Missing | ✅ Required |
| Charter sync service | ❌ Missing | ✅ Required |
| Visibility controls | ❌ Missing | ✅ Required |
| Location geocoding | ❌ Missing | ✅ Required |
| Map view UI | ❌ Missing | ✅ Required |
| Discovery filters | ❌ Missing | ✅ Required |

---

## Phase 1: Backend Foundation & Basic Sync

**Goal:** Enable charters to be stored in backend with visibility controls and basic sync.

### 1.1 Backend: Charter Data Model

**Files to create:**
- `app/models/charter.py`
- `app/schemas/charter.py`
- `alembic/versions/2026_01_21_1200-add_charters.py`

**Charter Model Schema:**
```python
class Charter(Base):
    __tablename__ = "charters"
    
    # Identity
    id: UUID (primary key)
    user_id: UUID (foreign key to users)
    
    # Charter details
    name: str (max 200)
    boat_name: str | None
    location_text: str | None  # User-entered location
    start_date: datetime
    end_date: datetime
    
    # Geolocation (Phase 1b)
    latitude: float | None
    longitude: float | None
    location_place_id: str | None  # External geocoding reference
    
    # Visibility & Discovery
    visibility: str = "private"  # private, community, public
    
    # Metadata
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None  # Soft delete
    
    # Relationships
    user: relationship(User)
```

**Visibility Levels:**
- `private`: Only visible to owner (default)
- `community`: Visible to community members (Phase 2)
- `public`: Visible to all users

**Migration Strategy:**
- Create charter table with indices on `user_id`, `visibility`, `start_date`
- Add GiST index on location (lat/lon) for geo queries
- Add check constraint for date logic (end_date >= start_date)

### 1.2 Backend: Charter API Endpoints

**Files to create:**
- `app/api/v1/charters.py`
- `app/repositories/charter.py`
- `app/services/charter_service.py`

**Endpoints:**

```python
# CRUD for user's own charters
POST   /api/v1/charters                 # Create charter
GET    /api/v1/charters                 # List user's charters
GET    /api/v1/charters/{charter_id}    # Get charter detail
PUT    /api/v1/charters/{charter_id}    # Update charter
DELETE /api/v1/charters/{charter_id}    # Delete charter

# Discovery (Phase 1c)
GET    /api/v1/charters/discover         # Discover public charters with filters
```

**Request/Response Schemas:**
```python
class CharterCreate(BaseModel):
    name: str
    boat_name: str | None
    location_text: str | None
    start_date: datetime
    end_date: datetime
    visibility: str = "private"

class CharterResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    boat_name: str | None
    location_text: str | None
    start_date: datetime
    end_date: datetime
    latitude: float | None
    longitude: float | None
    visibility: str
    created_at: datetime
    updated_at: datetime
    
    # Embedded user info for discovery
    user: UserBasicInfo

class UserBasicInfo(BaseModel):
    id: UUID
    username: str | None
    profile_image_thumbnail_url: str | None
```

### 1.3 iOS: Charter Sync Service

**Files to create:**
- `anyfleet/Services/CharterSyncService.swift`

**Files to modify:**
- `anyfleet/Core/Models/CharterModel.swift` - Add sync fields
- `anyfleet/Data/Local/Records/CharterRecord.swift` - Add sync columns
- `anyfleet/Core/Stores/CharterStore.swift` - Integrate sync service

**CharterModel additions:**
```swift
struct CharterModel {
    // ... existing fields ...
    
    // Sync fields
    var serverID: UUID?  // Backend charter ID
    var visibility: CharterVisibility = .private
    var needsSync: Bool = false
    var lastSyncedAt: Date?
}

enum CharterVisibility: String, Codable {
    case private
    case community
    case public
}
```

**CharterSyncService responsibilities:**
- Push local charters to backend when created/updated
- Pull remote charters when visibility != private
- Handle conflict resolution (last-write-wins)
- Queue operations for offline resilience
- Mirror `ContentSyncService` patterns

**Sync Strategy:**
1. **Manual trigger initially** - Sync button in settings
2. **Automatic background sync** - On app launch and foreground
3. **Conflict resolution** - Server timestamp wins, notify user if local changes lost

### 1.4 iOS: Visibility Settings UI

**Files to modify:**
- `anyfleet/Features/Charter/CharterEditorView.swift`
- `anyfleet/Features/Charter/CharterEditorViewModel.swift`

**UI Changes:**
- Add "Charter Visibility" picker in charter editor
- Options: Private (default), Public
- Help text: "Public charters are visible to other sailors planning similar trips"
- Privacy reassurance: "You can change this anytime in charter settings"

**Settings Screen** (new):
- `anyfleet/Features/Settings/CharterSettingsView.swift`
- Default visibility for new charters
- Sync status indicator
- Manual sync trigger button

### 1.5 Testing & Validation

**Backend Tests:**
- Unit tests for charter repository CRUD
- API endpoint tests with auth
- Visibility filtering tests
- Date validation tests

**iOS Tests:**
- Charter sync service unit tests
- Offline queue tests
- Conflict resolution tests
- UI tests for visibility picker

**Deliverables:**
- ✅ Charters stored in backend
- ✅ Basic sync working (manual trigger)
- ✅ Visibility controls in UI
- ✅ User can set charters to public/private

---

## Phase 2: Location Intelligence & Geocoding

**Goal:** Add location autocomplete, geocoding, and map-based charter display.

### 2.1 Backend: Location Geocoding Service

**Files to create:**
- `app/services/geocoding_service.py`
- `app/api/v1/locations.py`

**Geocoding Strategy:**

**Option A: Mapbox Geocoding API** (Recommended)
- Free tier: 100,000 requests/month
- Excellent for sailing destinations (coastal accuracy)
- Returns coordinates, place hierarchy, bounding boxes
- `pip install mapbox`

**Option B: Google Places API**
- More comprehensive data
- Higher cost (after free tier)
- Better for landmark recognition

**Endpoints:**
```python
GET /api/v1/locations/autocomplete?query={text}
  # Returns: list of suggested locations with coordinates

GET /api/v1/locations/geocode?place_id={id}
  # Returns: full location details
```

**Response Schema:**
```python
class LocationSuggestion(BaseModel):
    place_id: str
    name: str
    full_name: str  # "Santorini, Cyclades, Greece"
    latitude: float
    longitude: float
    place_type: str  # "harbor", "island", "city", "region"
```

**Caching Strategy:**
- Cache popular locations in Redis (or PostgreSQL jsonb column)
- Pre-seed with top 500 sailing destinations
- Cache TTL: 30 days

### 2.2 Backend: Discovery Endpoint with Geo Filters

**Modify:** `app/api/v1/charters.py`

**Discovery Query Parameters:**
```python
GET /api/v1/charters/discover?
    date_from={date}          # Filter by start date range
    &date_to={date}
    &near_lat={lat}           # Geo proximity filter
    &near_lon={lon}
    &radius_km={km}           # Default 50km
    &limit={int}              # Pagination limit
    &offset={int}
```

**SQL Query Pattern:**
```sql
SELECT c.*, u.username, u.profile_image_thumbnail_url
FROM charters c
JOIN users u ON c.user_id = u.id
WHERE c.visibility = 'public'
  AND c.deleted_at IS NULL
  AND c.start_date >= :date_from
  AND c.start_date <= :date_to
  AND ST_DWithin(
    ST_MakePoint(c.longitude, c.latitude)::geography,
    ST_MakePoint(:near_lon, :near_lat)::geography,
    :radius_meters
  )
ORDER BY c.start_date ASC
LIMIT :limit OFFSET :offset
```

**Performance Optimization:**
- PostGIS extension for geo queries
- GiST index on geography(location)
- Composite index on (visibility, start_date)

### 2.3 iOS: Location Autocomplete UI

**Files to create:**
- `anyfleet/Features/Charter/LocationSearchView.swift`
- `anyfleet/Features/Charter/LocationSearchViewModel.swift`
- `anyfleet/Services/LocationService.swift`

**UI Pattern:**
- Text field with real-time autocomplete dropdown
- Debounced API calls (300ms delay)
- Show 5-10 suggestions below field
- Map thumbnail preview on selection
- "Use Current Location" button (if permission granted)

**LocationSearchView Components:**
```swift
struct LocationSearchView: View {
    @State private var searchText: String = ""
    @State private var suggestions: [LocationSuggestion] = []
    @Binding var selectedLocation: LocationData?
    
    var body: some View {
        VStack {
            TextField("Search destination", text: $searchText)
                .onChange(of: searchText) { 
                    Task { await searchLocations() }
                }
            
            if !suggestions.isEmpty {
                suggestionsList
            }
            
            if let location = selectedLocation {
                MapPreview(location: location)
            }
        }
    }
}
```

**Caching:**
- Cache recent searches locally (UserDefaults or CoreData)
- Cache popular destinations on first launch
- Offline fallback to cached data

### 2.4 iOS: Charter Detail Map View

**Files to modify:**
- `anyfleet/Features/Charter/CharterDetailView.swift`

**UI Additions:**
- Map showing charter destination pin
- Tap to expand full-screen map
- Show nearby charters on map (Phase 3)

**Map Integration:**
- Use SwiftUI MapKit
- Custom annotation with boat icon
- Show route if multi-day (future enhancement)

### 2.5 Testing & Validation

**Backend Tests:**
- Geocoding service tests with mocked API
- Geo query tests with sample data
- Performance tests for discovery queries

**iOS Tests:**
- Location search debouncing tests
- Offline autocomplete fallback tests
- Map rendering tests

**Deliverables:**
- ✅ Location autocomplete working
- ✅ Charters geocoded and stored with coordinates
- ✅ Discovery endpoint returns geo-filtered results
- ✅ Charter detail shows destination on map

---

## Phase 3: Discovery Feed & Map View

**Goal:** Full discovery experience with feed, filters, and interactive map.

### 3.1 iOS: Discovery Tab Integration

**Design Decision:** 
- **Option A:** Add "Charters" filter to existing Discover tab (Recommended)
- **Option B:** New "Discover Charters" section in Charters tab
- **Option C:** Separate "Explore" tab for charter discovery

**Recommendation: Option A** - Leverages existing discovery patterns, unified experience.

**Files to modify:**
- `anyfleet/Features/Discover/DiscoverView.swift`
- `anyfleet/Features/Discover/DiscoverViewModel.swift`

**UI Changes:**
- Add "Charters" content type to filter tabs
- New `CharterDiscoveryRow` component
- Filter panel with date range, location, distance

**CharterDiscoveryRow Design:**
```swift
struct CharterDiscoveryRow: View {
    let charter: DiscoverableCharter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Captain info
            HStack {
                AsyncImage(url: charter.user.profileImageURL)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(charter.user.username ?? "Captain")
                        .font(.subheadline.weight(.medium))
                    Text(charter.destination)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Distance indicator
                if let distance = charter.distanceKm {
                    Text("\(Int(distance))km away")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Charter details
            VStack(alignment: .leading, spacing: 4) {
                Text(charter.name)
                    .font(.headline)
                
                HStack {
                    Label(charter.dateRange, systemImage: "calendar")
                    if let boat = charter.boatName {
                        Label(boat, systemImage: "sailboat")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Map preview thumbnail
            if charter.hasLocation {
                MapPreviewThumbnail(
                    coordinate: charter.coordinate,
                    height: 120
                )
            }
        }
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(12)
    }
}
```

### 3.2 iOS: Discovery Filter Panel

**Files to create:**
- `anyfleet/Features/Discover/CharterFilterView.swift`

**Filters:**
1. **Date Range**
   - Presets: Upcoming, This Week, This Month, Custom Range
   - Date picker for custom range

2. **Location & Distance**
   - "Near Me" toggle (requires location permission)
   - Distance slider: 10km, 50km, 100km, 500km, Any
   - Custom location search

3. **Sort By**
   - Date (earliest first)
   - Distance (closest first)
   - Recently posted

**UI Pattern:**
- Bottom sheet modal
- Filter chips showing active filters
- Clear all button
- Apply/Cancel buttons

### 3.3 iOS: Map View Mode

**Files to create:**
- `anyfleet/Features/Charter/CharterMapView.swift`
- `anyfleet/Features/Charter/CharterMapViewModel.swift`

**Design:**
- **Toggle:** Segmented control: [List | Map]
- **Map:** Full-screen interactive map with charter pins
- **Pin annotation:** Custom boat icon, color-coded by date proximity
- **Callout:** Tappable pin shows charter card preview
- **Clustering:** Group nearby charters when zoomed out

**MapAnnotation Customization:**
```swift
struct CharterMapAnnotation: View {
    let charter: DiscoverableCharter
    
    var pinColor: Color {
        switch charter.daysUntilStart {
        case ..<0: return .gray  // Past
        case 0...7: return .red  // This week
        case 8...30: return .orange  // This month
        default: return .blue  // Future
        }
    }
    
    var body: some View {
        Image(systemName: "sailboat.fill")
            .foregroundColor(pinColor)
            .background(Circle().fill(.white))
            .frame(width: 32, height: 32)
    }
}
```

**Clustering Strategy:**
- Use MapKit's `MKClusterAnnotation`
- Show count badge on cluster
- Zoom to expand cluster on tap

### 3.4 iOS: Charter Detail Modal (Discovery Context)

**Files to create:**
- `anyfleet/Features/Charter/DiscoveredCharterDetailView.swift`

**UI Components:**
- Captain profile section with avatar, username, bio preview
- Charter details: name, dates, boat, destination
- Full-screen map with destination pin
- "View Captain Profile" button
- **[Phase 4]** "Request to Join" button (deferred)

**Privacy Considerations:**
- Don't expose captain's exact location (only destination)
- Show limited profile info unless connected

### 3.5 Backend: Discovery Analytics

**Files to create:**
- `app/models/charter_view.py`
- Track charter views for future recommendations

**Schema:**
```python
class CharterView(Base):
    __tablename__ = "charter_views"
    
    id: UUID
    charter_id: UUID
    viewer_user_id: UUID
    viewed_at: datetime
    view_duration_seconds: int | None
```

**Use Cases:**
- Popular charter tracking
- Recommendation engine (Phase 4)
- Captain analytics dashboard (Phase 4)

### 3.6 Testing & Validation

**Backend Tests:**
- Discovery endpoint with complex filters
- Geo query performance tests
- Pagination tests

**iOS Tests:**
- Filter combination tests
- Map view rendering tests
- Annotation clustering tests
- UI responsiveness tests

**Deliverables:**
- ✅ Discovery feed showing public charters
- ✅ Filter panel with date, location, distance
- ✅ Map view with charter pins
- ✅ Charter detail modal from discovery context
- ✅ View tracking analytics

---

## Design & UX Best Practices

### Visual Design Principles

1. **Consistent Card Pattern**
   - Use existing `DesignSystem.Colors.cardBackground`
   - 12pt corner radius
   - Subtle shadow for depth
   - Match content card styling

2. **Information Hierarchy**
   - Captain identity first (avatar + name)
   - Charter name prominent (headline font)
   - Metadata secondary (calendar, boat icons)
   - Map thumbnail last (visual interest)

3. **Color Semantics**
   - Blue: Future charters
   - Orange: Upcoming (this month)
   - Red: Imminent (this week)
   - Gray: Past charters

4. **Accessibility**
   - Minimum 48×48pt touch targets
   - 4.5:1 contrast ratio for all text
   - VoiceOver labels for all interactive elements
   - Dynamic type support

### UX Patterns

1. **Progressive Disclosure**
   - Show summary in feed
   - Expand details on tap
   - Full map on second tap
   - Don't overwhelm with info upfront

2. **Offline Graceful Degradation**
   - Cache last discovery results
   - Show "Offline" indicator
   - Queue filter changes for next sync
   - Allow viewing cached charters

3. **Empty States**
   - No charters nearby: "Expand your search radius"
   - No charters in date range: "Try a different timeframe"
   - No results with filters: "Clear filters to see all"

4. **Loading States**
   - Skeleton screens for charter cards
   - Spinner on map during load
   - Partial results shown immediately

5. **Error Handling**
   - Location permission denied: "Enable location to discover nearby"
   - Network error: "Can't load charters. Tap to retry"
   - Invalid filters: Clear messaging with reset option

### Privacy & Trust

1. **Transparency**
   - Clear visibility indicators on charter cards
   - "Who can see this?" help text
   - Privacy settings easily accessible

2. **Control**
   - Easy visibility toggle
   - Ability to hide/unhide anytime
   - Delete charter removes from discovery immediately

3. **Safety**
   - No exact user location exposed
   - Only destination shown on map
   - Captain profile limited to public info

---

## Architecture Recommendations

### Backend Refactoring Suggestions

**1. Repository Pattern Consistency**
Current: `ContentRepository`, `UserRepository`  
Enhance: Create `CharterRepository` following same patterns

```python
# app/repositories/charter.py
class CharterRepository(BaseRepository[Charter]):
    async def find_discoverable(
        self,
        date_from: datetime,
        date_to: datetime,
        near_lat: float | None,
        near_lon: float | None,
        radius_km: float,
        limit: int,
        offset: int
    ) -> list[Charter]:
        # Complex geo query here
        pass
```

**2. Service Layer Enhancement**
Add business logic separation:

```python
# app/services/charter_service.py
class CharterService:
    def __init__(self, repository: CharterRepository):
        self.repository = repository
    
    async def create_charter(self, user_id: UUID, data: CharterCreate) -> Charter:
        # Validation, geocoding, creation
        pass
    
    async def discover_charters(
        self, 
        filters: CharterDiscoveryFilters,
        current_user: User
    ) -> Page[CharterWithUserInfo]:
        # Discovery logic with user context
        pass
```

**3. Geocoding Abstraction**
Create interface for swappable geocoding providers:

```python
# app/services/geocoding/base.py
class GeocodingProvider(ABC):
    @abstractmethod
    async def autocomplete(self, query: str) -> list[LocationSuggestion]:
        pass
    
    @abstractmethod
    async def geocode(self, place_id: str) -> LocationDetails:
        pass

# app/services/geocoding/mapbox.py
class MapboxGeocodingProvider(GeocodingProvider):
    # Implementation
    pass
```

**4. Database Optimization**

```sql
-- Add PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Geography column for accurate distance calculations
ALTER TABLE charters 
ADD COLUMN location geography(POINT, 4326);

-- Spatial index
CREATE INDEX idx_charters_location 
ON charters USING GIST(location);

-- Composite index for discovery queries
CREATE INDEX idx_charters_discovery 
ON charters(visibility, start_date) 
WHERE deleted_at IS NULL;
```

### iOS Refactoring Suggestions

**1. Sync Service Protocol**
Create reusable sync protocol for charters and content:

```swift
// anyfleet/Services/Protocols/SyncableService.swift
protocol SyncableService {
    associatedtype Model
    
    func push(item: Model) async throws
    func pull() async throws -> [Model]
    func sync() async throws
    func queueForSync(_ item: Model)
}
```

**2. Location Service Abstraction**

```swift
// anyfleet/Services/LocationService.swift
protocol LocationService {
    func autocomplete(query: String) async throws -> [LocationSuggestion]
    func geocode(placeID: String) async throws -> LocationDetails
    func reverseGeocode(lat: Double, lon: Double) async throws -> LocationDetails
}

class MapboxLocationService: LocationService {
    // Implementation
}
```

**3. Charter Model Enhancement**
Add computed properties for discovery:

```swift
extension CharterModel {
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    var isDiscoverable: Bool {
        visibility != .private && isUpcoming
    }
    
    var daysUntilStart: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }
    
    var urgencyLevel: UrgencyLevel {
        switch daysUntilStart {
        case ..<0: return .past
        case 0...7: return .imminent
        case 8...30: return .soon
        default: return .future
        }
    }
}
```

**4. View Architecture**
Separate discovery and personal charter concerns:

```
Features/
  Charter/
    Personal/              # Existing charter management
      CharterListView
      CharterEditorView
      CharterDetailView
    
    Discovery/             # New discovery features
      CharterDiscoveryView
      CharterMapView
      DiscoveredCharterDetailView
      CharterFilterView
```

---

## Migration Strategy

### Data Migration

**Backend:**
1. Run migration to create charter tables
2. No data to migrate (new feature)
3. Pre-seed popular sailing destinations

**iOS:**
1. Add sync columns to local database via migration
2. Existing local charters remain local-only until user changes visibility
3. No forced sync - opt-in via settings

### Rollout Strategy

**Phase 1: Internal Beta**
- Deploy to TestFlight with limited users
- Test sync reliability
- Gather feedback on privacy controls

**Phase 2: Soft Launch**
- Release to all users with feature flag
- Default visibility: Private
- In-app education about discovery feature

**Phase 3: Full Launch**
- Enable discovery by default
- Marketing push
- Monitor analytics

---

## Success Metrics

### Technical Metrics
- Sync success rate > 99%
- Discovery API response time < 500ms
- Geo query performance < 200ms
- Crash-free rate > 99.5%

### Product Metrics
- % users who set charters to public
- Discovery feed engagement rate
- Map view usage vs list view
- Time spent on discovery feed
- Charter detail views per session

### Business Metrics
- User retention improvement
- Session duration increase
- Feature adoption rate (% users creating public charters)
- Community growth (connections made)

---

## Open Questions & Future Considerations

### Deferred to Phase 4 (Join Requests)
- Join request UI/UX flow
- Crew manifest management
- Notification system for requests
- Approval/rejection workflows

### Future Enhancements
- **Community filtering:** Filter charters by community membership
- **Skill level tagging:** Add skill requirements to charters
- **Multi-day routes:** Show sailing route on map, not just destination
- **Weather integration:** Display forecast for charter dates
- **Social features:** Comments, favorites, sharing
- **Recommendations:** ML-based charter suggestions
- **Crew profiles:** Detailed crew member profiles
- **Charter templates:** Reusable charter configurations
- **Export:** iCal export for charter dates

### Technical Debt Considerations
- Eventual consistency challenges with offline-first
- Conflict resolution UX improvements
- Real-time updates (WebSocket for live charter changes)
- Background sync optimization
- Cache invalidation strategies

---

## Implementation Timeline

### Phase 1: Backend Foundation (2-3 weeks)
- Week 1: Data models, migrations, repository layer
- Week 2: API endpoints, basic CRUD, visibility controls
- Week 3: iOS sync service, testing, integration

### Phase 2: Location Intelligence (2-3 weeks)
- Week 1: Geocoding service, location endpoints
- Week 2: iOS location autocomplete, map integration
- Week 3: Discovery endpoint with geo filters, testing

### Phase 3: Discovery Feed & Map (3-4 weeks)
- Week 1: Discovery UI integration, filter panel
- Week 2: Map view implementation, clustering
- Week 3: Charter detail modal, polish
- Week 4: Testing, analytics, refinement

**Total: 7-10 weeks**

---

## Appendix

### A. API Examples

**Create Charter:**
```http
POST /api/v1/charters
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Greek Islands Adventure",
  "boat_name": "Sea Spirit",
  "location_text": "Santorini, Greece",
  "start_date": "2026-06-15T09:00:00Z",
  "end_date": "2026-06-22T18:00:00Z",
  "visibility": "public"
}
```

**Discover Charters:**
```http
GET /api/v1/charters/discover?date_from=2026-06-01&date_to=2026-08-31&near_lat=36.3932&near_lon=25.4615&radius_km=100&limit=20&offset=0
Authorization: Bearer {token}

Response:
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "Greek Islands Adventure",
      "boat_name": "Sea Spirit",
      "location_text": "Santorini, Greece",
      "latitude": 36.3932,
      "longitude": 25.4615,
      "start_date": "2026-06-15T09:00:00Z",
      "end_date": "2026-06-22T18:00:00Z",
      "visibility": "public",
      "user": {
        "id": "456e7890-e89b-12d3-a456-426614174001",
        "username": "captain_alex",
        "profile_image_thumbnail_url": "https://..."
      },
      "distance_km": 12.5
    }
  ],
  "total": 47,
  "limit": 20,
  "offset": 0
}
```

### B. Database Schema

```sql
CREATE TABLE charters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    boat_name VARCHAR(200),
    location_text VARCHAR(500),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    location geography(POINT, 4326),
    location_place_id VARCHAR(255),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    visibility VARCHAR(20) NOT NULL DEFAULT 'private',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT charters_date_order CHECK (end_date >= start_date),
    CONSTRAINT charters_visibility_check CHECK (visibility IN ('private', 'community', 'public'))
);

CREATE INDEX idx_charters_user_id ON charters(user_id);
CREATE INDEX idx_charters_visibility ON charters(visibility) WHERE deleted_at IS NULL;
CREATE INDEX idx_charters_start_date ON charters(start_date);
CREATE INDEX idx_charters_location ON charters USING GIST(location);
CREATE INDEX idx_charters_discovery ON charters(visibility, start_date) 
  WHERE deleted_at IS NULL AND visibility != 'private';
```

### C. Swift Data Models

```swift
// Enhanced CharterModel
struct CharterModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var boatName: String?
    var location: String?
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var checkInChecklistID: UUID?
    
    // Sync fields
    var serverID: UUID?
    var visibility: CharterVisibility = .private
    var needsSync: Bool = false
    var lastSyncedAt: Date?
    
    // Geolocation
    var latitude: Double?
    var longitude: Double?
    var locationPlaceID: String?
}

// Discovery model (from API)
struct DiscoverableCharter: Identifiable, Hashable {
    let id: UUID
    let name: String
    let boatName: String?
    let destination: String
    let startDate: Date
    let endDate: Date
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let user: CaptainBasicInfo
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct CaptainBasicInfo: Hashable {
    let id: UUID
    let username: String?
    let profileImageURL: URL?
}
```

---

**Document Version:** 1.0  
**Last Updated:** January 20, 2026  
**Status:** Ready for Implementation  
**Next Steps:** Begin Phase 1 backend implementation
