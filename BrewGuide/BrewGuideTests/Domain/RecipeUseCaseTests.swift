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
        
        // Create steps that match the updated yield of 300g
        let updatedSteps = [
            DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                instructionText: "Rinse filter",
                stepKind: .preparation,
                durationSeconds: nil,
                targetElapsedSeconds: nil,
                waterAmountGrams: nil,
                isCumulativeWaterTarget: false
            ),
            DTOFixtures.makeRecipeStepDTO(
                orderIndex: 1,
                instructionText: "Bloom",
                stepKind: .bloom,
                durationSeconds: 45,
                targetElapsedSeconds: nil,
                waterAmountGrams: 54.0, // Scaled for 300g
                isCumulativeWaterTarget: true
            ),
            DTOFixtures.makeRecipeStepDTO(
                orderIndex: 2,
                instructionText: "Pour to 300g",
                stepKind: .pour,
                durationSeconds: nil,
                targetElapsedSeconds: 135,
                waterAmountGrams: 300.0, // Matches yield
                isCumulativeWaterTarget: true
            )
        ]
        
        let request = DTOFixtures.makeUpdateRecipeRequest(
            id: recipe.id,
            name: "Updated Recipe Name",
            defaultDose: 18.0,
            defaultTargetYield: 300.0,
            steps: updatedSteps
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
    
    // MARK: - Duplicate Recipe Tests
    
    @Test("Duplicate recipe creates new custom recipe with 'Copy' suffix")
    func testDuplicateRecipeCreatesCustomCopy() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let sourceRecipe = RecipeFixtures.makeValidV60Recipe()
        sourceRecipe.name = "Original Recipe"
        repository.addRecipe(sourceRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let newId = try useCase.duplicateRecipe(id: sourceRecipe.id)
        
        // Assert
        #expect(newId != sourceRecipe.id)
        #expect(repository.insertCalls.count == 1)
        #expect(repository.insertStepsCalls.count == 1)
        #expect(repository.saveCalls == 1)
        
        let newRecipe = repository.getRecipe(byId: newId)
        #expect(newRecipe?.name == "Original Recipe Copy")
        #expect(newRecipe?.isStarter == false)
        #expect(newRecipe?.origin == .custom)
        #expect(newRecipe?.defaultDose == sourceRecipe.defaultDose)
        #expect(newRecipe?.defaultTargetYield == sourceRecipe.defaultTargetYield)
    }
    
    @Test("Duplicate recipe clones all steps")
    func testDuplicateRecipeClonesSteps() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let sourceRecipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(sourceRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let newId = try useCase.duplicateRecipe(id: sourceRecipe.id)
        
        // Assert
        let newRecipe = repository.getRecipe(byId: newId)
        let sourceStepCount = sourceRecipe.steps?.count ?? 0
        let newStepCount = newRecipe?.steps?.count ?? 0
        
        #expect(newStepCount == sourceStepCount)
        #expect(newStepCount > 0) // Ensure steps were actually cloned
    }
    
    @Test("Duplicate starter recipe creates custom non-starter copy")
    func testDuplicateStarterRecipeCreatesCustom() throws {
        // Arrange
        let repository = FakeRecipeRepository()
        let starterRecipe = RecipeFixtures.makeStarterV60Recipe()
        repository.addRecipe(starterRecipe)
        
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let newId = try useCase.duplicateRecipe(id: starterRecipe.id)
        
        // Assert
        let newRecipe = repository.getRecipe(byId: newId)
        #expect(newRecipe?.isStarter == false)
        #expect(newRecipe?.origin == .custom)
    }
    
    @Test("Duplicate non-existent recipe throws recipeNotFound")
    func testDuplicateNonExistentRecipeThrows() {
        // Arrange
        let repository = FakeRecipeRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Act & Assert
        #expect(throws: RecipeUseCaseError.recipeNotFound) {
            try useCase.duplicateRecipe(id: UUID())
        }
    }
    
    // MARK: - Delete Recipe Tests
    
    @Test("Delete custom recipe succeeds and saves")
    func testDeleteCustomRecipeSucceeds() throws {
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
    
    @Test("Delete starter recipe throws cannotDeleteStarter error")
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
    
    // MARK: - Can Edit/Delete Tests
    
    @Test("Can edit custom recipe returns true")
    func testCanEditCustomRecipe() {
        // Arrange
        let useCase = makeUseCase(repository: FakeRecipeRepository())
        let customRecipe = RecipeSummaryDTO(
            id: UUID(),
            name: "Custom",
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
        let canEdit = useCase.canEdit(recipe: customRecipe)
        
        // Assert
        #expect(canEdit == true)
    }
    
    @Test("Cannot edit starter recipe")
    func testCannotEditStarterRecipe() {
        // Arrange
        let useCase = makeUseCase(repository: FakeRecipeRepository())
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
        let canEdit = useCase.canEdit(recipe: starterRecipe)
        
        // Assert
        #expect(canEdit == false)
    }
    
    @Test("Can delete custom recipe returns true")
    func testCanDeleteCustomRecipe() {
        // Arrange
        let useCase = makeUseCase(repository: FakeRecipeRepository())
        let customRecipe = RecipeSummaryDTO(
            id: UUID(),
            name: "Custom",
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
        let canDelete = useCase.canDelete(recipe: customRecipe)
        
        // Assert
        #expect(canDelete == true)
    }
    
    @Test("Cannot delete starter recipe")
    func testCannotDeleteStarterRecipe() {
        // Arrange
        let useCase = makeUseCase(repository: FakeRecipeRepository())
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
        let canDelete = useCase.canDelete(recipe: starterRecipe)
        
        // Assert
        #expect(canDelete == false)
    }
}

