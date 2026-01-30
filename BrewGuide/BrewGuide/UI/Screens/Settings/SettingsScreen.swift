//
//  SettingsScreen.swift
//  BrewGuide
//
//  Pure rendering component for Settings.
//

import SwiftUI

/// Pure SwiftUI renderer for the settings screen.
/// Emits user intent via events/callbacks.
struct SettingsScreen: View {
    let state: SettingsViewState
    let onEvent: (SettingsEvent) -> Void
    
    var body: some View {
        List {
            // Inline message banner (if present)
            if let message = state.inlineMessage {
                Section {
                    InlineMessageBanner(message: message) {
                        onEvent(.dataDeletionTapped) // Dummy event; could add dismissMessage event
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Sync section
            Section("Sync (optional)") {
                // Sign in or Sign out row
                if state.isSignedIn {
                    SignOutRow(
                        isEnabled: !state.isPerformingAuth && !state.isSyncInProgress,
                        onTap: { onEvent(.signOutTapped) }
                    )
                } else {
                    SignInRow(
                        isEnabled: !state.isPerformingAuth,
                        onTap: { onEvent(.signInTapped) }
                    )
                }
                
                // Sync enabled toggle
                SyncEnabledToggleRow(
                    isSignedIn: state.isSignedIn,
                    syncEnabled: state.syncEnabled,
                    isBusy: state.isSyncInProgress,
                    onChange: { onEvent(.syncToggleChanged($0)) }
                )
                
                // Sync status
                SyncStatusRow(status: state.syncStatus)
                
                // Retry sync
                RetrySyncRow(
                    isEnabled: state.isSignedIn && state.syncEnabled,
                    isInProgress: state.isSyncInProgress,
                    isSignedIn: state.isSignedIn,
                    syncEnabled: state.syncEnabled,
                    onTap: { onEvent(.retrySyncTapped) }
                )
            }
            
            // Privacy section
            Section("Privacy") {
                DataDeletionEntryRow()
            }
            
            // About section
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Preview

#Preview("Signed Out") {
    NavigationStack {
        SettingsScreen(
            state: SettingsViewState(
                isSignedIn: false,
                syncEnabled: false,
                syncStatus: SyncStatusDisplay(
                    mode: .localOnly,
                    lastAttempt: nil,
                    lastFailureMessage: nil
                ),
                isPerformingAuth: false,
                isSyncInProgress: false,
                inlineMessage: nil
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Signed In - Sync Enabled") {
    NavigationStack {
        SettingsScreen(
            state: SettingsViewState(
                isSignedIn: true,
                syncEnabled: true,
                syncStatus: SyncStatusDisplay(
                    mode: .syncEnabled,
                    lastAttempt: SyncAttemptDisplay(
                        timestamp: Date(),
                        result: .success
                    ),
                    lastFailureMessage: nil
                ),
                isPerformingAuth: false,
                isSyncInProgress: false,
                inlineMessage: nil
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Sync Failure") {
    NavigationStack {
        SettingsScreen(
            state: SettingsViewState(
                isSignedIn: true,
                syncEnabled: true,
                syncStatus: SyncStatusDisplay(
                    mode: .syncEnabled,
                    lastAttempt: SyncAttemptDisplay(
                        timestamp: Date().addingTimeInterval(-300),
                        result: .failure
                    ),
                    lastFailureMessage: "Network unavailable. Check your connection."
                ),
                isPerformingAuth: false,
                isSyncInProgress: false,
                inlineMessage: InlineMessage(
                    kind: .error,
                    text: "Sync failed. Please try again."
                )
            ),
            onEvent: { _ in }
        )
    }
}
