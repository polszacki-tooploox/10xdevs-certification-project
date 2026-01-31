//
//  RecipeValidatorTests.swift
//  BrewGuideTests
//
//  Tests for RecipeValidator - pure validation logic without persistence dependencies.
//

import Foundation
import Testing
@testable import BrewGuide

@Suite("RecipeValidator Tests")
@MainActor
struct RecipeValidatorTests {
    
    // MARK: - Recipe Entity Validation
    
    @Test("Valid recipe passes validation")
    func testValidRecipe() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.isEmpty)
    }
    
    @Test("Empty name fails validation")
    func testEmptyName() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.name = ""
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.emptyName))
    }
    
    @Test("Whitespace-only name fails validation")
    func testWhitespaceOnlyName() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.name = "   \n\t  "
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.emptyName))
    }
    
    @Test("Zero dose fails validation")
    func testZeroDose() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultDose = 0
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.invalidDose))
    }
    
    @Test("Negative dose fails validation")
    func testNegativeDose() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultDose = -15
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.invalidDose))
    }
    
    @Test("Zero yield fails validation")
    func testZeroYield() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultTargetYield = 0
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.invalidYield))
    }
    
    @Test("Negative yield fails validation")
    func testNegativeYield() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultTargetYield = -250
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.invalidYield))
    }
    
    @Test("Recipe with no steps fails validation")
    func testNoSteps() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.steps = nil
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.noSteps))
    }
    
    @Test("Recipe with empty steps array fails validation")
    func testEmptyStepsArray() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.steps = []
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains(.noSteps))
    }
    
    @Test("Negative timer duration fails validation")
    func testNegativeTimer() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        let step = recipe.steps!.first!
        step.timerDurationSeconds = -30
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains { error in
            if case .negativeTimer(let index) = error {
                return index == step.orderIndex
            }
            return false
        })
    }
    
    @Test("Negative water amount fails validation")
    func testNegativeWaterAmount() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        let step = recipe.steps!.first!
        step.waterAmountGrams = -50
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains { error in
            if case .negativeWaterAmount(let index) = error {
                return index == step.orderIndex
            }
            return false
        })
    }
    
    @Test("Water total mismatch fails validation")
    func testWaterTotalMismatch() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultTargetYield = 250
        // Set max water to 300 (more than 1g difference)
        recipe.steps?.last?.waterAmountGrams = 300
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.contains { error in
            if case .waterTotalMismatch = error {
                return true
            }
            return false
        })
    }
    
    @Test("Water total within 1g tolerance passes validation")
    func testWaterTotalWithinTolerance() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.defaultTargetYield = 250
        // Set max water to 250.5 (within 1g tolerance)
        recipe.steps?.last?.waterAmountGrams = 250.5
        
        let errors = RecipeValidator.validate(recipe)
        #expect(!errors.contains { error in
            if case .waterTotalMismatch = error {
                return true
            }
            return false
        })
    }
    
    // MARK: - UpdateRecipeRequest Validation
    
    @Test("Valid update request passes validation")
    func testValidUpdateRequest() {
        let request = DTOFixtures.makeUpdateRecipeRequest()
        let errors = RecipeValidator.validate(request)
        #expect(errors.isEmpty)
    }
    
    @Test("Update request with empty name fails validation")
    func testUpdateRequestEmptyName() {
        var request = DTOFixtures.makeUpdateRecipeRequest()
        request = UpdateRecipeRequest(
            id: request.id,
            name: "",
            defaultDose: request.defaultDose,
            defaultTargetYield: request.defaultTargetYield,
            defaultWaterTemperature: request.defaultWaterTemperature,
            defaultGrindLabel: request.defaultGrindLabel,
            grindTactileDescriptor: request.grindTactileDescriptor,
            steps: request.steps
        )
        
        let errors = RecipeValidator.validate(request)
        #expect(errors.contains(.emptyName))
    }
    
    @Test("Update request with invalid dose fails validation")
    func testUpdateRequestInvalidDose() {
        var request = DTOFixtures.makeUpdateRecipeRequest()
        request = UpdateRecipeRequest(
            id: request.id,
            name: request.name,
            defaultDose: -10,
            defaultTargetYield: request.defaultTargetYield,
            defaultWaterTemperature: request.defaultWaterTemperature,
            defaultGrindLabel: request.defaultGrindLabel,
            grindTactileDescriptor: request.grindTactileDescriptor,
            steps: request.steps
        )
        
        let errors = RecipeValidator.validate(request)
        #expect(errors.contains(.invalidDose))
    }
    
    @Test("Update request with no steps fails validation")
    func testUpdateRequestNoSteps() {
        var request = DTOFixtures.makeUpdateRecipeRequest()
        request = UpdateRecipeRequest(
            id: request.id,
            name: request.name,
            defaultDose: request.defaultDose,
            defaultTargetYield: request.defaultTargetYield,
            defaultWaterTemperature: request.defaultWaterTemperature,
            defaultGrindLabel: request.defaultGrindLabel,
            grindTactileDescriptor: request.grindTactileDescriptor,
            steps: []
        )
        
        let errors = RecipeValidator.validate(request)
        #expect(errors.contains(.noSteps))
    }
    
    @Test("Multiple validation errors are all reported")
    func testMultipleErrors() {
        let recipe = RecipeFixtures.makeValidV60Recipe()
        recipe.name = ""
        recipe.defaultDose = -10
        recipe.defaultTargetYield = 0
        recipe.steps = []
        
        let errors = RecipeValidator.validate(recipe)
        #expect(errors.count == 4)
        #expect(errors.contains(.emptyName))
        #expect(errors.contains(.invalidDose))
        #expect(errors.contains(.invalidYield))
        #expect(errors.contains(.noSteps))
    }
}
