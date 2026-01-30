//
//  SyncStatusStore.swift
//  BrewGuide
//
//  Persists last sync attempt information.
//

import Foundation

/// Protocol for sync status persistence.
protocol SyncStatusStoreProtocol: Sendable {
    @MainActor func lastAttempt() -> SyncAttempt?
    @MainActor func setLastAttempt(_ attempt: SyncAttempt)
    @MainActor func clearLastAttempt()
}

/// Manages sync status persistence.
@MainActor
final class SyncStatusStore: SyncStatusStoreProtocol {
    static let shared = SyncStatusStore()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let lastAttemptTimestamp = "lastSyncAttemptTimestamp"
        static let lastAttemptResult = "lastSyncAttemptResult"
        static let lastAttemptMessage = "lastSyncAttemptMessage"
    }
    
    // MARK: - SyncStatusStoreProtocol
    
    func lastAttempt() -> SyncAttempt? {
        guard let timestamp = defaults.object(forKey: Keys.lastAttemptTimestamp) as? Date,
              let resultRaw = defaults.string(forKey: Keys.lastAttemptResult) else {
            return nil
        }
        
        let result: SyncAttemptResult
        if resultRaw == "success" {
            result = .success
        } else {
            let message = defaults.string(forKey: Keys.lastAttemptMessage) ?? "Sync failed"
            result = .failure(message: message)
        }
        
        return SyncAttempt(timestamp: timestamp, result: result)
    }
    
    func setLastAttempt(_ attempt: SyncAttempt) {
        defaults.set(attempt.timestamp, forKey: Keys.lastAttemptTimestamp)
        
        switch attempt.result {
        case .success:
            defaults.set("success", forKey: Keys.lastAttemptResult)
            defaults.removeObject(forKey: Keys.lastAttemptMessage)
        case .failure(let message):
            defaults.set("failure", forKey: Keys.lastAttemptResult)
            defaults.set(message, forKey: Keys.lastAttemptMessage)
        }
    }
    
    func clearLastAttempt() {
        defaults.removeObject(forKey: Keys.lastAttemptTimestamp)
        defaults.removeObject(forKey: Keys.lastAttemptResult)
        defaults.removeObject(forKey: Keys.lastAttemptMessage)
    }
}
