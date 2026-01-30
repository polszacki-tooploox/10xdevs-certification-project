//
//  SettingsViewState.swift
//  BrewGuide
//
//  View state models for SettingsView.
//

import Foundation

// MARK: - Main State

/// View state for SettingsView.
struct SettingsViewState: Equatable {
    var isSignedIn: Bool
    var syncEnabled: Bool
    var syncStatus: SyncStatusDisplay
    var isPerformingAuth: Bool
    var isSyncInProgress: Bool
    var inlineMessage: InlineMessage?
}

// MARK: - Sync Status

/// Display model for sync status.
struct SyncStatusDisplay: Equatable {
    var mode: SyncModeDisplay
    var lastAttempt: SyncAttemptDisplay?
    var lastFailureMessage: String?
}

/// Sync mode display values.
enum SyncModeDisplay: Equatable {
    case localOnly
    case syncEnabled
}

/// Display model for a sync attempt.
struct SyncAttemptDisplay: Equatable {
    var timestamp: Date
    var result: SyncAttemptResultDisplay
}

/// Result of a sync attempt for display.
enum SyncAttemptResultDisplay: Equatable {
    case success
    case failure
}

// MARK: - Inline Message

/// Non-blocking inline message.
struct InlineMessage: Equatable {
    var kind: InlineMessageKind
    var text: String
}

/// Kind of inline message.
enum InlineMessageKind: Equatable {
    case info
    case warning
    case error
}

// MARK: - Events

/// Events emitted from SettingsScreen.
enum SettingsEvent {
    case signInTapped
    case signOutTapped
    case syncToggleChanged(Bool)
    case retrySyncTapped
    case dataDeletionTapped
}
