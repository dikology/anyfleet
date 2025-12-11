# Charter Creation Form – Design System

## Design Philosophy

This form isn't about collecting data—it's about **capturing the beginning of an adventure**. Every visual element should evoke the freedom, anticipation, and maritime romance of sailing. The composition guides users through their journey while maintaining emotional engagement.

---

## Visual Hierarchy & Composition

### Primary Focal Points
- **The Journey Timeline** (dates section): This is the hero—it visualizes the adventure span
- **Yacht Selection**: The "character" of the journey—what vessel will carry this story
- **Location/Route**: The destination that drives emotion and imagination

### Secondary Elements
- Charter name (personalization)
- Crew details, budget, amenities (supporting data)

### Design Principle: "The Horizon"
Use negative space and subtle visual depth to create a sense of openness—like looking out to sea. This prevents the form from feeling cramped or administrative.

---

## Color System

### Primary Palette (Emotional)
- **Deep Ocean Blue** (`#0F3B5F`): Trust, stability, maritime authority
- **Soft Horizon White** (`#FAFAF8`): Openness, clarity
- **Warm Gold/Amber** (`#D4A574`): Luxury, sun-kissed experiences, premium yacht life
- **Teal Accent** (`#2BA39F`): Energy, movement, the living sea

### Secondary Colors
- **Soft Gray** (`#8B8B8B`): Supporting text, disabled states
- **Success Green** (`#4CAF7F`): Confirmation, smooth sailing
- **Alert Coral** (`#E8694A`): Warnings, date conflicts

### Psychological Application
- Use warm gold as hover states on yacht cards—suggests luxury
- Teal for interactive elements that suggest movement/progress
- Deep blue as base—conveys expertise and trustworthiness
- Ample white space—psychological freedom

---

## Layout Structure

### Three-Phase Composition

#### **Phase 1: The Dream** (Visual Anchor)
```
┌─────────────────────────────────┐
│                                 │
│   [Hero Image/Illustration]     │  ← Emotional entry point
│   Sunset over sailing yacht      │     Tells the story before data entry
│                                 │
└─────────────────────────────────┘
```
- Full-width hero image (400-500px height)
- Features a sailboat at golden hour or a serene seascape
- Overlay text: "Plan Your Adventure" or charter-specific messaging
- Sets emotional tone before form begins

#### **Phase 2: The Essentials** (Primary Content)
Three-column grid that adapts:

```
Desktop (1200px+):
┌────────────────────────────────────────────┐
│ [Charter Name]     [Dates]                 │
│ [Location]         [Yacht Selection]       │
│ [Crew Size]        [Budget]                │
└────────────────────────────────────────────┘

Tablet (768px-1199px):
┌────────────────────┐
│ [Charter Name]     │
│ [Dates]            │
│ [Location]         │
│ [Yacht Selection]  │
│ [Crew Size]        │
│ [Budget]           │
└────────────────────┘
```

- Cards for major sections, not inline inputs
- Generous padding (24px-32px) between elements
- Each input field has clear, hierarchical labels

#### **Phase 3: The Confirmation** (Visual Closure)
```
┌─────────────────────────────────────────────┐
│  [Summary Card]                             │
│  Your Adventure at a Glance                 │
│  ✓ March 15-22, 2025                        │
│  ✓ Greek Islands • 42ft Catamaran           │
│  ✓ Captain + 6 Guests                       │
└─────────────────────────────────────────────┘
   [Create Charter Button]
```

- Visual confirmation of choices before submission
- Removes cognitive load—users see what they're creating
- Button placement emphasizes commitment

---

## Component Specifications

### 1. Charter Name Input
```
Structure:
┌─────────────────────────────┐
│ Charter Name                │  ← Minimal label
│ ┌───────────────────────────┤
│ │ "Summer Escape 2025"      │  ← Placeholder hints at possibility
│ └───────────────────────────┤
│ Personalize your voyage      │  ← Supportive microcopy
└─────────────────────────────┘

Design Details:
- Font: Bold, 14px (semantic weight)
- Input height: 44px (touch-friendly)
- Border: Subtle, 1px, color-border (activated on focus with teal glow)
- Border radius: 8px (modern, not harsh)
- Icon (optional): Feather or compass icon (soft gold) on left
- Focus state: Teal underline + soft shadow
- Character counter: Appears at 80+ characters (non-intrusive gray)
```

