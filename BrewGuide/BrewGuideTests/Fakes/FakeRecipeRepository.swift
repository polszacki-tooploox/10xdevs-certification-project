//
//  FakeRecipeRepository.swift
//  BrewGuideTests
//
//  Fake implementation of RecipeRepository for unit testing.
//  Provides in-memory storage and call tracking without SwiftData dependencies.
//

import Foundation
import SwiftData
@testable import BrewGuide

/// Fake recipe repository for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeRecipeRepository: RecipeRepositoryProtocol {
    // In-memory storage
    private var recipes: [UUID: Recipe] = [:]
    
    // Call tracking
    private(set) var fetchRecipeCalls: [UUID] = []
    private(set) var saveCalls: Int = 0
    private(set) var validateCalls: [Recipe] = []
    
    // Error injection
    var shouldThrowOnFetch: Bool = false
    var shouldThrowOnSave: Bool = false
    var fetchError: Error = NSError(domain: "test", code: 1)
    var saveError: Error = NSError(domain: "test", code: 2)
    
    init() {
    }
    
    // MARK: - RecipeRepositoryProtocol
    
    func fetchRecipe(byId id: UUID) throws -> Recipe? {
        fetchRecipeCalls.append(id)
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return recipes[id]
    }
    
    func save() throws {
        saveCalls += 1
        
        if shouldThrowOnSave {
            throw saveError
        }
    }
    
    func validate(_ recipe: Recipe) -> [RecipeValidationError] {
        validateCalls.append(recipe)
        
        var errors: [RecipeValidationError] = []
        
        if recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        if recipe.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        
        if recipe.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        guard let steps = recipe.steps, !steps.isEmpty else {
            errors.append(.noSteps)
            return errors
        }
        
        for step in steps where step.timerDurationSeconds ?? 0 < 0 {
            errors.append(.negativeTimer(stepIndex: step.orderIndex))
        }
        
        for step in steps where step.waterAmountGrams ?? 0 < 0 {
            errors.append(.negativeWaterAmount(stepIndex: step.orderIndex))
        }
        
        if let maxWater = steps.compactMap({ $0.waterAmountGrams }).max(),
           steps.contains(where: { $0.isCumulativeWaterTarget }) {
            let difference = abs(maxWater - recipe.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(
                    expected: recipe.defaultTargetYield,
                    actual: maxWater
                ))
            }
        }
        
        return errors
    }
    
    func replaceSteps(for recipe: Recipe, with stepDTOs: [RecipeStepDTO]) throws {
        // Sort DTOs by orderIndex and normalize to 0, 1, 2, ...
        let normalizedSteps: [RecipeStepDTO] = stepDTOs
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
        
        // Create new step entities (in-memory, no SwiftData context)
        let newSteps = normalizedSteps.map { dto in
            RecipeStep(from: dto, recipe: recipe)
        }
        
        // Update recipe's steps
        recipe.steps = newSteps
    }
    
    // MARK: - Test Helpers
    
    /// Add a recipe to the in-memory store
    func addRecipe(_ recipe: Recipe) {
        recipes[recipe.id] = recipe
    }
    
    /// Get a recipe directly (bypasses call tracking)
    func getRecipe(byId id: UUID) -> Recipe? {
        recipes[id]
    }
    
    /// Clear all stored recipes
    func clearRecipes() {
        recipes.removeAll()
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        fetchRecipeCalls.removeAll()
        saveCalls = 0
        validateCalls.removeAll()
    }
}
