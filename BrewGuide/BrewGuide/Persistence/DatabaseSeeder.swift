import Foundation
import SwiftData

/// Manages seeding of initial data (starter recipes) into the database.
@MainActor
final class DatabaseSeeder {
    /// Seeds the V60 starter recipes if they don't already exist.
    /// Should be called once on app first launch.
    static func seedStarterRecipesIfNeeded(in context: ModelContext) {
        // Check if starter recipes already exist
        // Note: Predicate only checks isStarter, then filter by method in Swift
        // (SwiftData predicates don't support enum comparisons)
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.isStarter == true
            }
        )
        
        do {
            let allStarters = try context.fetch(descriptor)
            let existingV60Starters = allStarters.filter { $0.method == .v60 }
            
            // If V60 starters already exist, skip seeding
            guard existingV60Starters.isEmpty else {
                return
            }
            
            // Create all three starter recipes
            let recipes = [
                createV60BalancedRecipe(),
                createV60BrightRecipe(),
                createV60BoldRecipe()
            ]
            
            for recipe in recipes {
                context.insert(recipe)
                
                // Create and attach steps for each recipe
                let steps = createSteps(for: recipe)
                for step in steps {
                    context.insert(step)
                }
                recipe.steps = steps
            }
            
            // Save the context
            try context.save()
            
        } catch {
            print("Error seeding starter recipes: \(error)")
        }
    }
    
    // MARK: - Recipe Definitions
    
    /// Creates the balanced V60 starter recipe with default values from PRD section 3.5
    /// Best for: Medium roasts, balanced flavor profile
    private static func createV60BalancedRecipe() -> Recipe {
        Recipe(
            isStarter: true,
            origin: .starterTemplate,
            method: .v60,
            name: "V60 Balanced",
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 94.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: "sand; slightly finer than sea salt",
            bloomRatio: 3.0
        )
    }
    
    /// Creates a bright & light V60 recipe optimized for lighter roasts
    /// Best for: Light roasts, floral/fruity notes, higher acidity
    private static func createV60BrightRecipe() -> Recipe {
        Recipe(
            isStarter: true,
            origin: .starterTemplate,
            method: .v60,
            name: "V60 Bright & Light",
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 96.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: "fine sand; slightly finer than table salt",
            bloomRatio: 3.3
        )
    }
    
    /// Creates a bold & strong V60 recipe optimized for darker roasts
    /// Best for: Dark roasts, fuller body, chocolate/nutty notes
    private static func createV60BoldRecipe() -> Recipe {
        Recipe(
            isStarter: true,
            origin: .starterTemplate,
            method: .v60,
            name: "V60 Bold & Strong",
            defaultDose: 18.0,
            defaultTargetYield: 270.0,
            defaultWaterTemperature: 92.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: "coarse sand; similar to sea salt",
            bloomRatio: 3.0
        )
    }
    
    // MARK: - Steps Creation
    
    /// Creates appropriate steps based on the recipe type
    private static func createSteps(for recipe: Recipe) -> [RecipeStep] {
        switch recipe.name {
        case "V60 Balanced":
            return createV60BalancedSteps(for: recipe)
        case "V60 Bright & Light":
            return createV60BrightSteps(for: recipe)
        case "V60 Bold & Strong":
            return createV60BoldSteps(for: recipe)
        default:
            return createV60BalancedSteps(for: recipe)
        }
    }
    
    /// Creates the balanced V60 recipe steps as defined in PRD section 3.5
    private static func createV60BalancedSteps(for recipe: Recipe) -> [RecipeStep] {
        [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter and preheat",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Add coffee, level bed",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Bloom: pour 45g, start timer",
                stepKind: .bloom,
                durationSeconds: 45,
                targetElapsedSeconds: nil,
                waterAmountGrams: 45,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 150g by 1:30",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 90,
                waterAmountGrams: 150,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Pour to 250g by 2:15",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 135,
                waterAmountGrams: 250,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 5,
                instructionText: "Wait for drawdown, target finish 3:00–3:30",
                stepKind: .wait,
                durationSeconds: 180,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            )
        ]
    }
    
    /// Creates steps for the bright & light recipe (longer bloom, multiple pours)
    private static func createV60BrightSteps(for recipe: Recipe) -> [RecipeStep] {
        [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter with hot water",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Add coffee, create small well in center",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Bloom: pour 50g in gentle spiral, start timer",
                stepKind: .bloom,
                durationSeconds: 50,
                targetElapsedSeconds: nil,
                waterAmountGrams: 50,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 125g by 1:20",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 80,
                waterAmountGrams: 125,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Pour to 200g by 2:00",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 120,
                waterAmountGrams: 200,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 5,
                instructionText: "Pour to 250g by 2:30",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 150,
                waterAmountGrams: 250,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 6,
                instructionText: "Wait for drawdown, target finish 3:30–4:00",
                stepKind: .wait,
                durationSeconds: 210,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            )
        ]
    }
    
    /// Creates steps for the bold & strong recipe (stronger ratio, faster pours)
    private static func createV60BoldSteps(for recipe: Recipe) -> [RecipeStep] {
        [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter and preheat",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Add coffee, tap to level",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Bloom: pour 54g (3× dose), start timer",
                stepKind: .bloom,
                durationSeconds: 45,
                targetElapsedSeconds: nil,
                waterAmountGrams: 54,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 180g by 1:30",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 90,
                waterAmountGrams: 180,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Pour to 270g by 2:00",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 120,
                waterAmountGrams: 270,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 5,
                instructionText: "Wait for drawdown, target finish 2:45–3:15",
                stepKind: .wait,
                durationSeconds: 165,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            )
        ]
    }
}
