# Expense Tracker & Splitter — Product Requirements Document

---

## Executive Summary

The Expense Tracker adds charter expense management to AnyFleet — logging costs, categorizing them, and splitting them among crew members. It solves a universal charter pain point: every group charter ends with an awkward "who owes whom" conversation, usually resolved through Splitwise, spreadsheets, or a captain's memory.

AnyFleet's version is differentiated by being **charter-aware** (expenses are grouped by charter, not generic), **offline-first** (expenses logged at sea without connectivity), and — most innovatively — capable of **proximity-based sync via Bluetooth** so crew members can share expenses in real-time even without internet, such as in a marina with no Wi-Fi or at sea.

The goal is not to replace Splitwise for everyday life. It's to be the expense tool that's *already open* because you're already using AnyFleet for your charter — and to solve the specific pains that generic splitters don't address (offshore sync, charter categorization, captain-as-default-payer patterns, provisioning vs marina vs fuel breakdowns).

---

## Problem Statement

### Captain Pain Points

1. **The captain pays for everything upfront.** Marina fees, fuel, provisioning — the captain typically fronts costs and tracks them manually. Reconciliation happens at the end of the charter, often incompletely.
2. **No connectivity when expenses happen.** Fuel at a remote marina, provisioning at a fishing village, emergency repair in an anchorage — the moments expenses occur are often the moments with worst connectivity.
3. **Crew members aren't all on the same app.** A charter group of 6 might have 2 who are tech-savvy and 4 who barely use their phones. Any expense system that requires everyone to sign up and install an app before it works will fail.
4. **Charter-specific expense categories.** Generic splitters don't know what "provisioning" or "marina fees" or "fuel" mean. Captains want to see a breakdown by sailing-specific categories.
5. **End-of-charter settlement is awkward.** Calculating who owes whom across 30+ expenses with varying splits is error-prone. Captains need a clear, shareable summary.

### Why Not Just Use Splitwise?

Splitwise is excellent for ongoing shared households and trips with reliable connectivity. AnyFleet's expense tracker occupies a different niche:

| Concern | Splitwise | AnyFleet Expense Tracker |
|---------|-----------|--------------------------|
| Offline logging | Requires sync to add | Full offline-first; entries stored locally |
| Crew on same platform | Required for splitting | Not required — crew can be added by name without app account |
| Charter context | Generic groups | Expenses attached to charters with sailing categories |
| Connectivity at sea | Depends on internet | Bluetooth proximity sync between nearby devices |
| Settlement summary | In-app only | Exportable per-charter summary (share sheet) |
| Already open on the boat | Separate app | Inside the app you're already using for checklists and logbook |

---

## Design Principles

### 1. Captain-Centric, Crew-Friendly

The captain is the primary expense logger. The system is designed around the captain adding expenses and assigning them to crew. Crew members can *also* log expenses (if they have the app), but the captain has final authority to edit or remove any entry.

### 2. Crew Without Accounts

Crew members in the expense tracker are **not required to be AnyFleet users**. A crew member can be:
- An AnyFleet user (linked by profile) — full sync, can view and add expenses in-app
- A name-only entry (e.g., "Tom") — captain manages their balance; settlement shared via text/PDF

This is critical for adoption. A captain shouldn't have to convince all 5 crew members to install an app before they can track expenses.

### 3. Offline-First, Proximity-Enhanced

All expense operations work offline. When multiple crew members have AnyFleet and are physically nearby (same boat, same marina), **Bluetooth Low Energy (BLE) proximity sync** enables real-time expense sharing without internet.

### 4. Charter-Scoped, Season-Summarizable

Expenses belong to a charter. Cross-charter expense comparison ("How much did we spend on fuel in Croatia vs Greece?") is a future analytics feature, not a v1 requirement.

---

## User Personas (Expense-Specific)

### Captain Andrei — The Fronter

- Pays for most things on his credit card during the charter
- Currently tracks expenses in Apple Notes, reconciles with crew via WhatsApp messages at the end
- Often forgets small expenses (ice, water taxi, laundry) and absorbs the cost
- Wants a "just tap and log" experience that doesn't slow down the charter day

### Crew Member Sarah — The Organized One

- The one person on the boat who actually tries to keep track of shared costs
- Often logs expenses on behalf of others ("I'll add it to the spreadsheet")
- Wants to see the running balance so she knows where things stand mid-charter
- Has AnyFleet installed because the captain asked the crew to use it for checklists

### Crew Member Tom — The Reluctant

- Doesn't want another app. Will not install AnyFleet for expense tracking alone
- Pays for things occasionally (a round of drinks, a taxi) and tells the captain
- Needs to receive a settlement summary at the end — WhatsApp message or PDF is fine
- Should be representable in the system without an account

