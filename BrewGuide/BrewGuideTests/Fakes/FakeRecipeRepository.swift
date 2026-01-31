//
//  FakeRecipeRepository.swift
//  BrewGuideTests
//
//  Fake implementation of RecipeRepository for unit testing.
//  Provides in-memory storage and call tracking without SwiftData dependencies.
//

import Foundation
import SwiftData
@testable import BrewGuide

/// Fake recipe repository for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeRecipeRepository: RecipeRepositoryProtocol {
    // In-memory storage
    private var recipes: [UUID: Recipe] = [:]
    
    // Call tracking
    private(set) var fetchRecipeCalls: [UUID] = []
    private(set) var fetchRecipesForMethodCalls: [BrewMethod] = []
    private(set) var fetchStarterRecipeCalls: [BrewMethod] = []
    private(set) var insertCalls: [Recipe] = []
    private(set) var deleteCalls: [Recipe] = []
    private(set) var saveCalls: Int = 0
    private(set) var replaceStepsCalls: [(recipe: Recipe, steps: [RecipeStep])] = []
    private(set) var insertStepsCalls: [[RecipeStep]] = []
    
    // Error injection
    var shouldThrowOnFetch: Bool = false
    var shouldThrowOnSave: Bool = false
    var fetchError: Error = NSError(domain: "test", code: 1)
    var saveError: Error = NSError(domain: "test", code: 2)
    
    init() {
    }
    
    // MARK: - RecipeRepositoryProtocol
    
    func fetchRecipe(byId id: UUID) throws -> Recipe? {
        fetchRecipeCalls.append(id)
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return recipes[id]
    }
    
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
        fetchRecipesForMethodCalls.append(method)
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return recipes.values.filter { $0.method == method }
    }
    
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe? {
        fetchStarterRecipeCalls.append(method)
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return recipes.values.first { $0.isStarter && $0.method == method }
    }
    
    func insert(_ recipe: Recipe) {
        insertCalls.append(recipe)
        recipes[recipe.id] = recipe
    }
    
    func delete(_ recipe: Recipe) {
        deleteCalls.append(recipe)
        recipes.removeValue(forKey: recipe.id)
    }
    
    func save() throws {
        saveCalls += 1
        
        if shouldThrowOnSave {
            throw saveError
        }
    }
    
    func replaceSteps(for recipe: Recipe, with steps: [RecipeStep]) {
        replaceStepsCalls.append((recipe: recipe, steps: steps))
        recipe.steps = steps
    }
    
    func insertSteps(_ steps: [RecipeStep]) {
        insertStepsCalls.append(steps)
        // In fake, steps are already linked to recipes
    }
    
    // MARK: - Test Helpers
    
    /// Add a recipe to the in-memory store
    func addRecipe(_ recipe: Recipe) {
        recipes[recipe.id] = recipe
    }
    
    /// Get a recipe directly (bypasses call tracking)
    func getRecipe(byId id: UUID) -> Recipe? {
        recipes[id]
    }
    
    /// Clear all stored recipes
    func clearRecipes() {
        recipes.removeAll()
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        fetchRecipeCalls.removeAll()
        fetchRecipesForMethodCalls.removeAll()
        fetchStarterRecipeCalls.removeAll()
        insertCalls.removeAll()
        deleteCalls.removeAll()
        saveCalls = 0
        replaceStepsCalls.removeAll()
        insertStepsCalls.removeAll()
    }
}
