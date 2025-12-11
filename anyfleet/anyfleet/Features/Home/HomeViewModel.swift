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
    private let appModel: AppModel

    init(appModel: AppModel) {
        self.appModel = appModel
    }
    
    func onCreateCharterTapped() {
        appModel.navigate(to: .createCharter)
    }
}

