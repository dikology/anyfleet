# Digital Logbook — Product Requirements Document

---

## Executive Summary

The Digital Logbook transforms AnyFleet from a charter planning tool into a daily sailing companion. It provides structured passage logging — departures, arrivals, engine events, weather observations, and freeform notes — that every captain needs regardless of experience level. The logbook is private by default, optionally syncable with charter crew, and never publishable to the community library.

**Core value:** A captain opens AnyFleet every time they leave the dock. The logbook is the anchor habit that drives daily engagement independent of community size.

---

## Problem Statement

### Captain Pain Points

1. **Paper logbooks are fragile and unsearchable.** Most captains maintain paper logs because it's legally expected. Paper gets wet, lost, and can't be queried ("when did I last change the impeller?").
2. **Digital alternatives require connectivity.** Existing sailing log apps assume constant internet. Logging happens at sea — often the worst possible time for connectivity.
3. **No single source of truth.** Engine hours are tracked separately from passage logs, which are separate from weather notes. Information is scattered across notebooks, spreadsheets, and messaging apps.
4. **Proving experience is manual.** Charter companies, sailing schools, and crew positions ask for sailing CVs. Captains reconstruct these from memory and scattered records.
5. **Crew has no shared record.** After a charter, crew members have no access to the passage record unless the captain photographs the paper logbook.

### Business Context

- The logbook creates **daily-use utility** that doesn't depend on community size — it works for a solo captain on day one
- Every log entry generates data that later enriches the Profile (`CaptainStats`: nautical miles, days at sea, regions visited — currently placeholder "—" values)
- Crew sync creates organic app adoption: crew members receive log access, discover the app
- Logbook entries attached to charters make Charter Detail significantly more valuable

---

## Design Principles

### 1. Quick Capture, Detailed Later

Logging at sea happens in rough conditions — wet hands, bouncing cockpit, limited attention. The primary interaction must be a **single-tap quick action** that captures the essential data point (timestamp + type + GPS) with zero required fields beyond that. Detail can be added later when conditions allow.

### 2. Charter-Scoped, Standalone-Capable

Log entries belong to a charter when one is active. But captains also do day sails, deliveries, and maintenance runs outside of planned charters. The logbook must work both as a charter sub-feature and as a standalone tool.

### 3. Private by Default, Crew-Syncable by Choice

Log entries are never publishable to the community library or Discover tab. They can optionally be shared with charter crew members (when crew management exists). Sync with crew is the only sharing vector.

### 4. Offline-First, Always

All logging happens locally. Sync (to backend for backup, to crew for sharing) is opportunistic and never blocks the logging flow. The entire log history must be available offline.

---

## User Personas (Logbook-Specific)

### Captain Andrei — Weekend Sailor / Boat Owner

- Sails 2–3 times per month, owns a 36ft monohull
- Currently tracks engine hours in a spreadsheet, passage details in a paper logbook
- Wants to know total engine hours since last oil change, total miles this season
- **Logbook use:** Quick departure/arrival logs, engine start/stop tracking, end-of-season stats

### Captain Maria — Charter Skipper (from Phase 2 persona)

- Runs 3–5 charters per season on different boats
- Needs to hand over a clean log to the charter company at the end
- Crew members ask "how far did we sail today?"
- **Logbook use:** Per-charter passage records, crew-shared log, exportable summary

### Jamie — Charter Crew (from Phase 2 persona)

- Joins 1–2 charters per year as crew
- Wants a record of passages sailed for their own experience tracking
- **Logbook use:** Read-only access to captain's shared log, own stats accumulation

---

## Feature Specification

### 5.1 Log Entry Types

Each log entry has a `type` that determines its icon, default fields, and display treatment.

