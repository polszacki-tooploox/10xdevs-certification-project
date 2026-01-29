//
//  RecipeListView.swift
//  BrewGuide
//
//  Full recipe list view (navigable from ConfirmInputsView).
//

import SwiftUI
import SwiftData

/// Displays all recipes organized by origin (starter/custom).
/// Allows navigation to recipe detail, selection for brewing, and deletion of custom recipes.
struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRootCoordinator.self) private var coordinator
    
    @State private var viewModel: RecipeListViewModel?
    
    var body: some View {
        Group {
            if let viewModel {
                RecipeListLoadedView(viewModel: viewModel, dismiss: dismiss, coordinator: coordinator)
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Recipe", systemImage: "plus") {
                    // TODO: Navigate to recipe creation
                }
                .disabled(viewModel?.isLoading ?? true)
            }
        }
        .task {
            if viewModel == nil {
                let repository = RecipeRepository(context: modelContext)
                viewModel = RecipeListViewModel(repository: repository)
                await viewModel?.load()
            }
        }
    }
}

// MARK: - Loaded View

/// View shown once ViewModel is initialized
private struct RecipeListLoadedView: View {
    @Bindable var viewModel: RecipeListViewModel
    let dismiss: DismissAction
    let coordinator: AppRootCoordinator
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                // Initial loading state
                ProgressView("Loading recipes...")
            } else if let errorState = viewModel.errorState {
                // Error state
                ContentUnavailableView {
                    Label("Error Loading Recipes", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorState.message)
                } actions: {
                    Button("Retry") {
                        Task {
                            await viewModel.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.sections.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Recipes",
                    systemImage: "cup.and.saucer",
                    description: Text("No recipes found for this brew method.")
                )
            } else {
                // Recipe list
                RecipeListContent(
                    sections: viewModel.sections,
                    onTapRecipe: { id in
                        coordinator.recipesPath.append(RecipesRoute.recipeDetail(id: id))
                    },
                    onUseRecipe: { id in
                        viewModel.useRecipe(id: id)
                        // Return to ConfirmInputsView
                        dismiss()
                    },
                    onRequestDelete: { id in
                        if let recipe = viewModel.sections.all.first(where: { $0.id == id }) {
                            viewModel.requestDelete(recipe)
                        }
                    }
                )
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: .constant(viewModel.pendingDelete != nil),
            presenting: viewModel.pendingDelete
        ) { recipe in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: { recipe in
            Text("Are you sure you want to delete \(recipe.name)? This cannot be undone.")
        }
    }
}

// MARK: - Recipe List Content

/// Pure rendering of the recipe list based on sections
private struct RecipeListContent: View {
    let sections: RecipeListSections
    let onTapRecipe: (UUID) -> Void
    let onUseRecipe: (UUID) -> Void
    let onRequestDelete: (UUID) -> Void
    
    var body: some View {
        List {
            if !sections.starter.isEmpty {
                Section("Starter") {
                    ForEach(sections.starter) { recipe in
                        RecipeListRow(
                            recipe: recipe,
                            onTap: { onTapRecipe(recipe.id) },
                            onUse: { onUseRecipe(recipe.id) },
                            onRequestDelete: nil // Starter recipes cannot be deleted
                        )
                    }
                }
            }
            
            if !sections.custom.isEmpty {
                Section("My Recipes") {
                    ForEach(sections.custom) { recipe in
                        RecipeListRow(
                            recipe: recipe,
                            onTap: { onTapRecipe(recipe.id) },
                            onUse: { onUseRecipe(recipe.id) },
                            onRequestDelete: { onRequestDelete(recipe.id) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecipeListView()
    }
    .environment(AppRootCoordinator())
    .modelContainer(PersistenceController.preview.container)
}
