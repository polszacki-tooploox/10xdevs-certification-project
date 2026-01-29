//
//  RecipeDetailView.swift
//  BrewGuide
//
//  Displays a single recipe's details with defaults, steps, and actions.
//

import SwiftUI
import SwiftData

/// Main screen entry for recipe detail view.
/// Displays recipe defaults, steps, and provides Use/Duplicate/Edit/Delete actions.
struct RecipeDetailView: View {
    let recipeId: UUID
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRootCoordinator.self) private var coordinator
    
    @State private var viewModel: RecipeDetailViewModel?
    @State private var showInvalidRecipeAlert = false
    
    var body: some View {
        Group {
            if let viewModel {
                RecipeDetailScreen(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            RecipeDetailToolbarActions(
                                summary: viewModel.state.detail?.recipe,
                                isPerformingAction: viewModel.isPerformingAction,
                                onDuplicate: {
                                    Task {
                                        await handleDuplicate()
                                    }
                                },
                                onEdit: {
                                    handleEdit()
                                },
                                onRequestDelete: {
                                    viewModel.requestDelete()
                                }
                            )
                        }
                    }
                    .confirmationDialog(
                        "Delete Recipe?",
                        isPresented: .constant(viewModel.pendingDeletion != nil),
                        presenting: viewModel.pendingDeletion
                    ) { pending in
                        Button("Delete", role: .destructive) {
                            Task {
                                await handleDeleteConfirmation()
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            viewModel.cancelDelete()
                        }
                    } message: { pending in
                        Text("Are you sure you want to delete \"\(pending.recipeName)\"? This cannot be undone.")
                    }
                    .alert(
                        "Action Failed",
                        isPresented: .constant(viewModel.actionError != nil),
                        presenting: viewModel.actionError
                    ) { error in
                        Button("OK") {
                            viewModel.clearActionError()
                        }
                    } message: { error in
                        Text(error.message)
                    }
                    .alert(
                        "Cannot Use Recipe",
                        isPresented: $showInvalidRecipeAlert
                    ) {
                        if viewModel.canEdit {
                            Button("Edit Recipe") {
                                handleEdit()
                            }
                            Button("Cancel", role: .cancel) {}
                        } else {
                            Button("OK", role: .cancel) {}
                        }
                    } message: {
                        Text("This recipe has validation errors and cannot be used for brewing. Please fix the issues first.")
                    }
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let repository = RecipeRepository(context: modelContext)
                viewModel = RecipeDetailViewModel(
                    recipeId: recipeId,
                    repository: repository
                )
                await viewModel?.load()
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleUseRecipe() {
        guard let viewModel else { return }
        
        if viewModel.canUseRecipe {
            viewModel.useRecipe()
            dismiss()
        } else {
            showInvalidRecipeAlert = true
        }
    }
    
    private func handleDuplicate() async {
        guard let viewModel else { return }
        
        if let newRecipeId = await viewModel.duplicateRecipe() {
            // Navigate to edit screen for the new recipe
            coordinator.recipesPath.append(RecipesRoute.recipeEdit(id: newRecipeId))
        }
    }
    
    private func handleEdit() {
        coordinator.recipesPath.append(RecipesRoute.recipeEdit(id: recipeId))
    }
    
    private func handleDeleteConfirmation() async {
        guard let viewModel else { return }
        
        let success = await viewModel.confirmDelete()
        if success {
            dismiss()
        }
    }
}

// MARK: - Recipe Detail Screen

/// Pure rendering based on view model state
private struct RecipeDetailScreen: View {
    @Bindable var viewModel: RecipeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if viewModel.state.isLoading && viewModel.state.detail == nil {
                // Initial loading
                ProgressView("Loading recipe...")
            } else if let error = viewModel.state.error {
                // Error state
                ContentUnavailableView {
                    Label("Error Loading Recipe", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.message)
                } actions: {
                    if error.isRetryable {
                        Button("Retry") {
                            Task {
                                await viewModel.load()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else if let detail = viewModel.state.detail {
                // Loaded content
                RecipeDetailContent(
                    detail: detail,
                    isUseEnabled: viewModel.canUseRecipe,
                    onUse: {
                        handleUseRecipe()
                    }
                )
                .refreshable {
                    await viewModel.load()
                }
            } else {
                // Fallback empty state
                ContentUnavailableView(
                    "No Recipe",
                    systemImage: "cup.and.saucer",
                    description: Text("Recipe information is not available.")
                )
            }
        }
    }
    
    private func handleUseRecipe() {
        if viewModel.canUseRecipe {
            viewModel.useRecipe()
            dismiss()
        }
    }
}

// MARK: - Recipe Detail Content

/// Scrollable content showing recipe details
private struct RecipeDetailContent: View {
    let detail: RecipeDetailDTO
    let isUseEnabled: Bool
    let onUse: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with name and badges
                RecipeHeader(summary: detail.recipe)
                    .padding(.horizontal)
                
                // Defaults summary card
                DefaultsSummaryCard(detail: detail)
                    .padding(.horizontal)
                
                // Steps section
                if !detail.steps.isEmpty {
                    StepsSection(
                        steps: detail.steps,
                        defaultTargetYield: detail.recipe.defaultTargetYield
                    )
                    .padding(.horizontal)
                }
                
                // Bottom spacing so CTA doesn't overlap
                Color.clear.frame(height: 80)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            PrimaryActionBar(
                isEnabled: isUseEnabled,
                onUse: onUse
            )
        }
    }
}

// MARK: - Preview

#Preview("Loaded Recipe") {
    NavigationStack {
        RecipeDetailView(recipeId: UUID())
    }
    .environment(AppRootCoordinator())
    .modelContainer(PersistenceController.preview.container)
}
