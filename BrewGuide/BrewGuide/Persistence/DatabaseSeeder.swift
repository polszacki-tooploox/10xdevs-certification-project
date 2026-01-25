import Foundation
import SwiftData

/// Manages seeding of initial data (starter recipes) into the database.
@MainActor
final class DatabaseSeeder {
    /// Seeds the V60 starter recipe if it doesn't already exist.
    /// Should be called once on app first launch.
    static func seedStarterRecipesIfNeeded(in context: ModelContext) {
        // Check if starter recipe already exists
        let v60Method = BrewMethod.v60
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.isStarter == true && recipe.method == v60Method
            }
        )
        
        do {
            let existingStarters = try context.fetch(descriptor)
            
            // If starter already exists, skip seeding
            guard existingStarters.isEmpty else {
                return
            }
            
            // Create the V60 starter recipe
            let starterRecipe = createV60StarterRecipe()
            context.insert(starterRecipe)
            
            // Create and attach steps
            let steps = createV60StarterSteps(for: starterRecipe)
            for step in steps {
                context.insert(step)
            }
            starterRecipe.steps = steps
            
            // Save the context
            try context.save()
            
        } catch {
            print("Error seeding starter recipes: \(error)")
        }
    }
    
    /// Creates the V60 starter recipe with default values from PRD section 3.5
    private static func createV60StarterRecipe() -> Recipe {
        Recipe(
            isStarter: true,
            origin: .starterTemplate,
            method: .v60,
            name: "V60 Starter",
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 94.0,
            defaultGrindLabel: .medium,
            grindTactileDescriptor: "sand; slightly finer than sea salt"
        )
    }
    
    /// Creates the V60 starter recipe steps as defined in PRD section 3.5
    private static func createV60StarterSteps(for recipe: Recipe) -> [RecipeStep] {
        [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter and preheat",
                timerDurationSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Add coffee, level bed",
                timerDurationSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Bloom: pour 45g, start timer",
                timerDurationSeconds: 45,
                waterAmountGrams: 45,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 150g by 1:30",
                timerDurationSeconds: 90,
                waterAmountGrams: 150,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Pour to 250g by 2:15",
                timerDurationSeconds: 135,
                waterAmountGrams: 250,
                isCumulativeWaterTarget: true,
                recipe: recipe
            ),
            RecipeStep(
                orderIndex: 5,
                instructionText: "Wait for drawdown, target finish 3:00–3:30",
                timerDurationSeconds: 180,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: true,
                recipe: recipe
            )
        ]
    }
}
