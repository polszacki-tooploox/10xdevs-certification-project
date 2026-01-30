//
//  ScalingService.swift
//  BrewGuide
//
//  Domain service for scaling brew inputs according to PRD rules.
//

import Foundation

/// Service responsible for scaling brew inputs using "last edited wins" logic
/// and computing V60-specific water targets with warnings.
final class ScalingService {
    
    /// Scales brew inputs based on user edits and recipe defaults.
    /// - Parameters:
    ///   - request: Scaling request containing recipe defaults and user values
    ///   - temperatureCelsius: Water temperature for warning computation
    /// - Returns: Scaled response with rounded values, water targets, and warnings
    func scaleInputs(
        request: ScaleInputsRequest,
        temperatureCelsius: Double
    ) -> ScaleInputsResponse {
        let recipeRatio = request.recipeRatio
        
        // Apply "last edited wins" logic
        var scaledDose: Double
        var scaledYield: Double
        
        switch request.lastEdited {
        case .dose:
            // User edited dose → compute yield from recipe ratio
            scaledDose = request.userDose
            scaledYield = scaledDose * recipeRatio
            
        case .yield:
            // User edited yield → compute dose from recipe ratio
            scaledYield = request.userTargetYield
            scaledDose = recipeRatio > 0 ? scaledYield / recipeRatio : 0
        }
        
        // Apply rounding rules
        scaledDose = roundDose(scaledDose)
        scaledYield = roundWater(scaledYield)
        
        // Compute V60-specific water targets
        let waterTargets = computeV60WaterTargets(
            dose: scaledDose,
            targetYield: scaledYield
        )
        
        // Compute derived ratio
        let derivedRatio = scaledDose > 0 ? scaledYield / scaledDose : 0
        
        // Generate warnings
        let warnings = V60RecommendedRanges.warnings(
            dose: scaledDose,
            yield: scaledYield,
            temperature: temperatureCelsius
        )
        
        return ScaleInputsResponse(
            scaledDose: scaledDose,
            scaledTargetYield: scaledYield,
            scaledWaterTargets: waterTargets,
            derivedRatio: derivedRatio,
            warnings: warnings
        )
    }
    
    // MARK: - V60 Water Target Computation
    
    /// Computes V60-specific cumulative water targets per PRD.
    /// - Bloom = bloomRatio × dose (configurable, default 3×)
    /// - Remaining split 50/50 into two pours
    /// - Final pour adjusted so last target == yield
    private func computeV60WaterTargets(
        dose: Double,
        targetYield: Double,
        bloomRatio: Double = 3.0
    ) -> [Double] {
        // Bloom water
        let bloom = roundWater(bloomRatio * dose)
        
        // Remaining water after bloom
        let remaining = max(0, targetYield - bloom)
        
        // Split remaining into two pours (50/50)
        let secondPour = roundWater(remaining / 2.0)
        _ = remaining - secondPour // thirdPour would be used for non-cumulative targets
        
        // Cumulative targets
        let target1 = bloom
        let target2 = bloom + secondPour
        let target3 = targetYield // Ensure final matches yield exactly
        
        return [target1, target2, target3]
    }
    
    // MARK: - Rounding Helpers
    
    /// Rounds dose to nearest 0.1g
    private func roundDose(_ value: Double) -> Double {
        (value * 10.0).rounded() / 10.0
    }
    
    /// Rounds water/yield to nearest 1g
    private func roundWater(_ value: Double) -> Double {
        value.rounded()
    }
}
