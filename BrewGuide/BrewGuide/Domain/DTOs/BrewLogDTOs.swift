import Foundation

// MARK: - BrewLog DTOs

/// Summary representation of a brew log for list views.
/// Derived from `BrewLog` entity.
struct BrewLogSummaryDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let method: BrewMethod
    let recipeNameAtBrew: String
    let rating: Int
    let tasteTag: TasteTag?
    
    /// Optional reference to the recipe ID for navigation (may be nil if recipe was deleted)
    let recipeId: UUID?
}

/// Detailed representation of a brew log including all parameters.
/// Derived from `BrewLog` entity.
struct BrewLogDetailDTO: Codable, Identifiable, Hashable {
    let summary: BrewLogSummaryDTO
    
    // Snapshot of brew parameters
    let doseGrams: Double
    let targetYieldGrams: Double
    let waterTemperatureCelsius: Double
    let grindLabel: GrindLabel
    
    let note: String?
    
    var id: UUID { summary.id }
    
    /// Computed brew ratio (yield / dose)
    var ratio: Double {
        guard doseGrams > 0 else { return 0 }
        return targetYieldGrams / doseGrams
    }
}

// MARK: - BrewLog Command Models

/// Request payload for creating a new brew log entry.
struct CreateBrewLogRequest: Codable {
    let timestamp: Date
    let method: BrewMethod
    
    /// Optional reference to the recipe used (for navigation)
    let recipeId: UUID?
    
    /// Snapshot of recipe name at brew time
    let recipeNameAtBrew: String
    
    // Snapshot of brew parameters
    let doseGrams: Double
    let targetYieldGrams: Double
    let waterTemperatureCelsius: Double
    let grindLabel: GrindLabel
    
    let rating: Int
    let tasteTag: TasteTag?
    let note: String?
    
    /// Default initializer with timestamp defaulting to now
    init(
        timestamp: Date = Date(),
        method: BrewMethod,
        recipeId: UUID? = nil,
        recipeNameAtBrew: String,
        doseGrams: Double,
        targetYieldGrams: Double,
        waterTemperatureCelsius: Double,
        grindLabel: GrindLabel,
        rating: Int,
        tasteTag: TasteTag? = nil,
        note: String? = nil
    ) {
        self.timestamp = timestamp
        self.method = method
        self.recipeId = recipeId
        self.recipeNameAtBrew = recipeNameAtBrew
        self.doseGrams = doseGrams
        self.targetYieldGrams = targetYieldGrams
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.grindLabel = grindLabel
        self.rating = rating
        self.tasteTag = tasteTag
        self.note = note
    }
    
    /// Validate the request before persisting
    func validate() -> [BrewLogValidationError] {
        var errors: [BrewLogValidationError] = []
        
        if !(1...5).contains(rating) {
            errors.append(.invalidRating(rating))
        }
        
        if recipeNameAtBrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRecipeName)
        }
        
        if doseGrams <= 0 {
            errors.append(.invalidDose)
        }
        
        if targetYieldGrams <= 0 {
            errors.append(.invalidYield)
        }
        
        if let note = note, note.count > 280 {
            errors.append(.noteTooLong(count: note.count))
        }
        
        return errors
    }
}

// MARK: - BrewLog Validation Errors

/// Validation errors that block brew log save operations.
enum BrewLogValidationError: Error, Equatable {
    case invalidRating(Int)
    case emptyRecipeName
    case invalidDose
    case invalidYield
    case noteTooLong(count: Int)
    
    var localizedDescription: String {
        switch self {
        case .invalidRating(let value):
            return "Rating must be between 1 and 5 (got \(value))"
        case .emptyRecipeName:
            return "Recipe name cannot be empty"
        case .invalidDose:
            return "Dose must be greater than 0"
        case .invalidYield:
            return "Yield must be greater than 0"
        case .noteTooLong(let count):
            return "Note is too long (\(count) characters; max 280)"
        }
    }
}
