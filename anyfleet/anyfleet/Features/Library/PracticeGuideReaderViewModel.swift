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
final class PracticeGuideReaderViewModel: ErrorHandling {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let guideID: UUID
    
    // MARK: - State

    var currentError: AppError?
    var showErrorBanner: Bool = false
    var guide: PracticeGuide?
    var isLoading = false
    
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
        defer { isLoading = false }

        do {
            // Ensure library metadata is loaded for on-demand fetching
            if libraryStore.myGuides.isEmpty {
                await libraryStore.loadLibrary()
            }

            let loaded: PracticeGuide? = try await libraryStore.fetchFullContent(guideID)
            self.guide = loaded
            if loaded == nil {
                throw AppError.notFound(entity: "Practice Guide", id: guideID)
            }
            AppLogger.view.info("Guide loaded: success - ID: \(guideID.uuidString)")
        } catch {
            handleError(error)
        }
    }
}


