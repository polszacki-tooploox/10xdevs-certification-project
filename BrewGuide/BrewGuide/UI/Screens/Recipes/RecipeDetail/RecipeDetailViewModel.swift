//
//  RecipeDetailViewModel.swift
//  BrewGuide
//
//  View model for recipe detail screen, orchestrating loading and actions.
//

import Foundation
import OSLog

private let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BrewGuide", category: "RecipeDetailViewModel")

// MARK: - View State Types

/// Represents the overall UI state for the recipe detail screen
struct RecipeDetailViewState {
    var isLoading: Bool
    var detail: RecipeDetailDTO?
    var error: RecipeDetailErrorState?
}

/// Error state with user-facing messaging
struct RecipeDetailErrorState {
    let message: String
    let isRetryable: Bool
}

/// Action error (separate from load errors)
struct RecipeDetailActionError: Identifiable {
    let id = UUID()
    let message: String
}

/// Pending deletion state for confirmation dialog
struct RecipeDetailPendingDeletion: Identifiable {
    let id = UUID()
    let recipeId: UUID
    let recipeName: String
}

// MARK: - View Model

/// Orchestrates recipe detail loading, validation, and actions (use/duplicate/edit/delete).
@MainActor
@Observable
final class RecipeDetailViewModel {
    // MARK: - Identity
    
    let recipeId: UUID
    
    // MARK: - State
    
    private(set) var state: RecipeDetailViewState
    private(set) var pendingDeletion: RecipeDetailPendingDeletion?
    private(set) var actionError: RecipeDetailActionError?
    private(set) var isPerformingAction: Bool = false
    
    // MARK: - Dependencies
    
    private let repository: RecipeRepository
    private let preferences: PreferencesStore
    
    // MARK: - Derived UI Flags
    
    /// Whether "Use this recipe" should be enabled
    var canUseRecipe: Bool {
        guard let detail = state.detail else { return false }
        return detail.recipe.isValid
    }
    
    /// Whether Edit action should be available (custom recipes only)
    var canEdit: Bool {
        guard let detail = state.detail else { return false }
        return !detail.recipe.isStarter && detail.recipe.origin != .starterTemplate
    }
    
    /// Whether Delete action should be available (custom recipes only)
    var canDelete: Bool {
        guard let detail = state.detail else { return false }
        return !detail.recipe.isStarter && detail.recipe.origin != .starterTemplate
    }
    
    /// Whether Duplicate action should be available (always true for loaded recipes)
    var canDuplicate: Bool {
        state.detail != nil
    }
    
    // MARK: - Initialization
    
    init(
        recipeId: UUID,
        repository: RecipeRepository,
        preferences: PreferencesStore = .shared
    ) {
        self.recipeId = recipeId
        self.repository = repository
        self.preferences = preferences
        self.state = RecipeDetailViewState(
            isLoading: false,
            detail: nil,
            error: nil
        )
    }
    
    // MARK: - Loading
    
    /// Load recipe detail from repository
    func load() async {
        state.isLoading = true
        state.error = nil
        
        do {
            guard let recipe = try repository.fetchRecipe(byId: recipeId) else {
                state.isLoading = false
                state.error = RecipeDetailErrorState(
                    message: "Recipe not found. It may have been deleted.",
                    isRetryable: false
                )
                return
            }
            
            let validationErrors = repository.validate(recipe)
            let isValid = validationErrors.isEmpty
            let detail = recipe.toDetailDTO(isValid: isValid)
            
            state.isLoading = false
            state.detail = detail
            
        } catch {
            os_log(.error, log: logger, "Failed to load recipe: %@", error.localizedDescription)
            state.isLoading = false
            state.error = RecipeDetailErrorState(
                message: "Failed to load recipe. Please try again.",
                isRetryable: true
            )
        }
    }
    
    // MARK: - Actions
    
    /// Select this recipe for brewing
    func useRecipe() {
        preferences.lastSelectedRecipeId = recipeId
    }
    
    /// Request deletion (shows confirmation dialog)
    func requestDelete() {
        guard let detail = state.detail else { return }
        pendingDeletion = RecipeDetailPendingDeletion(
            recipeId: detail.recipe.id,
            recipeName: detail.recipe.name
        )
    }
    
    /// Cancel deletion
    func cancelDelete() {
        pendingDeletion = nil
    }
    
    /// Confirm and execute deletion
    /// - Returns: `true` if successful (caller should navigate away)
    func confirmDelete() async -> Bool {
        guard let pending = pendingDeletion else { return false }
        
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            guard let recipe = try repository.fetchRecipe(byId: pending.recipeId) else {
                actionError = RecipeDetailActionError(
                    message: "Recipe not found."
                )
                pendingDeletion = nil
                return false
            }
            
            try repository.deleteCustomRecipe(recipe)
            try repository.save()
            
            pendingDeletion = nil
            return true
            
        } catch RecipeRepositoryError.cannotDeleteStarterRecipe {
            actionError = RecipeDetailActionError(
                message: "Starter recipes cannot be deleted."
            )
            pendingDeletion = nil
            return false
            
        } catch {
            os_log(.error, log: logger, "Failed to delete recipe: %@", error.localizedDescription)
            actionError = RecipeDetailActionError(
                message: "Failed to delete recipe. Please try again."
            )
            pendingDeletion = nil
            return false
        }
    }
    
    /// Duplicate this recipe
    /// - Returns: New recipe ID if successful
    func duplicateRecipe() async -> UUID? {
        guard state.detail != nil else { return nil }
        
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            guard let recipe = try repository.fetchRecipe(byId: recipeId) else {
                actionError = RecipeDetailActionError(
                    message: "Recipe not found."
                )
                return nil
            }
            
            let newRecipe = try repository.duplicate(recipe)
            try repository.save()
            
            return newRecipe.id
            
        } catch {
            os_log(.error, log: logger, "Failed to duplicate recipe: %@", error.localizedDescription)
            actionError = RecipeDetailActionError(
                message: "Failed to duplicate recipe. Please try again."
            )
            return nil
        }
    }
    
    /// Clear action error
    func clearActionError() {
        actionError = nil
    }
}
