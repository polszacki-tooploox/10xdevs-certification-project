//
//  BrewSessionUseCase.swift
//  BrewGuide
//
//  Business logic for creating and managing brew sessions.
//

import Foundation
import SwiftData

/// Use case for brew session operations: creating brew plans, scaling recipes.
@MainActor
final class BrewSessionUseCase {
    private let recipeRepository: RecipeRepository
    
    init(recipeRepository: RecipeRepository) {
        self.recipeRepository = recipeRepository
    }
    
    // MARK: - Create Brew Plan
    
    /// Creates a brew plan from the given inputs by scaling recipe steps.
    func createPlan(from inputs: BrewInputs) async throws -> BrewPlan {
        // Fetch the full recipe detail
        let recipe = try recipeRepository.fetchRecipe(byId: inputs.recipeId)
        
        guard let recipe else {
            throw BrewSessionError.recipeNotFound
        }
        
        // Ensure recipe is brewable
        guard recipe.method == inputs.method else {
            throw BrewSessionError.methodMismatch
        }
        
        guard let steps = recipe.steps?.sorted(by: { $0.orderIndex < $1.orderIndex }), !steps.isEmpty else {
            throw BrewSessionError.noSteps
        }
        
        // Calculate scaling factor based on target yield
        let scalingFactor = inputs.targetYieldGrams / recipe.defaultTargetYield
        
        // Scale steps
        let scaledSteps = steps.map { step in
            ScaledStep(
                stepId: step.stepId,
                orderIndex: step.orderIndex,
                instructionText: step.instructionText,
                stepKind: step.stepKind,
                durationSeconds: step.durationSeconds,
                targetElapsedSeconds: step.targetElapsedSeconds,
                waterAmountGrams: step.waterAmountGrams.map { $0 * scalingFactor },
                isCumulativeWaterTarget: step.isCumulativeWaterTarget
            )
        }
        
        return BrewPlan(inputs: inputs, scaledSteps: scaledSteps)
    }
    
    // MARK: - Create Inputs from Recipe
    
    /// Creates default brew inputs from a recipe.
    func createInputs(from recipe: Recipe) -> BrewInputs {
        BrewInputs(
            recipeId: recipe.id,
            recipeName: recipe.name,
            method: recipe.method,
            doseGrams: recipe.defaultDose,
            targetYieldGrams: recipe.defaultTargetYield,
            waterTemperatureCelsius: recipe.defaultWaterTemperature,
            grindLabel: recipe.defaultGrindLabel,
            lastEdited: .yield
        )
    }
}

// MARK: - Errors

enum BrewSessionError: LocalizedError {
    case recipeNotFound
    case methodMismatch
    case noSteps
    case invalidInputs
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            "Recipe not found"
        case .methodMismatch:
            "Brew method doesn't match recipe"
        case .noSteps:
            "Recipe has no steps to brew"
        case .invalidInputs:
            "Invalid brew parameters"
        }
    }
}
