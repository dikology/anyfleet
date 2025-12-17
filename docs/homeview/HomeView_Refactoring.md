# Refactoring Guide - Home View Implementation
**Priority**: CRITICAL  
**Target Version**: Next Sprint  
**Estimated Effort**: 5-7 developer days

---

## Executive Summary

The new Home View implementation is **structurally incomplete**. The new HomeView.swift only displays a create charter card regardless of app state, missing the core adaptive behavior. The embedded `HomeIncrementalDebugView` in AppView needs extraction. Below are critical issues ranked by severity.

---

## Critical Issues (Must Fix Before Release)

### 🔴 ISSUE #1: HomeView Only Shows Create Card (BREAKING)

**Severity**: CRITICAL  
**File**: HomeView.swift  
**Problem**:
```swift
// CURRENT (BROKEN)
var body: some View {
    ScrollView {
        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            ActionCard(
                icon: "sailboat.fill",
                title: L10n.homeCreateCharterTitle,
                subtitle: L10n.homeCreateCharterSubtitle,
                buttonTitle: L10n.homeCreateCharterAction,
                onTap: { viewModel.onCreateCharterTapped() },
                onButtonTap: { viewModel.onCreateCharterTapped() }
            )
        }
    }
}
```

**Issue**: No conditional rendering. Always shows "create charter" even when active charter exists.

**Solution**:
```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // 1. Greeting Header
            headerSection
            
            // 2. Adaptive Primary Card
            if let charter = viewModel.activeCharter {
                activeCharterCard(charter: charter)
            } else {
                createCharterCard
            }
            
            // 3. Reference Content
            referenceContentSection
        }
        .padding(.vertical, AppSpacing.md)
    }
    .background(AppColors.background.ignoresSafeArea())
    .task {
        await viewModel.refresh()
    }
}
```

**Implementation Time**: 2 hours

---

### 🔴 ISSUE #2: ViewModel Initialization Mismatch (BREAKING)

**Severity**: CRITICAL  
**Files**: HomeView.swift, HomeViewModel.swift  
**Problem**:

HomeView is initialized with only coordinator:
```swift
// HomeView init
init(viewModel: HomeViewModel) {
    _viewModel = State(initialValue: viewModel)
}
```

But AppView passes 4 dependencies:
```swift
// AppView creates with
HomeIncrementalDebugView(
    appModel: model, 
    charterStore: charterStore, 
    userStore: userStore, 
    contentStore: contentStore
)
```

**Result**: Compile error or runtime crash.

**Solution A** (Recommended): Make HomeView accept stores
```swift
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.charterStore) private var charterStore
    @Environment(\.userStore) private var userStore
    @Environment(\.contentStore) private var contentStore
    
    init() {
        // Initialize ViewModel with environment stores
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            charterStore: charterStore,  // ❌ Can't access here
            userStore: userStore,
            contentStore: contentStore
        ))
    }
}
```

**Solution B** (Better): Pass stores via dependency injection
```swift
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    
    init(
        charterStore: CharterStore,
        userStore: UserStore,
        contentStore: ContentStore,
        appModel: AppModel
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            charterStore: charterStore,
            userStore: userStore,
            contentStore: contentStore,
            appModel: appModel
        ))
    }
}

// In AppView
case .home:
    HomeView(
        charterStore: charterStore,
        userStore: userStore,
        contentStore: contentStore,
        appModel: model
    )
```

**Implementation Time**: 1 hour

---

### 🔴 ISSUE #3: Architecture - Embedded HomeIncrementalDebugView in AppView (ANTI-PATTERN)

**Severity**: CRITICAL  
**File**: AppView.swift (lines ~200+)  
**Problem**:

HomeIncrementalDebugView is defined **inside AppView.swift**, creating tight coupling:
```swift
// BAD: In AppView.swift
private struct HomeIncrementalDebugView: View {
    @Environment(\.contentStore) private var contentStore
    @Environment(\.localization) private var localization
    @StateObject private var viewModel: HomeViewModel
    
    // ... entire view implementation here
}
```

**Issues**:
- ❌ Violates separation of concerns
- ❌ Hard to test HomeView independently
- ❌ Makes AppView file 50KB (too large)
- ❌ Can't reuse HomeView elsewhere
- ❌ Difficult to debug (nested in tab logic)

**Solution**: Extract to HomeView.swift
```swift
// File: HomeView.swift (top-level)
import SwiftUI

@MainActor
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.contentStore) private var contentStore
    @Environment(\.localization) private var localization
    
    init(charterStore: CharterStore, userStore: UserStore, 
         contentStore: ContentStore, appModel: AppModel) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            charterStore: charterStore,
            userStore: userStore,
            contentStore: contentStore,
            appModel: appModel
        ))
    }
    
    var body: some View {
        // Implementation from HomeIncrementalDebugView
    }
}
```

