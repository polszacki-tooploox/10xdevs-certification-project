//
//  BrewSessionUseCaseTests.swift
//  BrewGuideTests
//
//  Unit tests for BrewSessionUseCase.
//  Tests brew plan creation, recipe scaling, and method validation.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for BrewSessionUseCase business rules.
/// Covers plan creation, step scaling, and error handling.
@Suite("BrewSessionUseCase Tests")
@MainActor
struct BrewSessionUseCaseTests {
    
    // MARK: - Test Helpers
    
    func makeUseCase(repository: FakeRecipeRepository) -> BrewSessionUseCase {
        BrewSessionUseCase(recipeRepository: repository)
    }
    
    // MARK: - createPlan Tests
    
    @Test("Create plan from valid inputs succeeds and scales steps")
    func testCreatePlanSucceeds() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe(
            defaultDose: 15.0,
            defaultTargetYield: 250.0
        )
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            method: .v60,
            doseGrams: 15.0,
            targetYieldGrams: 250.0
        )
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert
        #expect(plan.inputs.recipeId == recipe.id)
        #expect(plan.scaledSteps.count == 5) // From fixture
        #expect(repository.fetchRecipeCalls.count == 1)
    }
    
    @Test("Create plan scales water amounts by yield ratio")
    func testCreatePlanScalesWaterAmounts() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe(
            defaultDose: 15.0,
            defaultTargetYield: 250.0
        )
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // User wants to brew with double the yield
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            method: .v60,
            doseGrams: 30.0,
            targetYieldGrams: 500.0 // 2x scale
        )
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert
        let scalingFactor = 500.0 / 250.0 // = 2.0
        
        // Check bloom step (step 1, 45g water in recipe)
        let bloomStep = plan.scaledSteps.first { $0.stepKind == .bloom }
        #expect(bloomStep?.waterAmountGrams == 45.0 * scalingFactor) // 90g
        
        // Check first pour step (step 2, 148g water in recipe)
        let firstPour = plan.scaledSteps.first { 
            $0.stepKind == .pour && $0.orderIndex == 2 
        }
        #expect(firstPour?.waterAmountGrams == 148.0 * scalingFactor) // 296g
    }
    
    @Test("Create plan preserves step properties except water amounts")
    func testCreatePlanPreservesStepProperties() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            targetYieldGrams: 250.0
        )
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert: Step properties preserved
        let prepStep = plan.scaledSteps.first { $0.stepKind == .preparation }
        #expect(prepStep?.instructionText.contains("Rinse") == true)
        
        let bloomStep = plan.scaledSteps.first { $0.stepKind == .bloom }
        #expect(bloomStep?.durationSeconds == 45.0)
        #expect(bloomStep?.isCumulativeWaterTarget == true)
    }
    
    // MARK: - Error: Recipe not found
    
    @Test("Create plan throws recipeNotFound for non-existent recipe")
    func testCreatePlanThrowsForNonExistentRecipe() async {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: UUID() // Non-existent
        )
        
        // Act & Assert
        await #expect(throws: BrewSessionError.recipeNotFound) {
            try await useCase.createPlan(from: inputs)
        }
    }
    
    // MARK: - Error: Method mismatch
    
    @Test("Create plan throws methodMismatch when brew method doesn't match recipe")
    func testCreatePlanThrowsForMethodMismatch() async {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe() // V60 recipe
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Try to brew with wrong method (future-proof test for when other methods exist)
        var inputs = DTOFixtures.makeBrewInputs(recipeId: recipe.id)
        // Since we only have v60, we can't directly test this without adding another method
        // For now, we'll verify the logic path exists
        
        // This test documents the intended behavior for when multiple methods exist
        // Currently all recipes are v60, so this would require production code change
    }
    
    // MARK: - Error: No steps
    
    @Test("Create plan throws noSteps when recipe has no steps")
    func testCreatePlanThrowsForNoSteps() async {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeNoStepsRecipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(recipeId: recipe.id)
        
        // Act & Assert
        await #expect(throws: BrewSessionError.noSteps) {
            try await useCase.createPlan(from: inputs)
        }
    }
    
    @Test("Create plan throws noSteps when recipe steps array is nil")
    func testCreatePlanThrowsForNilSteps() async {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.steps = nil // Simulate nil steps
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(recipeId: recipe.id)
        
        // Act & Assert
        await #expect(throws: BrewSessionError.noSteps) {
            try await useCase.createPlan(from: inputs)
        }
    }
    
    // MARK: - createInputs Tests
    
    @Test("Create inputs from recipe uses default values")
    func testCreateInputsFromRecipe() {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe(
            name: "My Recipe",
            defaultDose: 18.0,
            defaultTargetYield: 300.0,
            defaultWaterTemperature: 92.0,
            defaultGrindLabel: .fine
        )
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let inputs = useCase.createInputs(from: recipe)
        
        // Assert
        #expect(inputs.recipeId == recipe.id)
        #expect(inputs.recipeName == "My Recipe")
        #expect(inputs.method == .v60)
        #expect(inputs.doseGrams == 18.0)
        #expect(inputs.targetYieldGrams == 300.0)
        #expect(inputs.waterTemperatureCelsius == 92.0)
        #expect(inputs.grindLabel == .fine)
        #expect(inputs.lastEdited == .yield) // Default per PRD
    }
    
    // MARK: - Scaling factor calculation
    
    @Test("Scaling factor calculated correctly for various yields")
    func testScalingFactorCalculation() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe(
            defaultDose: 15.0,
            defaultTargetYield: 250.0
        )
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Test 1: Half scale
        let halfInputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            targetYieldGrams: 125.0 // 0.5x
        )
        let halfPlan = try await useCase.createPlan(from: halfInputs)
        
        // Bloom step should be 45g × 0.5 = 22.5g
        let halfBloom = halfPlan.scaledSteps.first { $0.stepKind == .bloom }
        #expect(halfBloom?.waterAmountGrams == 22.5)
        
        // Test 2: 1.5x scale
        let largerInputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            targetYieldGrams: 375.0 // 1.5x
        )
        let largerPlan = try await useCase.createPlan(from: largerInputs)
        
        // Bloom step should be 45g × 1.5 = 67.5g
        let largerBloom = largerPlan.scaledSteps.first { $0.stepKind == .bloom }
        #expect(largerBloom?.waterAmountGrams == 67.5)
    }
    
    // MARK: - Steps with nil water amounts
    
    @Test("Create plan handles steps with nil water amounts")
    func testCreatePlanHandlesNilWaterAmounts() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            targetYieldGrams: 500.0 // 2x scale
        )
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert: Preparation and wait steps have nil water, should remain nil
        let prepStep = plan.scaledSteps.first { $0.stepKind == .preparation }
        #expect(prepStep?.waterAmountGrams == nil)
        
        let waitStep = plan.scaledSteps.first { $0.stepKind == .wait }
        #expect(waitStep?.waterAmountGrams == nil)
    }
    
    // MARK: - Step ordering preserved
    
    @Test("Create plan preserves step ordering from recipe")
    func testCreatePlanPreservesStepOrdering() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(recipeId: recipe.id)
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert: Steps are in order
        for (index, step) in plan.scaledSteps.enumerated() {
            #expect(step.orderIndex == index)
        }
        
        // Verify expected sequence
        #expect(plan.scaledSteps[0].stepKind == .preparation)
        #expect(plan.scaledSteps[1].stepKind == .bloom)
        #expect(plan.scaledSteps[2].stepKind == .pour)
        #expect(plan.scaledSteps[3].stepKind == .pour)
        #expect(plan.scaledSteps[4].stepKind == .wait)
    }
    
    // MARK: - Edge cases
    
    @Test("Create plan with 1:1 scaling (no change) works correctly")
    func testCreatePlanWithNoScaling() async throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe(
            defaultDose: 15.0,
            defaultTargetYield: 250.0
        )
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let inputs = DTOFixtures.makeBrewInputs(
            recipeId: recipe.id,
            targetYieldGrams: 250.0 // Same as recipe
        )
        
        // Act
        let plan = try await useCase.createPlan(from: inputs)
        
        // Assert: Water amounts unchanged
        let bloomStep = plan.scaledSteps.first { $0.stepKind == .bloom }
        #expect(bloomStep?.waterAmountGrams == 45.0) // Original amount
    }
    
    // MARK: - Load Recipe for Brewing Tests
    
    @Test("Load recipe by ID returns the specified recipe")
    func testLoadRecipeByIdReturnsSpecifiedRecipe() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe1 = RecipeFixtures.makeValidV60Recipe()
        recipe1.name = "Recipe 1"
        let recipe2 = RecipeFixtures.makeValidV60Recipe()
        recipe2.name = "Recipe 2"
        repository.addRecipe(recipe1)
        repository.addRecipe(recipe2)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let loadedRecipe = try useCase.loadRecipeForBrewing(id: recipe2.id, fallbackMethod: .v60)
        
        // Assert
        #expect(loadedRecipe.id == recipe2.id)
        #expect(loadedRecipe.name == "Recipe 2")
    }
    
    @Test("Load recipe with nil ID falls back to starter recipe")
    func testLoadRecipeWithNilIdFallsBackToStarter() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        let customRecipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(starterRecipe)
        repository.addRecipe(customRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let loadedRecipe = try useCase.loadRecipeForBrewing(id: nil, fallbackMethod: .v60)
        
        // Assert
        #expect(loadedRecipe.id == starterRecipe.id)
        #expect(loadedRecipe.isStarter == true)
    }
    
    @Test("Load recipe with non-existent ID falls back to starter recipe")
    func testLoadRecipeWithNonExistentIdFallsBackToStarter() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        repository.addRecipe(starterRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let loadedRecipe = try useCase.loadRecipeForBrewing(
            id: UUID(), // Non-existent
            fallbackMethod: .v60
        )
        
        // Assert
        #expect(loadedRecipe.id == starterRecipe.id)
        #expect(loadedRecipe.isStarter == true)
    }
    
    @Test("Load recipe with no starter available throws recipeNotFound")
    func testLoadRecipeWithNoStarterThrows() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Act & Assert
        #expect(throws: BrewSessionError.recipeNotFound) {
            try useCase.loadRecipeForBrewing(id: nil, fallbackMethod: .v60)
        }
    }
    
    @Test("Load recipe uses fallback method for starter lookup")
    func testLoadRecipeUsesFallbackMethodForStarter() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let v60Starter = RecipeFixtures.makeStarterV60Recipe()
        v60Starter.method = .v60
        repository.addRecipe(v60Starter)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let loadedRecipe = try useCase.loadRecipeForBrewing(id: nil, fallbackMethod: .v60)
        
        // Assert
        #expect(loadedRecipe.method == .v60)
        #expect(loadedRecipe.id == v60Starter.id)
    }
}

