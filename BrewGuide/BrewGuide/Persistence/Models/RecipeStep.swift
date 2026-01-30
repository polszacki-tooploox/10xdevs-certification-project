import Foundation
import SwiftData

/// A single step in a brew recipe with instructions, timing, and water addition guidance.
/// CloudKit-compatible: all properties have default values or are optional.
@Model
final class RecipeStep {
    /// Stable identifier for this step
    var stepId: UUID = UUID()
    
    /// Position in the recipe's step sequence (0-based)
    var orderIndex: Int = 0
    
    /// Human-readable instruction text
    var instructionText: String = ""
    
    /// Duration in seconds for timed steps (nil if not timed)
    var timerDurationSeconds: Double?
    
    /// Target water amount in grams for water addition steps (nil if not applicable)
    var waterAmountGrams: Double?
    
    /// Whether this is a cumulative water target (e.g., "pour to 150g") vs incremental
    var isCumulativeWaterTarget: Bool = true
    
    /// Parent recipe
    /// CloudKit-compatible: relationship is optional with inverse
    @Relationship(inverse: \Recipe.steps)
    var recipe: Recipe?
    
    /// Initializer for creating new recipe steps
    init(
        stepId: UUID = UUID(),
        orderIndex: Int = 0,
        instructionText: String = "",
        timerDurationSeconds: Double? = nil,
        waterAmountGrams: Double? = nil,
        isCumulativeWaterTarget: Bool = true,
        recipe: Recipe? = nil
    ) {
        self.stepId = stepId
        self.orderIndex = orderIndex
        self.instructionText = instructionText
        self.timerDurationSeconds = timerDurationSeconds
        self.waterAmountGrams = waterAmountGrams
        self.isCumulativeWaterTarget = isCumulativeWaterTarget
        self.recipe = recipe
    }
}
