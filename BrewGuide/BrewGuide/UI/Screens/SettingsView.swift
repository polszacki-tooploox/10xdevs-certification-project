//
//  SettingsView.swift
//  BrewGuide
//
//  Settings tab root: app preferences and account management.
//

import SwiftUI

/// Root view for the Settings tab.
/// Owns view model lifecycle, wires dependencies, and renders SettingsScreen.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        SettingsScreen(
            state: viewModel.ui,
            onEvent: handleEvent
        )
        .task {
            await viewModel.onAppear()
        }
    }
    
    private func handleEvent(_ event: SettingsEvent) {
        Task {
            switch event {
            case .signInTapped:
                await viewModel.signIn()
                
            case .signOutTapped:
                await viewModel.signOut()
                
            case .syncToggleChanged(let enabled):
                await viewModel.setSyncEnabled(enabled)
                
            case .retrySyncTapped:
                await viewModel.retrySync()
                
            case .dataDeletionTapped:
                // Navigation is handled by NavigationLink in DataDeletionEntryRow
                break
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
