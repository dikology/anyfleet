# Complete Implementation Example - HomeView & ViewModel
**Status**: Ready to implement  
**Files**: HomeView.swift, HomeViewModel.swift

---

## HomeView.swift (Complete)

```swift
import SwiftUI

/// Home tab view displaying active charter status and reference content
@MainActor
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.contentStore) private var contentStore
    @Environment(\.localization) private var localization
    
    // MARK: - Initialization
    
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
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Greeting header
                headerSection
                
                // Primary card: adaptive based on charter state
                if let charter = viewModel.activeCharter {
                    activeCharterCard(charter: charter)
                } else {
                    createCharterCard
                }
                
                // Reference content: pinned checklists and guides
                referenceContentSection
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Sections
    
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
        case 5..<12:
            return localization.localized(L10n.Greeting.morning)
        case 12..<17:
            return localization.localized(L10n.Greeting.day)
        case 17..<22:
            return localization.localized(L10n.Greeting.evening)
        default:
            return localization.localized(L10n.Greeting.night)
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
    
    // MARK: - Primary Card: Active Charter State
    
    private func activeCharterCard(charter: CharterModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Badge label
            Text(localization.localized(L10n.Charter.activeCharter))
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.85))
            
            // Charter name (title)
            Text(charter.name)
                .font(AppTypography.title2)
                .foregroundColor(.white)
            
            // Location with icon
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active charter")
        .accessibilityValue(charter.name)
        .accessibilityHint("Double tap to view details and checkins")
    }
    
    // MARK: - Primary Card: Create Charter State
    
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Create new charter")
        .accessibilityHint("Double tap to start a new sailing trip")
    }
    
    // MARK: - Auth Prompt Button
    
    private var signInPromptButton: some View {
        Button {
            Task { await viewModel.signIn() }
        } label: {
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
        .accessibilityLabel("Sign in to continue")
    }
    
    // MARK: - Reference Content Section
    
    private var referenceContentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(localization.localized(L10n.Home.referenceContent))
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.screenPadding)
            
            // Checklists subsection
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(localization.localized(L10n.Home.checklistsTitle))
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.screenPadding)
                
                if viewModel.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        loadingCard
                    }
                } else if contentStore.myChecklists.isEmpty {
                    emptyCard(
                        message: localization.localized(L10n.Home.noChecklists)
                    )
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
            
            // Guides subsection
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(localization.localized(L10n.Home.guidesTitle))
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.screenPadding)
                
                if viewModel.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        loadingCard
                    }
                } else if contentStore.myGuides.isEmpty {
                    emptyCard(
                        message: localization.localized(L10n.Home.noGuides)
                    )
                } else {
                    ForEach(contentStore.myGuides.prefix(3), id: \.id) { guide in
                        referenceCard(
                            title: guide.title,
                            subtitle: guide.description
                        )
                        .onTapGesture {
                            viewModel.openGuide(guide.id)
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
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
    
    private func emptyCard(message: String) -> some View {
        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .fill(AppColors.cardBackground)
            .overlay(
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(AppSpacing.md),
                alignment: .leading
            )
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AppSpacing.screenPadding)
    }
    
    private func referenceCard(title: String, subtitle: String?) -> some View {
        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .fill(AppColors.cardBackground)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .overlay(
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md),
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 68)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityHint("Double tap to view")
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        charterStore: CharterStore(),
        userStore: UserStore(),
        contentStore: ContentStore(),
        appModel: AppModel()
    )
    .environment(\.localization, LocalizationService())
}
```

---

## HomeViewModel.swift (Complete)

```swift
import Foundation
import Observation

/// ViewModel for Home screen managing charter state and content discovery
@MainActor
@Observable
final class HomeViewModel: Sendable {
    // MARK: - State
    
    var activeCharter: CharterModel?
    var activeCharterChecklistID: UUID?
    var isLoading = false
    var showAuthPrompt = false
    
    // MARK: - Dependencies
    
    private let charterStore: CharterStore
    private let userStore: UserStore
    private let contentStore: ContentStore
    private let appModel: AppModel
    
    // MARK: - Initialization
    
    init(
        charterStore: CharterStore,
        userStore: UserStore,
        contentStore: ContentStore,
        appModel: AppModel
    ) {
        self.charterStore = charterStore
        self.userStore = userStore
        self.contentStore = contentStore
        self.appModel = appModel
    }
    
    // MARK: - Data Fetching
    
    /// Refresh home screen data: active charter, auth state, content
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // Update auth prompt visibility
        showAuthPrompt = !userStore.isAuthenticated
        
        // Fetch active charter (latest with today in date range)
        let today = Calendar.current.startOfDay(for: Date())
        activeCharter = charterStore.charters
            .filter { charter in
                charter.startDate <= today && charter.endDate >= today
            }
            .sorted { $0.startDate > $1.startDate } // Latest first
            .first
        
        AppLogger.home.info("Active charter: \(activeCharter?.name ?? "none")")
        
        // Fetch checkin checklist for active charter if it exists
        if let charterID = activeCharter?.id {
            activeCharterChecklistID = contentStore.myChecklists
                .filter { checklist in
                    checklist.type == .checkin && 
                    checklist.charterID == charterID
                }
                .sorted { $0.createdAt > $1.createdAt } // Latest first
                .first?.id
            
            AppLogger.home.info(
                "Active charter checklist: \(activeCharterChecklistID?.uuidString ?? "none")"
            )
        } else {
            activeCharterChecklistID = nil
        }
    }
    
    // MARK: - Navigation Actions
    
    /// Handle charter card tap: navigate to charter detail
    func onActiveCharterTapped(_ charter: CharterModel) {
        AppLogger.home.info("Active charter tapped: \(charter.id)")
        appModel.navigationPath.append(.charterDetail(id: charter.id))
    }
    
    /// Handle create charter card tap: navigate to creation flow
    func onCreateCharterTapped() {
        AppLogger.home.info("Create charter tapped from home")
        appModel.navigationPath.append(.charterCreation)
    }
    
    /// Navigate to checklist detail
    func openChecklist(_ id: UUID) {
        AppLogger.home.info("Open checklist: \(id)")
        appModel.navigationPath.append(.checklistDetail(id: id))
    }
    
    /// Navigate to guide detail
    func openGuide(_ id: UUID) {
        AppLogger.home.info("Open guide: \(id)")
        appModel.navigationPath.append(.guideDetail(id: id))
    }
    
    // MARK: - Authentication
    
    /// Perform Sign in with Apple
    func signIn() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await userStore.signInWithApple()
            AppLogger.home.info("Sign in successful")
            
            // Refresh after successful sign-in
            await refresh()
        } catch let error as AppError {
            // Don't show error for cancelled sign-in
            if case .auth(.signInCancelled) = error {
                AppLogger.home.info("Sign in cancelled by user")
                return
            }
            
            AppLogger.home.error("Sign in failed: \(error.localizedMessage)")
        } catch {
            AppLogger.home.error("Unexpected sign in error: \(error.localizedDescription)")
        }
    }
}
```

