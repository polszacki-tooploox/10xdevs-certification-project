import Foundation

// MARK: - Scaling DTOs

/// Request payload for scaling brew inputs (Confirm Inputs screen).
/// Uses recipe defaults and user-edited values to compute scaled parameters.
struct ScaleInputsRequest: Codable {
    let method: BrewMethod
    
    // Recipe defaults (immutable reference)
    let recipeDefaultDose: Double
    let recipeDefaultTargetYield: Double
    
    // User-edited values
    let userDose: Double
    let userTargetYield: Double
    
    /// Tracks which field was last edited to determine scaling direction
    let lastEdited: BrewInputs.LastEditedField
    
    /// Computed recipe ratio (immutable)
    var recipeRatio: Double {
        guard recipeDefaultDose > 0 else { return 0 }
        return recipeDefaultTargetYield / recipeDefaultDose
    }
}

/// Response payload containing scaled and rounded brew parameters.
struct ScaleInputsResponse: Codable {
    /// Scaled dose (rounded to 0.1g)
    let scaledDose: Double
    
    /// Scaled target yield (rounded to 1g)
    let scaledTargetYield: Double
    
    /// Scaled cumulative water targets for each step (rounded to 1g)
    /// Final value adjusted to match scaledTargetYield exactly
    let scaledWaterTargets: [Double]
    
    /// Derived ratio (yield / dose)
    let derivedRatio: Double
    
    /// Non-blocking warnings about out-of-range values
    let warnings: [InputWarning]
    
    /// Computed ratio from scaled values
    var computedRatio: Double {
        guard scaledDose > 0 else { return 0 }
        return scaledTargetYield / scaledDose
    }
}

/// Non-blocking warning about brew input being outside recommended range.
enum InputWarning: Codable, Equatable {
    case doseTooLow(dose: Double, minRecommended: Double)
    case doseTooHigh(dose: Double, maxRecommended: Double)
    case yieldTooLow(yield: Double, minRecommended: Double)
    case yieldTooHigh(yield: Double, maxRecommended: Double)
    case ratioTooLow(ratio: Double, minRecommended: Double)
    case ratioTooHigh(ratio: Double, maxRecommended: Double)
    case temperatureTooLow(temp: Double, minRecommended: Double)
    case temperatureTooHigh(temp: Double, maxRecommended: Double)
    
    var message: String {
        switch self {
        case .doseTooLow(let dose, let min):
            return "Dose (\(String(format: "%.1f", dose))g) is below recommended range (≥\(String(format: "%.1f", min))g)"
        case .doseTooHigh(let dose, let max):
            return "Dose (\(String(format: "%.1f", dose))g) is above recommended range (≤\(String(format: "%.1f", max))g)"
        case .yieldTooLow(let yield, let min):
            return "Yield (\(Int(yield))g) is below recommended range (≥\(Int(min))g)"
        case .yieldTooHigh(let yield, let max):
            return "Yield (\(Int(yield))g) is above recommended range (≤\(Int(max))g)"
        case .ratioTooLow(let ratio, let min):
            return "Ratio (1:\(String(format: "%.1f", ratio))) is below recommended range (≥1:\(String(format: "%.1f", min)))"
        case .ratioTooHigh(let ratio, let max):
            return "Ratio (1:\(String(format: "%.1f", ratio))) is above recommended range (≤1:\(String(format: "%.1f", max)))"
        case .temperatureTooLow(let temp, let min):
            return "Temperature (\(Int(temp))°C) is below recommended range (≥\(Int(min))°C)"
        case .temperatureTooHigh(let temp, let max):
            return "Temperature (\(Int(temp))°C) is above recommended range (≤\(Int(max))°C)"
        }
    }
}

// MARK: - V60 Recommended Ranges

/// Recommended ranges for V60 brewing (MVP).
/// Used for non-blocking warnings in ScaleInputsResponse.
struct V60RecommendedRanges {
    static let doseRange: ClosedRange<Double> = 12.0...40.0
    static let yieldRange: ClosedRange<Double> = 180.0...720.0
    static let ratioRange: ClosedRange<Double> = 14.0...18.0
    static let temperatureRange: ClosedRange<Double> = 90.0...96.0
    
    /// Generate warnings for out-of-range values
    static func warnings(
        dose: Double,
        yield: Double,
        temperature: Double
    ) -> [InputWarning] {
        var warnings: [InputWarning] = []
        
        // Dose warnings
        if dose < doseRange.lowerBound {
            warnings.append(.doseTooLow(dose: dose, minRecommended: doseRange.lowerBound))
        } else if dose > doseRange.upperBound {
            warnings.append(.doseTooHigh(dose: dose, maxRecommended: doseRange.upperBound))
        }
        
        // Yield warnings
        if yield < yieldRange.lowerBound {
            warnings.append(.yieldTooLow(yield: yield, minRecommended: yieldRange.lowerBound))
        } else if yield > yieldRange.upperBound {
            warnings.append(.yieldTooHigh(yield: yield, maxRecommended: yieldRange.upperBound))
        }
        
        // Ratio warnings
        let ratio = dose > 0 ? yield / dose : 0
        if ratio > 0 && ratio < ratioRange.lowerBound {
            warnings.append(.ratioTooLow(ratio: ratio, minRecommended: ratioRange.lowerBound))
        } else if ratio > ratioRange.upperBound {
            warnings.append(.ratioTooHigh(ratio: ratio, maxRecommended: ratioRange.upperBound))
        }
        
        // Temperature warnings
        if temperature < temperatureRange.lowerBound {
            warnings.append(.temperatureTooLow(temp: temperature, minRecommended: temperatureRange.lowerBound))
        } else if temperature > temperatureRange.upperBound {
            warnings.append(.temperatureTooHigh(temp: temperature, maxRecommended: temperatureRange.upperBound))
        }
        
        return warnings
    }
}
