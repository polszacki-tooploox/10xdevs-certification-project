//
//  SyncTypes.swift
//  BrewGuide
//
//  Sync domain types and protocols.
//

import Foundation

/// Sync errors.
enum SyncError: LocalizedError, Equatable {
    case notSignedIn
    case networkUnavailable
    case cloudKitError(message: String)
    case unknown(message: String)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to sync."
        case .networkUnavailable:
            return "Network is unavailable. Check your connection."
        case .cloudKitError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}

/// Result of a sync attempt.
enum SyncAttemptResult: Equatable, Sendable {
    case success
    case failure(message: String)
}

/// Record of a sync attempt.
struct SyncAttempt: Equatable, Sendable {
    let timestamp: Date
    let result: SyncAttemptResult
}

/// Protocol for sync operations.
protocol SyncUseCaseProtocol: Sendable {
    @MainActor func enableSync() async -> Result<Void, SyncError>
    @MainActor func disableSync() async
    @MainActor func syncNow() async -> Result<Void, SyncError>
    @MainActor func requestDataDeletion() async -> Result<Void, SyncError>
}
