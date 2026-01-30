//
//  ConfirmInputsFlowView.swift
//  BrewGuide
//
//  Modal root wrapper for the confirm inputs flow with its own navigation stack.
//

import SwiftUI
import SwiftData

/// Modal wrapper for the confirm inputs flow.
/// Provides its own navigation stack to handle recipe selection within the modal.
struct ConfirmInputsFlowView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let presentation: ConfirmInputsPresentation
    
    var body: some View {
        NavigationStack {
            ConfirmInputsView(initialRecipeId: presentation.recipeId)
                .navigationTitle("Brew")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
        .onDisappear {
            // Clean up coordinator state when dismissed
            coordinator.dismissConfirmInputs()
        }
    }
}
