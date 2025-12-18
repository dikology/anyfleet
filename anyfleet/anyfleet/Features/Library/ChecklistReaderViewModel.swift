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
final class ChecklistReaderViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let checklistID: UUID
    
    // MARK: - State
    
    var checklist: Checklist?
    var isLoading = false
    var errorMessage: String?
    
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
            errorMessage = nil
        }
        
        do {
            let loaded = try await libraryStore.fetchChecklist(checklistID)
            await MainActor.run {
                self.checklist = loaded
                if loaded == nil {
                    self.errorMessage = "Checklist not found"
                }
                self.isLoading = false
            }
            AppLogger.view.info("Checklist loaded: \(loaded != nil ? "success" : "not found") - ID: \(checklistID.uuidString)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load checklist: \(error.localizedDescription)"
                self.isLoading = false
            }
            AppLogger.view.error("Failed to load checklist \(checklistID.uuidString): \(error.localizedDescription)")
        }
    }
}

