import Foundation
import SwiftData

/// Repository for Recipe persistence operations.
@MainActor
final class RecipeRepository: BaseRepository<Recipe> {
    
    /// Fetch all recipes for a specific brew method
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.method == method }
        )
        let results = try fetch(descriptor: descriptor)
        // Sort manually: starters first, then alphabetical by name
        return results.sorted {  ($0.isStarter && !$1.isStarter) || ($0.isStarter == $1.isStarter && $0.name < $1.name)
        }
    }
    
    /// Fetch the starter recipe for a specific method
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.isStarter == true && recipe.method == method
            }
        )
        return try fetch(descriptor: descriptor).first
    }
    
    /// Fetch a recipe by its ID
    func fetchRecipe(byId id: UUID) throws -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try fetch(descriptor: descriptor).first
    }
    
    /// Duplicate a recipe (typically for creating custom recipes from starters)
    /// - Parameter source: The source recipe to duplicate
    /// - Returns: A new custom recipe with cloned steps
    func duplicate(_ source: Recipe) throws -> Recipe {
        // Create new recipe with copied defaults
        let newRecipe = Recipe(
            isStarter: false,
            origin: .custom,
            method: source.method,
            name: "\(source.name) Copy",
            defaultDose: source.defaultDose,
            defaultTargetYield: source.defaultTargetYield,
            defaultWaterTemperature: source.defaultWaterTemperature,
            defaultGrindLabel: source.defaultGrindLabel,
            grindTactileDescriptor: source.grindTactileDescriptor
        )
        
        // Clone steps
        let clonedSteps = (source.steps ?? []).map { step in
            RecipeStep(
                orderIndex: step.orderIndex,
                instructionText: step.instructionText,
                timerDurationSeconds: step.timerDurationSeconds,
                waterAmountGrams: step.waterAmountGrams,
                isCumulativeWaterTarget: step.isCumulativeWaterTarget,
                recipe: newRecipe
            )
        }
        
        // Insert recipe and steps
        insert(newRecipe)
        for step in clonedSteps {
            context.insert(step)
        }
        newRecipe.steps = clonedSteps
        
        return newRecipe
    }
    
    /// Delete a custom recipe (starter recipes cannot be deleted)
    /// - Parameter recipe: The recipe to delete
    /// - Throws: Error if attempting to delete a starter recipe
    func deleteCustomRecipe(_ recipe: Recipe) throws {
        guard !recipe.isStarter else {
            throw RecipeRepositoryError.cannotDeleteStarterRecipe
        }
        delete(recipe)
    }
    
    /// Validate a recipe against business rules
    /// - Parameter recipe: The recipe to validate
    /// - Returns: Array of validation errors (empty if valid)
    func validate(_ recipe: Recipe) -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        // Validate name is not empty
        if recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // Validate dose and yield are positive
        if recipe.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        if recipe.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        // Validate steps
        guard let steps = recipe.steps, !steps.isEmpty else {
            errors.append(.noSteps)
            return errors
        }
        
        // All timers must be non-negative
        for step in steps {
            if let duration = step.timerDurationSeconds, duration < 0 {
                errors.append(.negativeTimer(stepIndex: step.orderIndex))
            }
        }
        
        // Sum of water additions should equal target yield (±1g tolerance)
        let waterSteps = steps.compactMap { $0.waterAmountGrams }
        if !waterSteps.isEmpty {
            let totalWater = waterSteps.max() ?? 0 // Assuming cumulative targets
            let difference = abs(totalWater - recipe.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: recipe.defaultTargetYield, actual: totalWater))
            }
        }
        
        return errors
    }
}

// MARK: - Errors

enum RecipeRepositoryError: LocalizedError {
    case cannotDeleteStarterRecipe
    
    var errorDescription: String? {
        switch self {
        case .cannotDeleteStarterRecipe:
            return "Starter recipes cannot be deleted."
        }
    }
}
