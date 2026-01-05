import Foundation
import Observation

/// Represents the different content filters available in the library
enum ContentFilter: String, CaseIterable, Identifiable {
    case all
    case checklists
    case guides
    case decks

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return L10n.Library.filterAll
        case .checklists: return L10n.Library.filterChecklists
        case .guides: return L10n.Library.filterGuides
        case .decks: return L10n.Library.filterDecks
        }
    }
}

/// Represents the different delete confirmation modals that can be shown
enum DeleteAction {
    case showPublishedModal
    case showPrivateModal
}

@MainActor
@Observable
final class LibraryListViewModel: ErrorHandling {
    // MARK: - Dependencies

    let libraryStore: LibraryStoreProtocol
    let visibilityService: VisibilityServiceProtocol
    let authObserver: AuthStateObserverProtocol
    let coordinator: AppCoordinatorProtocol

    // MARK: - State

    var isLoading = false
    var pendingPublishItem: LibraryModel?
    var publishError: Error?
    var currentError: AppError?
    var showErrorBanner: Bool = false

    // MARK: - UI State

    var selectedFilter: ContentFilter = .all
    var showingPublishConfirmation = false
    var showingSignInModal = false
    var pendingDeleteItem: LibraryModel?
    var showPrivateDeleteConfirmation = false
    var showPublishedDeleteConfirmation = false
    var publishedDeleteModalItem: LibraryModel?
    
    // MARK: - Computed Properties
    
    var library: [LibraryModel] {
        libraryStore.library
    }
    
    var checklists: [LibraryModel] {
        libraryStore.myChecklists
    }
    
    var guides: [LibraryModel] {
        libraryStore.myGuides
    }
    
    var decks: [LibraryModel] {
        libraryStore.myDecks
    }
    
    var isEmpty: Bool {
        library.isEmpty
    }
    
    // MARK: - Visibility Computed Properties
    
    /// Whether the user is currently signed in
    var isSignedIn: Bool {
        authObserver.isSignedIn
    }
    
    /// Local content (private or unlisted)
    var localContent: [LibraryModel] {
        library.filter { item in
            item.visibility == .private || item.visibility == .unlisted
        }
    }
    
    /// Public content (published)
    var publicContent: [LibraryModel] {
        library.filter { item in
            item.visibility == .public
        }
    }
    
    /// Whether there is any local content
    var hasLocalContent: Bool {
        !localContent.isEmpty
    }
    
    /// Whether there is any public content
    var hasPublicContent: Bool {
        !publicContent.isEmpty
    }

