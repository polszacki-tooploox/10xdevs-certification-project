import Foundation

// MARK: - Recipe DTOs

/// Summary representation of a recipe for list views.
/// Derived from `Recipe` entity.
struct RecipeSummaryDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let method: BrewMethod
    let isStarter: Bool
    let origin: RecipeOrigin
    
    /// Whether the recipe passes all validation rules for brewing
    let isValid: Bool
    
    // Default brew parameters
    let defaultDose: Double
    let defaultTargetYield: Double
    let defaultWaterTemperature: Double
    let defaultGrindLabel: GrindLabel
    
    /// Derived computed ratio (yield / dose)
    var defaultRatio: Double {
        guard defaultDose > 0 else { return 0 }
        return defaultTargetYield / defaultDose
    }
}

/// Detailed representation of a recipe including all steps.
/// Derived from `Recipe` entity with related `RecipeStep` entities.
struct RecipeDetailDTO: Codable, Identifiable, Hashable {
    let recipe: RecipeSummaryDTO
    let grindTactileDescriptor: String?
    
    /// Ordered steps (sorted by orderIndex)
    let steps: [RecipeStepDTO]
    
    var id: UUID { recipe.id }
}

/// Representation of a single recipe step.
/// Derived from `RecipeStep` entity.
struct RecipeStepDTO: Codable, Identifiable, Hashable {
    let stepId: UUID
    let orderIndex: Int
    let instructionText: String
    let timerDurationSeconds: Double?
    let waterAmountGrams: Double?
    let isCumulativeWaterTarget: Bool
    
    var id: UUID { stepId }
}

// MARK: - Recipe Command Models

/// Request payload for creating a new custom recipe.
struct CreateRecipeRequest: Codable {
    let method: BrewMethod
    let name: String
    
    // Default brew parameters
    let defaultDose: Double
    let defaultTargetYield: Double
    let defaultWaterTemperature: Double
    let defaultGrindLabel: GrindLabel
    
    let grindTactileDescriptor: String?
    let steps: [RecipeStepDTO]
    
    /// Validate the request before persisting
    func validate() -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        if defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        
        if defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        if steps.isEmpty {
            errors.append(.noSteps)
        }
        
        // Validate step timers
        for step in steps where step.timerDurationSeconds ?? 0 < 0 {
            errors.append(.negativeTimer(stepIndex: step.orderIndex))
        }
        
        // Validate water amounts
        for step in steps where step.waterAmountGrams ?? 0 < 0 {
            errors.append(.negativeWaterAmount(stepIndex: step.orderIndex))
        }
        
        // Validate water totals match yield (±1g tolerance) for cumulative targets
        if !steps.isEmpty,
           let maxWater = steps.compactMap({ $0.waterAmountGrams }).max(),
           steps.contains(where: { $0.isCumulativeWaterTarget }) {
            let difference = abs(maxWater - defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: defaultTargetYield, actual: maxWater))
            }
        }
        
        return errors
    }
}

/// Request payload for updating an existing custom recipe.
struct UpdateRecipeRequest: Codable {
    let id: UUID
    let name: String
    
    // Default brew parameters
    let defaultDose: Double
    let defaultTargetYield: Double
    let defaultWaterTemperature: Double
    let defaultGrindLabel: GrindLabel
    
    let grindTactileDescriptor: String?
    
    /// Full replacement of steps (not a patch)
    let steps: [RecipeStepDTO]
    
    /// Validate the request before persisting
    func validate() -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        if defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        
        if defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        if steps.isEmpty {
            errors.append(.noSteps)
        }
        
        // Validate step timers
        for step in steps where step.timerDurationSeconds ?? 0 < 0 {
            errors.append(.negativeTimer(stepIndex: step.orderIndex))
        }
        
        // Validate water amounts
        for step in steps where step.waterAmountGrams ?? 0 < 0 {
            errors.append(.negativeWaterAmount(stepIndex: step.orderIndex))
        }
        
        // Validate water totals match yield (±1g tolerance) for cumulative targets
        if !steps.isEmpty,
           let maxWater = steps.compactMap({ $0.waterAmountGrams }).max(),
           steps.contains(where: { $0.isCumulativeWaterTarget }) {
            let difference = abs(maxWater - defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: defaultTargetYield, actual: maxWater))
            }
        }
        
        return errors
    }
}

// MARK: - Recipe Validation Errors

/// Validation errors that block recipe save or brew operations.
enum RecipeValidationError: Error, Equatable {
    case emptyName
    case invalidDose
    case invalidYield
    case noSteps
    case negativeTimer(stepIndex: Int)
    case negativeWaterAmount(stepIndex: Int)
    case waterTotalMismatch(expected: Double, actual: Double)
    case starterCannotBeModified
    case starterCannotBeDeleted
    
    var localizedDescription: String {
        switch self {
        case .emptyName:
            return "Recipe name cannot be empty"
        case .invalidDose:
            return "Dose must be greater than 0"
        case .invalidYield:
            return "Yield must be greater than 0"
        case .noSteps:
            return "Recipe must have at least one step"
        case .negativeTimer(let index):
            return "Step \(index + 1) has a negative timer duration"
        case .negativeWaterAmount(let index):
            return "Step \(index + 1) has a negative water amount"
        case .waterTotalMismatch(let expected, let actual):
            return "Water total (\(Int(actual))g) doesn't match yield (\(Int(expected))g)"
        case .starterCannotBeModified:
            return "Starter recipes cannot be modified. Please duplicate it first."
        case .starterCannotBeDeleted:
            return "Starter recipes cannot be deleted"
        }
    }
}

/// Error indicating a recipe cannot be used for brewing.
struct RecipeNotBrewableError: Error {
    let recipeId: UUID
    let validationErrors: [RecipeValidationError]
    
    var localizedDescription: String {
        let errorList = validationErrors.map { "• \($0.localizedDescription)" }.joined(separator: "\n")
        return "This recipe cannot be used for brewing:\n\(errorList)"
    }
}