---

## AppView Integration

Update the home tab case in AppView:

```swift
// In AppView.swift, replace:
case .home:
    HomeIncrementalDebugView(...)

// With:
case .home:
    HomeView(
        charterStore: charterStore,
        userStore: userStore,
        contentStore: contentStore,
        appModel: model
    )
    .onAppear { AppLogger.view.info("[HomeView] appeared") }
```

---

## Key Implementation Details

### Date Overlap Logic
```swift
// Includes charter if today is within [startDate, endDate] (inclusive)
let today = Calendar.current.startOfDay(for: Date())
activeCharter = charterStore.charters
    .filter { $0.startDate <= today && $0.endDate >= today }
    .sorted { $0.startDate > $1.startDate } // Latest start date first
    .first
```

### Checkin Checklist Query
```swift
// Find latest checkin-type checklist scoped to active charter
activeCharterChecklistID = contentStore.myChecklists
    .filter { 
        $0.type == .checkin &&              // Type matches
        $0.charterID == charterID           // Scoped to charter
    }
    .sorted { $0.createdAt > $1.createdAt } // Latest created
    .first?.id
```

### State Transitions
```
Initial (ViewLoad)
  └─> refresh() called in .task
      ├─> Load auth state
      ├─> Calculate activeCharter
      ├─> Load activeCharterChecklistID
      └─> Set isLoading = false
  
User has active charter
  └─> Show activeCharterCard
      └─> Tap card → Navigate to charterDetail
  
User has no active charter
  └─> Show createCharterCard
      ├─> If authenticated: tap → navigate to charterCreation
      └─> If not authenticated: show sign-in button
  
Reference content always shown
  └─> Show first 3 checklists
  └─> Show first 3 guides
  └─> Loading state for both
```

### Error Handling
```swift
// Network failure during refresh:
// - Set isLoading = false
// - Keep previous state (cached)
// - Log error silently
// - Do not show alert (ambient experience)

// Missing checkin checklist:
// - Show empty state
// - User can create in Library tab

// Not authenticated:
// - Show auth prompt on create card
// - User taps button → Apple Sign In
// - After success → Refresh and re-render
```

---

## Accessibility Checklist

- ✅ All text meets 4.5:1 contrast (white on oceanGradient = high contrast)
- ✅ Tab order: Greeting → Card → Reference items
- ✅ Meaningful labels: "Active charter, [name]"
- ✅ Hints: "Double tap to view details"
- ✅ Icons have system names (recognized by VoiceOver)
- ✅ Loading state uses ProgressView (spoken as "loading")
- ✅ Empty states have descriptive text
- ✅ Buttons have clear labels

---

## Testing Examples

### Test Active Charter Display
```swift
// Setup
let charter = CharterModel(
    id: UUID(),
    name: "Test Charter",
    location: "Aegean Sea",
    startDate: Date().addingTimeInterval(-86400),  // Yesterday
    endDate: Date().addingTimeInterval(86400)      // Tomorrow
)
charterStore.charters = [charter]

// Assert
viewModel.refresh()
XCTAssertEqual(viewModel.activeCharter?.id, charter.id)
```

### Test Create Card When No Active Charter
```swift
// Setup
charterStore.charters = []

// Assert
viewModel.refresh()
XCTAssertNil(viewModel.activeCharter)
```

### Test Checkin Checklist Loading
```swift
// Setup
let charter = CharterModel(...)
let checklist = ChecklistModel(
    id: UUID(),
    type: .checkin,
    charterID: charter.id,
    ...
)
viewModel.activeCharter = charter
contentStore.myChecklists = [checklist]

// Assert
viewModel.refresh()
XCTAssertEqual(viewModel.activeCharterChecklistID, checklist.id)
```

