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
    
    private let useCase: RecipeUseCaseProtocol
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
        return useCase.canEdit(recipe: detail.recipe)
    }
    
    /// Whether Delete action should be available (custom recipes only)
    var canDelete: Bool {
        guard let detail = state.detail else { return false }
        return useCase.canDelete(recipe: detail.recipe)
    }
    
    /// Whether Duplicate action should be available (always true for loaded recipes)
    var canDuplicate: Bool {
        state.detail != nil
    }
    
    // MARK: - Initialization
    
    init(
        recipeId: UUID,
        useCase: RecipeUseCaseProtocol,
        preferences: PreferencesStore = .shared
    ) {
        self.recipeId = recipeId
        self.useCase = useCase
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
            let detail = try useCase.fetchRecipeDetail(id: recipeId)
            state.isLoading = false
            state.detail = detail
        } catch RecipeUseCaseError.recipeNotFound {
            state.isLoading = false
            state.error = RecipeDetailErrorState(
                message: "Recipe not found. It may have been deleted.",
                isRetryable: false
            )
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
        guard pendingDeletion != nil else { return false }
        
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            try useCase.deleteRecipe(id: recipeId)
            pendingDeletion = nil
            return true
        } catch RecipeUseCaseError.cannotDeleteStarter {
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
            let newRecipeId = try useCase.duplicateRecipe(id: recipeId)
            return newRecipeId
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
