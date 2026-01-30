//
//  DataDeletionRequestView.swift
//  BrewGuide
//
//  Data deletion request flow for synced (cloud) data.
//

import SwiftUI

/// View for requesting deletion of synced data from iCloud.
/// Provides clear information and confirmation before requesting deletion.
struct DataDeletionRequestView: View {
    @State private var viewModel = DataDeletionRequestViewModel()
    
    var body: some View {
        DataDeletionRequestScreen(
            state: viewModel.ui,
            onEvent: handleEvent
        )
        .task {
            await viewModel.onAppear()
        }
    }
    
    private func handleEvent(_ event: DataDeletionRequestEvent) {
        Task {
            switch event {
            case .confirmChanged(let confirmed):
                viewModel.setConfirmed(confirmed)
                
            case .requestDeletionTapped:
                await viewModel.requestDeletion()
            }
        }
    }
}

#Preview {
    NavigationStack {
        DataDeletionRequestView()
    }
}