### 2. Date Range Picker
```
Structure:
┌─────────────────────────────────────┐
│ When Will You Sail?                 │  ← Emotional framing
│                                     │
│ From: [15]  To: [22]  March 2025    │  ← Clear, scannable
│ ┌─────────────────┬─────────────────┤
│ │  15  16  17     │  20  21  22      │
│ │  [highlighted]  │  [highlighted]   │
│ └─────────────────┴─────────────────┘
│                                     │
│ 7 nights • 6 full days               │ ← Automatic calculation
└─────────────────────────────────────┘

Design Details:
- Dual calendar view (desktop), single (mobile)
- Selected dates: Soft teal background with deep blue text
- Hover dates: Warm gold background (suggests luxury experience)
- Weekend dates: Subtle gold tint (visual emphasis)
- Unavailable dates: Grayed out, strikethrough (clear exclusion)
- Duration display: Large, bold number (psychological weight)
- Microcopy guides users to think in terms of "nights" and "experiences"
```

### 3. Location Picker
```
Structure:
┌──────────────────────────────────────┐
│ Sailing Region                       │  ← Not "where" but "which waters"
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ 🌊 Greek Islands                 │ │  ← Icon + geography
│ │ Aegean, Ionian, Cyclades         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [Search or browse map]               │  ← Optional interactive element
│ • Mediterranean (12)                 │
│ • Caribbean (8)                      │
│ • Southeast Asia (5)                 │
└──────────────────────────────────────┘

Design Details:
- Location card: Soft drop shadow on hover (elevates, suggests selection)
- Icon: Maritime-themed (anchor, waves, compass)
- Subtext: Specific sailing regions (evokes geography)
- Selected state: Teal accent bar on left + warm gold background
- Optional map: Small, interactive regional map with visual hotspots
```

### 4. Yacht Selection (Hero Component)
```
Structure:
┌──────────────────────────────────────┐
│ Your Vessel                          │  ← Poetic framing
│                                      │
│ ┌──────────────┐  ┌──────────────┐  │
│ │  [YACHT 1]   │  │  [YACHT 2]   │  │
│ │ 38ft Mono    │  │ 42ft Catamaran
│ │              │  │               │  │
│ │ ⭐⭐⭐⭐⭐ │  │ ⭐⭐⭐⭐⭐ │  │
│ │ $2,400/night │  │ $3,100/night  │  │
│ │              │  │               │  │
│ │ [SELECT]     │  │ [SELECT]      │  │
│ └──────────────┘  └──────────────┘  │
└──────────────────────────────────────┘

Design Details:
- Card format: 280px × 320px (desktop)
- Image: 100% top area, subtle maritime aesthetic
- Selection border: 3px teal (confident, not subtle)
- Icon tags: Cabin count, engine type, draft (practical icons)
- Rating: Stars in warm gold (premium perception)
- Price typography: Bold, large (anchors decision)
- Hover state: Lift effect (2px shadow), warm gold glow around border
- Selected state: Teal border + checkmark overlay + subtle background tint
- Responsive: Stack vertically on mobile
```

### 5. Crew & Guest Configuration
```
Structure:
┌──────────────────────────────────────┐
│ Who's Coming?                        │
│                                      │
│ Captain Included: ✓                  │  ← Clear, positive
│                                      │
│ Guests & Crew                        │
│ ┌─────────────────────────────────┐  │
│ │ [−]  6  [+]  Total Berths: 8   │  │
│ └─────────────────────────────────┘  │
│                                      │
│ Additional Crew                      │
│ ☐ Chef/Cook                          │
│ ☐ Deckhand                           │
│ ☐ Stewardess                         │
└──────────────────────────────────────┘

Design Details:
- Stepper (−/+): Large, 44px buttons (mobile-friendly)
- Current value: Extra large, centered (primary information)
- Capacity display: Secondary text (prevents overstaffing anxiety)
- Checkboxes: Rounded (modern, friendly), teal when selected
- Availability: Grayed out if no berths remain (honest UX)
```

