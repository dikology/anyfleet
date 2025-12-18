//
//  PracticeGuideReaderViewModel.swift
//  anyfleet
//
//  ViewModel for reading an existing practice guide.
//

import Foundation
import Observation

@MainActor
@Observable
final class PracticeGuideReaderViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let guideID: UUID
    
    // MARK: - State
    
    var guide: PracticeGuide?
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Initialization
    
    init(libraryStore: LibraryStore, guideID: UUID) {
        self.libraryStore = libraryStore
        self.guideID = guideID
    }
    
    // MARK: - Actions
    
    func loadGuide() async {
        // Skip loading if guide is already set (useful for previews)
        guard guide == nil else { return }
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let loaded = try await libraryStore.fetchGuide(guideID)
            await MainActor.run {
                self.guide = loaded
                if loaded == nil {
                    self.errorMessage = "Guide not found"
                }
                self.isLoading = false
            }
            AppLogger.view.info("Guide loaded: \(loaded != nil ? "success" : "not found") - ID: \(guideID.uuidString)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load guide: \(error.localizedDescription)"
                self.isLoading = false
            }
            AppLogger.view.error("Failed to load guide \(guideID.uuidString): \(error.localizedDescription)")
        }
    }
}


