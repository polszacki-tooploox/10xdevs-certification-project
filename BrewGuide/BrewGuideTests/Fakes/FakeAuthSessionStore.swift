//
//  FakeAuthSessionStore.swift
//  BrewGuideTests
//
//  Fake implementation of AuthSessionStoreProtocol for unit testing.
//

import Foundation
@testable import BrewGuide

/// Fake authentication session store for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeAuthSessionStore: AuthSessionStoreProtocol, @unchecked Sendable {
    // In-memory storage
    private var _userId: String?
    
    // Call tracking
    private(set) var userIdCalls: Int = 0
    private(set) var isSignedInCalls: Int = 0
    private(set) var setSessionCalls: [String?] = []
    private(set) var clearSessionCalls: Int = 0
    
    // MARK: - AuthSessionStoreProtocol
    
    func userId() -> String? {
        userIdCalls += 1
        return _userId
    }
    
    func isSignedIn() -> Bool {
        isSignedInCalls += 1
        return _userId != nil
    }
    
    func setSession(userId: String?) {
        setSessionCalls.append(userId)
        _userId = userId
    }
    
    func clearSession() {
        clearSessionCalls += 1
        _userId = nil
    }
    
    // MARK: - Test Helpers
    
    /// Set the user ID directly (bypasses call tracking)
    func setUserIdDirect(_ userId: String?) {
        _userId = userId
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        userIdCalls = 0
        isSignedInCalls = 0
        setSessionCalls.removeAll()
        clearSessionCalls = 0
    }
}
