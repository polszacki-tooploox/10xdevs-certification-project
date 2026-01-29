//
//  RecipeListViewModel.swift
//  BrewGuide
//
//  ViewModel for RecipeListView - manages loading, grouping, selection, and deletion.
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "RecipeListViewModel")

// MARK: - Helper Types

/// Grouped recipe sections for the list view
struct RecipeListSections: Equatable {
    let starter: [RecipeSummaryDTO]
    let custom: [RecipeSummaryDTO]
    
    var all: [RecipeSummaryDTO] {
        starter + custom
    }
    
    var isEmpty: Bool {
        starter.isEmpty && custom.isEmpty
    }
}

/// Error states for recipe list operations
enum RecipeListErrorState: Equatable {
    case loadFailed(message: String)
    case deleteFailed(message: String)
    
    var message: String {
        switch self {
        case .loadFailed(let msg), .deleteFailed(let msg):
            return msg
        }
    }
}

// MARK: - ViewModel

/// Observable view-model for recipe list screen
/// Handles loading, grouping, selection, and delete flows using repositories + preferences
@Observable
@MainActor
final class RecipeListViewModel {
    // MARK: - State
    
    /// Current brew method filter (default to V60 for MVP)
    private(set) var method: BrewMethod
    
    /// Grouped recipe sections (starter + custom)
    private(set) var sections: RecipeListSections
    
    /// Loading state
    private(set) var isLoading: Bool
    
    /// Error state
    private(set) var errorState: RecipeListErrorState?
    
    /// Pending delete recipe (triggers confirmation dialog)
    private(set) var pendingDelete: RecipeSummaryDTO?
    
    /// Deleting state (prevents multiple deletion attempts)
    private(set) var isDeleting: Bool
    
    // MARK: - Dependencies
    
    private let preferences: PreferencesStore
    private let repository: RecipeRepository
    
    // MARK: - Init
    
    init(
        method: BrewMethod = .v60,
        preferences: PreferencesStore = .shared,
        repository: RecipeRepository
    ) {
        self.method = method
        self.sections = RecipeListSections(starter: [], custom: [])
        self.isLoading = false
        self.errorState = nil
        self.pendingDelete = nil
        self.isDeleting = false
        self.preferences = preferences
        self.repository = repository
    }
    
    // MARK: - Actions
    
    /// Load recipes for the current method
    func load() async {
        isLoading = true
        errorState = nil
        
        do {
            let recipes = try repository.fetchRecipes(for: method)
            
            // Map to DTOs with validation
            let dtos = recipes.map { recipe -> RecipeSummaryDTO in
                let validationErrors = repository.validate(recipe)
                let isValid = validationErrors.isEmpty
                return recipe.toSummaryDTO(isValid: isValid)
            }
            
            // Group by origin
            let starterRecipes = dtos
                .filter { $0.isStarter || $0.origin == .starterTemplate }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
            let customRecipes = dtos
                .filter { !$0.isStarter && $0.origin != .starterTemplate }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
            sections = RecipeListSections(
                starter: starterRecipes,
                custom: customRecipes
            )
            
            logger.info("Loaded \(dtos.count) recipes: \(starterRecipes.count) starter, \(customRecipes.count) custom")
            
        } catch {
            logger.error("Failed to load recipes: \(error.localizedDescription)")
            errorState = .loadFailed(message: "Could not load recipes. Please try again.")
        }
        
        isLoading = false
    }
    
    /// Mark a recipe for use and persist selection
    func useRecipe(id: UUID) {
        preferences.lastSelectedRecipeId = id
        logger.info("Selected recipe \(id.uuidString) for brewing")
    }
    
    /// Request deletion of a recipe (triggers confirmation dialog)
    func requestDelete(_ recipe: RecipeSummaryDTO) {
        guard !recipe.isStarter && recipe.origin != .starterTemplate else {
            logger.warning("Attempted to delete starter recipe \(recipe.id.uuidString)")
            return
        }
        
        pendingDelete = recipe
    }
    
    /// Cancel pending delete request
    func cancelDelete() {
        pendingDelete = nil
    }
    
    /// Confirm and execute recipe deletion
    func confirmDelete() async {
        guard let recipeToDelete = pendingDelete else { return }
        
        isDeleting = true
        errorState = nil
        
        do {
            // Fetch the recipe entity
            guard let recipe = try repository.fetchRecipe(byId: recipeToDelete.id) else {
                logger.warning("Recipe \(recipeToDelete.id.uuidString) not found for deletion")
                // Treat as success - already gone
                pendingDelete = nil
                await load()
                return
            }
            
            // Delete the recipe
            try repository.deleteCustomRecipe(recipe)
            try repository.save()
            
            logger.info("Deleted recipe \(recipeToDelete.id.uuidString)")
            
            // Clear selection if deleted recipe was selected
            if preferences.lastSelectedRecipeId == recipeToDelete.id {
                // Set to first starter recipe if available
                if let starterRecipe = sections.starter.first {
                    preferences.lastSelectedRecipeId = starterRecipe.id
                    logger.info("Cleared deleted recipe from selection, reset to starter recipe")
                } else {
                    preferences.lastSelectedRecipeId = nil
                    logger.info("Cleared deleted recipe from selection")
                }
            }
            
            // Clear pending delete
            pendingDelete = nil
            
            // Reload list
            await load()
            
        } catch {
            logger.error("Failed to delete recipe: \(error.localizedDescription)")
            errorState = .deleteFailed(message: "Could not delete recipe. Please try again.")
            pendingDelete = nil
        }
        
        isDeleting = false
    }
    
    /// Retry after error
    func retry() async {
        await load()
    }
}
