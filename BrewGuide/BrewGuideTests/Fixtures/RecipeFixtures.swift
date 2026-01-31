//
//  RecipeFixtures.swift
//  BrewGuideTests
//
//  Fixture builders for Recipe and RecipeStep entities for testing.
//

import Foundation
import SwiftData
@testable import BrewGuide

/// Fixture factory for creating test recipes with sensible defaults.
struct RecipeFixtures {
    
    // MARK: - Valid Recipes
    
    /// Creates a valid V60 recipe with default parameters
    static func makeValidV60Recipe(
        id: UUID = UUID(),
        name: String = "Test V60 Recipe",
        isStarter: Bool = false,
        origin: RecipeOrigin = .custom,
        defaultDose: Double = 15.0,
        defaultTargetYield: Double = 250.0,
        defaultWaterTemperature: Double = 94.0,
        defaultGrindLabel: GrindLabel = .medium,
        grindTactileDescriptor: String? = "sand; slightly finer than sea salt",
        bloomRatio: Double = 3.0
    ) -> Recipe {
        let recipe = Recipe(
            id: id,
            isStarter: isStarter,
            origin: origin,
            method: .v60,
            name: name,
            defaultDose: defaultDose,
            defaultTargetYield: defaultTargetYield,
            defaultWaterTemperature: defaultWaterTemperature,
            defaultGrindLabel: defaultGrindLabel,
            grindTactileDescriptor: grindTactileDescriptor,
            bloomRatio: bloomRatio
        )
        
        // Add default steps
        let steps = makeDefaultV60Steps(recipe: recipe)
        recipe.steps = steps
        
        return recipe
    }
    
    /// Creates a starter V60 recipe (isStarter = true)
    static func makeStarterV60Recipe(
        id: UUID = UUID(),
        name: String = "Starter V60 Recipe"
    ) -> Recipe {
        makeValidV60Recipe(
            id: id,
            name: name,
            isStarter: true,
            origin: .starterTemplate
        )
    }
    
    // MARK: - Invalid Recipes
    
    /// Creates a recipe with empty name
    static func makeEmptyNameRecipe(id: UUID = UUID()) -> Recipe {
        makeValidV60Recipe(id: id, name: "")
    }
    
    /// Creates a recipe with zero dose
    static func makeZeroDoseRecipe(id: UUID = UUID()) -> Recipe {
        makeValidV60Recipe(id: id, defaultDose: 0.0)
    }
    
    /// Creates a recipe with negative dose
    static func makeNegativeDoseRecipe(id: UUID = UUID()) -> Recipe {
        makeValidV60Recipe(id: id, defaultDose: -5.0)
    }
    
    /// Creates a recipe with zero yield
    static func makeZeroYieldRecipe(id: UUID = UUID()) -> Recipe {
        makeValidV60Recipe(id: id, defaultTargetYield: 0.0)
    }
    
    /// Creates a recipe with no steps
    static func makeNoStepsRecipe(id: UUID = UUID()) -> Recipe {
        let recipe = makeValidV60Recipe(id: id)
        recipe.steps = []
        return recipe
    }
    
    /// Creates a recipe with a negative timer step
    static func makeNegativeTimerRecipe(id: UUID = UUID()) -> Recipe {
        let recipe = Recipe(
            id: id,
            isStarter: false,
            origin: .custom,
            method: .v60,
            name: "Negative Timer Recipe",
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 94.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: nil,
            bloomRatio: 3.0
        )
        
        let step = RecipeStep(
            orderIndex: 0,
            instructionText: "Invalid step",
            stepKind: .wait,
            durationSeconds: -10,
            recipe: recipe
        )
        recipe.steps = [step]
        
        return recipe
    }
    
    /// Creates a recipe with water total mismatch
    static func makeWaterMismatchRecipe(id: UUID = UUID()) -> Recipe {
        let recipe = Recipe(
            id: id,
            isStarter: false,
            origin: .custom,
            method: .v60,
            name: "Water Mismatch Recipe",
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 94.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: nil,
            bloomRatio: 3.0
        )
        
        let step = RecipeStep(
            orderIndex: 0,
            instructionText: "Pour",
            stepKind: .pour,
            targetElapsedSeconds: 90,
            waterAmountGrams: 200.0, // Mismatch with yield of 250
            isCumulativeWaterTarget: true,
            recipe: recipe
        )
        recipe.steps = [step]
        
        return recipe
    }
    
    // MARK: - Recipe Steps
    
    /// Creates default V60 steps for a recipe
    static func makeDefaultV60Steps(recipe: Recipe) -> [RecipeStep] {
        [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter and preheat",
                stepKind: .preparation,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Bloom",
                stepKind: .bloom,
                durationSeconds: 45,
                waterAmountGrams: 45.0,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Pour to 148g",
                stepKind: .pour,
                targetElapsedSeconds: 90,
                waterAmountGrams: 148.0,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 250g",
                stepKind: .pour,
                targetElapsedSeconds: 135,
                waterAmountGrams: 250.0,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Wait for drawdown",
                stepKind: .wait,
                durationSeconds: 60,
                recipe: recipe
            )
        ]
    }
}