**In AppView.swift**:
```swift
case .home:
    HomeView(
        charterStore: charterStore,
        userStore: userStore,
        contentStore: contentStore,
        appModel: model
    )
```

**Implementation Time**: 3 hours (includes cleanup)

---

### 🔴 ISSUE #4: Missing Active Charter Filtering Logic

**Severity**: CRITICAL  
**File**: HomeViewModel.swift  
**Problem**:

No charter date filtering implementation shown. ViewModel lacks the core business logic.

**Missing Code**:
```swift
// In HomeViewModel
func refresh() async {
    isLoading = true
    defer { isLoading = false }
    
    // THIS IS MISSING:
    let today = Calendar.current.startOfDay(for: Date())
    activeCharter = charterStore.charters
        .filter { $0.startDate <= today && $0.endDate >= today }
        .sorted { $0.startDate > $1.startDate }
        .first
    
    // Also fetch checkin checklist for active charter
    if let charterID = activeCharter?.id {
        activeCharterChecklistID = contentStore.myChecklists
            .filter { $0.type == .checkin && $0.charterID == charterID }
            .sorted { $0.createdAt > $1.createdAt }
            .first?.id
    }
}
```

**Solution**: Implement complete refresh() in HomeViewModel
```swift
@Observable
final class HomeViewModel {
    var activeCharter: CharterModel?
    var activeCharterChecklistID: UUID?
    var isLoading = false
    var showAuthPrompt = false
    
    private let charterStore: CharterStore
    private let userStore: UserStore
    private let contentStore: ContentStore
    private let appModel: AppModel
    
    init(charterStore: CharterStore, userStore: UserStore, 
         contentStore: ContentStore, appModel: AppModel) {
        self.charterStore = charterStore
        self.userStore = userStore
        self.contentStore = contentStore
        self.appModel = appModel
    }
    
    @MainActor
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check auth state
        showAuthPrompt = !userStore.isAuthenticated
        
        // Fetch active charter with date overlap check
        let today = Calendar.current.startOfDay(for: Date())
        activeCharter = charterStore.charters
            .filter { $0.startDate <= today && $0.endDate >= today }
            .sorted { $0.startDate > $1.startDate } // Latest first
            .first
        
        // Fetch checkin checklist for active charter
        if let charterID = activeCharter?.id {
            activeCharterChecklistID = contentStore.myChecklists
                .filter { $0.type == .checkin && $0.charterID == charterID }
                .sorted { $0.createdAt > $1.createdAt }
                .first?.id
        } else {
            activeCharterChecklistID = nil
        }
    }
    
    func onCreateCharterTapped() {
        AppLogger.view.info("Create charter tapped")
        appModel.navigationPath.append(.charterCreation)
    }
    
    func onActiveCharterTapped(_ charter: CharterModel) {
        AppLogger.view.info("Active charter tapped: \(charter.id)")
        appModel.navigationPath.append(.charterDetail(id: charter.id))
    }
}
```

**Implementation Time**: 2 hours

---

## Major Issues (Should Fix This Sprint)

### 🟠 ISSUE #5: Reference Content Section Not Implemented

**Severity**: HIGH  
**File**: HomeView.swift  
**Problem**:

The reference content section (checklists + guides pinned content) is completely missing from new HomeView.

**Old Implementation** (from AppView):
```swift
private var referenceContentSection: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        Text("Reference Content")
            .font(AppTypography.title3)
        
        // Checklists
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(contentStore.myChecklists.prefix(3)) { checklist in
                referenceCard(title: checklist.title, subtitle: checklist.description)
                    .onTapGesture { viewModel.openChecklist(checklist.id) }
            }
        }
        
        // Guides
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(contentStore.myGuides.prefix(3)) { guide in
                referenceCard(title: guide.title, subtitle: guide.description)
                    .onTapGesture { viewModel.openGuide(guide.id) }
            }
        }
    }
}
```

**Solution**: Implement in new HomeView
```swift
private var referenceContentSection: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        Text(localization.localized(L10n.Home.referenceContent))
            .font(AppTypography.title3)
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.screenPadding)
        
        // Checklists subsection
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Checklists")
                .font(AppTypography.bodyBold)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.screenPadding)
            
            if contentStore.myChecklists.isEmpty {
                Text("No checklists yet")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.screenPadding)
            } else {
                ForEach(contentStore.myChecklists.prefix(3)) { checklist in
                    referenceCard(
                        title: checklist.title,
                        subtitle: checklist.description
                    )
                    .onTapGesture {
                        viewModel.openChecklist(checklist.id)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            }
        }
        
        // Guides subsection (similar pattern)
        // ...
    }
}
```

