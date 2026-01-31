//
//  RecipeUseCaseTests.swift
//  BrewGuideTests
//
//  Unit tests for RecipeUseCase following Test Plan scenarios RV-001 to RV-008.
//  Tests CRUD operations, validation rules, and starter recipe protection.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for RecipeUseCase business rules.
/// Covers all recipe validation scenarios from Test Plan section 4.3.
@Suite("RecipeUseCase Tests")
@MainActor
struct RecipeUseCaseTests {
    
    // MARK: - Test Helpers
    
    func makeUseCase(repository: FakeRecipeRepository) -> RecipeUseCase {
        RecipeUseCase(repository: repository)
    }
    
    // MARK: - fetchRecipeDetail Tests
    
    @Test("Fetch existing recipe returns detail DTO with validation status")
    func testFetchExistingRecipe() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let detail = try useCase.fetchRecipeDetail(id: recipe.id)
        
        // Assert
        #expect(detail.id == recipe.id)
        #expect(detail.recipe.name == recipe.name)
        #expect(detail.recipe.isValid == true)
        #expect(detail.steps.count == 5)
        #expect(repository.fetchRecipeCalls.count == 1)
        #expect(repository.validateCalls.count == 1)
    }
    
    @Test("Fetch non-existent recipe throws recipeNotFound error")
    func testFetchNonExistentRecipe() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        let nonExistentId = UUID()
        
        // Act & Assert
        #expect(throws: RecipeUseCaseError.recipeNotFound) {
            try useCase.fetchRecipeDetail(id: nonExistentId)
        }
    }
    
    @Test("Fetch invalid recipe returns detail DTO with isValid = false")
    func testFetchInvalidRecipe() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeEmptyNameRecipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let detail = try useCase.fetchRecipeDetail(id: recipe.id)
        
        // Assert
        #expect(detail.recipe.isValid == false)
    }
    
    // MARK: - RV-001: Empty name validation
    
    @Test("RV-001: Empty name produces emptyName error")
    func testEmptyNameValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            name: "" // Empty name
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure with validation errors")
            return
        }
        
        #expect(validationErrors.errors.contains(.emptyName))
    }
    
    @Test("RV-001b: Whitespace-only name produces emptyName error")
    func testWhitespaceNameValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            name: "   " // Whitespace only
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        #expect(validationErrors.errors.contains(.emptyName))
    }
    
    // MARK: - RV-002: Zero dose validation
    
    @Test("RV-002: Zero dose produces invalidDose error")
    func testZeroDoseValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultDose: 0.0
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        #expect(validationErrors.errors.contains(.invalidDose))
    }
    
    @Test("RV-002b: Negative dose produces invalidDose error")
    func testNegativeDoseValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultDose: -5.0
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        #expect(validationErrors.errors.contains(.invalidDose))
    }
    
    // MARK: - RV-003: Negative timer validation
    
    @Test("RV-003: Negative timer duration produces negativeTimer error")
    func testNegativeTimerValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let invalidStep = DTOFixtures.makeRecipeStepDTO(
            orderIndex: 0,
            instructionText: "Wait",
            stepKind: .wait,
            durationSeconds: -10, // Negative timer
            targetElapsedSeconds: nil
        )
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            steps: [invalidStep]
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        let hasNegativeTimerError = validationErrors.errors.contains { error in
            if case .negativeTimer(let stepIndex) = error {
                return stepIndex == 0
            }
            return false
        }
        #expect(hasNegativeTimerError)
    }
    
    // MARK: - RV-004: Water total mismatch validation
    
    @Test("RV-004: Water total mismatch produces waterTotalMismatch error")
    func testWaterTotalMismatchValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let mismatchedStep = DTOFixtures.makeRecipeStepDTO(
            orderIndex: 0,
            waterAmountGrams: 200.0, // Doesn't match yield of 250g
            isCumulativeWaterTarget: true
        )
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultTargetYield: 250.0,
            steps: [mismatchedStep]
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        let hasMismatchError = validationErrors.errors.contains { error in
            if case .waterTotalMismatch(let expected, let actual) = error {
                return expected == 250.0 && actual == 200.0
            }
            return false
        }
        #expect(hasMismatchError)
    }
    
    // MARK: - RV-005: No steps validation
    
    @Test("RV-005: Recipe with no steps produces noSteps error")
    func testNoStepsValidation() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            steps: [] // No steps
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        #expect(validationErrors.errors.contains(.noSteps))
    }
    
    // MARK: - RV-006: Starter recipe protection
    
    @Test("RV-006: Editing starter recipe produces starterCannotBeModified error")
    func testStarterRecipeCannotBeModified() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        repository.addRecipe(starterRecipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: starterRecipe.id,
            name: "Modified Name"
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        #expect(validationErrors.errors.contains(.starterCannotBeModified))
        #expect(repository.saveCalls == 0) // Should not attempt save
    }
    
    // MARK: - RV-007: Valid recipe update succeeds
    
    @Test("RV-007: Valid recipe update succeeds and saves changes")
    func testValidRecipeUpdateSucceeds() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            name: "Updated Recipe Name",
            defaultDose: 18.0,
            defaultTargetYield: 300.0
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .success = result else {
            Issue.record("Expected success")
            return
        }
        
        #expect(repository.saveCalls == 1)
        
        // Verify recipe was updated
        let updatedRecipe = repository.getRecipe(byId: recipe.id)
        #expect(updatedRecipe?.name == "Updated Recipe Name")
        #expect(updatedRecipe?.defaultDose == 18.0)
        #expect(updatedRecipe?.defaultTargetYield == 300.0)
    }
    
    // MARK: - RV-008: Water tolerance (±1g)
    
    @Test("RV-008: Water within ±1g tolerance passes validation")
    func testWaterWithinTolerancePasses() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Water is 251g, yield is 250g → difference 1g (within tolerance)
        let step = DTOFixtures.makeRecipeStepDTO(
            orderIndex: 0,
            waterAmountGrams: 251.0,
            isCumulativeWaterTarget: true
        )
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultTargetYield: 250.0,
            steps: [step]
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .success = result else {
            Issue.record("Expected success")
            return
        }
    }
    
    @Test("RV-008b: Water exactly 1g off passes validation")
    func testWaterExactly1gOffPasses() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let step = DTOFixtures.makeRecipeStepDTO(
            orderIndex: 0,
            waterAmountGrams: 249.0, // Exactly 1g under
            isCumulativeWaterTarget: true
        )
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultTargetYield: 250.0,
            steps: [step]
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .success = result else {
            Issue.record("Expected success")
            return
        }
    }
    
    @Test("RV-008c: Water more than 1g off fails validation")
    func testWaterMoreThan1gOffFails() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        let step = DTOFixtures.makeRecipeStepDTO(
            orderIndex: 0,
            waterAmountGrams: 248.0, // 2g off (exceeds tolerance)
            isCumulativeWaterTarget: true
        )
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            defaultTargetYield: 250.0,
            steps: [step]
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .failure(let validationErrors) = result else {
            Issue.record("Expected failure")
            return
        }
        
        let hasMismatchError = validationErrors.errors.contains { error in
            if case .waterTotalMismatch = error { return true }
            return false
        }
        #expect(hasMismatchError)
    }
    
    // MARK: - Step ordering and normalization
    
    @Test("Steps are normalized to contiguous orderIndex during update")
    func testStepsNormalizedToContiguousOrder() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        let useCase = makeUseCase(repository: repository)
        
        // Provide steps with non-contiguous orderIndex
        let steps = [
            DTOFixtures.makeRecipeStepDTO(orderIndex: 5, instructionText: "First"),
            DTOFixtures.makeRecipeStepDTO(orderIndex: 10, instructionText: "Second"),
            DTOFixtures.makeRecipeStepDTO(orderIndex: 2, instructionText: "Third")
        ]
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            steps: steps
        )
        
        // Act
        let result = try useCase.updateCustomRecipe(request)
        
        // Assert
        guard case .success = result else {
            Issue.record("Expected success")
            return
        }
        
        let updatedRecipe = repository.getRecipe(byId: recipe.id)
        let savedSteps = updatedRecipe?.steps?.sorted { $0.orderIndex < $1.orderIndex }
        
        // Steps should be normalized to 0, 1, 2 (sorted by original orderIndex)
        #expect(savedSteps?.count == 3)
        #expect(savedSteps?[0].orderIndex == 0)
        #expect(savedSteps?[0].instructionText == "Third") // Was orderIndex 2
        #expect(savedSteps?[1].orderIndex == 1)
        #expect(savedSteps?[1].instructionText == "First") // Was orderIndex 5
        #expect(savedSteps?[2].orderIndex == 2)
        #expect(savedSteps?[2].instructionText == "Second") // Was orderIndex 10
    }
    
    // MARK: - Error handling
    
    @Test("Update throws recipeNotFound for non-existent recipe")
    func testUpdateNonExistentRecipeThrows() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: UUID() // Non-existent
        )
        
        // Act & Assert
        #expect(throws: RecipeUseCaseError.recipeNotFound) {
            try useCase.updateCustomRecipe(request)
        }
    }
    
    @Test("Save failure throws saveFailed error")
    func testSaveFailureThrowsError() {
        // Arrange
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        repository.shouldThrowOnSave = true
        let useCase = makeUseCase(repository: repository)
        
        let request = DTOFixtures.makeUpdateRecipeRequest(id: recipe.id)
        
        // Act & Assert
        #expect(throws: RecipeUseCaseError.saveFailed(message: "Could not save recipe changes. Please try again.")) {
            try useCase.updateCustomRecipe(request)
        }
    }
}
