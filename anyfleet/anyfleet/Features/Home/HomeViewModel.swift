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
    
    // MARK: - State
    
    // Future: Add state properties for home screen content
    // var recentCharters: [CharterModel] = []
    // var isLoading = false
    
    // MARK: - Initialization
    
    /// Creates a new HomeViewModel.
    ///
    /// - Parameter coordinator: The app coordinator for navigation
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
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
}