**Implementation Time**: 3 hours

---

### 🟠 ISSUE #6: Active Charter Card Structure Incomplete

**Severity**: HIGH  
**File**: HomeView.swift  
**Problem**:

No separate component for displaying active charter. The card should show:
- Charter name (title)
- Location (subtitle)
- Optional date range
- Tap handler to detail view

**Solution**: Create dedicated component
```swift
private func activeCharterCard(charter: CharterModel) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
        // Label
        Text(localization.localized(L10n.Charter.activeCharter))
            .font(AppTypography.caption)
            .foregroundColor(.white.opacity(0.85))
        
        // Title
        Text(charter.name)
            .font(AppTypography.title2)
            .foregroundColor(.white)
        
        // Location
        if let location = charter.location, !location.isEmpty {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "mappin.and.ellipse")
                Text(location)
            }
            .font(AppTypography.bodySmall)
            .foregroundColor(.white.opacity(0.9))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(AppSpacing.cardPadding)
    .background(AppColors.oceanGradient)
    .cornerRadius(AppSpacing.cardCornerRadiusLarge)
    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    .padding(.horizontal, AppSpacing.screenPadding)
    .onTapGesture {
        viewModel.onActiveCharterTapped(charter)
    }
}
```

**Implementation Time**: 1 hour

---

### 🟠 ISSUE #7: Design Token Inconsistency

**Severity**: MEDIUM  
**Files**: HomeView.swift (new) vs AppView.swift (old)  
**Problem**:

Mixing design systems:
- Old code: `AppSpacing`, `AppColors`, `AppTypography`
- New code: `DesignSystem.Spacing`, `DesignSystem.Colors`

**Example**:
```swift
// OLD (AppView.swift)
.font(AppTypography.largeTitle)
.padding(.horizontal, AppSpacing.screenPadding)
.background(AppColors.oceanGradient)

// NEW (HomeView.swift)
.padding(.horizontal, DesignSystem.Spacing.lg)
.background(DesignSystem.Colors.background)
```

**Solution**: Unify on single system
```swift
// Choose: Use AppTypography, AppSpacing, AppColors everywhere
// Or: Use DesignSystem.Typography, DesignSystem.Spacing, DesignSystem.Colors

// RECOMMENDATION: Keep AppTypography/AppSpacing/AppColors
// (already used consistently in old code)
```

**Implementation Time**: 1.5 hours (search/replace + verification)

---

### 🟠 ISSUE #8: Auth Prompt Missing from Create Card

**Severity**: HIGH  
**File**: HomeView.swift  
**Problem**:

The create charter card should show a sign-in button overlay when user is not authenticated. Current code omits this.

**Old Implementation**:
```swift
.overlay(alignment: .bottomTrailing) {
    if viewModel.showAuthPrompt {
        Button { Task { await viewModel.signIn() } } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Sign in to continue")
            }
            .font(AppTypography.caption)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.white.opacity(0.15))
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.badgeCornerRadius)
        }
        .padding()
    }
}
```

**Solution**: Add to new HomeView
```swift
private var createCharterCard: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(.white)
        
        Spacer()
        
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(localization.localized(L10n.Charter.createCharter))
                .font(AppTypography.title2)
                .foregroundColor(.white)
            
            Text(localization.localized(L10n.Charter.createCharterDescription))
                .font(AppTypography.bodySmall)
                .foregroundColor(.white.opacity(0.9))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(AppSpacing.cardPadding)
    .frame(height: AppSpacing.featuredCardHeight)
    .background(AppColors.oceanGradient)
    .cornerRadius(AppSpacing.cardCornerRadiusLarge)
    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    .padding(.horizontal, AppSpacing.screenPadding)
    .onTapGesture {
        viewModel.onCreateCharterTapped()
    }
    .overlay(alignment: .bottomTrailing) {
        if viewModel.showAuthPrompt {
            signInPromptButton
                .padding()
        }
    }
}

private var signInPromptButton: some View {
    Button { Task { await viewModel.signIn() } } label: {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "person.crop.circle.badge.plus")
            Text(localization.localized(L10n.Auth.signInWithApple))
        }
        .font(AppTypography.caption)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.white.opacity(0.15))
        .foregroundColor(.white)
        .cornerRadius(AppSpacing.badgeCornerRadius)
    }
}
```