| Type | Icon | Purpose | Auto-captured |
|------|------|---------|---------------|
| `departure` | `arrow.up.right.circle.fill` | Leaving port/anchorage | timestamp, GPS |
| `arrival` | `arrow.down.left.circle.fill` | Arriving at port/anchorage | timestamp, GPS |
| `engineStart` | `engine.combustion.fill` | Engine turned on | timestamp, engine hours |
| `engineStop` | `engine.combustion` | Engine turned off | timestamp, engine hours, computed run duration |
| `waypoint` | `mappin.circle.fill` | Position log / notable point | timestamp, GPS |
| `weather` | `cloud.sun.fill` | Weather observation | timestamp |
| `note` | `note.text` | Freeform log entry | timestamp |
| `safety` | `exclamationmark.triangle.fill` | Safety event (MOB, equipment failure, etc.) | timestamp, GPS |

### 5.2 Log Entry Data Model

```
LogEntry
├── id: UUID
├── charterID: UUID?              // nil for standalone entries
├── type: LogEntryType            // enum above
├── timestamp: Date               // auto-set, user-adjustable
├── latitude: Double?             // auto-captured from device GPS
├── longitude: Double?
├── locationName: String?         // optional user label ("Hvar Marina", "Vis anchorage")
│
├── title: String?                // optional short description
├── notes: String?                // freeform text
│
├── engineHours: Double?          // for engine events: current engine hour reading
├── engineRunDuration: Double?    // computed: stop.engineHours - start.engineHours (minutes)
│
├── windSpeed: Double?            // knots, for weather entries
├── windDirection: Int?           // degrees (0-359)
├── seaState: SeaState?           // calm, slight, moderate, rough, veryRough
├── visibility: WeatherVisibility? // good, moderate, poor, veryPoor
├── barometricPressure: Double?   // hPa, for weather entries
│
├── distanceFromPrevious: Double? // computed: nm from previous departure/waypoint
│
├── createdAt: Date
├── updatedAt: Date
│
├── serverID: UUID?               // backend sync
├── needsSync: Bool
├── lastSyncedAt: Date?
```

**Enums:**

```
LogEntryType: String, CaseIterable
  departure, arrival, engineStart, engineStop, waypoint, weather, note, safety

SeaState: String, CaseIterable
  calm, slight, moderate, rough, veryRough

WeatherVisibility: String, CaseIterable
  good, moderate, poor, veryPoor
```

### 5.3 Engine Hours Tracker

Engine hour tracking deserves special attention because it's the most common logbook data point and the most error-prone on paper.

