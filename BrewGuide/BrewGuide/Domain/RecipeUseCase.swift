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
    @MainActor func duplicateRecipe(id: UUID) throws -> UUID
    @MainActor func deleteRecipe(id: UUID) throws
    @MainActor func canEdit(recipe: RecipeSummaryDTO) -> Bool
    @MainActor func canDelete(recipe: RecipeSummaryDTO) -> Bool
}

enum RecipeUseCaseError: LocalizedError, Equatable {
    case recipeNotFound
    case cannotDeleteStarter
    case saveFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found."
        case .cannotDeleteStarter:
            return "Starter recipes cannot be deleted."
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
        
        // Use domain validator instead of repository
        let validationErrors = RecipeValidator.validate(recipe)
        return recipe.toDetailDTO(isValid: validationErrors.isEmpty)
    }
    
    func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors> {
        guard let recipe = try repository.fetchRecipe(byId: request.id) else {
            throw RecipeUseCaseError.recipeNotFound
        }
        
        guard recipe.isStarter == false else {
            return .failure(RecipeValidationErrors(errors: [.starterCannotBeModified]))
        }
        
        // Validate request using domain validator
        let requestErrors = RecipeValidator.validate(request)
        guard requestErrors.isEmpty else {
            return .failure(RecipeValidationErrors(errors: requestErrors))
        }
        
        recipe.update(from: request)
        
        // Normalize step ordering (business rule)
        let normalizedSteps = normalizeStepOrdering(request.steps)
        
        // Create step entities
        let stepEntities = normalizedSteps.map { dto in
            RecipeStep(from: dto, recipe: recipe)
        }
        
        // Repository just persists
        repository.replaceSteps(for: recipe, with: stepEntities)
        
        do {
            try repository.save()
            return .success(())
        } catch {
            throw RecipeUseCaseError.saveFailed(message: "Could not save recipe changes. Please try again.")
        }
    }
    
    func duplicateRecipe(id: UUID) throws -> UUID {
        guard let source = try repository.fetchRecipe(byId: id) else {
            throw RecipeUseCaseError.recipeNotFound
        }
        
        // Business rules applied here
        let newRecipe = Recipe(
            isStarter: false,
            origin: .custom,
            method: source.method,
            name: generateCopyName(source.name),
            defaultDose: source.defaultDose,
            defaultTargetYield: source.defaultTargetYield,
            defaultWaterTemperature: source.defaultWaterTemperature,
            defaultGrindLabel: source.defaultGrindLabel,
            grindTactileDescriptor: source.grindTactileDescriptor
        )
        
        repository.insert(newRecipe)
        
        // Clone steps
        let clonedSteps = (source.steps ?? []).map { step in
            RecipeStep(
                orderIndex: step.orderIndex,
                instructionText: step.instructionText,
                stepKind: step.stepKind,
                durationSeconds: step.durationSeconds,
                targetElapsedSeconds: step.targetElapsedSeconds,
                timerDurationSeconds: step.timerDurationSeconds,
                waterAmountGrams: step.waterAmountGrams,
                isCumulativeWaterTarget: step.isCumulativeWaterTarget,
                recipe: newRecipe
            )
        }
        repository.insertSteps(clonedSteps)
        newRecipe.steps = clonedSteps
        
        try repository.save()
        return newRecipe.id
    }
    
    func deleteRecipe(id: UUID) throws {
        guard let recipe = try repository.fetchRecipe(byId: id) else {
            return // Idempotent: treat as success
        }
        
        // Business rule check here
        guard !recipe.isStarter else {
            throw RecipeUseCaseError.cannotDeleteStarter
        }
        
        repository.delete(recipe)
        try repository.save()
    }
    
    func canEdit(recipe: RecipeSummaryDTO) -> Bool {
        !recipe.isStarter && recipe.origin != .starterTemplate
    }
    
    func canDelete(recipe: RecipeSummaryDTO) -> Bool {
        !recipe.isStarter && recipe.origin != .starterTemplate
    }
    
    // MARK: - Private Helpers
    
    /// Normalize step ordering to contiguous indices (0, 1, 2, ...)
    private func normalizeStepOrdering(_ steps: [RecipeStepDTO]) -> [RecipeStepDTO] {
        steps
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
    }
    
    /// Generate a copy name for duplicated recipes
    private func generateCopyName(_ originalName: String) -> String {
        "\(originalName) Copy"
    }
}