**Implementation Time**: 1.5 hours

---

## Moderate Issues (Next Sprint)

### 🟡 ISSUE #9: Missing viewModel.signIn() Implementation

**Severity**: MEDIUM  
**File**: HomeViewModel.swift  
**Problem**:

Auth prompt button calls `viewModel.signIn()` but this method is not defined.

**Solution**:
```swift
@MainActor
func signIn() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        try await userStore.signInWithApple()
        // Refresh after successful sign-in
        await refresh()
    } catch {
        AppLogger.error.error("Sign in failed: \(error.localizedDescription)")
    }
}
```

**Implementation Time**: 30 minutes

---

### 🟡 ISSUE #10: Greeting Section Missing

**Severity**: MEDIUM  
**File**: HomeView.swift  
**Problem**:

New HomeView completely omits the greeting header ("Good Morning", date).

**Solution**:
```swift
private var headerSection: some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(greetingText)
            .font(AppTypography.largeTitle)
            .foregroundColor(AppColors.textPrimary)
        
        Text(dateText)
            .font(AppTypography.body)
            .foregroundColor(AppColors.textSecondary)
    }
    .padding(.horizontal, AppSpacing.screenPadding)
}

private var greetingText: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return localization.localized(L10n.Greeting.morning)
    case 12..<17: return localization.localized(L10n.Greeting.day)
    case 17..<22: return localization.localized(L10n.Greeting.evening)
    default: return localization.localized(L10n.Greeting.night)
    }
}

private var dateText: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter.string(from: Date())
}
```

**Implementation Time**: 45 minutes

---

### 🟡 ISSUE #11: No Loading State in Reference Content

**Severity**: MEDIUM  
**File**: HomeView.swift  
**Problem**:

Reference content should show skeleton loaders while `isLoading == true`.

**Solution**:
```swift
private var referenceContentSection: some View {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        if viewModel.isLoading {
            // Show skeleton cards
            ForEach(0..<6, id: \.self) { _ in
                loadingCard
            }
        } else {
            // Show actual content
            // ...
        }
    }
}

private var loadingCard: some View {
    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
        .fill(AppColors.cardBackground)
        .frame(height: 68)
        .overlay(
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Rectangle()
                        .fill(AppColors.textTertiary.opacity(0.2))
                        .frame(height: 10)
                    
                    Rectangle()
                        .fill(AppColors.textTertiary.opacity(0.2))
                        .frame(height: 8)
                }
            }
            .padding(AppSpacing.md)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
}
```

**Implementation Time**: 1 hour

---

## Implementation Roadmap

### Phase 1: Emergency Fix (1 day)
- [ ] Extract HomeIncrementalDebugView from AppView → HomeView.swift
- [ ] Fix ViewModel initialization (pass all 4 stores)
- [ ] Implement active charter filtering logic
- [ ] Implement conditional card rendering (active vs create)

### Phase 2: Restore Features (2 days)
- [ ] Add greeting header section
- [ ] Implement reference content section (checklists + guides)
- [ ] Add auth prompt button overlay
- [ ] Implement loading states and empty states

### Phase 3: Polish (1-2 days)
- [ ] Unify design tokens (AppSpacing/AppColors consistency)
- [ ] Add error boundaries
- [ ] Implement proper accessibility labels
- [ ] Test all edge cases

---

## Code Review Checklist

Before merging, ensure:

- [ ] No hardcoded charter data (all from store)
- [ ] `viewModel.refresh()` called in `.task`
- [ ] Active charter filtering uses date overlap logic
- [ ] Design tokens are consistent (AppSpacing, AppColors, AppTypography)
- [ ] No embedded views in AppView (HomeView is top-level)
- [ ] Reference content section shows first 3 items
- [ ] Loading states work correctly
- [ ] Empty states have helpful messaging
- [ ] Auth prompt shows when `showAuthPrompt == true`
- [ ] All navigation paths are correct
- [ ] Accessibility labels present on all interactive elements

---

## Migration Path

**For teams with existing code:**

1. **Backup current implementation**
   ```bash
   git branch backup/home-view-current
   ```

2. **Extract from AppView**
   - Copy `HomeIncrementalDebugView` struct
   - Rename to `HomeView`
   - Create new file: `Sources/Views/Home/HomeView.swift`

3. **Update AppView**
   - Replace embedded struct with import
   - Call `HomeView(...)` directly

4. **Update ViewModel**
   - Add missing refresh() logic
   - Add signIn() method
   - Add activeCharterChecklistID property

5. **Test incrementally**
   - Verify no regressions
   - Test all state transitions
   - Validate navigation

