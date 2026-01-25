import Foundation
import SwiftData

/// Configuration for the app's SwiftData model container.
/// Supports CloudKit sync via private database when sync is enabled.
@MainActor
final class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()
    
    /// The app's model container
    let container: ModelContainer
    
    /// Schema definition for all models
    private static let schema = Schema([
        Recipe.self,
        RecipeStep.self,
        BrewLog.self
    ])
    
    /// Default configuration with CloudKit support
    private static var defaultConfiguration: ModelConfiguration {
        // CloudKit container identifier should match the app's container ID
        // Format: iCloud.{bundle-id}
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.brewguide.BrewGuide")
        )
        return configuration
    }
    
    /// In-memory configuration for testing/previews
    private static var inMemoryConfiguration: ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
    }
    
    /// Private initializer for production use
    private init() {
        container = try! ModelContainer(
            for: Self.schema,
            configurations: [Self.defaultConfiguration]
        )
    }
    
    /// Initializer for testing/preview with custom configuration
    init(inMemory: Bool) {
        if inMemory {
            container = try! ModelContainer(
                for: Self.schema,
                configurations: [Self.inMemoryConfiguration]
            )
        } else {
            container = try! ModelContainer(
                for: Self.schema,
                configurations: [Self.defaultConfiguration]
            )
        }
    }
    
    /// Main context for UI operations (runs on main actor)
    var mainContext: ModelContext {
        container.mainContext
    }
    
    /// Creates a new background context for async operations
    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        return context
    }
}

// MARK: - Preview Support

extension PersistenceController {
    /// Shared preview instance with in-memory storage
    @MainActor
    static var preview: PersistenceController {
        let controller = PersistenceController(inMemory: true)
        let context = controller.mainContext
        
        // Seed with sample data for previews
        seedPreviewData(in: context)
        
        return controller
    }
    
    /// Seeds preview data
    @MainActor
    private static func seedPreviewData(in context: ModelContext) {
        // Create a sample V60 starter recipe
        let starterRecipe = Recipe(
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
        context.insert(starterRecipe)
        
        // Add steps to starter recipe
        let steps = [
            RecipeStep(
                orderIndex: 0,
                instructionText: "Rinse filter and preheat",
                recipe: starterRecipe
            ),
            RecipeStep(
                orderIndex: 1,
                instructionText: "Add coffee, level bed",
                recipe: starterRecipe
            ),
            RecipeStep(
                orderIndex: 2,
                instructionText: "Bloom: pour 45g, start timer",
                timerDurationSeconds: 45,
                waterAmountGrams: 45,
                recipe: starterRecipe
            ),
            RecipeStep(
                orderIndex: 3,
                instructionText: "Pour to 150g by 1:30",
                timerDurationSeconds: 90,
                waterAmountGrams: 150,
                recipe: starterRecipe
            ),
            RecipeStep(
                orderIndex: 4,
                instructionText: "Pour to 250g by 2:15",
                timerDurationSeconds: 135,
                waterAmountGrams: 250,
                recipe: starterRecipe
            ),
            RecipeStep(
                orderIndex: 5,
                instructionText: "Wait for drawdown, target finish 3:00–3:30",
                timerDurationSeconds: 180,
                recipe: starterRecipe
            )
        ]
        
        for step in steps {
            context.insert(step)
        }
        
        starterRecipe.steps = steps
        
        // Create a sample custom recipe
        let customRecipe = Recipe(
            isStarter: false,
            origin: .custom,
            method: .v60,
            name: "My Custom V60",
            defaultDose: 18.0,
            defaultTargetYield: 300.0,
            defaultWaterTemperature: 95.0,
            defaultGrindLabel: .medium
        )
        context.insert(customRecipe)
        
        // Create sample brew logs
        let log1 = BrewLog(
            timestamp: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            method: .v60,
            recipeNameAtBrew: "V60 Starter",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 4,
            tasteTag: nil,
            note: "Good balance, slightly bright",
            recipe: starterRecipe
        )
        context.insert(log1)
        
        let log2 = BrewLog(
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            method: .v60,
            recipeNameAtBrew: "V60 Starter",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 93.0,
            grindLabel: .medium,
            rating: 5,
            tasteTag: nil,
            note: "Perfect!",
            recipe: starterRecipe
        )
        context.insert(log2)
        
        let log3 = BrewLog(
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            method: .v60,
            recipeNameAtBrew: "My Custom V60",
            doseGrams: 18.0,
            targetYieldGrams: 300.0,
            waterTemperatureCelsius: 95.0,
            grindLabel: .fine,
            rating: 3,
            tasteTag: .tooBitter,
            note: "Too intense, will try coarser grind next time",
            recipe: customRecipe
        )
        context.insert(log3)
        
        // Save the context
        do {
            try context.save()
        } catch {
            print("Failed to save preview data: \(error)")
        }
    }
}
