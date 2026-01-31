import Foundation
import SwiftData

/// Protocol for recipe repository operations
@MainActor
protocol RecipeRepositoryProtocol {
    // Fetch operations
    func fetchRecipe(byId id: UUID) throws -> Recipe?
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe]
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe?
    
    // CRUD operations
    func insert(_ recipe: Recipe)
    func delete(_ recipe: Recipe)
    func save() throws
    
    // Step operations (pure persistence, no normalization)
    func replaceSteps(for recipe: Recipe, with steps: [RecipeStep])
    func insertSteps(_ steps: [RecipeStep])
}

/// Repository for Recipe persistence operations.
@MainActor
final class RecipeRepository: BaseRepository<Recipe>, RecipeRepositoryProtocol {

    /// Fetch all recipes for a specific brew method
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
        // Fetch all recipes and filter in memory
        // SwiftData predicates don't support captured enum values
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try fetch(descriptor: descriptor)

        // Filter by method and sort: starters first, then alphabetical by name
        return allRecipes
            .filter { $0.method == method }
            .sorted { ($0.isStarter && !$1.isStarter) || ($0.isStarter == $1.isStarter && $0.name < $1.name) }
    }

    /// Fetch the starter recipe for a specific method
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe? {
        // Fetch all starter recipes and filter in memory
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.isStarter == true
            }
        )
        let starters = try fetch(descriptor: descriptor)
        return starters.first { $0.method == method }
    }

    /// Fetch a recipe by its ID
    func fetchRecipe(byId id: UUID) throws -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try fetch(descriptor: descriptor).first
    }

    /// Delete a recipe (caller is responsible for business rule checks)
    /// - Parameter recipe: The recipe to delete
    override func delete(_ recipe: Recipe) {
        context.delete(recipe)
    }

    /// Replace all steps for a recipe with new steps.
    /// Note: Caller is responsible for sorting and normalizing step ordering.
    /// - Parameters:
    ///   - recipe: The recipe to update
    ///   - steps: Array of step entities (already normalized)
    func replaceSteps(for recipe: Recipe, with steps: [RecipeStep]) {
        // Delete existing steps
        if let existingSteps = recipe.steps {
            for step in existingSteps {
                context.delete(step)
            }
        }

        // Insert new steps
        for step in steps {
            context.insert(step)
        }

        // Update recipe's steps relationship
        recipe.steps = steps
    }

    /// Insert multiple steps into context
    /// - Parameter steps: Array of step entities to insert
    func insertSteps(_ steps: [RecipeStep]) {
        for step in steps {
            context.insert(step)
        }
    }
}
