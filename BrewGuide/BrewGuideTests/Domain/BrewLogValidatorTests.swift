//
//  BrewLogValidatorTests.swift
//  BrewGuideTests
//
//  Tests for BrewLogValidator - pure validation logic without persistence dependencies.
//

import Foundation
import Testing
@testable import BrewGuide

@Suite("BrewLogValidator Tests")
@MainActor
struct BrewLogValidatorTests {
    
    // MARK: - BrewLog Entity Validation
    
    @Test("Valid brew log passes validation")
    func testValidBrewLog() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 4,
            tasteTag: .tooBitter,
            note: "Great brew!"
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.isEmpty)
    }
    
    @Test("Rating below 1 fails validation")
    func testRatingTooLow() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 0,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains { error in
            if case .invalidRating(let rating) = error {
                return rating == 0
            }
            return false
        })
    }
    
    @Test("Rating above 5 fails validation")
    func testRatingTooHigh() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 6,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains { error in
            if case .invalidRating(let rating) = error {
                return rating == 6
            }
            return false
        })
    }
    
    @Test("Empty recipe name fails validation")
    func testEmptyRecipeName() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains(.emptyRecipeName))
    }
    
    @Test("Whitespace-only recipe name fails validation")
    func testWhitespaceOnlyRecipeName() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "   \t\n  ",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains(.emptyRecipeName))
    }
    
    @Test("Zero dose fails validation")
    func testZeroDose() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 0,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains(.invalidDose))
    }
    
    @Test("Negative yield fails validation")
    func testNegativeYield() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: -250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: nil
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains(.invalidYield))
    }
    
    @Test("Note exceeding 280 characters fails validation")
    func testNoteTooLong() {
        let longNote = String(repeating: "a", count: 281)
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: longNote
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.contains { error in
            if case .noteTooLong(let count) = error {
                return count == 281
            }
            return false
        })
    }
    
    @Test("Note at 280 characters passes validation")
    func testNoteAtLimit() {
        let note = String(repeating: "a", count: 280)
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 3,
            tasteTag: nil,
            note: note
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.isEmpty)
    }
    
    // MARK: - CreateBrewLogRequest Validation
    
    @Test("Valid create request passes validation")
    func testValidCreateRequest() {
        let request = CreateBrewLogRequest(
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 4
        )
        
        let errors = BrewLogValidator.validate(request)
        #expect(errors.isEmpty)
    }
    
    @Test("Create request with invalid rating fails validation")
    func testCreateRequestInvalidRating() {
        let request = CreateBrewLogRequest(
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            doseGrams: 15,
            targetYieldGrams: 250,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 10
        )
        
        let errors = BrewLogValidator.validate(request)
        #expect(errors.contains { error in
            if case .invalidRating = error {
                return true
            }
            return false
        })
    }
    
    @Test("Multiple validation errors are all reported")
    func testMultipleErrors() {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "",
            doseGrams: 0,
            targetYieldGrams: -100,
            waterTemperatureCelsius: 94,
            grindLabel: .medium,
            rating: 10,
            tasteTag: nil,
            note: String(repeating: "x", count: 300)
        )
        
        let errors = BrewLogValidator.validate(log)
        #expect(errors.count == 5)
        #expect(errors.contains { if case .invalidRating = $0 { return true }; return false })
        #expect(errors.contains(.emptyRecipeName))
        #expect(errors.contains(.invalidDose))
        #expect(errors.contains(.invalidYield))
        #expect(errors.contains { if case .noteTooLong = $0 { return true }; return false })
    }
}
