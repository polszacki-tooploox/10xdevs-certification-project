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
    private let repository: RecipeRepository
    
    init(repository: RecipeRepository) {
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
        
        // Replace all steps, enforcing contiguous orderIndex.
        let normalizedSteps: [RecipeStepDTO] = request.steps
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated()
            .map { index, dto in
                RecipeStepDTO(
                    stepId: dto.stepId,
                    orderIndex: index,
                    instructionText: dto.instructionText,
                    stepKind: dto.stepKind,
                    durationSeconds: dto.durationSeconds,
                    targetElapsedSeconds: dto.targetElapsedSeconds,
                    timerDurationSeconds: dto.timerDurationSeconds,
                    waterAmountGrams: dto.waterAmountGrams,
                    isCumulativeWaterTarget: dto.isCumulativeWaterTarget
                )
            }
        
        if let existingSteps = recipe.steps {
            for step in existingSteps {
                repository.context.delete(step)
            }
        }
        
        let newSteps = normalizedSteps.map { dto in
            RecipeStep(from: dto, recipe: recipe)
        }
        
        for step in newSteps {
            repository.context.insert(step)
        }
        recipe.steps = newSteps
        
        do {
            try repository.save()
            return .success(())
        } catch {
            throw RecipeUseCaseError.saveFailed(message: "Could not save recipe changes. Please try again.")
        }
    }
}