### 6. Budget & Pricing
```
Structure:
┌──────────────────────────────────────┐
│ Total Estimated Cost                 │  ← Transparency
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ Base Rate:        $3,100 × 7     │ │
│ │ Crew Premium:            +$800   │ │
│ │ Additional Services:     +$1,200 │ │
│ │ ────────────────────────────────  │
│ │ TOTAL:           $24,700         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ Deposit Due: $7,410 (30%)            │
│ Final Payment: Due 30 days before    │
└──────────────────────────────────────┘

Design Details:
- Background: Very soft warm gold (luxury perception)
- Breakdown format: Scannable, right-aligned numbers
- Total amount: Largest typography (72px+, bold)
- Color: Deep blue text on warm background (premium, not alarming)
- Currency symbol: Smaller, gray (secondary detail)
- Payment breakdown: Light gray text (secondary, informational)
```

### 7. Form Controls (Buttons)

#### Create Charter (Primary)
```
Structure:
   [CREATE YOUR CHARTER]
     (with subtle icon)

Design Details:
- Background: Teal gradient (subtle, left-to-right)
- Text: White, bold, 16px
- Padding: 14px × 32px (generous)
- Border radius: 8px
- Shadow: Soft drop shadow, teal-tinted (depth without darkness)
- Hover: Gradient intensifies, lift effect
- Active: Slight compress (tactile feedback)
- Width: Full-width on mobile, auto on desktop
```

#### Cancel/Save Draft (Secondary)
```
Structure:
   [SAVE AS DRAFT]  or  [CANCEL]

Design Details:
- Background: Transparent
- Border: 1px, subtle gray
- Text: Gray or primary text color
- Hover: Soft background tint (warm gold or light gray)
```

---

## Layout Grid & Spacing

### Horizontal Grid
- **Desktop**: 12-column grid, 1200px max-width
- **Tablet**: 8-column grid, 768px max-width
- **Mobile**: Single column, full-width with 16px padding

### Vertical Spacing
```
Hero Section:           80px top, 60px bottom
Form Section Title:     32px top, 16px bottom
Form Field:             16px bottom margin
Form Section:           48px bottom margin
Summary Card:           32px top margin
Button Area:            32px top padding
```

### Card Padding
- **Standard**: 24px
- **Compact**: 16px
- **Spacious**: 32px

---

## Typography System

### Font Stack
```
Primary: Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI'
Serif (accents): Georgia, serif
Mono (technical): Menlo, Monaco, monospace
```

### Type Scale
```
Hero Title:         48px, 700, line-height 1.2
Section Title:      28px, 600, line-height 1.3
Field Label:        14px, 600, line-height 1.4
Input Text:         16px, 400, line-height 1.5
Supporting Text:    12px, 400, line-height 1.4, color: gray-secondary
Error Text:         12px, 500, color: coral, line-height 1.4
```

---

## Interactive States

### Input Field States
```
Default:    Border #E0E0E0, text-color: text-primary
Hover:      Border #2BA39F (teal), shadow: subtle
Focus:      Border #2BA39F, shadow: teal glow (4px), bg-tint
Filled:     Border #2BA39F, check-icon (gold) appears
Error:      Border #E8694A (coral), error-text below, bg-tint red
Disabled:   Border #E0E0E0, text-color: gray, bg: #F5F5F5
```

### Card States
```
Default:    Border 1px #E0E0E0, shadow: subtle
Hover:      Shadow expands, border teal tint, slight lift (2px)
Selected:   Border 3px #0F3B5F, bg-tint gold, checkmark overlay
Disabled:   Opacity 0.5, cursor: not-allowed, strikethrough text
```

### Button States
```
Default:    Teal gradient, white text, shadow: soft
Hover:      Gradient saturates, lift effect (1px)
Active:     Gradient darker, compress (−1px)
Loading:    Spinner overlay, pointer: wait
Disabled:   Opacity 0.5, cursor: not-allowed, no shadow
Success:    Checkmark animation, background shifts to green
```

---

## Microinteractions & Animation

### Entrance Animations
```
Hero Image:     Fade + subtle scale (200ms, ease-out)
Form Sections:  Stagger slide-up (100ms each, ease-out)
Cards:          Fade + scale (150ms, ease-out)
```

### Focus Animations
```
Field Focus:    Teal glow expands (150ms, ease-out)
Label Lift:     Label moves up (100ms, ease-out) ← Floating label pattern
Icon Swap:      Icon color change (100ms) ← Compass needle spins to teal
```

