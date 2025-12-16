# LibraryStore & LibraryModel Architecture

## Current State

Your current `LibraryStore` and `LibraryModel` are minimal:

```swift
// Current LibraryModel - very simple
struct LibraryModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
}

// Current LibraryStore - just holds an array
@Observable
final class LibraryStore {
    private(set) var library: [LibraryModel] = []
    private let repository: any LibraryRepository
    
    init(repository: any LibraryRepository) {
        self.repository = repository
    }
}
```

## How They Fit Into Content Architecture

`LibraryModel` should become the **metadata model** for all library content types (similar to `ContentItem` in sailaway). It needs to support:

1. **Checklists** - Structured task lists
2. **Practice Guides** - Markdown guides/briefings  
3. **Flashcard Decks** - Study decks

## Recommended Extension

### Option 1: Extend LibraryModel (Recommended)

Transform `LibraryModel` into a content metadata model:

```swift
// Extended LibraryModel - supports all content types
nonisolated struct LibraryModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String  // Keep for backward compatibility, or rename to `title`
    var title: String { name }  // Alias for clarity
    var description: String?
    var type: ContentType  // .checklist, .practiceGuide, .flashcardDeck
    var visibility: ContentVisibility  // .private, .unlisted, .public
    var creatorID: UUID
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: ContentSyncStatus
    
    // Content type discriminator
    enum ContentType: String, Codable, CaseIterable, Sendable {
        case checklist = "checklist"
        case practiceGuide = "practice_guide"
        case flashcardDeck = "flashcard_deck"
        
        var displayName: String {
            switch self {
            case .checklist: return "Checklist"
            case .practiceGuide: return "Practice Guide"
            case .flashcardDeck: return "Flashcard Deck"
            }
        }
        
        var icon: String {
            switch self {
            case .checklist: return "checklist"
            case .practiceGuide: return "book"
            case .flashcardDeck: return "rectangle.stack"
            }
        }
    }
}
```

## Extended LibraryStore

Extend `LibraryStore` to manage different content types:

```swift
@Observable
final class LibraryStore {
    // Unified content collection (metadata for all types)
    private(set) var library: [LibraryModel] = []
    
    // Type-specific collections (full models for editing)
    private(set) var checklists: [Checklist] = []
    private(set) var guides: [PracticeGuide] = []
    private(set) var decks: [FlashcardDeck] = []
    
    private let repository: any LibraryRepository
    
    // Computed filters
    var myChecklists: [LibraryModel] {
        library.filter { $0.type == .checklist }
    }
    
    var myGuides: [LibraryModel] {
        library.filter { $0.type == .practiceGuide }
    }
    
    var myDecks: [LibraryModel] {
        library.filter { $0.type == .flashcardDeck }
    }
    
    // MARK: - Loading
    
    @MainActor
    func loadLibrary(userID: UUID) async {
        // Load metadata for all content types
        library = try await repository.fetchUserLibrary(userID: userID)
        
        // Load full models for editing
        checklists = try await repository.fetchUserChecklists(userID: userID)
        guides = try await repository.fetchUserGuides(userID: userID)
        decks = try await repository.fetchUserDecks(userID: userID)
    }
    
    // MARK: - Creating Content
    
    @MainActor
    func createChecklist(_ checklist: Checklist, creatorID: UUID) async throws {
        try await repository.createChecklist(checklist, creatorID: creatorID)
        await loadLibrary(userID: creatorID)
    }
    
    @MainActor
    func createGuide(_ guide: PracticeGuide, creatorID: UUID) async throws {
        try await repository.createGuide(guide, creatorID: creatorID)
        await loadLibrary(userID: creatorID)
    }
    
    // MARK: - Deleting Content
    
    @MainActor
    func deleteContent(_ item: LibraryModel) async throws {
        try await repository.deleteContent(item.id)
        library.removeAll { $0.id == item.id }
    }
}
```

## Data Flow

### Creating a Checklist

