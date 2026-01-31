//
//  RecipeListUseCase.swift
//  BrewGuide
//
//  Orchestrates recipe list operations with business logic for grouping and deletion.
//

import Foundation
import SwiftData

/// Sections for recipe list display
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

protocol RecipeListUseCaseProtocol: Sendable {
    @MainActor func fetchGroupedRecipes(for method: BrewMethod) throws -> RecipeListSections
    @MainActor func deleteRecipe(id: UUID) throws
    @MainActor func canDeleteRecipe(_ recipe: RecipeSummaryDTO) -> Bool
}

@MainActor
final class RecipeListUseCase: RecipeListUseCaseProtocol {
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchGroupedRecipes(for method: BrewMethod) throws -> RecipeListSections {
        let recipes = try repository.fetchRecipes(for: method)
        
        let dtos = recipes.map { recipe -> RecipeSummaryDTO in
            let validationErrors = RecipeValidator.validate(recipe)
            return recipe.toSummaryDTO(isValid: validationErrors.isEmpty)
        }
        
        let starterRecipes = dtos
            .filter { $0.isStarter || $0.origin == .starterTemplate }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        let customRecipes = dtos
            .filter { !$0.isStarter && $0.origin != .starterTemplate }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        return RecipeListSections(starter: starterRecipes, custom: customRecipes)
    }
    
    func deleteRecipe(id: UUID) throws {
        guard let recipe = try repository.fetchRecipe(byId: id) else {
            return // Treat as success (idempotent)
        }
        
        // Business rule: cannot delete starters
        guard !recipe.isStarter else {
            throw RecipeUseCaseError.cannotDeleteStarter
        }
        
        repository.delete(recipe)
        try repository.save()
    }
    
    func canDeleteRecipe(_ recipe: RecipeSummaryDTO) -> Bool {
        !recipe.isStarter && recipe.origin != .starterTemplate
    }
}
