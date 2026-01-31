//
//  FakeSyncStatusStore.swift
//  BrewGuideTests
//
//  Fake implementation of SyncStatusStoreProtocol for unit testing.
//

import Foundation
@testable import BrewGuide

/// Fake sync status store for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeSyncStatusStore: SyncStatusStoreProtocol, @unchecked Sendable {
    // In-memory storage
    private var _lastAttempt: SyncAttempt?
    
    // Call tracking
    private(set) var lastAttemptCalls: Int = 0
    private(set) var setLastAttemptCalls: [SyncAttempt] = []
    
    // MARK: - SyncStatusStoreProtocol
    
    func lastAttempt() -> SyncAttempt? {
        lastAttemptCalls += 1
        return _lastAttempt
    }
    
    func setLastAttempt(_ attempt: SyncAttempt) {
        setLastAttemptCalls.append(attempt)
        _lastAttempt = attempt
    }
    
    func clearLastAttempt() {
        _lastAttempt = nil
    }
    
    // MARK: - Test Helpers
    
    /// Set last attempt directly (bypasses call tracking)
    func setLastAttemptDirect(_ attempt: SyncAttempt?) {
        _lastAttempt = attempt
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        lastAttemptCalls = 0
        setLastAttemptCalls.removeAll()
    }
}