---

## Feature Specification

### 5.1 Expense Data Model

```
Expense
├── id: UUID
├── charterID: UUID                   // always charter-scoped
├── title: String                     // "Fuel at Split marina", "Dinner at Hvar"
├── amount: Decimal                   // always positive
├── currency: String                  // ISO 4217 (EUR, USD, HRK, etc.)
├── category: ExpenseCategory         // enum
├── paidByMemberID: UUID              // reference to CharterCrewMember
├── splitType: SplitType              // equal, custom, shares, none
├── splitAmong: [SplitEntry]          // who is included and their share
├── date: Date                        // when the expense occurred
├── notes: String?                    // optional details
├── receiptImageID: UUID?             // optional photo reference (future)
│
├── createdAt: Date
├── updatedAt: Date
├── createdByUserID: UUID?            // nil if created offline before auth
│
├── syncID: UUID                      // stable ID for cross-device merge
├── needsSync: Bool
├── lastSyncedAt: Date?
├── syncSource: SyncSource            // local, bluetooth, server
```

**Supporting types:**

```
ExpenseCategory: String, CaseIterable
├── fuel                  // ⛽ Fuel & pump-outs
├── marina                // ⚓ Marina & port fees
├── provisioning          // 🛒 Food & drink supplies
├── diningOut             // 🍽️ Restaurants & bars
├── transport             // 🚕 Taxis, buses, ferries
├── activities            // 🤿 Excursions, diving, rentals
├── boatMaintenance       // 🔧 Repairs, spare parts
├── charterFee            // 📋 Charter base cost
├── insurance             // 🛡️ Deposit, insurance
├── communication         // 📡 SIM cards, Wi-Fi
├── other                 // Other

SplitType: String
├── equal                 // split equally among selected members
├── custom                // custom amount per member
├── shares               // proportional shares (e.g., 2:1:1)
├── paidFor               // fully paid for by one person, owed by others equally
├── noSplit               // personal expense tracked for records only

SplitEntry
├── memberID: UUID
├── amount: Decimal?       // for custom splits
├── shares: Int?           // for share-based splits
├── isPayer: Bool          // whether this person paid

SyncSource: String
├── local                 // created on this device
├── bluetooth             // received via BLE proximity sync
├── server                // received from backend
```

### 5.2 Charter Crew Member Model

Crew members in the expense context exist independently of AnyFleet user accounts. This model is shared with the broader Crew Management feature (separate PRD) but the expense tracker needs a minimal version.

```
CharterCrewMember
├── id: UUID
├── charterID: UUID
├── name: String                    // display name ("Tom", "Captain Andrei")
├── userID: UUID?                   // linked AnyFleet user, nil for name-only members
├── role: CrewRole                  // captain, crew (affects default payer logic)
├── color: String                   // assigned color for UI (auto-assigned from palette)
├── isActive: Bool                  // can be deactivated if someone leaves mid-charter
├── createdAt: Date
├── updatedAt: Date
```

**`CrewRole`:** `captain`, `crew`

The captain is auto-added as the first crew member when the expense tracker is initialized for a charter. Additional crew are added by name. If a crew member later creates an AnyFleet account, their `userID` can be linked retroactively.

### 5.3 Balance Computation

Balances are **computed client-side**, not stored. This avoids sync conflicts on derived data.

```
struct MemberBalance {
    let member: CharterCrewMember
    let totalPaid: Decimal          // sum of expenses where member is payer
    let totalOwed: Decimal          // sum of member's share across all expenses
    let netBalance: Decimal         // totalPaid - totalOwed (positive = others owe them)
}

struct Settlement {
    let from: CharterCrewMember     // debtor
    let to: CharterCrewMember       // creditor
    let amount: Decimal
}
```

**Settlement algorithm:** Minimize number of transactions. Standard "simplify debts" approach:
1. Compute net balance per member
2. Sort debtors (negative balance) and creditors (positive balance)
3. Match largest debtor with largest creditor, settle the minimum of their balances
4. Repeat until all balanced

### 5.4 Currency Handling

**v1 approach: single currency per charter.**
- When creating the first expense for a charter, the currency is set and becomes the charter's default
- All subsequent expenses use the same currency
- This avoids exchange rate complexity, which is a deep rabbit hole

**Future:** Multi-currency support with manual exchange rates (captain enters "1 EUR = 7.53 HRK"). No live rate fetching — the app is offline-first.

---

## Bluetooth Proximity Sync

### 6.1 Concept

When crew members with AnyFleet are physically near each other (on the same boat, at the same marina), their devices discover each other via BLE and exchange expense data directly — no internet required. This is the headline differentiator for the expense tracker.

