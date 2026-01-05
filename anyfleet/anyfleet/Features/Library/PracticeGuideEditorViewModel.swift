//
//  PracticeGuideEditorViewModel.swift
//  anyfleet
//
//  ViewModel for creating and editing practice guides (markdown documents).
//

import Foundation
import Observation

@MainActor
@Observable
final class PracticeGuideEditorViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let guideID: UUID?
    private let onDismiss: () -> Void
    
    // MARK: - State
    
    var guide: PracticeGuide
    var isSaving = false
    var isLoading = false
    var errorMessage: String?
    
    var isNewGuide: Bool {
        guideID == nil
    }
    
    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStore,
        guideID: UUID? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.libraryStore = libraryStore
        self.guideID = guideID
        self.onDismiss = onDismiss
        self.guide = PracticeGuide.empty()
    }
    
    // MARK: - Actions
    
    func loadGuide() async {
        guard let guideID = guideID, !isNewGuide else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Ensure library metadata is loaded for on-demand fetching
            if libraryStore.myGuides.isEmpty {
                await libraryStore.loadLibrary()
            }

            if let loaded: PracticeGuide = try await libraryStore.fetchFullContent(guideID) {
                guide = loaded
            }
        } catch {
            errorMessage = "Failed to load guide: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func saveGuide() async {
        guard !isSaving else { return }
        
        // Basic validation
        let trimmedTitle = guide.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errorMessage = "Guide title is required"
            return
        }
        
        let trimmedMarkdown = guide.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMarkdown.isEmpty {
            errorMessage = "Guide content (markdown) is required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Ensure timestamps are updated
        guide.title = trimmedTitle
        guide.markdown = trimmedMarkdown
        guide.updatedAt = Date()
        
        do {
            if isNewGuide {
                try await libraryStore.createGuide(guide)
            } else {
                try await libraryStore.saveGuide(guide)
            }
            
            // Reload library to reflect changes
            await libraryStore.loadLibrary()
            
            onDismiss()
        } catch {
            errorMessage = "Failed to save guide: \(error.localizedDescription)"
            isSaving = false
        }
    }
}


