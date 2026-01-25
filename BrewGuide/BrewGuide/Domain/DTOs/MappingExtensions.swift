import Foundation

// MARK: - Entity → DTO Mapping Extensions

/// Extensions for mapping SwiftData entities to DTOs.
/// These provide the connection between persistence models and transfer objects.

extension Recipe {
    /// Convert to summary DTO (for list views)
    /// - Parameter isValid: Whether the recipe passes validation rules
    func toSummaryDTO(isValid: Bool = true) -> RecipeSummaryDTO {
        RecipeSummaryDTO(
            id: id,
            name: name,
            method: method,
            isStarter: isStarter,
            origin: origin,
            isValid: isValid,
            defaultDose: defaultDose,
            defaultTargetYield: defaultTargetYield,
            defaultWaterTemperature: defaultWaterTemperature,
            defaultGrindLabel: defaultGrindLabel
        )
    }
    
    /// Convert to detail DTO with sorted steps
    /// - Parameter isValid: Whether the recipe passes validation rules
    func toDetailDTO(isValid: Bool = true) -> RecipeDetailDTO {
        let sortedSteps = (steps ?? [])
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .map { $0.toDTO() }
        
        return RecipeDetailDTO(
            recipe: toSummaryDTO(isValid: isValid),
            grindTactileDescriptor: grindTactileDescriptor,
            steps: sortedSteps
        )
    }
}

extension RecipeStep {
    /// Convert to DTO
    func toDTO() -> RecipeStepDTO {
        RecipeStepDTO(
            stepId: stepId,
            orderIndex: orderIndex,
            instructionText: instructionText,
            timerDurationSeconds: timerDurationSeconds,
            waterAmountGrams: waterAmountGrams,
            isCumulativeWaterTarget: isCumulativeWaterTarget
        )
    }
}

extension BrewLog {
    /// Convert to summary DTO (for list views)
    func toSummaryDTO() -> BrewLogSummaryDTO {
        BrewLogSummaryDTO(
            id: id,
            timestamp: timestamp,
            method: method,
            recipeNameAtBrew: recipeNameAtBrew,
            rating: rating,
            tasteTag: tasteTag,
            recipeId: recipe?.id
        )
    }
    
    /// Convert to detail DTO
    func toDetailDTO() -> BrewLogDetailDTO {
        BrewLogDetailDTO(
            summary: toSummaryDTO(),
            doseGrams: doseGrams,
            targetYieldGrams: targetYieldGrams,
            waterTemperatureCelsius: waterTemperatureCelsius,
            grindLabel: grindLabel,
            note: note
        )
    }
}

// MARK: - DTO → Entity Creation Helpers

extension Recipe {
    /// Create a new Recipe from CreateRecipeRequest
    convenience init(from request: CreateRecipeRequest) {
        let now = Date()
        self.init(
            id: UUID(),
            isStarter: false,
            origin: .custom,
            method: request.method,
            name: request.name,
            defaultDose: request.defaultDose,
            defaultTargetYield: request.defaultTargetYield,
            defaultWaterTemperature: request.defaultWaterTemperature,
            defaultGrindLabel: request.defaultGrindLabel,
            grindTactileDescriptor: request.grindTactileDescriptor,
            steps: nil, // Steps will be created separately and linked
            createdAt: now,
            modifiedAt: now
        )
    }
    
    /// Update this Recipe from UpdateRecipeRequest
    /// - Parameter request: The update request
    /// - Note: Does NOT update steps; handle step replacement separately
    func update(from request: UpdateRecipeRequest) {
        name = request.name
        defaultDose = request.defaultDose
        defaultTargetYield = request.defaultTargetYield
        defaultWaterTemperature = request.defaultWaterTemperature
        defaultGrindLabel = request.defaultGrindLabel
        grindTactileDescriptor = request.grindTactileDescriptor
        modifiedAt = Date()
    }
}

extension RecipeStep {
    /// Create a new RecipeStep from RecipeStepDTO
    convenience init(from dto: RecipeStepDTO, recipe: Recipe? = nil) {
        self.init(
            stepId: dto.stepId,
            orderIndex: dto.orderIndex,
            instructionText: dto.instructionText,
            timerDurationSeconds: dto.timerDurationSeconds,
            waterAmountGrams: dto.waterAmountGrams,
            isCumulativeWaterTarget: dto.isCumulativeWaterTarget,
            recipe: recipe
        )
    }
}

extension BrewLog {
    /// Create a new BrewLog from CreateBrewLogRequest
    convenience init(from request: CreateBrewLogRequest, recipe: Recipe? = nil) {
        self.init(
            id: UUID(),
            timestamp: request.timestamp,
            method: request.method,
            recipeNameAtBrew: request.recipeNameAtBrew,
            doseGrams: request.doseGrams,
            targetYieldGrams: request.targetYieldGrams,
            waterTemperatureCelsius: request.waterTemperatureCelsius,
            grindLabel: request.grindLabel,
            rating: request.rating,
            tasteTag: request.tasteTag,
            note: request.note,
            recipe: recipe
        )
    }
}

// MARK: - Recipe → BrewInputs

extension Recipe {
    /// Create initial BrewInputs from recipe defaults
    func toBrewInputs() -> BrewInputs {
        BrewInputs(
            recipeId: id,
            recipeName: name,
            method: method,
            doseGrams: defaultDose,
            targetYieldGrams: defaultTargetYield,
            waterTemperatureCelsius: defaultWaterTemperature,
            grindLabel: defaultGrindLabel,
            lastEdited: .dose // Default to dose as last edited
        )
    }
}

// MARK: - RecipeStepDTO → ScaledStep

extension RecipeStepDTO {
    /// Convert to ScaledStep with scaled water amount
    /// - Parameter scaledWaterAmount: The scaled water amount (already rounded)
    func toScaledStep(scaledWaterAmount: Double?) -> ScaledStep {
        ScaledStep(
            stepId: stepId,
            orderIndex: orderIndex,
            instructionText: instructionText,
            timerDurationSeconds: timerDurationSeconds,
            waterAmountGrams: scaledWaterAmount,
            isCumulativeWaterTarget: isCumulativeWaterTarget
        )
    }
}