### Confirmation Animations
```
Checkmark:      Bounce-in (300ms, cubic-bezier)
Success Message: Slide-in from right (200ms)
Button Transform: Swap to checkmark icon (200ms)
```

### Micro-Validation
```
Character Limit Approach:  Gentle color fade to gold (warns at 80%)
Capacity Overflow:         Input shake (100ms × 2) + red border
Date Conflict:             Conflicting dates flash coral (200ms)
```

---

## Accessibility & Inclusive Design

### Semantic Structure
```html
<form aria-label="Create Sailing Charter">
  <section aria-labelledby="hero-title">
    <!-- Hero section -->
  </section>
  
  <fieldset>
    <legend>Charter Details</legend>
    <!-- Form fields -->
  </fieldset>
</form>
```

### Color Contrast
- Teal on White: 4.8:1 (AAA compliant)
- Deep Blue on White: 7.2:1 (AAA compliant)
- Gold on White: 2.8:1 (AA compliant for large text)
- Error text: 5.1:1 (AAA compliant)

### Interactive Elements
- Minimum touch target: 44px × 44px
- Focus indicators: 3px teal outline, 2px offset
- Keyboard navigation: Tab order follows visual hierarchy
- Skip links: Jump to form sections

### Labels & Descriptions
```
<label for="charter-name">
  Charter Name
  <span aria-label="required">*</span>
</label>
<input id="charter-name" required />
<small id="charter-help">Personalize your voyage</small>
```

### ARIA Attributes
```
aria-required="true"         ← Required fields
aria-invalid="true"          ← Error states
aria-describedby="hint-id"   ← Helper text
aria-live="polite"           ← Dynamic updates (price, berths)
role="alert"                 ← Error messages
```

---

## Responsive Breakpoints

### Desktop (1200px+)
- Two-column grid: Labels + Inputs side-by-side
- Yacht cards: 3-column carousel or grid
- Date picker: Dual calendar view

### Tablet (768px-1199px)
- Single column: Full-width inputs
- Yacht cards: 2-column grid
- Date picker: Single calendar, wider viewport

### Mobile (< 768px)
- Full-width inputs: 100% with padding
- Yacht cards: Full-width, card-scroll pattern
- Date picker: Bottom sheet or modal
- Buttons: Full-width, sticky footer
- Hero image: 60vh (maintains emotion, not overwhelming)

---

## Dark Mode Adaptation

### Color Adjustments
```
Background:     #1A1A1A (charcoal)
Surface:        #2D2D2D (panels)
Text Primary:   #FAFAF8 (off-white)
Text Secondary: #A0A0A0 (gray)
Borders:        #3A3A3A (subtle)
Teal Accent:    #32D9E3 (slightly lighter for contrast)
Gold Accent:    #E5C77D (slightly lighter)
```

### Dark Mode Icon Adjustments
- Invert icons that use solid colors
- Use light strokes for icon outlines
- Maintain warmth with adjustments to gold

---

## Design System Tokens (CSS Variables)

```css
/* Colors */
--color-ocean-deep: #0F3B5F;
--color-horizon-white: #FAFAF8;
--color-gold-warm: #D4A574;
--color-teal-accent: #2BA39F;
--color-success-green: #4CAF7F;
--color-alert-coral: #E8694A;
--color-gray-secondary: #8B8B8B;

/* Spacing */
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 32px;
--space-2xl: 48px;

/* Shadows */
--shadow-subtle: 0 2px 8px rgba(0,0,0,0.08);
--shadow-medium: 0 4px 16px rgba(0,0,0,0.12);
--shadow-lifted: 0 8px 24px rgba(0,0,0,0.15);

/* Border Radius */
--radius-sm: 6px;
--radius-md: 8px;
--radius-lg: 12px;
--radius-full: 9999px;

/* Typography */
--font-family-base: 'Inter', sans-serif;
--font-family-serif: 'Georgia', serif;
--font-size-body: 16px;
--line-height-normal: 1.5;

/* Animation */
--duration-fast: 100ms;
--duration-normal: 150ms;
--duration-slow: 200ms;
--ease-out: cubic-bezier(0.16, 1, 0.3, 1);
```

---

