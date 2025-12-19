# Library Visibility Feature - Visual UX Patterns Reference

## 1. CONTENT ORGANIZATION STRUCTURE

### Proposed Layout
```
┌──────────────────────────────────────┐
│ My Library  [All] [Local] [Public]   │
├──────────────────────────────────────┤
│                                      │
│ 🔒 LOCAL CONTENT (Not Published)    │
│ ──────────────────────────────────── │
│                                      │
│ [Icon] Sailing Pre-Check            │
│ Checklist | Updated 2 days ago      │
│ [🔒 private]     [Publish →]        │
│                                      │
│ [Icon] Storm Preparation Guide      │
│ Practice Guide | Updated 1 day ago  │
│ [🔒 private]     [Publish →]        │
│                                      │
├──────────────────────────────────────┤
│                                      │
│ 🌐 PUBLIC CONTENT (Published)       │
│ ──────────────────────────────────── │
│                                      │
│ [Icon] Racing Tips                  │
│ Practice Guide | Updated 3 days ago │
│ [🌐 public] · 234 views             │
│ by @SailorMaria                     │
│                                      │
│ [Icon] Knot Tying Flashcards       │
│ Flashcard Deck | Updated 5 days ago │
│ [🌐 public] · 89 views              │
│ by @SailorMaria                     │
│                                      │
└──────────────────────────────────────┘
```

---

## 2. PUBLISH FLOW - USER JOURNEY

### Scenario A: User NOT Signed In

```
User sees local content
    ↓
[Publish] button disabled (opacity: 0.5)
    ↓
User taps [Publish]
    ↓
┌─────────────────────────────┐
│ Sign In Required            │
│                             │
│ To publish your content,    │
│ please sign in with Apple   │
│                             │
│ [Sign In with Apple]        │
│ [Maybe Later]               │
└─────────────────────────────┘
    ↓
User signs in
    ↓
┌─────────────────────────────┐
│ Share "Racing Tips"?        │
│                             │
│ Others can see and fork     │
│ this content. You'll be     │
│ credited as the author.     │
│                             │
│ ℹ️ This is permanent.        │
│                             │
│ [Share Publicly] [Cancel]   │
└─────────────────────────────┘
    ↓
Published! Item moves to Public section
```

### Scenario B: User IS Signed In (Direct)

```
User sees local content
    ↓
[Publish] button enabled
    ↓
User taps [Publish]
    ↓
┌─────────────────────────────┐
│ Share "Racing Tips"?        │
│                             │
│ Others can see and fork     │
│ this content. You'll be     │
│ credited as the author.     │
│                             │
│ ℹ️ This is permanent.        │
│                             │
│ [Share Publicly] [Cancel]   │
└─────────────────────────────┘
    ↓
[⏳ Publishing...] → [✓ Published!]
    ↓
Item moves to Public section with badge
```

---

## 3. ROW INTERACTION PATTERNS

### Local (Private) Content Row

```
┌──────────────────────────────────────────┐
│ 📋 Sailing Pre-Check                     │
│ Checklist                                │
│                                          │
│ Complete before every sailing trip       │
│ Updated 2 days ago                       │
│                                          │
├──────────────────────────────────────────┤
│ [🔒 private]                 [Publish →] │
│                                          │
└──────────────────────────────────────────┘

Swipe left reveals: [Pin] [Edit] [Delete]
Tap [Publish]: Shows confirmation modal
```

### Published (Public) Content Row

```
┌──────────────────────────────────────────┐
│ 📖 Racing Tips                           │
│ Practice Guide                           │
│                                          │
│ Advanced techniques for racing boats     │
│ Updated 3 days ago                       │
│                                          │
├──────────────────────────────────────────┤
│ [🌐 public · 234 views] [Unpublish ↓]   │
│ by @SailorMaria                          │
│                                          │
└──────────────────────────────────────────┘

Swipe left reveals: [Pin] [Edit] [Delete]
Tap [Unpublish]: Shows confirmation
```

---

## 4. VISIBILITY BADGE STATES

```
PRIVATE
┌────────────────────┐
│ 🔒 private         │
│ Gray on light gray │
└────────────────────┘

PUBLIC
┌──────────────────────┐
│ 🌐 public · 234 views│
│ Green on light green │
└──────────────────────┘

SYNC STATES:
🔒 private       (local, never published)
⏳ publishing... (pending sync)
🌐 public       (synced, published)
⚠️ sync failed  (error state)
```

---

## 5. DISABLED STATE DESIGN

### What NOT to do
```
❌ CONFUSING:
┌────────────────────┐
│ [Publish]          │ ← Looks tappable
│ (but is greyed)    │
└────────────────────┘
```

### What TO do
```
✅ CLEAR:
┌──────────────────────────────┐
│ [Publish] (opacity: 0.5)     │
│ ℹ️ Sign in to publish         │
└──────────────────────────────┘

OR in-row:

┌────────────────────────────────┐
│ 🔒 Must sign in to publish      │
│                                │
│ [Sign In] ← Clear CTA          │
│ [Maybe Later]                  │
└────────────────────────────────┘
```

---

## 6. SIGN IN MODAL

