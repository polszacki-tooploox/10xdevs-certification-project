//
//  DTOValidationTests.swift
//  BrewGuideTests
//
//  Unit tests for DTO validation methods.
//  Tests validation rules for CreateRecipeRequest, UpdateRecipeRequest, and CreateBrewLogRequest.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for DTO validation logic.
/// Covers all validation scenarios for command DTOs.
@Suite("DTO Validation Tests")
struct DTOValidationTests {
    
    // MARK: - CreateRecipeRequest Validation
    
    @Suite("CreateRecipeRequest Validation")
    struct CreateRecipeRequestValidationTests {
        
        @Test("Valid request produces no errors")
        func testValidRequestPassesValidation() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest()
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.isEmpty)
        }
        
        @Test("Empty name produces emptyName error")
        func testEmptyNameError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(name: "")
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.emptyName))
        }
        
        @Test("Whitespace-only name produces emptyName error")
        func testWhitespaceNameError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(name: "   ")
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.emptyName))
        }
        
        @Test("Zero dose produces invalidDose error")
        func testZeroDoseError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(defaultDose: 0.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidDose))
        }
        
        @Test("Negative dose produces invalidDose error")
        func testNegativeDoseError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(defaultDose: -5.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidDose))
        }
        
        @Test("Zero yield produces invalidYield error")
        func testZeroYieldError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(defaultTargetYield: 0.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidYield))
        }
        
        @Test("Negative yield produces invalidYield error")
        func testNegativeYieldError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(defaultTargetYield: -100.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidYield))
        }
        
        @Test("No steps produces noSteps error")
        func testNoStepsError() {
            // Arrange
            let request = DTOFixtures.makeCreateRecipeRequest(steps: [])
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.noSteps))
        }
        
        @Test("Negative timer duration produces negativeTimer error")
        func testNegativeTimerError() {
            // Arrange
            let invalidStep = DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                durationSeconds: -10
            )
            let request = DTOFixtures.makeCreateRecipeRequest(steps: [invalidStep])
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasNegativeTimerError = errors.contains { error in
                if case .negativeTimer(let stepIndex) = error {
                    return stepIndex == 0
                }
                return false
            }
            #expect(hasNegativeTimerError)
        }
        
        @Test("Negative water amount produces negativeWaterAmount error")
        func testNegativeWaterAmountError() {
            // Arrange
            let invalidStep = DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                waterAmountGrams: -50.0
            )
            let request = DTOFixtures.makeCreateRecipeRequest(steps: [invalidStep])
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasNegativeWaterError = errors.contains { error in
                if case .negativeWaterAmount(let stepIndex) = error {
                    return stepIndex == 0
                }
                return false
            }
            #expect(hasNegativeWaterError)
        }
        
        @Test("Water total mismatch produces waterTotalMismatch error")
        func testWaterTotalMismatchError() {
            // Arrange
            let mismatchedStep = DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                waterAmountGrams: 200.0,
                isCumulativeWaterTarget: true
            )
            let request = DTOFixtures.makeCreateRecipeRequest(
                defaultTargetYield: 250.0,
                steps: [mismatchedStep]
            )
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasMismatchError = errors.contains { error in
                if case .waterTotalMismatch(let expected, let actual) = error {
                    return expected == 250.0 && actual == 200.0
                }
                return false
            }
            #expect(hasMismatchError)
        }
        
        @Test("Water within ±1g tolerance passes validation")
        func testWaterWithinTolerancePasses() {
            // Arrange
            let step = DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                waterAmountGrams: 251.0, // 1g over
                isCumulativeWaterTarget: true
            )
            let request = DTOFixtures.makeCreateRecipeRequest(
                defaultTargetYield: 250.0,
                steps: [step]
            )
            
            // Act
            let errors = request.validate()
            
            // Assert: Should not have water mismatch error
            let hasMismatchError = errors.contains { error in
                if case .waterTotalMismatch = error { return true }
                return false
            }
            #expect(!hasMismatchError)
        }
        
        @Test("Multiple validation errors are accumulated")
        func testMultipleErrorsAccumulated() {
            // Arrange: Multiple issues
            let request = DTOFixtures.makeCreateRecipeRequest(
                name: "", // Error 1
                defaultDose: 0.0, // Error 2
                steps: [] // Error 3
            )
            
            // Act
            let errors = request.validate()
            
            // Assert: All errors present
            #expect(errors.count >= 3)
            #expect(errors.contains(.emptyName))
            #expect(errors.contains(.invalidDose))
            #expect(errors.contains(.noSteps))
        }
    }
    
    // MARK: - UpdateRecipeRequest Validation
    
    @Suite("UpdateRecipeRequest Validation")
    struct UpdateRecipeRequestValidationTests {
        
        @Test("Valid update request produces no errors")
        func testValidUpdateRequestPassesValidation() {
            // Arrange
            let request = DTOFixtures.makeUpdateRecipeRequest()
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.isEmpty)
        }
        
        @Test("Empty name produces emptyName error")
        func testEmptyNameError() {
            // Arrange
            let request = DTOFixtures.makeUpdateRecipeRequest(name: "")
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.emptyName))
        }
        
        @Test("Zero dose produces invalidDose error")
        func testZeroDoseError() {
            // Arrange
            let request = DTOFixtures.makeUpdateRecipeRequest(defaultDose: 0.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidDose))
        }
        
        @Test("No steps produces noSteps error")
        func testNoStepsError() {
            // Arrange
            let request = DTOFixtures.makeUpdateRecipeRequest(steps: [])
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.noSteps))
        }
        
        @Test("Water total mismatch produces waterTotalMismatch error")
        func testWaterTotalMismatchError() {
            // Arrange
            let mismatchedStep = DTOFixtures.makeRecipeStepDTO(
                orderIndex: 0,
                waterAmountGrams: 200.0,
                isCumulativeWaterTarget: true
            )
            let request = DTOFixtures.makeUpdateRecipeRequest(
                defaultTargetYield: 250.0,
                steps: [mismatchedStep]
            )
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasMismatchError = errors.contains { error in
                if case .waterTotalMismatch = error { return true }
                return false
            }
            #expect(hasMismatchError)
        }
        
        // Note: UpdateRecipeRequest has the same validation rules as CreateRecipeRequest
        // Additional scenarios covered in CreateRecipeRequest tests
    }
    
    // MARK: - CreateBrewLogRequest Validation
    
    @Suite("CreateBrewLogRequest Validation")
    struct CreateBrewLogRequestValidationTests {
        
        @Test("Valid brew log request produces no errors")
        func testValidRequestPassesValidation() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest()
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.isEmpty)
        }
        
        @Test("Rating below 1 produces invalidRating error")
        func testRatingBelowMinimumError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(rating: 0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasRatingError = errors.contains { error in
                if case .invalidRating(let value) = error {
                    return value == 0
                }
                return false
            }
            #expect(hasRatingError)
        }
        
        @Test("Rating above 5 produces invalidRating error")
        func testRatingAboveMaximumError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(rating: 6)
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasRatingError = errors.contains { error in
                if case .invalidRating(let value) = error {
                    return value == 6
                }
                return false
            }
            #expect(hasRatingError)
        }
        
        @Test("Negative rating produces invalidRating error")
        func testNegativeRatingError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(rating: -1)
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasRatingError = errors.contains { error in
                if case .invalidRating = error { return true }
                return false
            }
            #expect(hasRatingError)
        }
        
        @Test("Valid rating values 1-5 pass validation")
        func testValidRatingsPass() {
            // Act & Assert: All ratings 1-5 should pass
            for rating in 1...5 {
                let request = DTOFixtures.makeCreateBrewLogRequest(rating: rating)
                let errors = request.validate()
                #expect(errors.isEmpty)
            }
        }
        
        @Test("Empty recipe name produces emptyRecipeName error")
        func testEmptyRecipeNameError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(recipeNameAtBrew: "")
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.emptyRecipeName))
        }
        
        @Test("Whitespace-only recipe name produces emptyRecipeName error")
        func testWhitespaceRecipeNameError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(recipeNameAtBrew: "   ")
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.emptyRecipeName))
        }
        
        @Test("Zero dose produces invalidDose error")
        func testZeroDoseError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(doseGrams: 0.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidDose))
        }
        
        @Test("Negative dose produces invalidDose error")
        func testNegativeDoseError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(doseGrams: -5.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidDose))
        }
        
        @Test("Zero yield produces invalidYield error")
        func testZeroYieldError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(targetYieldGrams: 0.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidYield))
        }
        
        @Test("Negative yield produces invalidYield error")
        func testNegativeYieldError() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(targetYieldGrams: -100.0)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.contains(.invalidYield))
        }
        
        @Test("Note with 280 characters passes validation")
        func testNoteAtMaxLengthPasses() {
            // Arrange
            let maxLengthNote = String(repeating: "a", count: 280)
            let request = DTOFixtures.makeCreateBrewLogRequest(note: maxLengthNote)
            
            // Act
            let errors = request.validate()
            
            // Assert: Should pass
            let hasNoteTooLongError = errors.contains { error in
                if case .noteTooLong = error { return true }
                return false
            }
            #expect(!hasNoteTooLongError)
        }
        
        @Test("Note with 281 characters produces noteTooLong error")
        func testNoteAboveMaxLengthFails() {
            // Arrange
            let tooLongNote = String(repeating: "a", count: 281)
            let request = DTOFixtures.makeCreateBrewLogRequest(note: tooLongNote)
            
            // Act
            let errors = request.validate()
            
            // Assert
            let hasNoteTooLongError = errors.contains { error in
                if case .noteTooLong(let count) = error {
                    return count == 281
                }
                return false
            }
            #expect(hasNoteTooLongError)
        }
        
        @Test("Nil note passes validation")
        func testNilNotePasses() {
            // Arrange
            let request = DTOFixtures.makeCreateBrewLogRequest(note: nil)
            
            // Act
            let errors = request.validate()
            
            // Assert
            #expect(errors.isEmpty)
        }
        
        @Test("Multiple validation errors are accumulated")
        func testMultipleErrorsAccumulated() {
            // Arrange: Multiple issues
            let tooLongNote = String(repeating: "x", count: 300)
            let request = DTOFixtures.makeCreateBrewLogRequest(
                recipeNameAtBrew: "", // Error 1
                doseGrams: 0.0, // Error 2
                rating: 0, // Error 3
                note: tooLongNote // Error 4
            )
            
            // Act
            let errors = request.validate()
            
            // Assert: All errors present
            #expect(errors.count >= 4)
            #expect(errors.contains(.emptyRecipeName))
            #expect(errors.contains(.invalidDose))
            
            let hasRatingError = errors.contains { error in
                if case .invalidRating = error { return true }
                return false
            }
            #expect(hasRatingError)
            
            let hasNoteTooLongError = errors.contains { error in
                if case .noteTooLong = error { return true }
                return false
            }
            #expect(hasNoteTooLongError)
        }
    }
    
    // MARK: - Validation Error Descriptions
    
    @Suite("Validation Error Descriptions")
    struct ValidationErrorDescriptionTests {
        
        @Test("RecipeValidationError descriptions are user-friendly")
        func testRecipeValidationErrorDescriptions() {
            // Arrange & Act
            let errors: [RecipeValidationError] = [
                .emptyName,
                .invalidDose,
                .invalidYield,
                .noSteps,
                .negativeTimer(stepIndex: 2),
                .negativeWaterAmount(stepIndex: 1),
                .waterTotalMismatch(expected: 250.0, actual: 200.0),
                .starterCannotBeModified,
                .starterCannotBeDeleted
            ]
            
            // Assert: All have non-empty descriptions
            for error in errors {
                #expect(!error.localizedDescription.isEmpty)
            }
        }
        
        @Test("BrewLogValidationError descriptions are user-friendly")
        func testBrewLogValidationErrorDescriptions() {
            // Arrange & Act
            let errors: [BrewLogValidationError] = [
                .invalidRating(6),
                .emptyRecipeName,
                .invalidDose,
                .invalidYield,
                .noteTooLong(count: 300)
            ]
            
            // Assert: All have non-empty descriptions
            for error in errors {
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }
}
