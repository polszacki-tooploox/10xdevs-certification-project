import Foundation

/// Pure validation logic for recipes - no dependencies on persistence.
/// Extracted from RecipeRepository to follow clean architecture principles.
struct RecipeValidator {
    
    /// Validate a recipe entity against business rules.
    /// - Parameter recipe: The recipe to validate
    /// - Returns: Array of validation errors (empty if valid)
    static func validate(_ recipe: Recipe) -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        // Name validation
        if recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // Dose/yield validation
        if recipe.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        if recipe.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        // Steps validation
        guard let steps = recipe.steps, !steps.isEmpty else {
            errors.append(.noSteps)
            return errors
        }
        
        // Timer validation
        for step in steps {
            if let duration = step.timerDurationSeconds, duration < 0 {
                errors.append(.negativeTimer(stepIndex: step.orderIndex))
            }
        }
        
        // Water amount validation
        for step in steps {
            if let waterAmount = step.waterAmountGrams, waterAmount < 0 {
                errors.append(.negativeWaterAmount(stepIndex: step.orderIndex))
            }
        }
        
        // Water total validation (±1g tolerance)
        let waterSteps = steps.compactMap { $0.waterAmountGrams }
        if !waterSteps.isEmpty {
            let totalWater = waterSteps.max() ?? 0
            let difference = abs(totalWater - recipe.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: recipe.defaultTargetYield, actual: totalWater))
            }
        }
        
        return errors
    }
    
    /// Validate an update request DTO.
    /// - Parameter request: The update request to validate
    /// - Returns: Array of validation errors (empty if valid)
    static func validate(_ request: UpdateRecipeRequest) -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        // Name validation
        if request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // Dose/yield validation
        if request.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        if request.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        // Steps validation
        if request.steps.isEmpty {
            errors.append(.noSteps)
        }
        
        // Validate steps
        for (index, step) in request.steps.enumerated() {
            if let duration = step.timerDurationSeconds, duration < 0 {
                errors.append(.negativeTimer(stepIndex: index))
            }
            if let waterAmount = step.waterAmountGrams, waterAmount < 0 {
                errors.append(.negativeWaterAmount(stepIndex: index))
            }
        }
        
        // Water total check (±1g tolerance)
        let waterAmounts = request.steps.compactMap { $0.waterAmountGrams }
        if !waterAmounts.isEmpty {
            let totalWater = waterAmounts.max() ?? 0
            let difference = abs(totalWater - request.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: request.defaultTargetYield, actual: totalWater))
            }
        }
        
        return errors
    }
}
