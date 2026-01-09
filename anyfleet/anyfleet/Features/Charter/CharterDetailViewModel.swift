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
final class CharterDetailViewModel: ErrorHandling {
    // MARK: - Dependencies
    
    private let charterStore: CharterStore
    private let libraryStore: LibraryStore
    
    // MARK: - Inputs
    
    let charterID: UUID
    
    // MARK: - State

    var currentError: AppError?
    var showErrorBanner: Bool = false

    // Computed property - single source of truth from store
    var charter: CharterModel? {
        charterStore.charters.first(where: { $0.id == charterID })
    }

    var isLoading = false
    
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

        do {
            // Ensure charters are loaded
            if charterStore.charters.isEmpty {
                try await charterStore.loadCharters()
            }

            guard charter != nil else {
                throw AppError.notFound(entity: "Charter", id: charterID)
            }

            // Ensure library content is loaded so we can look for check‑in templates
            if libraryStore.myChecklists.isEmpty {
                await libraryStore.loadLibrary()
            }

            await ensureCheckInChecklist()
        } catch {
            handleError(error)
        }
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
        var templateMetadata: LibraryModel? = nil
        for metadata in libraryStore.myChecklists {
            if let checklist: Checklist = try? await libraryStore.fetchFullContent(metadata.id),
               checklist.checklistType == .checkIn {
                templateMetadata = metadata
                break
            }
        }

        guard let templateMetadata = templateMetadata else {
            // No template available; leave nil and allow UI to show placeholder
            checkInChecklistID = nil
            return
        }
        
        // For now, reference the template's ID directly as the charter's check‑in instance.
        // In the future this can be expanded to clone the template into a true charter‑scoped checklist.
        currentCharter.checkInChecklistID = templateMetadata.id
        checkInChecklistID = templateMetadata.id
        
        do {
            try await charterStore.saveCharter(currentCharter)
        } catch {
            // Log the error but don't propagate it since we want to keep the in-memory link
            // so the UI can still navigate, even if persistence fails
            AppLogger.store.failOperation("Save Charter Check‑In Checklist", error: error)
        }
    }
}


