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
    
    // MARK: - State
    
    var activeCharter: CharterModel?
    var activeCharterChecklistID: UUID?
    var isLoading = false
    
    // MARK: - Initialization
    
    /// Creates a new HomeViewModel.
    ///
    /// - Parameter coordinator: The app coordinator for navigation
    init(coordinator: AppCoordinator,
         charterStore: CharterStore
    ) {
        self.coordinator = coordinator
        self.charterStore = charterStore
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

    /// Refresh home screen data: active charter, auth state, content
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // Ensure charters are loaded before checking for active charter
        if charterStore.charters.isEmpty {
            await charterStore.loadCharters()
        }
        
        // Fetch active charter (latest with today in date range)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        activeCharter = charterStore.charters
            .filter { charter in
                let start = calendar.startOfDay(for: charter.startDate)
                let end = calendar.startOfDay(for: charter.endDate)
                return start <= today && end >= today
            }
            .sorted { $0.startDate > $1.startDate } // Latest first
            .first
        
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
}

