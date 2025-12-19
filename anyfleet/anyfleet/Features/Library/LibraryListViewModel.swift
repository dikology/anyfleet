import Foundation
import Observation

@MainActor
@Observable
final class LibraryListViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let visibilityService: VisibilityService
    private let authObserver: AuthStateObserver
    private let coordinator: AppCoordinator

    // MARK: - State
    
    var isLoading = false
    var loadError: Error?
    var pendingPublishItem: LibraryModel?
    var publishError: Error?
    
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
    
    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStore,
        visibilityService: VisibilityService,
        authObserver: AuthStateObserver,
        coordinator: AppCoordinator
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
        loadError = nil
        
        await libraryStore.loadLibrary()
        
        isLoading = false
        AppLogger.view.completeOperation("Load Library")
        AppLogger.view.info("Loaded \(library.count) library items")
    }
    
    /// Refresh library content
    func refresh() async {
        await loadLibrary()
    }
    
    /// Delete content item
    func deleteContent(_ item: LibraryModel) async throws {
        try await libraryStore.deleteContent(item)
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
        publishError = nil
    }
    
    /// Confirm and execute the publish action
    /// This should be called after user confirms in the modal
    func confirmPublish() async {
        guard let item = pendingPublishItem else {
            AppLogger.view.warning("confirmPublish called but no pending item")
            return
        }
        
        AppLogger.view.info("Confirming publish for item: \(item.id)")
        publishError = nil
        
        do {
            try await visibilityService.publishContent(item)
            pendingPublishItem = nil
            await loadLibrary()
            AppLogger.view.info("Publish confirmed and completed for item: \(item.id)")
        } catch {
            AppLogger.view.error("Publish failed", error: error)
            publishError = error
        }
    }
    
    /// Cancel the pending publish action
    func cancelPublish() {
        AppLogger.view.info("Cancelling publish")
        pendingPublishItem = nil
        publishError = nil
    }
    
    /// Unpublish an item (make it private)
    /// - Parameter item: The library item to unpublish
    func unpublish(_ item: LibraryModel) async {
        AppLogger.view.info("Unpublishing item: \(item.id)")
        
        do {
            try await visibilityService.unpublishContent(item)
            await loadLibrary()
            AppLogger.view.info("Unpublish completed for item: \(item.id)")
        } catch {
            AppLogger.view.error("Unpublish failed", error: error)
            publishError = error
        }
    }
}