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
        
        isLoading = true
        errorMessage = nil
        
        do {
            guide = try await libraryStore.fetchGuide(guideID)
            if guide == nil {
                errorMessage = "Guide not found"
            }
        } catch {
            errorMessage = "Failed to load guide: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}