1. **User taps "New Checklist"** in `LibraryListView`
2. **Opens `ChecklistEditorView`** (from sailaway design)
3. **User edits and saves**:
   ```swift
   // In ChecklistEditorView
   try await libraryStore.createChecklist(checklist, creatorID: userID)
   ```
4. **LibraryStore saves to repository**:
   - Saves full `Checklist` model (sections/items)
   - Creates `LibraryModel` metadata record
   - Enqueues for sync
5. **LibraryStore refreshes**:
   ```swift
   await loadLibrary(userID: userID)
   ```
6. **UI updates automatically** (Observable pattern)

### Displaying Library Content

```swift
struct LibraryListView: View {
    @Environment(\.appDependencies) private var dependencies
    
    var body: some View {
        List {
            // Checklists section
            if !dependencies.libraryStore.myChecklists.isEmpty {
                Section("Checklists") {
                    ForEach(dependencies.libraryStore.myChecklists) { item in
                        LibraryItemRow(item: item)
                            .onTapGesture {
                                // Open ChecklistEditorView for editing
                                // or ChecklistExecutionView for using
                            }
                    }
                }
            }
            
            // Guides section
            if !dependencies.libraryStore.myGuides.isEmpty {
                Section("Guides") {
                    ForEach(dependencies.libraryStore.myGuides) { item in
                        LibraryItemRow(item: item)
                    }
                }
            }
            
            // Decks section
            if !dependencies.libraryStore.myDecks.isEmpty {
                Section("Decks") {
                    ForEach(dependencies.libraryStore.myDecks) { item in
                        LibraryItemRow(item: item)
                    }
                }
            }
        }
    }
}
```

## Repository Extension

Extend `LibraryRepository` protocol to support content operations:

```swift
protocol LibraryRepository: Sendable {
    // Metadata queries
    func fetchUserLibrary(userID: UUID) async throws -> [LibraryModel]
    
    // Full model queries
    func fetchUserChecklists(userID: UUID) async throws -> [Checklist]
    func fetchUserGuides(userID: UUID) async throws -> [PracticeGuide]
    func fetchUserDecks(userID: UUID) async throws -> [FlashcardDeck]
    
    // Creating
    func createChecklist(_ checklist: Checklist, creatorID: UUID) async throws
    func createGuide(_ guide: PracticeGuide, creatorID: UUID) async throws
    func createDeck(_ deck: FlashcardDeck, creatorID: UUID) async throws
    
    // Updating
    func saveChecklist(_ checklist: Checklist, creatorID: UUID) async throws
    func saveGuide(_ guide: PracticeGuide, creatorID: UUID) async throws
    
    // Deleting
    func deleteContent(_ contentID: UUID) async throws
}
```

## Migration Path

1. **Phase 1**: Extend `LibraryModel` with content type support
2. **Phase 2**: Add full model collections to `LibraryStore` (checklists, guides, decks)
3. **Phase 3**: Implement repository methods for each content type
4. **Phase 4**: Update `LibraryListView` to display all content types
5. **Phase 5**: Add editing flows (ChecklistEditorView, GuideEditorView, etc.)

## Key Design Decisions

1. **Unified Metadata**: `LibraryModel` serves as metadata for all content types
2. **Type-Specific Models**: Full models (`Checklist`, `PracticeGuide`, `FlashcardDeck`) for editing
3. **Observable Store**: `LibraryStore` uses `@Observable` for automatic UI updates
4. **Repository Pattern**: Abstracted data access for testability
5. **Offline-First**: Content created locally, synced in background

## Relationship to Sailaway's ContentStore

Your `LibraryStore` is equivalent to sailaway's `ContentStore`:
- Both manage library content metadata
- Both maintain type-specific collections
- Both use repository pattern for data access
- Both support offline-first sync

The main difference is naming:
- **anyfleet**: `LibraryStore` + `LibraryModel`
- **sailaway**: `ContentStore` + `ContentItem`

Both serve the same purpose: managing user-generated content in the library.

