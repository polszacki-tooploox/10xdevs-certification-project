//
//  PreferencesStore.swift
//  BrewGuide
//
//  UserDefaults-backed preferences storage.
//

import Foundation

/// Manages user preferences using UserDefaults.
@MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let lastSelectedRecipeId = "lastSelectedRecipeId"
        static let hasSeenOnboarding = "hasSeenOnboarding"
    }
    
    // MARK: - Last Selected Recipe
    
    var lastSelectedRecipeId: UUID? {
        get {
            guard let string = defaults.string(forKey: Keys.lastSelectedRecipeId) else {
                return nil
            }
            return UUID(uuidString: string)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: Keys.lastSelectedRecipeId)
        }
    }
    
    // MARK: - Onboarding
    
    var hasSeenOnboarding: Bool {
        get {
            defaults.bool(forKey: Keys.hasSeenOnboarding)
        }
        set {
            defaults.set(newValue, forKey: Keys.hasSeenOnboarding)
        }
    }
    
    // MARK: - Reset
    
    func resetAll() {
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleId)
        }
    }
}
