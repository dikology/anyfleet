//
//  CharterDetailViewModel.swift
//  anyfleet
//
//  ViewModel for charter detail screen, including charter-scoped checklists.
//

import Foundation
import Observation

@MainActor
@Observable
final class CharterDetailViewModel {
    // MARK: - Dependencies
    
    private let charterStore: CharterStore
    private let libraryStore: LibraryStore
    
    // MARK: - Inputs
    
    let charterID: UUID
    
    // MARK: - State
    
    var charter: CharterModel?
    var isLoading = false
    var loadError: String?
    
    /// ID of the charter-scoped check‑in checklist (backed by a library checklist template)
    var checkInChecklistID: UUID?
    
    // MARK: - Initialization
    
    init(
        charterID: UUID,
        charterStore: CharterStore,
        libraryStore: LibraryStore
    ) {
        self.charterID = charterID
        self.charterStore = charterStore
        self.libraryStore = libraryStore
    }
    
    // MARK: - Loading
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        // Ensure charters are loaded
        if charterStore.charters.isEmpty {
            try? await charterStore.loadCharters()
        }
        
        charter = charterStore.charters.first(where: { $0.id == charterID })
        
        if charter == nil {
            loadError = "Charter not found"
            return
        }
        
        // Ensure library content is loaded so we can look for check‑in templates
        if libraryStore.checklists.isEmpty {
            await libraryStore.loadLibrary()
        }
        
        await ensureCheckInChecklist()
    }
    
    // MARK: - Checklist Wiring
    
    /// Ensure the charter has a check‑in checklist instance if a template exists in the library.
    private func ensureCheckInChecklist() async {
        guard var currentCharter = charter else { return }
        
        // Already linked
        if let existingID = currentCharter.checkInChecklistID {
            checkInChecklistID = existingID
            return
        }
        
        // Find a check‑in checklist template in the user's library
        guard let template = libraryStore.checklists.first(where: { $0.checklistType == .checkIn }) else {
            // No template available; leave nil and allow UI to show placeholder
            checkInChecklistID = nil
            return
        }
        
        // For now, reference the template's ID directly as the charter's check‑in instance.
        // In the future this can be expanded to clone the template into a true charter‑scoped checklist.
        currentCharter.checkInChecklistID = template.id
        checkInChecklistID = template.id
        
        do {
            try await charterStore.saveCharter(currentCharter)
            charter = currentCharter
        } catch {
            AppLogger.store.failOperation("Save Charter Check‑In Checklist", error: error)
            // Keep in-memory link even if persistence fails so the UI can still navigate.
        }
    }
}


