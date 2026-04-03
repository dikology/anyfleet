//
//  anyfleetApp.swift
//  anyfleet
//
//  Created by Денис on 12/11/25.
//

import SwiftUI

@main
struct anyfleetApp: App {
    @State private var dependencies: AppDependencies
    @State private var coordinator: AppCoordinator
    @State private var databaseInitError: Error?

    init() {
        if ProcessInfo.processInfo.environment["RESET_SWIPE_ONBOARDING"] == "true" {
            [
                "hasSeenCharterSwipeHint",
                "hasSeenLibrarySwipeHint",
                "hasSeenDiscoverSwipeHint"
            ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        }
        let deps = AppDependencies.shared
        _dependencies = State(initialValue: deps)
        _coordinator = State(initialValue: AppCoordinator(dependencies: deps))
        _databaseInitError = State(initialValue: AppDatabase.initializationError)
    }
    
    var body: some Scene {
        WindowGroup {
            if let dbError = databaseInitError {
                DatabaseUnavailableView(error: dbError) {
                    retryDatabaseInit()
                }
            } else {
                AppView()
                    .environment(\.appDependencies, dependencies)
                    .environment(dependencies.authService)
                    .environment(\.appCoordinator, coordinator)
            }
        }
    }

    @MainActor
    private func retryDatabaseInit() {
        AppDatabase.reset()
        let freshDeps = AppDependencies()
        dependencies = freshDeps
        coordinator = AppCoordinator(dependencies: freshDeps)
        databaseInitError = AppDatabase.initializationError
    }
}
