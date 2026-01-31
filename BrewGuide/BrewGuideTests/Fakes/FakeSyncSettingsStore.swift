//
//  FakeSyncSettingsStore.swift
//  BrewGuideTests
//
//  Fake implementation of SyncSettingsStoreProtocol for unit testing.
//

import Foundation
@testable import BrewGuide

/// Fake sync settings store for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeSyncSettingsStore: SyncSettingsStoreProtocol {
    // In-memory storage
    private var _syncEnabled: Bool = false
    
    // Call tracking
    private(set) var isSyncEnabledCalls: Int = 0
    private(set) var setSyncEnabledCalls: [Bool] = []
    
    // MARK: - SyncSettingsStoreProtocol
    
    func isSyncEnabled() -> Bool {
        isSyncEnabledCalls += 1
        return _syncEnabled
    }
    
    func setSyncEnabled(_ enabled: Bool) {
        setSyncEnabledCalls.append(enabled)
        _syncEnabled = enabled
    }
    
    // MARK: - Test Helpers
    
    /// Set sync enabled directly (bypasses call tracking)
    func setSyncEnabledDirect(_ enabled: Bool) {
        _syncEnabled = enabled
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        isSyncEnabledCalls = 0
        setSyncEnabledCalls.removeAll()
    }
}
