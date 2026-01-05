//
//  ChecklistReaderViewModel.swift
//  anyfleet
//
//  ViewModel for reading an existing checklist.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChecklistReaderViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let libraryStore: LibraryStore
    private let checklistID: UUID

    // MARK: - State

    var checklist: Checklist?
    var isLoading = false

    // Error handling
    var currentError: AppError?
    var showErrorBanner = false
    
    // MARK: - Initialization
    
    init(libraryStore: LibraryStore, checklistID: UUID) {
        self.libraryStore = libraryStore
        self.checklistID = checklistID
    }
    
    // MARK: - Actions
    
    func loadChecklist() async {
        // Skip loading if checklist is already set (useful for previews)
        guard checklist == nil else { return }
        guard !isLoading else { return }

        await MainActor.run {
            isLoading = true
            clearError()
        }

        do {
            // Ensure library metadata is loaded for on-demand fetching
            if libraryStore.myChecklists.isEmpty {
                await libraryStore.loadLibrary()
            }

            let loaded = try await libraryStore.fetchChecklist(checklistID)
            await MainActor.run {
                self.checklist = loaded
                self.isLoading = false
            }
            AppLogger.view.info("Checklist loaded successfully - ID: \(checklistID.uuidString)")
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            handleError(error)
            AppLogger.view.error("Failed to load checklist \(checklistID.uuidString): \(error.localizedDescription)")
        }
    }
}

