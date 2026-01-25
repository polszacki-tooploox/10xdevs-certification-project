import Foundation
import SwiftData

/// A structured brew recipe with method-specific defaults and step-by-step instructions.
/// CloudKit-compatible: all properties have default values or are optional.
@Model
final class Recipe {
    /// Stable identifier
    var id: UUID
    
    /// Whether this is a built-in starter recipe
    var isStarter: Bool
    
    /// Origin/type of recipe
    var origin: RecipeOrigin
    
    /// Brew method (V60 only in MVP)
    var method: BrewMethod
    
    /// Recipe name
    var name: String
    
    /// Default coffee dose in grams
    var defaultDose: Double
    
    /// Default target yield in grams
    var defaultTargetYield: Double
    
    /// Default water temperature in Celsius
    var defaultWaterTemperature: Double
    
    /// Default grind size label
    var defaultGrindLabel: GrindLabel
    
    /// Tactile grind descriptor (e.g., "sand; slightly finer than sea salt")
    var grindTactileDescriptor: String?
    
    /// Ordered sequence of recipe steps
    /// CloudKit-compatible: relationship is optional
    @Relationship(deleteRule: .cascade, inverse: \RecipeStep.recipe)
    var steps: [RecipeStep]?
    
    /// Timestamp when recipe was created
    var createdAt: Date
    
    /// Timestamp when recipe was last modified
    var modifiedAt: Date
    
    /// Initializer for creating new recipes
    init(
        id: UUID = UUID(),
        isStarter: Bool = false,
        origin: RecipeOrigin = .custom,
        method: BrewMethod = .v60,
        name: String = "",
        defaultDose: Double = 15.0,
        defaultTargetYield: Double = 250.0,
        defaultWaterTemperature: Double = 94.0,
        defaultGrindLabel: GrindLabel = .medium,
        grindTactileDescriptor: String? = nil,
        steps: [RecipeStep]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.isStarter = isStarter
        self.origin = origin
        self.method = method
        self.name = name
        self.defaultDose = defaultDose
        self.defaultTargetYield = defaultTargetYield
        self.defaultWaterTemperature = defaultWaterTemperature
        self.defaultGrindLabel = defaultGrindLabel
        self.grindTactileDescriptor = grindTactileDescriptor
        self.steps = steps
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    /// Computed property for default ratio (yield / dose)
    var defaultRatio: Double {
        guard defaultDose > 0 else { return 0 }
        return defaultTargetYield / defaultDose
    }
}
