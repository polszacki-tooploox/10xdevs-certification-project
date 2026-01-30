//
//  ConfirmInputsView.swift
//  BrewGuide
//
//  Confirms brew inputs before starting a session.
//  Screen entry point + dependency wiring + lifecycle hooks.
//

import SwiftUI
import SwiftData

/// Root view for confirming brew inputs before starting a session.
/// Allows user to confirm/modify brew inputs and handles loading state.
struct ConfirmInputsView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: ConfirmInputsViewModel
    
    let initialRecipeId: UUID?
    
    init(initialRecipeId: UUID? = nil) {
        self.initialRecipeId = initialRecipeId
        _viewModel = State(initialValue: ConfirmInputsViewModel())
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading recipe...")
            } else if let viewState = viewModel.viewState {
                ConfirmInputsScreen(
                    state: viewState,
                    onEvent: handleEvent
                )
            } else {
                noRecipeView
            }
        }
        .task {
            await viewModel.onAppear(
                context: modelContext,
                recipeId: initialRecipeId
            )
        }
        .onAppear {
            viewModel.refreshIfSelectionChanged(context: modelContext)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.ui.showsError },
            set: { if !$0 { viewModel.ui.errorMessage = nil } }
        )) {
            Button("OK") {
                viewModel.ui.errorMessage = nil
            }
        } message: {
            if let error = viewModel.ui.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var noRecipeView: some View {
        ContentUnavailableView(
            "No Recipe Available",
            systemImage: "cup.and.saucer",
            description: Text("Please add a recipe to start brewing.")
        )
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(_ event: ConfirmInputsEvent) {
        switch event {
        case .changeRecipeTapped:
            // Navigate to recipe list within the modal's navigation stack
            coordinator.recipesPath.append(RecipesRoute.recipeList)
            
        case .startBrewTapped:
            Task {
                await viewModel.startBrew(coordinator: coordinator)
                
                // If successful, dismiss the confirm inputs modal
                // The brew session modal will be presented by the coordinator
                if !viewModel.ui.showsError {
                    dismiss()
                }
            }
            
        default:
            viewModel.handleEvent(event)
        }
    }
}

#Preview {
    NavigationStack {
        ConfirmInputsView()
    }
    .environment(AppRootCoordinator())
    .modelContainer(PersistenceController.preview.container)
}
