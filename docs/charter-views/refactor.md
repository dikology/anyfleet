## Refactoring Charter Create to Charter Editor

You correctly identified the pattern from `ChecklistEditorView` - it handles both create and edit modes using a nullable ID parameter. Here's how to refactor your charter flow:[4][6]

### Rename and Refactor ViewModel

**Rename:** `CreateCharterViewModel` → `CharterEditorViewModel`

**Key changes to the ViewModel:**

```swift
@MainActor
@Observable
final class CharterEditorViewModel {
    private let charterStore: CharterStore
    private let charterID: UUID? // Add this
    private let onDismiss: () -> Void
    
    var form: CharterFormState
    var isSaving = false
    var isLoading = false
    var saveError: Error?
    
    var isNewCharter: Bool {
        charterID == nil
    }
    
    init(
        charterStore: CharterStore,
        charterID: UUID? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.charterStore = charterStore
        self.charterID = charterID
        self.onDismiss = onDismiss
        self.form = CharterFormState()
    }
    
    // Add loading method
    func loadCharter() async {
        guard let charterID = charterID, !isNewCharter else { return }
        isLoading = true
        saveError = nil
        
        do {
            if let charter = try await charterStore.fetchCharter(charterID) {
                // Map charter to form
                form.name = charter.name
                form.startDate = charter.startDate
                form.endDate = charter.endDate
                form.destination = charter.location ?? ""
                form.vessel = charter.boatName ?? ""
            }
        } catch {
            saveError = error
        }
        
        isLoading = false
    }
    
    func saveCharter() async {
        // Existing logic, but check isNewCharter
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        
        do {
            if isNewCharter {
                // Create logic
                try await charterStore.createCharter(...)
            } else {
                // Update logic
                try await charterStore.updateCharter(charterID!, ...)
            }
            onDismiss()
        } catch {
            saveError = error
        }
        isSaving = false
    }
}
```

**Rename View:** `CreateCharterView` → `CharterEditorView`

Update navigation title based on mode:[10][11]

```swift
.navigationTitle(viewModel.isNewCharter ? "New Charter" : "Edit Charter")
.task {
    await viewModel.loadCharter()
}
```

## Make Charter Cards Tappable

Currently, you're using `NavigationLink` with a chevron. To match `LibraryListView` behavior, remove the `NavigationLink` wrapper and use a button with navigation:[2][1]

```swift
// In CharterListView
@Environment(\.appCoordinator) private var coordinator

// Replace NavigationLink with Button
ForEach(viewModel.charters) { charter in
    Button {
        coordinator.navigateToCharterDetail(charter.id)
    } label: {
        CharterRowView(charter: charter)
    }
    .buttonStyle(.plain)
    .listRowInsets(...)
    // ... rest of configuration
}
```

Update `CharterRowView` to remove the commented tap gesture code since the entire card is now tappable.[1]

## Extract Navigation Titles to Design System

Create a centralized navigation titles namespace in your Design System:[12]

```swift
// In DesignSystem/NavigationTitles.swift
extension DesignSystem {
    enum NavigationTitles {
        // Charter Flow
        static let charters = "Charters"
        static let charterDetail = "Charter Details"
        static let newCharter = "New Charter"
        static let editCharter = "Edit Charter"
        
        // Library Flow
        static let library = "My Library"
        static let newChecklist = "New Checklist"
        static let editChecklist = "Edit Checklist"
        static let viewChecklist = "Checklist"
        
        // Additional flows
        static let settings = "Settings"
        static let profile = "Profile"
    }
}
```

Then use throughout your app:

```swift
.navigationTitle(DesignSystem.NavigationTitles.charters)
.navigationTitle(viewModel.isNewCharter 
    ? DesignSystem.NavigationTitles.newCharter 
    : DesignSystem.NavigationTitles.editCharter)
```

## Make Dates Clickable with Modal Picker

Currently `DateRangeSection` displays inline date pickers. Refactor to show formatted dates that open a modal:[9][13][10]

```swift
struct DateRangeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let nights: Int
    
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Start Date Button
            Button {
                showingStartPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Departure")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(dateFormatter.string(from: startDate))
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding()
                .background(DesignSystem.Colors.surface)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // End Date Button
            Button {
                showingEndPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Return")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(dateFormatter.string(from: endDate))
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding()
                .background(DesignSystem.Colors.surface)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Nights badge
            if nights > 0 {
                HStack {
                    Image(systemName: "moon.stars.fill")
                    Text("\(nights) nights")
                }
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .sheet(isPresented: $showingStartPicker) {
            DatePickerModal(
                title: "Select Departure Date",
                selectedDate: $startDate
            )
        }
        .sheet(isPresented: $showingEndPicker) {
            DatePickerModal(
                title: "Select Return Date", 
                selectedDate: $endDate
            )
        }
    }
}

struct DatePickerModal: View {
    let title: String
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .background(DesignSystem.Colors.background)
        }
        .presentationDetents([.medium])
    }
}
```

## Additional Refactoring Suggestions

### Code Quality Improvements

**1. Remove placeholder initialization workarounds** [file:1][file:2][file:9]
The `updateViewModelIfNeeded()` pattern is commented as a workaround - consider using proper dependency injection through the coordinator instead of this pattern.

**2. Consolidate date formatting**
You have duplicate `dateFormatter` logic in multiple views [file:1]. Extract to Design System:

```swift
extension DesignSystem {
    enum DateFormatters {
        static let medium: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }()
        
        static let abbreviated: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .abbreviated
            return formatter
        }()
    }
}
```

**3. Extract magic numbers to constants** [file:5][file:9]
Replace hardcoded values like guest ranges:

```swift
extension DesignSystem {
    enum CharterLimits {
        static let minGuests = 1
        static let maxGuests = 12
        static let defaultGuests = 6
        static let defaultDurationDays = 7
    }
}
```

**4. Simplify validation logic** [file:3]
The `isValid` computed property could be more robust:

```swift
var isValid: Bool {
    !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    form.endDate > form.startDate && // Use > instead of >=
    form.nights > 0
}
```

**5. Unify error handling patterns**
You have inconsistent error handling between views [file:2][file:6][file:8]. Consider a unified error banner component or error state manager.

These refactorings will improve consistency, maintainability, and user experience across your charter and library features [file:1][file:2][file:3][file:4][file:5][file:6][file:7][file:8][file:9].
