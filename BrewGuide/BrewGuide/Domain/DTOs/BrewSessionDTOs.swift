import Foundation

// MARK: - Brew Session DTOs

/// Input parameters for a brew session (editable on Confirm Inputs screen).
/// Derived from `Recipe` entity defaults, modifiable by user.
struct BrewInputs: Codable, Hashable {
    let recipeId: UUID
    let recipeName: String
    let method: BrewMethod
    
    var doseGrams: Double
    var targetYieldGrams: Double
    var waterTemperatureCelsius: Double
    var grindLabel: GrindLabel
    
    /// Tracks which field was last edited for scaling logic
    var lastEdited: LastEditedField
    
    enum LastEditedField: String, Codable {
        case dose
        case yield
    }
    
    /// Computed brew ratio (yield / dose)
    var ratio: Double {
        guard doseGrams > 0 else { return 0 }
        return targetYieldGrams / doseGrams
    }
}

/// A single step in the brew plan with scaled water amounts.
struct ScaledStep: Codable, Identifiable, Hashable {
    let stepId: UUID
    let orderIndex: Int
    let instructionText: String
    let stepKind: StepKind
    
    /// Wait duration for bloom/wait steps (seconds)
    let durationSeconds: Double?
    
    /// Target milestone time from brew start for pour steps (seconds)
    let targetElapsedSeconds: Double?
    
    /// Scaled water amount in grams (rounded to 1g)
    let waterAmountGrams: Double?
    let isCumulativeWaterTarget: Bool
    
    var id: UUID { stepId }
    
    /// Computed: legacy compatibility
    var timerDurationSeconds: Double? {
        durationSeconds ?? targetElapsedSeconds
    }
}

/// Complete brew plan with scaled steps ready for execution.
/// Derived from `RecipeDetailDTO` + `BrewInputs` via scaling rules.
struct BrewPlan: Codable, Hashable {
    let inputs: BrewInputs
    let scaledSteps: [ScaledStep]
    
    /// Total expected water usage (from final cumulative target or sum of incremental)
    var totalWaterGrams: Double {
        if scaledSteps.contains(where: { $0.isCumulativeWaterTarget }),
           let maxWater = scaledSteps.compactMap({ $0.waterAmountGrams }).max() {
            return maxWater
        } else {
            return scaledSteps.compactMap({ $0.waterAmountGrams }).reduce(0, +)
        }
    }
}

/// Current state of an active brew session (state machine).
struct BrewSessionState: Codable, Hashable {
    let plan: BrewPlan
    var phase: Phase
    var currentStepIndex: Int
    var remainingTime: TimeInterval?
    var startedAt: Date?
    let isInputsLocked: Bool
    
    enum Phase: String, Codable {
        case notStarted
        case awaitingPourConfirmation   // NEW: Bloom step waiting for pour complete
        case active
        case paused
        case stepReadyToAdvance
        case completed
    }
    
    /// Current step being executed (if any)
    var currentStep: ScaledStep? {
        guard currentStepIndex >= 0 && currentStepIndex < plan.scaledSteps.count else {
            return nil
        }
        return plan.scaledSteps[currentStepIndex]
    }
    
    /// Whether this is the final step
    var isLastStep: Bool {
        currentStepIndex == plan.scaledSteps.count - 1
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard !plan.scaledSteps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(plan.scaledSteps.count)
    }
    
    /// Total elapsed time since brew started (first timed step began).
    /// Returns nil if brew hasn't started yet.
    var elapsedTime: TimeInterval? {
        guard let startedAt else { return nil }
        return Date.now.timeIntervalSince(startedAt)
    }
}
