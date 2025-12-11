//
//  HomeViewModel.swift
//  anyfleet
//
//  Home screen coordinator for charter/content shortcuts.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    func onCreateCharterTapped() {
        coordinator.push(.createCharter)
    }
}

