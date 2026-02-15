//
//  BorderLogApp.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import SwiftUI
import SwiftData

@main
struct BorderLogApp: App {
    var sharedModelContainer: ModelContainer = ModelContainerProvider.makeContainer()

    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
