//
//  SettingsComponents.swift
//  BrewGuide
//
//  Reusable components for SettingsScreen.
//

import SwiftUI
import AuthenticationServices

// MARK: - Sign In Row

/// Row component for Sign in with Apple when signed out.
struct SignInRow: View {
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SignInWithAppleButton(.signIn, onRequest: { _ in
                // Request configuration can go here if needed
            }, onCompletion: { _ in
                onTap()
            })
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .disabled(!isEnabled)
            
            Text("You can use the app without signing in. Sign in to enable sync.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sign Out Row

/// Row component for signing out when signed in.
struct SignOutRow: View {
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Sign Out", role: .destructive, action: onTap)
                .disabled(!isEnabled)
            
            Text("Local data stays on this device. Sync will be turned off.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sync Enabled Toggle Row

/// Row component for the sync enabled toggle.
struct SyncEnabledToggleRow: View {
    let isSignedIn: Bool
    let syncEnabled: Bool
    let isBusy: Bool
    let onChange: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Sync enabled", isOn: .init(
                get: { syncEnabled },
                set: { onChange($0) }
            ))
            .disabled(!isSignedIn || isBusy)
            
            if !isSignedIn {
                Text("Sign in to enable sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sync Status Row

/// Row component displaying current sync status and last attempt.
struct SyncStatusRow: View {
    let status: SyncStatusDisplay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .foregroundStyle(statusColor)
            }
            
            if let attempt = status.lastAttempt {
                HStack {
                    Text("Last attempt")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatAttempt(attempt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let failureMessage = status.lastFailureMessage {
                Text(failureMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var statusText: String {
        switch status.mode {
        case .localOnly:
            return "Local only"
        case .syncEnabled:
            return "Sync enabled"
        }
    }
    
    private var statusColor: Color {
        switch status.mode {
        case .localOnly:
            return .secondary
        case .syncEnabled:
            return .green
        }
    }
    
    private func formatAttempt(_ attempt: SyncAttemptDisplay) -> String {
        let dateString = attempt.timestamp.formatted(date: .abbreviated, time: .shortened)
        let resultString = attempt.result == .success ? "Success" : "Failed"
        return "\(dateString) — \(resultString)"
    }
}

// MARK: - Retry Sync Row

/// Row component for manually retrying sync.
struct RetrySyncRow: View {
    let isEnabled: Bool
    let isInProgress: Bool
    let isSignedIn: Bool
    let syncEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onTap()
            } label: {
                HStack {
                    Text("Retry Sync")
                    if isInProgress {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(!isEnabled || isInProgress)
            
            if !isSignedIn {
                Text("Sign in to retry sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !syncEnabled {
                Text("Enable sync to retry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Data Deletion Entry Row

/// Row component for navigating to data deletion request.
struct DataDeletionEntryRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: SettingsRoute.dataDeletionRequest) {
                Label("Request deletion of synced data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            
            Text("This affects cloud-synced data; local-only usage remains available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Inline Message Banner

/// Banner for displaying inline messages (info, warning, error).
struct InlineMessageBanner: View {
    let message: InlineMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            
            Text(message.text)
                .font(.callout)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: 8))
    }
    
    private var iconName: String {
        switch message.kind {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch message.kind {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch message.kind {
        case .info:
            return .blue.opacity(0.1)
        case .warning:
            return .orange.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        }
    }
}
