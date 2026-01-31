//
//  DTOFixtures.swift
//  BrewGuideTests
//
//  Fixture builders for DTO types for testing.
//

import Foundation
@testable import BrewGuide

/// Fixture factory for creating test DTOs with sensible defaults.
struct DTOFixtures {
    
    // MARK: - Recipe DTOs
    
    /// Creates a valid RecipeStepDTO
    static func makeRecipeStepDTO(
        stepId: UUID = UUID(),
        orderIndex: Int = 0,
        instructionText: String = "Test step",
        stepKind: StepKind = .pour,
        durationSeconds: Double? = nil,
        targetElapsedSeconds: Double? = 90,
        waterAmountGrams: Double? = 150.0,
        isCumulativeWaterTarget: Bool = true
    ) -> RecipeStepDTO {
        RecipeStepDTO(
            stepId: stepId,
            orderIndex: orderIndex,
            instructionText: instructionText,
            stepKind: stepKind,
            durationSeconds: durationSeconds,
            targetElapsedSeconds: targetElapsedSeconds,
            timerDurationSeconds: durationSeconds ?? targetElapsedSeconds,
            waterAmountGrams: waterAmountGrams,
            isCumulativeWaterTarget: isCumulativeWaterTarget
        )
    }
    
    /// Creates valid V60 step DTOs
    static func makeDefaultV60StepDTOs() -> [RecipeStepDTO] {
        [
            makeRecipeStepDTO(
                orderIndex: 0,
                instructionText: "Rinse filter",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: false
            ),
            makeRecipeStepDTO(
                orderIndex: 1,
                instructionText: "Bloom",
                stepKind: .bloom,
                durationSeconds: 45,
                targetElapsedSeconds: nil,
                waterAmountGrams: 45.0,
                isCumulativeWaterTarget: true
            ),
            makeRecipeStepDTO(
                orderIndex: 2,
                instructionText: "Pour to 148g",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 90,
                waterAmountGrams: 148.0,
                isCumulativeWaterTarget: true
            ),
            makeRecipeStepDTO(
                orderIndex: 3,
                instructionText: "Pour to 250g",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 135,
                waterAmountGrams: 250.0,
                isCumulativeWaterTarget: true
            ),
            makeRecipeStepDTO(
                orderIndex: 4,
                instructionText: "Wait",
                stepKind: .wait,
                durationSeconds: 60,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: false
            )
        ]
    }
    
    /// Creates a valid UpdateRecipeRequest
    static func makeUpdateRecipeRequest(
        id: UUID = UUID(),
        name: String = "Test Recipe",
        defaultDose: Double = 15.0,
        defaultTargetYield: Double = 250.0,
        defaultWaterTemperature: Double = 94.0,
        defaultGrindLabel: GrindLabel = .medium,
        grindTactileDescriptor: String? = nil,
        steps: [RecipeStepDTO]? = nil
    ) -> UpdateRecipeRequest {
        UpdateRecipeRequest(
            id: id,
            name: name,
            defaultDose: defaultDose,
            defaultTargetYield: defaultTargetYield,
            defaultWaterTemperature: defaultWaterTemperature,
            defaultGrindLabel: defaultGrindLabel,
            grindTactileDescriptor: grindTactileDescriptor,
            steps: steps ?? makeDefaultV60StepDTOs()
        )
    }
    
    /// Creates a valid CreateRecipeRequest
    static func makeCreateRecipeRequest(
        method: BrewMethod = .v60,
        name: String = "Test Recipe",
        defaultDose: Double = 15.0,
        defaultTargetYield: Double = 250.0,
        defaultWaterTemperature: Double = 94.0,
        defaultGrindLabel: GrindLabel = .medium,
        grindTactileDescriptor: String? = nil,
        steps: [RecipeStepDTO]? = nil
    ) -> CreateRecipeRequest {
        CreateRecipeRequest(
            method: method,
            name: name,
            defaultDose: defaultDose,
            defaultTargetYield: defaultTargetYield,
            defaultWaterTemperature: defaultWaterTemperature,
            defaultGrindLabel: defaultGrindLabel,
            grindTactileDescriptor: grindTactileDescriptor,
            steps: steps ?? makeDefaultV60StepDTOs()
        )
    }
    
    // MARK: - Brew Session DTOs
    
    /// Creates valid BrewInputs
    static func makeBrewInputs(
        recipeId: UUID = UUID(),
        recipeName: String = "Test Recipe",
        method: BrewMethod = .v60,
        doseGrams: Double = 15.0,
        targetYieldGrams: Double = 250.0,
        waterTemperatureCelsius: Double = 94.0,
        grindLabel: GrindLabel = .medium,
        lastEdited: BrewInputs.LastEditedField = .yield
    ) -> BrewInputs {
        BrewInputs(
            recipeId: recipeId,
            recipeName: recipeName,
            method: method,
            doseGrams: doseGrams,
            targetYieldGrams: targetYieldGrams,
            waterTemperatureCelsius: waterTemperatureCelsius,
            grindLabel: grindLabel,
            lastEdited: lastEdited
        )
    }
    
    /// Creates a valid ScaleInputsRequest
    static func makeScaleInputsRequest(
        method: BrewMethod = .v60,
        recipeDefaultDose: Double = 15.0,
        recipeDefaultTargetYield: Double = 250.0,
        userDose: Double = 15.0,
        userTargetYield: Double = 250.0,
        lastEdited: BrewInputs.LastEditedField = .yield
    ) -> ScaleInputsRequest {
        ScaleInputsRequest(
            method: method,
            recipeDefaultDose: recipeDefaultDose,
            recipeDefaultTargetYield: recipeDefaultTargetYield,
            userDose: userDose,
            userTargetYield: userTargetYield,
            lastEdited: lastEdited
        )
    }
    
    // MARK: - Brew Log DTOs
    
    /// Creates a valid CreateBrewLogRequest
    static func makeCreateBrewLogRequest(
        timestamp: Date = Date(),
        method: BrewMethod = .v60,
        recipeId: UUID? = UUID(),
        recipeNameAtBrew: String = "Test Recipe",
        doseGrams: Double = 15.0,
        targetYieldGrams: Double = 250.0,
        waterTemperatureCelsius: Double = 94.0,
        grindLabel: GrindLabel = .medium,
        rating: Int = 4,
        tasteTag: TasteTag? = nil,
        note: String? = nil
    ) -> CreateBrewLogRequest {
        CreateBrewLogRequest(
            timestamp: timestamp,
            method: method,
            recipeId: recipeId,
            recipeNameAtBrew: recipeNameAtBrew,
            doseGrams: doseGrams,
            targetYieldGrams: targetYieldGrams,
            waterTemperatureCelsius: waterTemperatureCelsius,
            grindLabel: grindLabel,
            rating: rating,
            tasteTag: tasteTag,
            note: note
        )
    }
}