**Behavior:**
- When the user taps "Engine Start," the app records the current engine hour reading (user-entered on first use, then auto-incremented from previous stop reading)
- When the user taps "Engine Stop," the app records the stop time, computes the run duration, and updates the running engine hours total
- The Home screen and Charter Detail show the current engine status (running/stopped) and total hours for the active charter
- Engine hours are tracked per-boat (derived from charter's `boatName`). If the captain switches boats between charters, hours reset to the new boat's baseline

**Edge cases:**
- User forgets to log engine stop → next engine start prompts "Engine was last started at [time]. Log engine stop now?" with a timestamp picker
- Engine hours reading can be manually corrected on any entry

### 5.4 Distance Calculation

- Distance between consecutive position-bearing entries (departure, arrival, waypoint) is computed using the Haversine formula on GPS coordinates
- This gives **straight-line distance** between logged points, not actual sailed distance (which would require continuous GPS tracking — out of scope for v1)
- Total charter distance is the sum of all inter-entry distances
- Display always shows "~X nm" with the tilde to signal approximation
- Note: actual track recording (continuous GPS logging at intervals) is a future enhancement that would give precise distance. The logbook's point-to-point calculation is a pragmatic v1 approach

### 5.5 Passage Summary

A passage is the span from a `departure` entry to the next `arrival` entry. The app auto-groups sequential log entries into passages.

**Passage summary card shows:**
- From → To (location names or GPS)
- Duration (departure timestamp → arrival timestamp)
- Approximate distance
- Engine hours used during passage
- Weather conditions logged
- Number of waypoints/notes

---

## User Interface

### 6.1 Access Points

**From Home Screen:**
- When an active charter exists, the active charter hero card gains a **"Log" quick action button** (bottom-right of the card, styled as a compact floating action)
- Below the hero, a new **"Quick Log" row** appears with two primary actions:
  - `departure`/`arrival` toggle (icon changes based on last entry type — if last was departure, show arrival; if last was arrival or no entries, show departure)
  - `engine start`/`engine stop` toggle (same logic — shows opposite of current engine state)
- When no active charter exists but a standalone log entry was recently created, the Home screen shows a **"Recent Log"** summary card instead of / below the create charter card

**From Charter Detail:**
- New section below the check-in checklist section: **"Logbook"**
- Section shows: entry count, total distance, total engine hours, latest entry preview
- **"View Full Log"** link → navigates to `LogbookView` filtered to this charter
- **"Quick Log" row** with departure/arrival + engine start/stop actions (same as Home)
- If no entries yet: empty state with CTA "Start logging your passage"

**From Tab Bar (future consideration):**
- The logbook does not get its own tab in v1. It lives within Home (quick actions) and Charter Detail (full view)
- If adoption is high, a dedicated Logbook tab or a floating quick-log button could be considered

### 6.2 LogbookView (Full Log Screen)

**Navigation:** `AppRoute.logbook(charterID: UUID?)` — if `charterID` is nil, shows all entries across all charters and standalone entries.

**Layout:**

```
NavigationStack
├── Header
│   ├── Charter name (or "All Entries" for standalone)
│   ├── Stats row: total entries · ~X nm · X engine hours
│   └── Filter chips: All | Passages | Engine | Weather | Notes
│
├── Timeline (ScrollView)
│   ├── [Passage group]
│   │   ├── Passage summary card (collapsed by default)
│   │   │   ├── From → To
│   │   │   ├── Duration · Distance · Engine hours
│   │   │   └── Expand chevron
│   │   └── [Expanded: individual entries as timeline nodes]
│   │       ├── ● Departure — Marina Split · 08:30
│   │       ├── ● Engine Start — 1,247.3h · 08:32
│   │       ├── ● Weather — SW 15kt, moderate sea · 10:00
│   │       ├── ● Waypoint — Passed Brač channel · 11:15
│   │       ├── ● Engine Stop — 1,249.1h (1.8h) · 12:00
│   │       └── ● Arrival — Hvar Town · 14:20
│   │
│   ├── [Standalone entries outside passages]
│   │   └── ● Note — Checked anchor chain · 16:00
│   │
│   └── [Next passage group...]
│
└── Floating Action Button
    └── "+" → Entry type picker sheet
```

**Timeline visual treatment:**
- Vertical line connecting entries within a passage
- Entry nodes are colored circles matching the entry type icon color
- Departure/arrival nodes are larger (12pt) than mid-passage nodes (8pt)
- Timestamps are left-aligned in a gutter; content is right of the timeline

### 6.3 Quick Log Actions

**Quick Log Row component** (reused in Home and Charter Detail):

```
HStack
├── QuickLogButton(
│     icon: departure/arrival toggle,
│     label: "Depart" / "Arrive",
│     action: → creates entry with one tap
│   )
├── QuickLogButton(
│     icon: engineStart/engineStop toggle,
│     label: "Engine On" / "Engine Off",
│     action: → creates entry with one tap (engine stop prompts for hours if first use)
│   )
└── QuickLogButton(
      icon: "plus.circle",
      label: "More",
      action: → presents entry type picker sheet
    )
```

**One-tap behavior:**
- Tapping "Depart" or "Arrive" instantly creates a log entry with: type, current timestamp, current GPS position (if authorized), and the active charter's ID
- A brief toast confirmation appears ("Departure logged at 08:30") with an "Edit" link that opens the full entry editor
- No modal, no form — the entry exists immediately and can be enriched later

**Engine hours prompt (first use per boat):**
- On the very first engine event for a charter (or standalone), the app shows a compact inline prompt: "Enter current engine hours reading" with a numeric input
- After the first reading is established, subsequent engine events auto-increment based on elapsed time since last reading, with manual override available

### 6.4 Log Entry Editor

**Navigation:** `AppRoute.logEntryEditor(entryID: UUID?)` — nil for new entry, existing ID for edit.

Presented as a **sheet** (matches Charter Editor pattern). Sections adapt based on entry type:

**All types:**
- Type picker (segmented or horizontal chips — pre-selected if created via quick action)
- Timestamp (date + time picker, defaults to now)
- Location (auto-filled GPS + optional text label with `MKLocationSearchService` autocomplete)
- Title (optional, single line)
- Notes (optional, multiline)

**Engine types additionally:**
- Engine hours reading (numeric, decimal)
- Run duration (display-only on engine stop, computed from paired start)

**Weather type additionally:**
- Wind speed (numeric, knots)
- Wind direction (compass picker or numeric degrees)
- Sea state (segmented: calm / slight / moderate / rough / very rough)
- Visibility (segmented: good / moderate / poor / very poor)
- Barometric pressure (numeric, hPa)

**Safety type additionally:**
- Severity indicator (info / warning / critical)
- Prominent red header to distinguish from routine entries

### 6.5 Home Screen Integration

**Active charter hero card changes:**
- Add a subtle log status strip at the bottom of the hero card:
  - "Underway from [location]" (if last entry is departure)
  - "At [location]" (if last entry is arrival)  
  - "Engine running · 2.3h" (if engine is currently on)
- This strip gives the Home screen a sense of *liveness* — the app knows where you are and what you're doing

**Stats feeding:**
- `CaptainStats.nauticalMiles` — computed from sum of all log entry distances (replaces current "—" placeholder)
- `CaptainStats.daysAtSea` — computed from days with at least one departure entry (replaces current placeholder)
- These appear on Profile immediately, giving the profile substance from the first logged passage

---

## Data Architecture

### 7.1 Local Database

**New table: `log_entries`**

| Column | Type | Notes |
|--------|------|-------|
| `id` | `TEXT` (UUID) | Primary key |
| `charter_id` | `TEXT` (UUID) | Nullable, FK → `charters.id` |
| `type` | `TEXT` | LogEntryType raw value |
| `timestamp` | `REAL` (Date) | User-adjustable event time |
| `latitude` | `REAL` | Nullable |
| `longitude` | `REAL` | Nullable |
| `location_name` | `TEXT` | Nullable |
| `title` | `TEXT` | Nullable |
| `notes` | `TEXT` | Nullable |
| `engine_hours` | `REAL` | Nullable |
| `engine_run_duration` | `REAL` | Nullable, minutes |
| `wind_speed` | `REAL` | Nullable, knots |
| `wind_direction` | `INTEGER` | Nullable, degrees |
| `sea_state` | `TEXT` | Nullable, SeaState raw value |
| `weather_visibility` | `TEXT` | Nullable |
| `barometric_pressure` | `REAL` | Nullable, hPa |
| `distance_from_previous` | `REAL` | Nullable, computed nm |
| `created_at` | `REAL` (Date) | |
| `updated_at` | `REAL` (Date) | |
| `server_id` | `TEXT` (UUID) | Nullable, backend sync |
| `needs_sync` | `INTEGER` (Bool) | Default 0 |
| `last_synced_at` | `REAL` (Date) | Nullable |

**Indexes:**
- `(charter_id, timestamp)` — primary query pattern
- `(type, timestamp)` — for filtering by type
- `(timestamp)` — for standalone chronological view

**Migration:** `v3.0.0_createLogEntries`

### 7.2 Repository Extensions

**`LogEntryRepository` protocol:**

```swift
protocol LogEntryRepository {
    func fetchLogEntries(charterID: UUID?, types: [LogEntryType]?, limit: Int?, offset: Int?) async throws -> [LogEntry]
    func fetchLogEntry(id: UUID) async throws -> LogEntry?
    func saveLogEntry(_ entry: LogEntry) async throws
    func deleteLogEntry(id: UUID) async throws
    func fetchLatestEntry(charterID: UUID?, type: LogEntryType?) async throws -> LogEntry?
    func fetchEngineState(charterID: UUID?) async throws -> EngineState
    func fetchPassageSummaries(charterID: UUID?) async throws -> [PassageSummary]
    func fetchLogStats(charterID: UUID?) async throws -> LogStats
    func fetchPendingSyncEntries() async throws -> [LogEntry]
    func markEntrySynced(id: UUID, serverID: UUID) async throws
}
```

**Computed types:**

```swift
struct EngineState {
    let isRunning: Bool
    let currentHours: Double?
    let runningForMinutes: Double? // if running, time since last engineStart
    let lastEvent: LogEntry?
}

struct PassageSummary {
    let departureEntry: LogEntry
    let arrivalEntry: LogEntry?  // nil if passage ongoing
    let entries: [LogEntry]
    let distanceNm: Double
    let durationMinutes: Double
    let engineMinutes: Double
}

struct LogStats {
    let totalEntries: Int
    let totalDistanceNm: Double
    let totalEngineHours: Double
    let totalPassages: Int
    let daysWithEntries: Int
}
```

### 7.3 Store

**`LogbookStore`** — `@Observable`, `@MainActor`

- Holds in-memory log entries for the current view scope (charter-specific or all)
- Exposes computed `engineState`, `latestEntry`, `passageSummaries`, `stats`
- Quick-log methods: `logDeparture()`, `logArrival()`, `logEngineStart(hours:)`, `logEngineStop(hours:)` — each creates an entry with auto-populated fields and persists immediately
- CRUD: `saveEntry(_:)`, `deleteEntry(id:)`
- Provides `currentPassageStatus` for Home screen status strip

### 7.4 Backend API (Future)

The logbook backend is not required for v1 (local-only). When crew sync is implemented:

**Endpoints:**

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/charters/{id}/log-entries` | Bearer | Create/bulk-create entries |
| GET | `/charters/{id}/log-entries` | Bearer | Fetch entries (charter crew only) |
| PUT | `/charters/{id}/log-entries/{entry_id}` | Bearer | Update entry (captain only) |
| DELETE | `/charters/{id}/log-entries/{entry_id}` | Bearer | Delete entry (captain only) |
| GET | `/charters/{id}/log-summary` | Bearer | Computed passage summaries + stats |
| GET | `/log-entries/stats` | Bearer | Cross-charter stats for profile |

**Access control:**
- Captain (charter owner) has full CRUD
- Crew members have read-only access to shared log entries
- Entries are *never* publicly discoverable — they don't appear in Discover or community feeds

**Sync pattern:** Follows existing `CharterSyncService` model — `needsSync` flag, push pending on connectivity, LWW conflict resolution on `updatedAt`.

---

## Crew Sync (Dependency: Crew Management PRD)

Crew sync for the logbook depends on a crew management feature that is scoped separately. This section describes the logbook's integration points with that future system.

### 8.1 Sharing Model

- Captain enables "Share log with crew" per charter (toggle in charter settings)
- When enabled, log entries sync to the backend and are readable by crew members of that charter
- Crew members see log entries in read-only mode on their charter detail
- Crew members cannot create, edit, or delete log entries (captain authority)

### 8.2 Crew Contributions (Future)

A later iteration could allow crew members to submit log entry *suggestions* (e.g., a crew member logs a weather observation). The captain reviews and approves these before they appear in the official log. This is explicitly out of scope for v1.

---

## Navigation Routes

**New `AppRoute` cases:**

```swift
case logbook(charterID: UUID?)           // full logbook view
case logEntryDetail(LogEntry)            // read-only entry detail
case logEntryEditor(entryID: UUID?)      // create/edit sheet
```

**Integration with existing routes:**

- `charterDetail` → adds logbook section with "View Full Log" → `.logbook(charterID:)`
- Home view → quick log actions don't navigate; they create entries in-place with toast confirmation
- Home view → "Recent Log" card → `.logbook(charterID: nil)` (all entries)

---

## Localization Keys

```
logbook.title = "Logbook"
logbook.emptyState.title = "No Log Entries"
logbook.emptyState.subtitle = "Start logging your passages with the quick actions below"
logbook.stats.entries = "%d entries"
logbook.stats.distance = "~%.1f nm"
logbook.stats.engineHours = "%.1fh engine"
logbook.stats.passages = "%d passages"

logbook.quickAction.depart = "Depart"
logbook.quickAction.arrive = "Arrive"
logbook.quickAction.engineOn = "Engine On"
logbook.quickAction.engineOff = "Engine Off"
logbook.quickAction.more = "More"

logbook.toast.departure = "Departure logged at %@"
logbook.toast.arrival = "Arrival logged at %@"
logbook.toast.engineStart = "Engine started at %@"
logbook.toast.engineStop = "Engine stopped — ran %.1fh"

logbook.entry.type.departure = "Departure"
logbook.entry.type.arrival = "Arrival"
logbook.entry.type.engineStart = "Engine Start"
logbook.entry.type.engineStop = "Engine Stop"
logbook.entry.type.waypoint = "Waypoint"
logbook.entry.type.weather = "Weather"
logbook.entry.type.note = "Note"
logbook.entry.type.safety = "Safety Event"

logbook.passage.from = "From %@"
logbook.passage.to = "to %@"
logbook.passage.ongoing = "Underway"
logbook.passage.duration = "%@ duration"

logbook.engine.prompt.title = "Engine Hours"
logbook.engine.prompt.message = "Enter the current engine hour meter reading"
logbook.engine.running = "Engine running · %@"
logbook.engine.forgotStop.title = "Engine Still Running?"
logbook.engine.forgotStop.message = "Engine was started at %@. Log engine stop?"

logbook.home.underway = "Underway from %@"
logbook.home.atPort = "At %@"

logbook.charterDetail.section.title = "Logbook"
logbook.charterDetail.section.subtitle = "Passage log, engine hours, and observations"
logbook.charterDetail.viewLog = "View Full Log"
logbook.charterDetail.emptyState = "Start logging your passage"

logbook.editor.title.new = "New Log Entry"
logbook.editor.title.edit = "Edit Log Entry"
logbook.editor.section.type = "Entry Type"
logbook.editor.section.time = "Time"
logbook.editor.section.location = "Location"
logbook.editor.section.details = "Details"
logbook.editor.section.engine = "Engine"
logbook.editor.section.weather = "Weather"
logbook.editor.section.notes = "Notes"

logbook.filter.all = "All"
logbook.filter.passages = "Passages"
logbook.filter.engine = "Engine"
logbook.filter.weather = "Weather"
logbook.filter.notes = "Notes"
```

---

## Privacy & Data Policy

- Log entries are **personal data** — they contain GPS positions and timestamps that reveal the user's location history
- Log entries are never included in public Discover feeds
- Log entries are never publishable to the community library
- When crew sync is enabled, entries are visible only to crew members of that specific charter
- If a user deletes their account, all log entries are permanently deleted (not anonymized — logbook data without identity has no community value)
- GPS capture requires standard iOS location permissions. The app should request "When In Use" and explain the benefit: "Location is used to auto-fill your logbook entries with GPS coordinates"
- If location permission is denied, all location fields become manual-entry only — the logbook remains fully functional

---

## Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Log entries per active charter | ≥ 4 | Minimum viable: depart, engine on, engine off, arrive |
| Captains with ≥1 log entry within first week | ≥ 40% of new users who create a charter | Validates that quick-log UX is frictionless |
| Standalone log entries (no charter) | Track count | Measures utility beyond planned charters |
| Engine hours logged | Track count | Validates engine tracking adoption |
| Profile stats populated (miles > 0) | ≥ 60% of captains with ≥3 entries | Validates data pipeline from logbook → profile |
| Session frequency increase | +30% vs pre-logbook | Measures daily habit formation |

---

## Implementation Sequence

```
Phase 1 — Core (local-only, MVP)
  1. LogEntry model + GRDB record + migration
  2. LogEntryRepository + LocalRepository implementation
  3. LogbookStore (observable)
  4. Quick Log actions (departure/arrival, engine start/stop)
  5. Toast confirmation component
  6. Charter Detail — logbook section + quick log row
  7. Home screen — quick log row on active charter card

Phase 2 — Full Logbook View
  8. LogbookView with timeline rendering
  9. PassageSummary computation
  10. Filter chips
  11. LogEntry editor sheet
  12. Weather and safety entry type fields

Phase 3 — Stats & Profile Integration
  13. LogStats computation
  14. CaptainStats population from logbook data (nautical miles, days at sea)
  15. Profile stats bar — live data replaces placeholder dashes
  16. Charter Detail — stats display (distance, engine hours, passages)

Phase 4 — Engine Hours Polish
  17. Per-boat engine hour baseline tracking
  18. "Forgot to stop" prompt on next engine start
  19. Engine status indicator on Home screen

Phase 5 — Crew Sync (requires Crew Management)
  20. Backend log entry endpoints
  21. LogbookSyncService (follows CharterSyncService pattern)
  22. Crew read-only log access
  23. SyncCoordinator integration
```

---

## Open Questions

1. **Continuous GPS track recording** — Should v2 of the logbook support background GPS logging at intervals (e.g., every 5 minutes) to compute actual sailed distance rather than point-to-point? This has significant battery and permission implications (requires "Always" location access) but would dramatically improve distance accuracy and enable route replay.

2. **Export format** — Captains may need to export logs for charter companies or insurance. What format? Options: PDF (human-readable), CSV (data), GPX (route/track). PDF is likely the priority for charter handover.

3. **Multi-boat engine hours** — If a captain charters different boats, engine hours are per-boat. Should the app maintain a persistent engine hours register per unique `boatName`, or is it charter-scoped only? Per-boat tracking is more useful but requires a boat entity (see Boat Management feature).

4. **Photo attachments** — Should log entries support photo attachments (e.g., photo of damage for safety entry, screenshot of weather forecast)? Adds significant storage implications but high value for safety entries.

---

## Dependencies

| Dependency | Status | Impact |
|------------|--------|--------|
| Location permissions (iOS) | Available | Required for auto-GPS. Graceful degradation if denied. |
| `MKLocationSearchService` | Implemented | Reuse for location name autocomplete in log entries |
| Crew Management | Not started (separate PRD) | Required for crew sync; logbook v1 is local-only without it |
| Backend log entry endpoints | Not started | Required for any sync; logbook v1 is local-only without it |
| Boat Management feature | Not started | Would enable per-boat engine hours tracking. Without it, engine hours are charter-scoped. |

---

## Relationship to Existing Features

| Existing Feature | Logbook Integration |
|------------------|---------------------|
| **Home Screen** | Quick log actions on active charter card; passage status strip; stats |
| **Charter Detail** | New logbook section; entry count, distance, engine hours |
| **Charter Model** | `charterID` FK on log entries; log stats as computed charter metadata |
| **Profile / CaptainStats** | Nautical miles and days at sea computed from log data |
| **Check-in Checklist** | Logbook section appears below checklist section in charter detail — complementary, not overlapping |
| **Library** | No integration — logbook is explicitly not publishable content |
| **Discover** | No integration — log entries are never discoverable |
| **SyncCoordinator** | Future: logbook sync added as third sync service alongside content and charter sync |

---

**Document Version:** 1.0
**Last Updated:** March 30, 2026
**Status:** Ready for Design & Implementation Planning
