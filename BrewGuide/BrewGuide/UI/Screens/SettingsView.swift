//
//  SettingsView.swift
//  BrewGuide
//
//  Settings tab root: app preferences and account management.
//

import SwiftUI

/// Root view for the Settings tab.
/// Provides access to preferences, account settings, and data management.
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                Button("Sign In") {
                    // TODO: Implement sign-in flow
                }
                
                Button("Sync Status") {
                    // TODO: Navigate to sync status screen
                }
            }
            
            Section("Data") {
                NavigationLink(value: SettingsRoute.dataDeletionRequest) {
                    Label("Request Data Deletion", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
            
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
