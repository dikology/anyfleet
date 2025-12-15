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
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.appDependencies, dependencies)
                .environment(\.appCoordinator, AppCoordinator())
        }
    }
}