    /// Filtered library items based on selected filter
    var filteredItems: [LibraryModel] {
        switch selectedFilter {
        case .all:
            return library
        case .checklists:
            return checklists
        case .guides:
            return guides
        case .decks:
            return decks
        }
    }
    
    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStoreProtocol,
        visibilityService: VisibilityServiceProtocol,
        authObserver: AuthStateObserverProtocol,
        coordinator: AppCoordinatorProtocol
    ) {
        self.libraryStore = libraryStore
        self.visibilityService = visibilityService
        self.authObserver = authObserver
        self.coordinator = coordinator
    }
    
    // MARK: - Actions
    
    /// Handles the create checklist action by navigating to the checklist editor.
    func onCreateChecklistTapped() {
        AppLogger.view.info("Create checklist tapped from library")
        coordinator.editChecklist(nil)
    }
    
    /// Handles the create guide action by navigating to the guide editor.
    func onCreateGuideTapped() {
        AppLogger.view.info("Create guide tapped from library")
        coordinator.editGuide(nil)
    }
    
    /// Handles the create deck action by navigating to the deck editor.
    func onCreateDeckTapped() {
        AppLogger.view.info("Create deck tapped from library")
        coordinator.editDeck(nil)
    }
    
    // MARK: - Read Actions
    
    /// Handles tapping a checklist to read/view it.
    func onReadChecklistTapped(_ checklistID: UUID) {
        AppLogger.view.info("Read checklist tapped: \(checklistID.uuidString)")
        coordinator.viewChecklist(checklistID)
    }
    
    /// Handles tapping a guide to read/view it.
    func onReadGuideTapped(_ guideID: UUID) {
        AppLogger.view.info("Read guide tapped: \(guideID.uuidString)")
        coordinator.viewGuide(guideID)
    }
    
    /// Handles editing an existing checklist.
    /// - Parameter checklistID: The ID of the checklist to edit
    func onEditChecklistTapped(_ checklistID: UUID) {
        AppLogger.view.info("Edit checklist tapped: \(checklistID.uuidString)")
        coordinator.editChecklist(checklistID)
    }
    
    /// Handles editing an existing guide.
    /// - Parameter guideID: The ID of the guide to edit
    func onEditGuideTapped(_ guideID: UUID) {
        AppLogger.view.info("Edit guide tapped: \(guideID.uuidString)")
        coordinator.editGuide(guideID)
    }
    
    /// Handles editing an existing deck.
    /// - Parameter deckID: The ID of the deck to edit
    func onEditDeckTapped(_ deckID: UUID) {
        AppLogger.view.info("Edit deck tapped: \(deckID.uuidString)")
        coordinator.editDeck(deckID)
    }
    
    // MARK: - Data Loading
    
    /// Load library content
    func loadLibrary() async {
        guard !isLoading else { return }
        
        AppLogger.view.startOperation("Load Library")
        isLoading = true
        clearError()
        
        await libraryStore.loadLibrary()
        
        isLoading = false
        AppLogger.view.completeOperation("Load Library")
        AppLogger.view.info("Loaded \(library.count) library items")
    }
    
    /// Refresh library content
    func refresh() async {
        await loadLibrary()
    }
    
    /// Delete content item with appropriate confirmation dialog
    func deleteContent(_ item: LibraryModel) async throws {
        // For published content, we need to handle unpublish operations
        // The actual confirmation dialogs are handled in the view layer
        AppLogger.view.info("Generic deleteContent called for item: \(item.id), publicID: \(item.publicID ?? "nil")")
        try await libraryStore.deleteContent(item, shouldUnpublish: true)
    }

    /// Delete published content and unpublish from backend
    /// Used for "Unpublish & Delete" option in published content deletion modal
    func deleteAndUnpublishContent(_ item: LibraryModel) async throws {
        AppLogger.view.info("Deleting and unpublishing content: \(item.id)")
        try await libraryStore.deleteContent(item, shouldUnpublish: true)
    }

    /// Delete local copy of published content but keep it published on backend
    /// Used for "Keep Published" option in published content deletion modal
    func deleteLocalCopyKeepPublished(_ item: LibraryModel) async throws {
        AppLogger.view.info("Deleting local copy but keeping published content: \(item.id)")
        try await libraryStore.deleteContent(item, shouldUnpublish: false)
    }

    /// Check if content is published (has publicID)
    func isPublishedContent(_ item: LibraryModel) -> Bool {
        return item.publicID != nil
    }

    /// Initiate delete action and return the appropriate modal type to show
    func initiateDelete(_ item: LibraryModel) -> DeleteAction {
        AppLogger.view.info("Delete initiated for item: \(item.id), title: '\(item.title)', publicID: \(item.publicID ?? "nil")")
        return item.publicID != nil ? .showPublishedModal : .showPrivateModal
    }
    
    /// Toggle pinned state for a library item
    func togglePin(for item: LibraryModel) async {
        await libraryStore.togglePin(for: item)
    }
    
    // MARK: - Visibility Actions
    
    /// Initiate the publish flow for an item
    /// Sets the item as pending and should trigger a confirmation modal
    /// - Parameter item: The library item to publish
    func initiatePublish(_ item: LibraryModel) {
        AppLogger.view.info("Initiate publish for item: \(item.id)")
        pendingPublishItem = item
        clearError()
    }
    
    /// Confirm and execute the publish action
    /// This should be called after user confirms in the modal
    func confirmPublish() async {
        guard let item = pendingPublishItem else {
            AppLogger.view.warning("confirmPublish called but no pending item")
            return
        }
        
        AppLogger.view.info("Confirming publish for item: \(item.id)")
        clearError()

        do {
            let syncSummary = try await visibilityService.publishContent(item)
            pendingPublishItem = nil
            await loadLibrary()
            AppLogger.view.info("Publish confirmed and completed for item: \(item.id) - \(syncSummary.succeeded) succeeded, \(syncSummary.failed) failed")
        } catch {
            AppLogger.view.error("Publish failed", error: error)
            publishError = error
        }
    }
    
    /// Cancel the pending publish action
    func cancelPublish() {
        AppLogger.view.info("Cancelling publish")
        pendingPublishItem = nil
        clearError()
    }
    
    /// Unpublish an item (make it private)
    /// - Parameter item: The library item to unpublish
    func unpublish(_ item: LibraryModel) async {
        AppLogger.view.info("Unpublishing item: \(item.id)")

        do {
            let syncSummary = try await visibilityService.unpublishContent(item)
            await loadLibrary()
            AppLogger.view.info("Unpublish completed for item: \(item.id) - \(syncSummary.succeeded) succeeded, \(syncSummary.failed) failed")
        } catch {
            AppLogger.view.error("Unpublish failed", error: error)
            publishError = error
        }
    }

    /// Retry sync operations for a failed content item
    /// - Parameter item: The library item to retry sync for
    func retrySync(for item: LibraryModel) async {
        AppLogger.view.info("Retrying sync for item: \(item.id)")
        await visibilityService.retrySync(for: item)
        // Reload to get updated sync status
        await loadLibrary()
    }
}