### Modal A: Sheet (Recommended)
```
┌────────────────────────────────────┐
│ 🔐 Sign In to Publish              │
│                                    │
│ Share your content with the        │
│ sailing community. Sign in to      │
│ get started.                       │
│                                    │
│ ┌──────────────────────────────┐   │
│ │ Sign In with Apple           │   │
│ └──────────────────────────────┘   │
│ ┌──────────────────────────────┐   │
│ │ Continue as Guest            │   │
│ └──────────────────────────────┘   │
└────────────────────────────────────┘
```

### Modal B: Full Screen
```
┌────────────────────────────────────┐
│ ✕                                  │
├────────────────────────────────────┤
│                                    │
│ 📱 Sign In with Apple ID           │
│                                    │
│ Sync across devices & publish to   │
│ community.                         │
│                                    │
│ ┌──────────────────────────────┐   │
│ │ Sign In with Apple           │   │
│ └──────────────────────────────┘   │
│                                    │
│ [Privacy] [Terms]                 │
│                                    │
└────────────────────────────────────┘
```

---

## 7. CONFIRMATION MODAL - ANATOMY

```
┌──────────────────────────────────────────┐
│                                          │
│             🌐 (Large icon)              │
│                                          │
│    Share "Racing Tips"?                  │
│    (Headline weight)                     │
│                                          │
│    Others can see and fork this content. │
│    You'll be credited as the author.     │
│    (Body text)                           │
│                                          │
│    ┌────────────────────────────────┐   │
│    │ ℹ️  This is permanent. Everyone │   │
│    │    will be able to find your    │   │
│    │    content.                     │   │
│    └────────────────────────────────┘   │
│                                          │
│    ┌────────────────────────────────┐   │
│    │ Share Publicly                 │   │
│    │ [⏳ Publishing...] on load      │   │
│    └────────────────────────────────┘   │
│    ┌────────────────────────────────┐   │
│    │ Cancel                         │   │
│    └────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘

Interaction states:
1. [Share Publicly] [Cancel]
2. [⏳ Publishing...] [Cancel] ← Loading
3. [✓ Published!] ← Success (auto-dismiss)
4. Error state with message + [Retry]
```

---

## 8. FILTER PICKER - OPTIONS

```
Option A: Segmented Control (Recommended)
┌───────────────────────────────────┐
│ [ All ] ◉ [ Local ] [ Public ]   │
└───────────────────────────────────┘

Option B: Picker
[All ▼]
Shows menu with:
- All
- Local  
- Public

Option C: Tab Style
[All] [Local] [Public]
      (underline on active)
```

---

## 9. EMPTY STATES

### All Empty
```
┌────────────────────────────────┐
│                                │
│          📚                    │
│    Your Library Awaits         │
│                                │
│ Create checklists, guides,     │
│ and flashcard decks to         │
│ organize your knowledge.       │
│                                │
│ [Create New]                   │
│                                │
└────────────────────────────────┘
```

### Local Empty
```
📚 All Published

You haven't published any
content yet. Create something,
then publish!

[Create New]
```

### Public Empty
```
🌐 No Published Content

You don't have any public
content. Sign in and publish
to get started.

[Sign In]
```

---

## 10. ANIMATION TIMELINE

### Publish Flow (3 seconds)

```
t=0.0s: User taps [Publish]
        Modal appears: scale 0.95 → 1.0 (0.3s)

t=0.3s: User reads content

t=2.0s: User taps [Share Publicly]
        Button transforms: text → spinner (0.2s)

t=2.2s: Network request (0.5-2s)

t=2.7s: Success state
        Checkmark appears (0.2s bounce)
        "✓ Published!"

t=3.0s: Auto-dismiss (0.3s fade-out)
        Return to library
        Item shows 🌐 public badge
```

---

## 11. ACCESSIBILITY LABELS

### VoiceOver
```
"Racing Tips. Practice Guide. Private.
 Updated 2 days ago. Publish button."

"Sailing Pre-Check. Checklist. Published.
 234 views. By SailorMaria. 
 Unpublish button."
```

### Focus Order
1. Filter picker
2. Create button
3. Item 1 → Publish button
4. Item 2 → Publish button
... continue

### Color Contrast
- Badges: 4.5:1+ (WCAG AA)
- Buttons: 4.5:1+ (WCAG AA)
- All text: 4.5:1+ (WCAG AA)

---

## 12. ERROR STATES

### Network Error
```
⚠️ Network error.
   Check your connection and try again.

[Retry] [Cancel]
```

### Validation Error
```
⚠️ Title must be at least 3 characters
   Edit your content and try again.

[Edit] [Cancel]
```

### Sync Failure
```
Item shows: ⚠️ Sync failed

Help text: "Your content is saved locally
           but couldn't be published.
           Check your connection."

[Retry] [Edit]
```

---

## 13. COLOR SPECIFICATIONS

```
Primary Teal:
RGB: 33, 128, 141
Hex: #208087

Success Green:
RGB: 43, 155, 74
Hex: #2b9b4a

Error Red:
RGB: 192, 21, 47
Hex: #c0152f

Gray (Private):
RGB: 102, 102, 102
Hex: #666666

Background:
RGB: 250, 248, 243
Hex: #faf8f3

Surface:
RGB: 255, 255, 253
Hex: #fffffd
```

---

## 14. PHASE 2 EXTENSIONS

These patterns support future features:

### Unlisted State
```
⚠️ unlisted (orange)
"Only people with the link can see this"
```

### Fork Indicator
```
🌐 public · 234 views · 12 forks
```

### Author Attribution
```
by @SailorMaria
(clickable for Phase 2 user profiles)
```

---
