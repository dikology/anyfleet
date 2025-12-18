//
//  anyfleetApp.swift
//  anyfleet
//
//  Created by Денис on 12/11/25.
//

import SwiftUI

@main
struct anyfleetApp: App {
    @State private var dependencies = AppDependencies()
    @StateObject private var coordinator: AppCoordinator
    
    init() {
        let deps = AppDependencies()
        _dependencies = State(initialValue: deps)
        _coordinator = StateObject(wrappedValue: AppCoordinator(dependencies: deps))
    }
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.appDependencies, dependencies)
                .environmentObject(coordinator)
        }
    }
}
