//
//  RecipeUseCase.swift
//  BrewGuide
//
//  Orchestrates recipe business rules and persistence updates.
//

import Foundation
import SwiftData

protocol RecipeUseCaseProtocol: Sendable {
    @MainActor func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO
    @MainActor func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors>
}

enum RecipeUseCaseError: LocalizedError, Equatable {
    case recipeNotFound
    case saveFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found."
        case .saveFailed(let message):
            return message
        }
    }
}

struct RecipeValidationErrors: Error, Equatable, Sendable {
    let errors: [RecipeValidationError]
}

@MainActor
final class RecipeUseCase: RecipeUseCaseProtocol {
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO {
        guard let recipe = try repository.fetchRecipe(byId: id) else {
            throw RecipeUseCaseError.recipeNotFound
        }
        
        let validationErrors = repository.validate(recipe)
        return recipe.toDetailDTO(isValid: validationErrors.isEmpty)
    }
    
    func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors> {
        guard let recipe = try repository.fetchRecipe(byId: request.id) else {
            throw RecipeUseCaseError.recipeNotFound
        }
        
        guard recipe.isStarter == false else {
            return .failure(RecipeValidationErrors(errors: [.starterCannotBeModified]))
        }
        
        let requestErrors = request.validate()
        guard requestErrors.isEmpty else {
            return .failure(RecipeValidationErrors(errors: requestErrors))
        }
        
        recipe.update(from: request)
        
        // Replace all steps using repository method
        try repository.replaceSteps(for: recipe, with: request.steps)
        
        do {
            try repository.save()
            return .success(())
        } catch {
            throw RecipeUseCaseError.saveFailed(message: "Could not save recipe changes. Please try again.")
        }
    }
}

