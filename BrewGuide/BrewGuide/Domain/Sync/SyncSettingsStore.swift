//
//  SyncSettingsStore.swift
//  BrewGuide
//
//  Persists sync settings (whether sync is enabled).
//

import Foundation

/// Protocol for sync settings persistence.
protocol SyncSettingsStoreProtocol: Sendable {
    @MainActor func isSyncEnabled() -> Bool
    @MainActor func setSyncEnabled(_ enabled: Bool)
}

/// Manages sync settings persistence.
@MainActor
final class SyncSettingsStore: SyncSettingsStoreProtocol {
    static let shared = SyncSettingsStore()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let syncEnabled = "syncEnabled"
    }
    
    // MARK: - SyncSettingsStoreProtocol
    
    func isSyncEnabled() -> Bool {
        defaults.bool(forKey: Keys.syncEnabled)
    }
    
    func setSyncEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.syncEnabled)
    }
}
