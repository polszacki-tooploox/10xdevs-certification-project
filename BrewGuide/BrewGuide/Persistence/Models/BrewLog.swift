import Foundation
import SwiftData

/// A lightweight log entry capturing the outcome of a completed brew.
/// Uses snapshot strategy: stores brew-time parameters for historical accuracy.
/// CloudKit-compatible: all properties have default values or are optional.
@Model
final class BrewLog {
    /// Stable identifier
    var id: UUID
    
    /// Timestamp when brew was completed
    var timestamp: Date
    
    /// Brew method used
    var method: BrewMethod
    
    /// Name of the recipe at brew time (snapshot)
    var recipeNameAtBrew: String
    
    /// Coffee dose in grams (snapshot)
    var doseGrams: Double
    
    /// Target yield in grams (snapshot)
    var targetYieldGrams: Double
    
    /// Water temperature in Celsius (snapshot)
    var waterTemperatureCelsius: Double
    
    /// Grind label used (snapshot)
    var grindLabel: GrindLabel
    
    /// User rating (1-5, required)
    var rating: Int
    
    /// Optional quick taste feedback tag
    var tasteTag: TasteTag?
    
    /// Optional free-text note
    var note: String?
    
    /// Optional reference to the recipe used (for navigation; may be nil if recipe was deleted)
    /// CloudKit-compatible: relationship is optional
    var recipe: Recipe?
    
    /// Initializer for creating new brew logs
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: BrewMethod = .v60,
        recipeNameAtBrew: String = "",
        doseGrams: Double = 0.0,
        targetYieldGrams: Double = 0.0,
        waterTemperatureCelsius: Double = 0.0,
        grindLabel: GrindLabel = .medium,
        rating: Int = 3,
        tasteTag: TasteTag? = nil,
        note: String? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.recipeNameAtBrew = recipeNameAtBrew
        self.doseGrams = doseGrams
        self.targetYieldGrams = targetYieldGrams
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.grindLabel = grindLabel
        self.rating = rating
        self.tasteTag = tasteTag
        self.note = note
        self.recipe = recipe
    }
    
    /// Computed property for brew ratio (yield / dose)
    var ratio: Double {
        guard doseGrams > 0 else { return 0 }
        return targetYieldGrams / doseGrams
    }
}
