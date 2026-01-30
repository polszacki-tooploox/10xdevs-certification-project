//
//  AuthSessionStore.swift
//  BrewGuide
//
//  Persists authentication session state using UserDefaults.
//

import Foundation

/// Protocol for auth session persistence.
protocol AuthSessionStoreProtocol: Sendable {
    @MainActor func isSignedIn() -> Bool
    @MainActor func userId() -> String?
    @MainActor func setSession(userId: String?)
    @MainActor func clearSession()
}

/// Manages authentication session persistence.
@MainActor
final class AuthSessionStore: AuthSessionStoreProtocol {
    static let shared = AuthSessionStore()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let appleUserId = "appleUserId"
    }
    
    // MARK: - AuthSessionStoreProtocol
    
    func isSignedIn() -> Bool {
        userId() != nil
    }
    
    func userId() -> String? {
        defaults.string(forKey: Keys.appleUserId)
    }
    
    func setSession(userId: String?) {
        defaults.set(userId, forKey: Keys.appleUserId)
    }
    
    func clearSession() {
        defaults.removeObject(forKey: Keys.appleUserId)
    }
}
