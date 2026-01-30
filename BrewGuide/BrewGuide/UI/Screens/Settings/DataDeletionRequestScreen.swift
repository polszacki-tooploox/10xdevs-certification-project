//
//  DataDeletionRequestScreen.swift
//  BrewGuide
//
//  Pure rendering component for data deletion request.
//

import SwiftUI

/// Pure SwiftUI renderer for the data deletion request screen.
/// Emits user intent via events/callbacks.
struct DataDeletionRequestScreen: View {
    let state: DataDeletionRequestViewState
    let onEvent: (DataDeletionRequestEvent) -> Void
    
    var body: some View {
        List {
            // Warning icon and title
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("Request Deletion of Synced Data")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            
            // Explanation section
            Section("What This Does") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This requests deletion of your synced BrewGuide data from iCloud.")
                        .font(.body)
                    
                    Text("Data deleted:")
                        .font(.subheadline)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        bulletPoint("Custom recipes")
                        bulletPoint("Brew logs")
                        bulletPoint("Basic preferences (e.g., last selected recipe)")
                    }
                    .padding(.leading)
                    
                    Text("What remains:")
                        .font(.subheadline)
                        .bold()
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        bulletPoint("The app can still be used locally")
                        bulletPoint("Local data on this device is not automatically deleted")
                        bulletPoint("You can continue brewing without sync")
                    }
                    .padding(.leading)
                }
            }
            
            // Requirements and limitations
            Section("Requirements") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.blue)
                        Text("You must be signed in to request cloud data deletion.")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("Deletion may take time and depends on connectivity.")
                    }
                    
                    if !state.isSignedIn {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Sign in from Settings to proceed.")
                                .bold()
                        }
                        .padding(.top, 4)
                    }
                }
                .font(.callout)
            }
            
            // Confirmation section
            if state.isSignedIn {
                Section("Confirmation") {
                    Toggle(
                        "I understand and want to request deletion",
                        isOn: .init(
                            get: { state.confirmation == .confirmed },
                            set: { onEvent(.confirmChanged($0)) }
                        )
                    )
                    .disabled(state.isSubmitting)
                }
            }
            
            // Primary action section
            if state.isSignedIn {
                Section {
                    Button {
                        onEvent(.requestDeletionTapped)
                    } label: {
                        HStack {
                            Spacer()
                            if state.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Request Deletion")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(state.confirmation != .confirmed || state.isSubmitting)
                    .foregroundStyle(.red)
                    .listRowBackground(
                        state.confirmation == .confirmed && !state.isSubmitting
                            ? Color.red.opacity(0.1)
                            : Color.clear
                    )
                }
            }
            
            // Result section
            if let result = state.result {
                Section {
                    switch result {
                    case .success(let message):
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Request Sent")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                
                                Text(message)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                    case .failure(let message):
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Request Failed")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                
                                Text(message)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Delete Synced Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.callout)
    }
}

// MARK: - Preview

#Preview("Signed Out") {
    NavigationStack {
        DataDeletionRequestScreen(
            state: DataDeletionRequestViewState(
                isSignedIn: false,
                syncEnabled: false,
                confirmation: .notConfirmed,
                isSubmitting: false,
                result: nil
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Signed In - Not Confirmed") {
    NavigationStack {
        DataDeletionRequestScreen(
            state: DataDeletionRequestViewState(
                isSignedIn: true,
                syncEnabled: true,
                confirmation: .notConfirmed,
                isSubmitting: false,
                result: nil
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Signed In - Confirmed") {
    NavigationStack {
        DataDeletionRequestScreen(
            state: DataDeletionRequestViewState(
                isSignedIn: true,
                syncEnabled: true,
                confirmation: .confirmed,
                isSubmitting: false,
                result: nil
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Success") {
    NavigationStack {
        DataDeletionRequestScreen(
            state: DataDeletionRequestViewState(
                isSignedIn: true,
                syncEnabled: false,
                confirmation: .confirmed,
                isSubmitting: false,
                result: .success(message: "Request sent. Sync has been turned off to prevent re-upload.")
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Failure") {
    NavigationStack {
        DataDeletionRequestScreen(
            state: DataDeletionRequestViewState(
                isSignedIn: true,
                syncEnabled: true,
                confirmation: .confirmed,
                isSubmitting: false,
                result: .failure(message: "Network is unavailable. Please try again.")
            ),
            onEvent: { _ in }
        )
    }
}
