import Foundation

/// Pure validation logic for brew logs - no dependencies on persistence.
/// Extracted from BrewLogRepository to follow clean architecture principles.
struct BrewLogValidator {
    
    /// Validate a brew log entity against business rules.
    /// - Parameter log: The brew log to validate
    /// - Returns: Array of validation errors (empty if valid)
    static func validate(_ log: BrewLog) -> [BrewLogValidationError] {
        var errors: [BrewLogValidationError] = []
        
        // Rating must be 1-5
        if log.rating < 1 || log.rating > 5 {
            errors.append(.invalidRating(log.rating))
        }
        
        // Recipe name cannot be empty
        if log.recipeNameAtBrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRecipeName)
        }
        
        // Dose and yield must be positive
        if log.doseGrams <= 0 {
            errors.append(.invalidDose)
        }
        if log.targetYieldGrams <= 0 {
            errors.append(.invalidYield)
        }
        
        // Note length limit
        if let note = log.note, note.count > 280 {
            errors.append(.noteTooLong(count: note.count))
        }
        
        return errors
    }
    
    /// Validate a create request DTO.
    /// - Parameter request: The create request to validate
    /// - Returns: Array of validation errors (empty if valid)
    static func validate(_ request: CreateBrewLogRequest) -> [BrewLogValidationError] {
        var errors: [BrewLogValidationError] = []
        
        // Rating must be 1-5
        if !(1...5).contains(request.rating) {
            errors.append(.invalidRating(request.rating))
        }
        
        // Recipe name cannot be empty
        if request.recipeNameAtBrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRecipeName)
        }
        
        // Dose and yield must be positive
        if request.doseGrams <= 0 {
            errors.append(.invalidDose)
        }
        if request.targetYieldGrams <= 0 {
            errors.append(.invalidYield)
        }
        
        // Note length limit
        if let note = request.note, note.count > 280 {
            errors.append(.noteTooLong(count: note.count))
        }
        
        return errors
    }
}
