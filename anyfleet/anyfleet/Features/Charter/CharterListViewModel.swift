//
//  CharterListViewModel.swift
//  anyfleet
//
//  ViewModel for charter list view.
//

import Foundation
import Observation

/// ViewModel managing the charter list display.
///
/// Handles loading charters, filtering, and navigation to charter details.
///
/// ## Usage
///
/// ```swift
/// struct CharterListView: View {
///     @State private var viewModel: CharterListViewModel
///
///     var body: some View {
///         // View implementation
///     }
/// }
/// ```
@MainActor
@Observable
final class CharterListViewModel {
    // MARK: - Dependencies
    
    private let charterStore: CharterStore
    
    // MARK: - State
    
    /// Whether charters are currently being loaded
    var isLoading = false
    
    /// Error that occurred during loading, if any
    var loadError: Error?
    
    /// The list of charters to display
    var charters: [CharterModel] {
        charterStore.charters
    }
    
    /// Whether the charter list is empty
    var isEmpty: Bool {
        charters.isEmpty
    }
    
    // MARK: - Initialization
    
    /// Creates a new CharterListViewModel.
    ///
    /// - Parameter charterStore: The charter store for accessing charters
    init(charterStore: CharterStore) {
        self.charterStore = charterStore
    }
    
    // MARK: - Actions
    
    /// Loads all charters from the store.
    func loadCharters() async {
        guard !isLoading else { return }
        
        AppLogger.view.startOperation("Load Charters")
        isLoading = true
        loadError = nil
        
        await charterStore.loadCharters()
        
        isLoading = false
        AppLogger.view.completeOperation("Load Charters")
        AppLogger.view.info("Loaded \(charters.count) charters")
    }
    
    /// Refreshes the charter list.
    func refresh() async {
        await loadCharters()
    }
    
    /// Deletes a charter by ID.
    ///
    /// - Parameter charterID: The ID of the charter to delete
    func deleteCharter(_ charterID: UUID) async throws {
        AppLogger.view.startOperation("Delete Charter")
        AppLogger.view.info("Deleting charter with ID: \(charterID.uuidString)")
        
        do {
            try await charterStore.deleteCharter(charterID)
            AppLogger.view.completeOperation("Delete Charter")
        } catch {
            AppLogger.view.failOperation("Delete Charter", error: error)
            throw error
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns charters sorted by start date (most recent first)
    var sortedByDate: [CharterModel] {
        charters.sorted { $0.startDate > $1.startDate }
    }
    
    /// Returns only upcoming charters
    var upcomingCharters: [CharterModel] {
        charters.filter { $0.daysUntilStart >= 0 }
    }
    
    /// Returns only past charters
    var pastCharters: [CharterModel] {
        charters.filter { $0.daysUntilStart < 0 }
    }
}

