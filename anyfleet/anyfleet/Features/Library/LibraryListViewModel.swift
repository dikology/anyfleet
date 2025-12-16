import Foundation
import Observation

@MainActor
@Observable
final class LibraryListViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let coordinator: AppCoordinator

    // MARK: - State
    
    var isLoading = false
    var loadError: Error?
    
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
    
    // MARK: - Initialization
    
    init(libraryStore: LibraryStore, coordinator: AppCoordinator) {
        self.libraryStore = libraryStore
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
    
    /// Load library content for the current user
    /// Note: This requires a userID - you may need to get it from UserStore or AppDependencies
    func loadLibrary(userID: UUID) async {
        guard !isLoading else { return }
        
        AppLogger.view.startOperation("Load Library")
        isLoading = true
        loadError = nil
        
        await libraryStore.loadLibrary(userID: userID)
        
        isLoading = false
        AppLogger.view.completeOperation("Load Library")
        AppLogger.view.info("Loaded \(library.count) library items")
    }
    
    /// Refresh library content
    func refresh() async {
        // TODO: Get userID from dependencies or environment
        // For now, this is a placeholder
        // await loadLibrary(userID: userID)
    }
    
    /// Delete content item
    func deleteContent(_ item: LibraryModel) async throws {
        try await libraryStore.deleteContent(item)
    }
}