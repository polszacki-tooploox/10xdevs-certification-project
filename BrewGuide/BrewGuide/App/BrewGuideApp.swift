//
//  BrewGuideApp.swift
//  BrewGuide
//
//  Created by Przemysław Olszacki on 24/01/2026.
//

import SwiftUI
import SwiftData

@main
struct BrewGuideApp: App {
    /// Shared persistence controller managing SwiftData + CloudKit
    private let persistenceController = PersistenceController.shared

    init() {
        // Seed starter recipes on first launch
        let controller = persistenceController
        Task { @MainActor in
            DatabaseSeeder.seedStarterRecipesIfNeeded(
                in: controller.mainContext
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistenceController.container)
    }
}
