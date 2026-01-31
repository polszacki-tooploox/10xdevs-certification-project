//
//  RecipeListUseCaseTests.swift
//  BrewGuideTests
//
//  Tests for RecipeListUseCase - business logic for recipe list operations.
//

import Foundation
import Testing
@testable import BrewGuide

@Suite("RecipeListUseCase Tests")
@MainActor
struct RecipeListUseCaseTests {
    
    private func makeUseCase(repository: FakeRecipeRepository) -> RecipeListUseCase {
        RecipeListUseCase(repository: repository)
    }
    
    // MARK: - Fetch Grouped Recipes
    
    @Test("Fetch grouped recipes separates starter and custom")
    func testFetchGroupedRecipes() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        let customRecipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(starterRecipe)
        repository.addRecipe(customRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        // Assert
        #expect(sections.starter.count == 1)
        #expect(sections.custom.count == 1)
        #expect(sections.starter.first?.id == starterRecipe.id)
        #expect(sections.custom.first?.id == customRecipe.id)
    }
    
    @Test("Fetch grouped recipes sorts alphabetically within sections")
    func testFetchGroupedRecipesSorting() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        
        let recipeZ = RecipeFixtures.makeValidV60Recipe()
        recipeZ.name = "Zebra Recipe"
        
        let recipeA = RecipeFixtures.makeValidV60Recipe()
        recipeA.name = "Alpha Recipe"
        
        let recipeM = RecipeFixtures.makeValidV60Recipe()
        recipeM.name = "Middle Recipe"
        
        repository.addRecipe(recipeZ)
        repository.addRecipe(recipeA)
        repository.addRecipe(recipeM)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        // Assert
        #expect(sections.custom.count == 3)
        #expect(sections.custom[0].name == "Alpha Recipe")
        #expect(sections.custom[1].name == "Middle Recipe")
        #expect(sections.custom[2].name == "Zebra Recipe")
    }
    
    @Test("Fetch grouped recipes validates each recipe")
    func testFetchGroupedRecipesValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        
        let validRecipe = RecipeFixtures.makeValidV60Recipe()
        let invalidRecipe = RecipeFixtures.makeValidV60Recipe()
        invalidRecipe.name = "" // Invalid
        
        repository.addRecipe(validRecipe)
        repository.addRecipe(invalidRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        // Assert
        let validDTO = sections.custom.first { $0.id == validRecipe.id }
        let invalidDTO = sections.custom.first { $0.id == invalidRecipe.id }
        
        #expect(validDTO?.isValid == true)
        #expect(invalidDTO?.isValid == false)
    }
    
    @Test("Fetch grouped recipes filters by method")
    func testFetchGroupedRecipesFiltersByMethod() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        
        let v60Recipe = RecipeFixtures.makeValidV60Recipe()
        v60Recipe.method = .v60
        
        repository.addRecipe(v60Recipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        // Assert
        #expect(sections.custom.count == 1)
        #expect(sections.custom.first?.method == .v60)
    }
    
    @Test("Fetch grouped recipes returns empty sections when no recipes")
    func testFetchGroupedRecipesEmpty() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        // Assert
        #expect(sections.isEmpty)
        #expect(sections.starter.isEmpty)
        #expect(sections.custom.isEmpty)
    }
    
    // MARK: - Delete Recipe
    
    @Test("Delete custom recipe succeeds")
    func testDeleteCustomRecipe() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        try useCase.deleteRecipe(id: recipe.id)
        
        // Assert
        #expect(repository.deleteCalls.count == 1)
        #expect(repository.saveCalls == 1)
        #expect(repository.getRecipe(byId: recipe.id) == nil)
    }
    
    @Test("Delete non-existent recipe succeeds (idempotent)")
    func testDeleteNonExistentRecipeSucceeds() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Act & Assert - Should not throw
        try useCase.deleteRecipe(id: UUID())
        
        #expect(repository.deleteCalls.isEmpty)
        #expect(repository.saveCalls == 0)
    }
    
    @Test("Delete starter recipe throws error")
    func testDeleteStarterRecipeThrows() {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        repository.addRecipe(starterRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act & Assert
        #expect(throws: RecipeUseCaseError.cannotDeleteStarter) {
            try useCase.deleteRecipe(id: starterRecipe.id)
        }
        
        #expect(repository.deleteCalls.isEmpty)
        #expect(repository.saveCalls == 0)
        #expect(repository.getRecipe(byId: starterRecipe.id) != nil) // Still exists
    }
    
    // MARK: - Can Delete Recipe
    
    @Test("Can delete custom recipe returns true")
    func testCanDeleteCustomRecipe() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        let customRecipe = RecipeSummaryDTO(
            id: UUID(),
            name: "Custom Recipe",
            method: .v60,
            isStarter: false,
            origin: .custom,
            isValid: true,
            defaultDose: 15,
            defaultTargetYield: 250,
            defaultWaterTemperature: 94,
            defaultGrindLabel: .medium
        )
        
        // Act
        let canDelete = useCase.canDeleteRecipe(customRecipe)
        
        // Assert
        #expect(canDelete == true)
    }
    
    @Test("Cannot delete starter recipe")
    func testCannotDeleteStarterRecipe() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        let starterRecipe = RecipeSummaryDTO(
            id: UUID(),
            name: "Starter",
            method: .v60,
            isStarter: true,
            origin: .starterTemplate,
            isValid: true,
            defaultDose: 15,
            defaultTargetYield: 250,
            defaultWaterTemperature: 94,
            defaultGrindLabel: .medium
        )
        
        // Act
        let canDelete = useCase.canDeleteRecipe(starterRecipe)
        
        // Assert
        #expect(canDelete == false)
    }
    
    @Test("Cannot delete starter template recipe")
    func testCannotDeleteStarterTemplateRecipe() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        let templateRecipe = RecipeSummaryDTO(
            id: UUID(),
            name: "Template",
            method: .v60,
            isStarter: false,
            origin: .starterTemplate,
            isValid: true,
            defaultDose: 15,
            defaultTargetYield: 250,
            defaultWaterTemperature: 94,
            defaultGrindLabel: .medium
        )
        
        // Act
        let canDelete = useCase.canDeleteRecipe(templateRecipe)
        
        // Assert
        #expect(canDelete == false)
    }
}
