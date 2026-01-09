//
//  HomeViewModel.swift
//  anyfleet
//
//  Home screen coordinator for charter/content shortcuts.
//

import Foundation
import Observation

/// ViewModel for the Home screen.
///
/// Manages navigation actions and future state for home screen shortcuts
/// and content discovery.
///
/// ## Usage
///
/// ```swift
/// struct HomeView: View {
///     @State private var viewModel: HomeViewModel
///
///     var body: some View {
///         // View implementation
///     }
/// }
/// ```
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Dependencies
    
    private let coordinator: AppCoordinator
    private let charterStore: CharterStore
    private let libraryStore: LibraryStore
    
    // MARK: - State

    var isLoading = false

    // MARK: - Derived State

    /// The currently active charter (latest with today in date range)
    var activeCharter: CharterModel? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return charterStore.charters
            .filter { charter in
                let start = calendar.startOfDay(for: charter.startDate)
                let end = calendar.startOfDay(for: charter.endDate)
                return start <= today && end >= today
            }
            .sorted { $0.startDate > $1.startDate } // Latest first
            .first
    }

    var activeCharterChecklistID: UUID?
    
    // MARK: - Initialization
    
    /// Creates a new HomeViewModel.
    ///
    /// - Parameters:
    ///   - coordinator: The app coordinator for navigation
    ///   - charterStore: Store for charter data
    ///   - libraryStore: Store for library content (for pinned items)
    init(
        coordinator: AppCoordinator,
        charterStore: CharterStore,
        libraryStore: LibraryStore
    ) {
        self.coordinator = coordinator
        self.charterStore = charterStore
        self.libraryStore = libraryStore
    }
    
    // MARK: - Derived State
    
    /// Pinned library items for quick access on the home screen.
    /// Sorted by explicit pinned order, then by most recently updated.
    var pinnedLibraryItems: [LibraryModel] {
        libraryStore.library
            .filter { $0.isPinned }
            .sorted { lhs, rhs in
                let leftOrder = lhs.pinnedOrder ?? Int.max
                let rightOrder = rhs.pinnedOrder ?? Int.max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }
    
    // MARK: - Actions
    
    /// Handles the create charter action by navigating to the charter creation flow.
    ///
    /// This performs cross-tab navigation, switching to the charters tab and
    /// presenting the charter creation view.
    func onCreateCharterTapped() {
        AppLogger.view.info("Create charter tapped from home")
        coordinator.navigateToCreateCharter()
    }
    
    /// Handles tapping a pinned library item from the home screen.
    func onPinnedItemTapped(_ item: LibraryModel) {
        AppLogger.view.info("Pinned library item tapped from home: \(item.id)")
        coordinator.selectedTab = .library
        
        switch item.type {
        case .checklist:
            coordinator.viewChecklist(item.id)
        case .practiceGuide:
            coordinator.viewGuide(item.id)
        case .flashcardDeck:
            // TODO: Implement deck reader when ready
            coordinator.editDeck(item.id)
        }
    }

    /// Refresh home screen data: active charter, auth state, content
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure charters are loaded before checking for active charter
        if charterStore.charters.isEmpty {
            try? await charterStore.loadCharters()
        }
        
        // Ensure library content is loaded for pinned items
        if libraryStore.library.isEmpty {
            await libraryStore.loadLibrary()
        }

        AppLogger.view.info("Active charter: \(activeCharter?.name ?? "none")")
        
        // Fetch checkin checklist for active charter if it exists
        // if let charterID = activeCharter?.id {
        //     activeCharterChecklistID = contentStore.myChecklists
        //         .filter { checklist in
        //             checklist.type == .checkin && 
        //             checklist.charterID == charterID
        //         }
        //         .sorted { $0.createdAt > $1.createdAt } // Latest first
        //         .first?.id
            
        //     AppLogger.home.info(
        //         "Active charter checklist: \(activeCharterChecklistID?.uuidString ?? "none")"
        //     )
        // } else {
        //     activeCharterChecklistID = nil
        // }
    }

    func onActiveCharterTapped(_ charter: CharterModel) {
        AppLogger.view.info("Active charter tapped: \(charter.id)")
        coordinator.navigateToCharter(charter.id)
    }
}

