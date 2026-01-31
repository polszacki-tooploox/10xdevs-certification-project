//
//  ScalingServiceTests.swift
//  BrewGuideTests
//
//  Unit tests for ScalingService following Test Plan scenarios SC-001 to SC-010.
//  Tests "last edited wins" logic, rounding rules, V60 water targets, and warnings.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for ScalingService business rules.
/// Covers all scaling scenarios from Test Plan section 4.1.
@Suite("ScalingService Tests")
struct ScalingServiceTests {
    let service = ScalingService()
    
    // MARK: - SC-001: Dose change triggers yield recalculation
    
    @Test("SC-001: Dose change from 15g to 20g triggers yield recalculation maintaining recipe ratio")
    func testDoseEditTriggersYieldRecalculation() {
        // Arrange: Recipe with 15g dose → 250g yield (ratio 1:16.67)
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 20.0,
            userTargetYield: 250.0, // User edited dose, not yield
            lastEdited: .dose
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.scaledDose == 20.0)
        // Expected yield = 20 × (250 / 15) = 20 × 16.667 = 333.33 → rounds to 333
        #expect(response.scaledTargetYield == 333.0)
        #expect(response.derivedRatio == 333.0 / 20.0) // ~16.65
    }
    
    // MARK: - SC-002: Yield change triggers dose recalculation
    
    @Test("SC-002: Yield change from 250g to 300g triggers dose recalculation maintaining recipe ratio")
    func testYieldEditTriggersDoseRecalculation() {
        // Arrange: Recipe with 15g dose → 250g yield (ratio 1:16.67)
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0, // User edited yield, not dose
            userTargetYield: 300.0,
            lastEdited: .yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.scaledTargetYield == 300.0)
        // Expected dose = 300 / (250 / 15) = 300 / 16.667 = 18.0
        #expect(response.scaledDose == 18.0)
        #expect(response.derivedRatio == 300.0 / 18.0) // ~16.67
    }
    
    // MARK: - SC-003: Dose rounds to 0.1g
    
    @Test("SC-003: Dose rounds to nearest 0.1g")
    func testDoseRoundingTo0Point1g() {
        // Arrange: Computed dose should be 17.456g
        // With recipe ratio 16.67, target yield 291g → dose = 291 / 16.67 = 17.456
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 291.0,
            lastEdited: .yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: 291 / 16.667 = 17.46... → rounds to 17.5
        #expect(response.scaledDose == 17.5)
    }
    
    @Test("SC-003b: Dose rounds down correctly")
    func testDoseRoundingDown() {
        // Arrange: Dose should round down to 17.4g
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 290.0, // → 17.4
            lastEdited: .yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.scaledDose == 17.4)
    }
    
    // MARK: - SC-004: Yield rounds to 1g
    
    @Test("SC-004: Yield rounds to nearest 1g")
    func testYieldRoundingTo1g() {
        // Arrange: Computed yield should be 287.3g
        // With dose 17.3g and ratio 16.67 → yield = 17.3 × 16.67 = 288.4
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 17.3,
            userTargetYield: 250.0,
            lastEdited: .dose
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: 17.3 × 16.667 = 288.4... → rounds to 288
        #expect(response.scaledTargetYield == 288.0)
    }
    
    // MARK: - SC-005: Bloom water = 3x dose
    
    @Test("SC-005: Bloom water equals 3x dose rounded to nearest 1g")
    func testBloomWaterCalculation() {
        // Arrange: Dose 15g
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 250.0,
            lastEdited: .yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: Bloom = 3 × 15 = 45g
        #expect(response.scaledWaterTargets.count == 3)
        #expect(response.scaledWaterTargets[0] == 45.0) // Bloom
    }
    
    @Test("SC-005b: Bloom water with non-integer dose rounds correctly")
    func testBloomWaterWithNonIntegerDose() {
        // Arrange: Dose 16.5g → bloom = 49.5 → rounds to 50g
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 16.5,
            userTargetYield: 250.0,
            lastEdited: .dose
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.scaledWaterTargets[0] == 50.0) // 3 × 16.5 = 49.5 → 50
    }
    
    // MARK: - SC-006: Pour split 50/50
    
    @Test("SC-006: Pours split 50/50 with final target matching yield exactly")
    func testPourSplit50_50() {
        // Arrange: Yield 250g, Bloom 45g → remaining 205g → split 103g + 102g
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 250.0,
            lastEdited: .yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: Cumulative targets
        #expect(response.scaledWaterTargets.count == 3)
        #expect(response.scaledWaterTargets[0] == 45.0) // Bloom
        
        // Second pour: 45 + (205 / 2) = 45 + 102.5 → 45 + 103 = 148
        #expect(response.scaledWaterTargets[1] == 148.0)
        
        // Final pour: exactly yield
        #expect(response.scaledWaterTargets[2] == 250.0)
    }
    
    // MARK: - SC-007 & SC-008: Ratio warnings
    
    @Test("SC-007: Warning on low ratio (< 1:14)")
    func testWarningOnLowRatio() {
        // Arrange: Dose 15g, yield 200g → ratio 1:13.33 (below 1:14)
        // Use lastEdited: .dose to prevent dose recalculation
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 200.0,
            lastEdited: .dose // Keep dose fixed, use user's yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.warnings.count > 0)
        
        let hasRatioWarning = response.warnings.contains { warning in
            if case .ratioTooLow = warning { return true }
            return false
        }
        #expect(hasRatioWarning)
    }
    
    @Test("SC-008: Warning on high ratio (> 1:18)")
    func testWarningOnHighRatio() {
        // Arrange: Dose 15g, yield 280g → ratio 1:18.67 (above 1:18)
        // Use lastEdited: .dose to prevent dose recalculation
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 280.0,
            lastEdited: .dose // Keep dose fixed, use user's yield
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.warnings.count > 0)
        
        let hasRatioWarning = response.warnings.contains { warning in
            if case .ratioTooHigh = warning { return true }
            return false
        }
        #expect(hasRatioWarning)
    }
    
    // MARK: - SC-009 & SC-010: Temperature warnings
    
    @Test("SC-009: Warning on low temperature (< 90°C)")
    func testWarningOnLowTemperature() {
        // Arrange
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 250.0,
            lastEdited: .yield
        )
        
        // Act: Temperature 88°C (below 90°C)
        let response = service.scaleInputs(request: request, temperatureCelsius: 88.0)
        
        // Assert
        #expect(response.warnings.count > 0)
        
        let hasTempWarning = response.warnings.contains { warning in
            if case .temperatureTooLow = warning { return true }
            return false
        }
        #expect(hasTempWarning)
    }
    
    @Test("SC-010: Warning on high temperature (> 96°C)")
    func testWarningOnHighTemperature() {
        // Arrange
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 250.0,
            lastEdited: .yield
        )
        
        // Act: Temperature 98°C (above 96°C)
        let response = service.scaleInputs(request: request, temperatureCelsius: 98.0)
        
        // Assert
        #expect(response.warnings.count > 0)
        
        let hasTempWarning = response.warnings.contains { warning in
            if case .temperatureTooHigh = warning { return true }
            return false
        }
        #expect(hasTempWarning)
    }
    
    // MARK: - Edge Cases
    
    @Test("No warnings for values within recommended ranges")
    func testNoWarningsForValidValues() {
        // Arrange: All values in range
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 15.0,
            userTargetYield: 250.0, // Ratio 1:16.67 (in range)
            lastEdited: .yield
        )
        
        // Act: Temperature 94°C (in range)
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert
        #expect(response.warnings.isEmpty)
    }
    
    @Test("Zero dose produces zero ratio without crashing")
    func testZeroDoseHandling() {
        // Arrange: Edge case with zero dose
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 0.0,
            userTargetYield: 250.0,
            lastEdited: .dose
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: Should handle gracefully
        #expect(response.scaledDose == 0.0)
        #expect(response.derivedRatio == 0.0)
        // Warnings will be present for invalid dose
        #expect(response.warnings.count > 0)
    }
    
    @Test("Computed water targets are all rounded to 1g")
    func testWaterTargetsAreRounded() {
        // Arrange: Dose that produces non-integer water values
        let request = DTOFixtures.makeScaleInputsRequest(
            recipeDefaultDose: 15.0,
            recipeDefaultTargetYield: 250.0,
            userDose: 16.7,
            userTargetYield: 250.0,
            lastEdited: .dose
        )
        
        // Act
        let response = service.scaleInputs(request: request, temperatureCelsius: 94.0)
        
        // Assert: All water targets should be whole numbers
        for target in response.scaledWaterTargets {
            #expect(target == floor(target))
        }
    }
}