### 6.2 How It Works

**Discovery:**
- Each device running AnyFleet with an active charter advertises a BLE service with a charter-specific identifier (derived from the charter's sync ID)
- Nearby devices scanning for the same charter ID discover each other
- Discovery happens in the foreground only (battery consideration) — no background BLE

**Pairing:**
- First-time connection between two crew members requires a simple confirmation on both devices ("Sync expenses with Sarah's iPhone?")
- After initial pairing for a charter, subsequent syncs happen automatically when in proximity
- Pairing is charter-scoped — it doesn't persist across different charters

**Sync protocol:**
- Each device maintains a vector clock (or last-sync timestamp) per peer
- On connection, devices exchange expense entries created or modified since the last peer sync
- Conflicts resolved by LWW (last-write-wins on `updatedAt`), same as existing charter sync
- Crew member additions are synced — if Sarah adds "Tom" as a crew member, all peers learn about Tom

**Data exchanged via BLE:**
- Expense entries (full model)
- Crew member entries (full model)
- Deletion markers (tombstones for deleted expenses)
- NOT synced: receipt images (too large for BLE; these sync via server only)

### 6.3 UX for Proximity Sync

**Sync status indicator:**
- In the expense tracker header, a small BLE icon shows sync state:
  - Gray dot: "No nearby crew detected"
  - Blue pulsing dot: "Syncing with [N] crew nearby"
  - Green check: "Synced with all nearby crew"
- Tapping the indicator opens a sheet showing connected peers and last sync time

**First-time flow:**
1. Captain opens expense tracker, adds crew members
2. App prompts: "Enable proximity sync? Crew members with AnyFleet nearby can share expenses automatically." → BLE permission request
3. When Sarah opens her AnyFleet on the same charter, both devices detect each other
4. Both see a banner: "Sync expenses with [peer name]?" → confirm
5. From this point, expenses created on either device appear on both within seconds

**Fallback:**
- If BLE is unavailable, disabled, or denied → the expense tracker works purely locally
- When internet is available, expenses sync via the backend (standard server sync)
- If one crew member has internet and others don't, the crew member with internet syncs to server; others sync via BLE from the connected crew member (indirect relay)

### 6.4 Technical Implementation Notes

**iOS framework:** MultipeerConnectivity (built on top of BLE + Wi-Fi) is the pragmatic choice. It handles discovery, session management, and data transfer without low-level BLE programming. It works over BLE when Wi-Fi is unavailable and upgrades to Wi-Fi when both devices are on the same network.

**Service type:** `anyfleet-exp` (max 15 characters, lowercase + hyphens per Bonjour spec)

**Advertised info:** `{ "charterSyncID": "<uuid>", "userName": "<display name>" }`

**Security considerations:**
- Data exchanged only between devices on the same charter (charter sync ID must match)
- Initial pairing requires user confirmation on both devices (no silent sync)
- No sensitive data beyond expense amounts and names is exchanged
- Encrypted via MultipeerConnectivity's built-in encryption (`.required`)

**Battery considerations:**
- Advertising and browsing only while the expense tracker screen is open, or when the app is in the active foreground with an active charter
- Stop advertising when app enters background
- No background BLE processing — this is not a real-time tracking feature

---

## User Interface

### 7.1 Access Points

**From Charter Detail:**
- New section below the Logbook section: **"Expenses"**
- Shows: total spent, your balance summary ("You're owed €45" or "You owe €30"), expense count
- **"View Expenses"** link → `ExpenseTrackerView`
- **"Add Expense"** quick action button

**From Home Screen:**
- Active charter hero card gains a second info line: "€340 total · 12 expenses" (subtle, below the logbook status)
- No dedicated Home screen quick action for expenses in v1 — charter detail is the primary entry point

### 7.2 ExpenseTrackerView (Main Screen)

**Navigation:** `AppRoute.expenseTracker(charterID: UUID)`

```
NavigationStack
├── Header
│   ├── Charter name
│   ├── Total: €1,240 · 23 expenses
│   ├── BLE sync indicator (see 6.3)
│   └── Segment control: Expenses | Balances | Settlement
│
├── [Expenses segment — default]
│   ├── Filter bar: All categories | category chip row
│   ├── Expense list (grouped by date, newest first)
│   │   ├── Date header: "Thursday, July 18"
│   │   │   ├── ExpenseRow: "⛽ Fuel at Split" · €85 · paid by Andrei · split 4 ways
│   │   │   ├── ExpenseRow: "🛒 Provisioning" · €120 · paid by Sarah · split 4 ways
│   │   │   └── ExpenseRow: "🍽️ Dinner at Hvar" · €95 · paid by Andrei · split 3 ways (Tom excluded)
│   │   └── Date header: "Wednesday, July 17"
│   │       └── ...
│   └── Empty state: "No expenses yet. Add your first expense to start tracking."
│
├── [Balances segment]
│   ├── Member balance cards (ordered by net balance)
│   │   ├── MemberBalanceCard: "Andrei" · Paid €650 · Owes €310 · Net: +€340 (others owe him)
│   │   ├── MemberBalanceCard: "Sarah" · Paid €200 · Owes €310 · Net: -€110 (she owes)
│   │   ├── MemberBalanceCard: "Tom" · Paid €50 · Owes €310 · Net: -€260 (he owes)
│   │   └── ...
│   └── Balance bar visualization (horizontal stacked bar showing each member's proportion)
│
├── [Settlement segment]
│   ├── Settlement instructions
│   │   ├── "Tom pays Andrei €260"
│   │   ├── "Sarah pays Andrei €80"
│   │   └── "Sarah pays Tom €30" (if applicable)
│   ├── "Mark as Settled" per transaction (records it, zeroes the debt)
│   └── "Share Summary" button → system share sheet (text or PDF)
│
└── Floating Action Button: "+" → Add Expense sheet
```

### 7.3 Add Expense Sheet

Presented as a **sheet** (consistent with Charter Editor and Log Entry Editor patterns).

```
Sheet: "Add Expense"
├── Amount input (large, centered, numeric keyboard)
│   ├── Currency indicator: "EUR" (tappable to change — v1: charter-wide, so first expense sets it)
│   └── Amount: €___
│
├── Title (single-line text field, required)
│   └── Placeholder: "What was this for?"
│
├── Category picker (horizontal scrollable chips)
│   └── ⛽ Fuel · ⚓ Marina · 🛒 Provisioning · 🍽️ Dining · 🚕 Transport · ...
│
├── Paid by (member selector)
│   └── Horizontal avatar/name chips; captain pre-selected as default
│
├── Split section
│   ├── Split type: Equal (default) | Custom | Shares | No split
│   ├── Member checkboxes (all checked by default for "equal")
│   │   └── If custom: amount input per member
│   │   └── If shares: share count per member (e.g., 2× for captain's cabin)
│   └── Per-member preview: "€21.25 each" or custom amounts
│
├── Date picker (defaults to today)
│
├── Notes (optional, multiline)
│
└── Save button (primary CTA)
```

**Interaction details:**
- Amount input is the first responder on sheet open — keypad appears immediately
- After entering amount and title, the default split (equal among all active crew) is pre-computed
- For common cases (captain pays, split equally), creating an expense is: type amount → type title → tap Save. Three actions.
- "Paid by" defaults to the current user (usually captain). Tapping another member's chip switches the payer

### 7.4 Crew Management (Minimal, Expense-Scoped)

Before expenses can be logged, the charter needs crew members. The expense tracker's crew setup is minimal and independent of the broader Crew Management feature.

**Setup flow (first expense access):**
1. User opens expenses for a charter that has no crew members
2. "Set up crew" screen appears:
   - Current user is pre-added as captain
   - "Add Crew Member" button → text field for name
   - Members appear as avatar-with-initial circles in a horizontal list
   - "Done" → expense tracker opens
3. Crew can be edited later from a "Manage Crew" option in the expense tracker header menu

**Adding a crew member:**
- Minimal: just a name (required) and optional AnyFleet user link
- Color is auto-assigned from a predefined palette (for balance visualization)
- A crew member can be added at any time — they retroactively appear in split options for future expenses

### 7.5 Expense Row Component

```
HStack
├── Category icon (colored circle, 32pt)
├── VStack (left-aligned)
│   ├── Title (Typography.subheader)
│   └── "Paid by [name]" (Typography.caption, textSecondary)
├── Spacer
├── VStack (right-aligned)
│   ├── Amount (Typography.subheader, bold)
│   └── Split info: "÷4" or "÷3 + Tom" (Typography.micro, textSecondary)
```

**Swipe actions:**
- Trailing: Edit (pencil, gray), Delete (trash, red)
- Leading: Duplicate (doc.on.doc, primary) — useful for recurring expenses like daily marina fees

### 7.6 Settlement Summary Export

The settlement screen's "Share Summary" generates a text or PDF summary:

**Text format (for WhatsApp/Messages):**

```
⛵ Charter Expenses Summary
"Croatia Week 2026" · Jul 14–21

Total: €1,240 · 23 expenses

📊 By category:
  ⛽ Fuel: €285 (23%)
  ⚓ Marina: €340 (27%)
  🛒 Provisioning: €280 (23%)
  🍽️ Dining: €195 (16%)
  🚕 Transport: €80 (6%)
  🤿 Activities: €60 (5%)

💰 Settlement:
  → Tom pays Andrei €260
  → Sarah pays Andrei €80

Generated by AnyFleet · anyfleet.app
```

**PDF format (future):** Detailed breakdown with per-expense line items, useful for tax deductions or corporate reporting.

---

## Data Architecture

### 8.1 Local Database

**New table: `charter_crew_members`**

| Column | Type | Notes |
|--------|------|-------|
| `id` | `TEXT` (UUID) | Primary key |
| `charter_id` | `TEXT` (UUID) | FK → `charters.id` |
| `name` | `TEXT` | Display name |
| `user_id` | `TEXT` (UUID) | Nullable, FK to AnyFleet user |
| `role` | `TEXT` | `captain` or `crew` |
| `color` | `TEXT` | Hex color code |
| `is_active` | `INTEGER` (Bool) | Default 1 |
| `created_at` | `REAL` (Date) | |
| `updated_at` | `REAL` (Date) | |

**New table: `expenses`**

| Column | Type | Notes |
|--------|------|-------|
| `id` | `TEXT` (UUID) | Primary key |
| `charter_id` | `TEXT` (UUID) | FK → `charters.id` |
| `title` | `TEXT` | |
| `amount` | `TEXT` | Stored as string for Decimal precision |
| `currency` | `TEXT` | ISO 4217 |
| `category` | `TEXT` | ExpenseCategory raw value |
| `paid_by_member_id` | `TEXT` (UUID) | FK → `charter_crew_members.id` |
| `split_type` | `TEXT` | SplitType raw value |
| `split_data` | `TEXT` (JSON) | Array of SplitEntry |
| `date` | `REAL` (Date) | Expense date |
| `notes` | `TEXT` | Nullable |
| `receipt_image_id` | `TEXT` (UUID) | Nullable, future |
| `created_at` | `REAL` (Date) | |
| `updated_at` | `REAL` (Date) | |
| `created_by_user_id` | `TEXT` (UUID) | Nullable |
| `sync_id` | `TEXT` (UUID) | Stable cross-device merge key |
| `needs_sync` | `INTEGER` (Bool) | Default 0 |
| `last_synced_at` | `REAL` (Date) | Nullable |
| `sync_source` | `TEXT` | SyncSource raw value |
| `is_deleted` | `INTEGER` (Bool) | Soft delete for sync tombstones |

**Indexes:**
- `(charter_id, date)` — primary query pattern
- `(charter_id, category)` — for category filtering
- `(sync_id)` UNIQUE — for cross-device deduplication
- `(charter_id, paid_by_member_id)` — for balance computation

**Migration:** `v3.1.0_createExpenseTracker`

### 8.2 Repository

**`ExpenseRepository` protocol:**

```swift
protocol ExpenseRepository {
    // Crew members
    func fetchCrewMembers(charterID: UUID) async throws -> [CharterCrewMember]
    func saveCrewMember(_ member: CharterCrewMember) async throws
    func deleteCrewMember(id: UUID) async throws

    // Expenses
    func fetchExpenses(charterID: UUID, category: ExpenseCategory?, limit: Int?, offset: Int?) async throws -> [Expense]
    func fetchExpense(id: UUID) async throws -> Expense?
    func saveExpense(_ expense: Expense) async throws
    func deleteExpense(id: UUID) async throws  // soft delete
    func fetchExpenseBySyncID(_ syncID: UUID) async throws -> Expense?

    // Computed
    func fetchCharterTotal(charterID: UUID) async throws -> Decimal
    func fetchCategoryTotals(charterID: UUID) async throws -> [(ExpenseCategory, Decimal)]
    func fetchMemberTotals(charterID: UUID) async throws -> [(UUID, Decimal)]  // memberID → total paid

    // Sync
    func fetchPendingSyncExpenses(charterID: UUID) async throws -> [Expense]
    func fetchExpensesModifiedAfter(_ date: Date, charterID: UUID) async throws -> [Expense]
    func markExpenseSynced(id: UUID) async throws
    func upsertFromSync(_ expense: Expense) async throws  // insert or update by syncID
}
```

### 8.3 Store

**`ExpenseStore`** — `@Observable`, `@MainActor`

- Holds expenses and crew members for the active charter
- Computes `memberBalances`, `settlements`, `categoryBreakdown`, `charterTotal` on-the-fly from in-memory data
- CRUD operations with immediate persistence
- Exposes `addExpenseQuick(title:amount:category:)` for common case (captain pays, equal split among all active crew)

### 8.4 Proximity Sync Service

**`ProximitySyncService`** — manages MultipeerConnectivity sessions.

```swift
@Observable
class ProximitySyncService: NSObject {
    // State
    var connectedPeers: [PeerInfo]          // currently connected crew devices
    var syncStatus: ProximitySyncStatus     // .idle, .searching, .connected(count), .syncing
    var lastSyncTime: Date?

    // Lifecycle
    func startAdvertising(charterSyncID: UUID, userName: String)
    func stopAdvertising()
    func startBrowsing(charterSyncID: UUID)
    func stopBrowsing()

    // Sync
    func sendExpenses(_ expenses: [Expense], toPeer: MCPeerID)
    func sendCrewMembers(_ members: [CharterCrewMember], toPeer: MCPeerID)
    func sendDeletions(_ syncIDs: [UUID], toPeer: MCPeerID)

    // Incoming (delegate-driven → publishes to ExpenseStore)
    var onExpensesReceived: (([Expense]) -> Void)?
    var onCrewMembersReceived: (([CharterCrewMember]) -> Void)?
    var onDeletionsReceived: (([UUID]) -> Void)?
}

struct PeerInfo {
    let peerID: MCPeerID
    let userName: String
    let charterSyncID: UUID
    let lastSyncedAt: Date?
}

enum ProximitySyncStatus {
    case idle
    case searching
    case connected(peerCount: Int)
    case syncing
    case error(String)
}
```

**Sync flow on connection:**
1. Devices connect → exchange `lastSyncedAt` timestamps
2. Each device sends expenses modified after the peer's `lastSyncedAt`
3. Receiving device upserts by `syncID` — if `syncID` exists and incoming `updatedAt` > local `updatedAt`, overwrite; otherwise keep local
4. Both devices update their `lastSyncedAt` for this peer

### 8.5 Backend API (Future)

When server sync is implemented:

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/charters/{id}/expenses` | Bearer | Create expense |
| GET | `/charters/{id}/expenses` | Bearer | Fetch all (charter crew only) |
| PUT | `/charters/{id}/expenses/{expense_id}` | Bearer | Update |
| DELETE | `/charters/{id}/expenses/{expense_id}` | Bearer | Soft delete |
| GET | `/charters/{id}/expenses/summary` | Bearer | Category totals, settlement |
| POST | `/charters/{id}/crew` | Bearer | Add crew member |
| GET | `/charters/{id}/crew` | Bearer | List crew |
| PUT | `/charters/{id}/crew/{member_id}` | Bearer | Update crew member |
| DELETE | `/charters/{id}/crew/{member_id}` | Bearer | Remove crew member |
| POST | `/charters/{id}/expenses/sync` | Bearer | Bulk upsert (for BLE-gathered data) |

**Sync strategy (three-tier):**
1. **Local** — always available, all operations work
2. **Bluetooth** — when crew nearby, real-time peer sync
3. **Server** — when internet available, cloud backup and cross-device sync

Priority: local > Bluetooth > server. Data flows upward: local changes → pushed to BLE peers → pushed to server. Server is the eventually-consistent backup, not the source of truth.

---

## Offline Scenarios

### 9.1 Scenario Matrix

| Scenario | Captain | Crew | Behavior |
|----------|---------|------|----------|
| At sea, no connectivity | Logs expenses locally | Cannot see captain's expenses | BLE sync if crew have app + are nearby |
| Marina with Wi-Fi | Syncs to server | Syncs from server | Full sync via backend |
| Marina, no Wi-Fi, crew on boat | BLE sync between devices | BLE sync between devices | Real-time sharing |
| Crew member without app | Captain manages their balance | Receives PDF/text summary at end | No sync needed |
| One crew member has internet | Syncs to server via that device | Others sync via BLE from that device | Indirect relay pattern |

### 9.2 Conflict Resolution

**Expense conflicts (same `syncID`, different content):**
- LWW on `updatedAt` — most recent edit wins
- If timestamps are identical (rare), device with alphabetically-first user ID wins (deterministic tiebreak)

**Crew member conflicts:**
- Same LWW approach
- If one device deactivates a member and another device adds an expense for them, the expense is kept and the member is reactivated (data preservation over deletion)

**Split conflicts:**
- When an expense is updated on one device and a crew member is added on another, the split doesn't auto-update to include the new member
- The expense editor shows a banner: "New crew member [name] added. Update split?" — requires explicit captain action

---

## Navigation Routes

**New `AppRoute` cases:**

```swift
case expenseTracker(charterID: UUID)           // main expense view
case addExpense(charterID: UUID)               // add expense sheet
case editExpense(expenseID: UUID)              // edit expense sheet
case expenseCrewSetup(charterID: UUID)         // crew setup screen
```

---

## Localization Keys

```
expenses.title = "Expenses"
expenses.total = "Total: %@ · %d expenses"
expenses.emptyState.title = "No Expenses Yet"
expenses.emptyState.subtitle = "Add your first expense to start tracking costs"
expenses.addExpense = "Add Expense"

expenses.category.fuel = "Fuel"
expenses.category.marina = "Marina"
expenses.category.provisioning = "Provisioning"
expenses.category.diningOut = "Dining Out"
expenses.category.transport = "Transport"
expenses.category.activities = "Activities"
expenses.category.boatMaintenance = "Boat Maintenance"
expenses.category.charterFee = "Charter Fee"
expenses.category.insurance = "Insurance"
expenses.category.communication = "Communication"
expenses.category.other = "Other"

expenses.paidBy = "Paid by %@"
expenses.splitEqual = "Split equally"
expenses.splitCustom = "Custom split"
expenses.splitShares = "Split by shares"
expenses.splitNone = "No split"
expenses.perPerson = "%@ each"

expenses.segment.expenses = "Expenses"
expenses.segment.balances = "Balances"
expenses.segment.settlement = "Settlement"

expenses.balance.youAreOwed = "You're owed %@"
expenses.balance.youOwe = "You owe %@"
expenses.balance.settled = "All settled up"
expenses.balance.paid = "Paid %@"
expenses.balance.owes = "Owes %@"
expenses.balance.net = "Net: %@"

expenses.settlement.pays = "%@ pays %@ %@"
expenses.settlement.markSettled = "Mark as Settled"
expenses.settlement.shareSummary = "Share Summary"
expenses.settlement.allSettled = "All Settled Up! 🎉"

expenses.crew.setup.title = "Set Up Crew"
expenses.crew.setup.subtitle = "Add crew members to split expenses"
expenses.crew.addMember = "Add Crew Member"
expenses.crew.manage = "Manage Crew"
expenses.crew.captain = "Captain"
expenses.crew.member = "Crew"
expenses.crew.namePlaceholder = "Name"

expenses.editor.title.new = "Add Expense"
expenses.editor.title.edit = "Edit Expense"
expenses.editor.amount.placeholder = "0.00"
expenses.editor.title.placeholder = "What was this for?"
expenses.editor.section.amount = "Amount"
expenses.editor.section.details = "Details"
expenses.editor.section.paidBy = "Paid By"
expenses.editor.section.split = "Split"
expenses.editor.section.date = "Date"
expenses.editor.section.notes = "Notes"

expenses.sync.noNearby = "No nearby crew"
expenses.sync.searching = "Searching for crew..."
expenses.sync.connected = "Synced with %d crew nearby"
expenses.sync.syncing = "Syncing expenses..."
expenses.sync.enable = "Enable proximity sync?"
expenses.sync.enableSubtitle = "Share expenses automatically with crew members nearby using Bluetooth"
expenses.sync.peerConfirm = "Sync expenses with %@?"

expenses.charterDetail.section.title = "Expenses"
expenses.charterDetail.section.subtitle = "Track costs and split with crew"
expenses.charterDetail.viewExpenses = "View Expenses"
expenses.charterDetail.summary = "%@ total · %d expenses"

expenses.export.title = "Charter Expenses Summary"
expenses.export.byCategory = "By category"
expenses.export.settlement = "Settlement"
expenses.export.generatedBy = "Generated by AnyFleet"
```

---

## Privacy & Permissions

- **Bluetooth:** Required for proximity sync. The app requests Bluetooth permission with benefit framing: "Bluetooth lets you share expenses with nearby crew without internet." If denied, proximity sync is disabled; all other features work normally.
- **Local Network (iOS 14+):** MultipeerConnectivity requires local network permission. Standard iOS prompt, no custom messaging needed.
- **Expense data privacy:** Expense data is personal financial information. It is never published to community feeds or Discover. It is shared only with charter crew members (via BLE or server sync).
- **Account deletion:** All expense data deleted with account. Name-only crew members (non-AnyFleet users) are anonymized in other users' data if the charter owner deletes their account.

---

## Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Expenses per charter | ≥ 8 | Typical charter has ~2 expenses/day over 5-7 days |
| Charters with expenses | ≥ 30% of charters with ≥2 crew members | Validates expense tracker adoption |
| Crew members per charter | ≥ 3 | Validates crew setup friction is low |
| BLE sync sessions | Track count | Measures proximity sync adoption |
| Settlement summaries shared | Track count | Measures end-of-charter utility (organic sharing) |
| Non-AnyFleet crew members added | Track percentage | Measures inclusivity of name-only approach |
| Time to add expense | ≤ 15 seconds | Validates quick-add UX |

---

## Implementation Sequence

```
Phase 1 — Core Expense Tracking (local-only, single device)
  1. CharterCrewMember model + GRDB record + migration
  2. Expense model + GRDB record + migration
  3. ExpenseRepository + LocalRepository implementation
  4. ExpenseStore (observable, balance computation)
  5. Crew setup screen (minimal: add names)
  6. Add Expense sheet
  7. ExpenseTrackerView — expense list segment
  8. Charter Detail — expenses section

Phase 2 — Balances & Settlement
  9. Balance computation engine
  10. Settlement optimization algorithm
  11. ExpenseTrackerView — balances segment
  12. ExpenseTrackerView — settlement segment
  13. Settlement summary text export (share sheet)

Phase 3 — Bluetooth Proximity Sync
  14. ProximitySyncService (MultipeerConnectivity)
  15. BLE discovery + pairing flow
  16. Expense sync protocol (exchange, merge, dedup)
  17. Crew member sync
  18. Sync status indicator in expense tracker header
  19. Conflict resolution handling

Phase 4 — Polish & UX
  20. Category filtering
  21. Expense duplication (swipe action)
  22. Currency handling (charter-wide default)
  23. Home screen expense summary on active charter card
  24. Expense editing with split recalculation

Phase 5 — Server Sync (requires Backend)
  25. Backend expense + crew member endpoints
  26. ExpenseSyncService (follows CharterSyncService pattern)
  27. Three-tier sync coordination (local → BLE → server)
  28. SyncCoordinator integration

Phase 6 — Future Enhancements
  29. Receipt photo capture + storage
  30. PDF export with full line-item breakdown
  31. Multi-currency support with manual exchange rates
  32. Recurring expenses (e.g., daily marina fee template)
  33. Season-level expense analytics across charters
```

---

## Open Questions

1. **Crew management scope boundary** — This PRD includes a minimal crew model (name + optional user link) scoped to expenses. The broader Crew Management feature (invitations, permissions, crew manifest for safety, crew log integration) is a separate PRD. Should crew setup for expenses create the canonical crew list that other features (logbook crew sync, float plan manifest) also reference? Probably yes — but that dependency needs coordination.

2. **Split presets** — Should the app remember common split patterns? E.g., "last charter we always excluded Tom from provisioning because he brought his own food." This is a quality-of-life feature that could wait for v2.

3. **Multiple payers per expense** — v1 assumes one payer per expense. Some situations involve multiple payers ("Sarah and I split the fuel 50/50 at the pump"). This can be modeled as two separate expenses or as a multi-payer extension. Multi-payer adds UI complexity — defer to v2?

4. **Tipping/rounding** — Should the app support rounding up splits ("€21.25 each → round to €22, captain absorbs the remainder")? Nice to have but adds split type complexity.

5. **MultipeerConnectivity vs raw CoreBluetooth** — MultipeerConnectivity is higher-level and handles BLE + Wi-Fi automatically. CoreBluetooth gives more control but requires implementing GATT services manually. MC is the recommended choice for v1 unless testing reveals showstopper limitations (e.g., data payload size constraints for large expense histories).

6. **Expense sharing as growth lever** — The settlement summary text includes "Generated by AnyFleet · anyfleet.app." Should it include a deep link to the charter (for crew members who don't have the app)? This could be a lightweight acquisition channel, but requires the deep linking infrastructure (currently a TODO).

---

## Dependencies

| Dependency | Status | Impact |
|------------|--------|--------|
| MultipeerConnectivity (iOS framework) | Available | Required for BLE proximity sync |
| Bluetooth permission (iOS) | Available | Required for proximity sync; graceful degradation if denied |
| Crew Management (separate PRD) | Not started | Minimal crew model in this PRD; broader crew feature extends it |
| Backend expense endpoints | Not started | Required for server sync; expense tracker v1 is local + BLE only |
| Deep linking | Not started (TODO in AppCoordinator) | Would enable settlement share links |

---

## Relationship to Existing Features

| Existing Feature | Expense Tracker Integration |
|------------------|----------------------------|
| **Charter Detail** | New expenses section; total and balance summary |
| **Charter Model** | `charterID` FK on expenses and crew members |
| **Home Screen** | Expense summary line on active charter hero card |
| **Digital Logbook** | Shared crew member model; logbook entries and expenses both scoped to charter |
| **Library** | No integration — expenses are not publishable content |
| **Discover** | No integration — expenses are never discoverable |
| **Profile** | Future: "Total charter value managed" stat (vanity metric for captain profile) |
| **SyncCoordinator** | Future: expense sync added as fourth service alongside content, charter, and logbook sync |
| **Crew Management (future)** | Expense crew model is the seed; broader crew feature extends it with invitations, permissions, manifest |

---

**Document Version:** 1.0
**Last Updated:** March 30, 2026
**Status:** Ready for Design & Implementation Planning