## Visual Example: Complete Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                                                           ║  │
│  ║  [HERO IMAGE: Golden Hour Sailing Scene]                 ║  │
│  ║  "Plan Your Next Adventure"                              ║  │
│  ║                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Charter Details                                          ║  │
│  ║  ┌─────────────────────────────────────────────────────┐  ║  │
│  ║  │ Charter Name                                        │  ║  │
│  ║  │ [Summer Escape 2025..................]              │  ║  │
│  ║  └─────────────────────────────────────────────────────┘  ║  │
│  ║                                                           ║  │
│  ║  ┌─────────────────────────────────────────────────────┐  ║  │
│  ║  │ When Will You Sail?                                 │  ║  │
│  ║  │ [Calendar Grid: March 15-22]                        │  ║  │
│  ║  │ 7 nights • 6 full days                              │  ║  │
│  ║  └─────────────────────────────────────────────────────┘  ║  │
│  ║                                                           ║  │
│  ║  ┌─────────────────────────────────────────────────────┐  ║  │
│  ║  │ Sailing Region                                      │  ║  │
│  ║  │ [🌊 Greek Islands · Aegean, Ionian, Cyclades]       │  ║  │
│  ║  └─────────────────────────────────────────────────────┘  ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Your Vessel                                              ║  │
│  ║  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ║  │
│  ║  │[YACHT 1]     │  │[YACHT 2]⭐   │  │[YACHT 3]     │  ║  │
│  ║  │38ft Mono     │  │42ft Catamaran│  │52ft Catamaran│  ║  │
│  ║  │⭐⭐⭐⭐⭐ │  │⭐⭐⭐⭐⭐ │  │⭐⭐⭐⭐⭐ │  ║  │
│  ║  │$2,400/night  │  │$3,100/night ✓│  │$4,200/night  │  ║  │
│  ║  │[SELECT]     │  │[SELECTED]    │  │[SELECT]     │  ║  │
│  ║  └──────────────┘  └──────────────┘  └──────────────┘  ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Your Adventure Summary                                   ║  │
│  ║  ┌─────────────────────────────────────────────────────┐  ║  │
│  ║  │ ✓ March 15-22, 2025 (7 nights)                     │  ║  │
│  ║  │ ✓ Greek Islands                                    │  ║  │
│  ║  │ ✓ 42ft Catamaran + Captain + 6 Guests             │  ║  │
│  ║  │                                                     │  ║  │
│  ║  │ Total: $24,700                                     │  ║  │
│  ║  │ Deposit: $7,410 (30%)                              │  ║  │
│  ║  └─────────────────────────────────────────────────────┘  ║  │
│  ║                                                           ║  │
│  ║      [CREATE YOUR CHARTER]                                ║  │
│  ║      [SAVE AS DRAFT]  [CANCEL]                            ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Notes

### For SwiftUI (iOS)
- Use `@State` for form data, `@Environment` for theme
- Implement custom `TextFieldStyle` with teal focus rings
- Use `Picker` for location/yacht with custom styling
- Animate transitions with `.easeOut` duration
- Leverage `@FocusState` for floating labels

### For Web (HTML/CSS)
- Semantic HTML5 form structure
- CSS Grid for layout flexibility
- CSS Custom Properties for theming
- Intersection Observer for animation triggers
- Framer Motion or Animate.css for micro-interactions

### For Design Tools (Figma)
- Create main component for card layouts
- Establish shared typography styles
- Build interactive prototypes with hover/focus states
- Use auto-layout for responsive behavior
- Create separate "Dark Mode" variants

---

## Success Metrics

### Engagement
- Form completion rate > 85%
- Average time to completion: < 3 minutes
- Abandonment rate < 15%

### Emotional Design
- User feedback: "Exciting, not intimidating"
- Visual appeal rating > 4.2/5
- Share/show-to-friend rate > 40%

### UX Performance
- Zero validation surprises (clear error messaging)
- Mobile completion rate = Desktop rate (responsive parity)
- Accessibility compliance: WCAG 2.1 AA minimum

---

## Conclusion

This charter creation form transcends data collection—it's a **visual and emotional gateway to adventure**. By layering cinematic composition (focal points, color psychology, pacing), maritime aesthetics (warm gold, ocean blues, horizon space), and meticulous interaction design, we create an experience that makes users **feel** the anticipation of sailing before they've even booked.

Every element—from the golden hour hero image to the subtle glow on the teal accent button—reinforces the message: *"This is the beginning of something extraordinary."*
