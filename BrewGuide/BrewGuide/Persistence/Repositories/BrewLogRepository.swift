import Foundation
import SwiftData

/// Repository for BrewLog persistence operations.
@MainActor
final class BrewLogRepository: BaseRepository<BrewLog> {
    
    /// Fetch all brew logs in chronological order (most recent first)
    func fetchAllLogs() throws -> [BrewLog] {
        let descriptor = FetchDescriptor<BrewLog>(
            sortBy: [SortDescriptor(\BrewLog.timestamp, order: .reverse)]
        )
        return try fetch(descriptor: descriptor)
    }
    
    /// Fetch brew logs for a specific method
    func fetchLogs(for method: BrewMethod) throws -> [BrewLog] {
        // Fetch all logs and filter in memory
        // SwiftData predicates don't support captured enum values
        let descriptor = FetchDescriptor<BrewLog>(
            sortBy: [SortDescriptor(\BrewLog.timestamp, order: .reverse)]
        )
        let allLogs = try fetch(descriptor: descriptor)
        return allLogs.filter { $0.method == method }
    }
    
    /// Fetch a brew log by its ID
    func fetchLog(byId id: UUID) throws -> BrewLog? {
        let descriptor = FetchDescriptor<BrewLog>(
            predicate: #Predicate { $0.id == id }
        )
        return try fetch(descriptor: descriptor).first
    }
    
    /// Fetch recent logs (limit to N most recent)
    func fetchRecentLogs(limit: Int = 10) throws -> [BrewLog] {
        var descriptor = FetchDescriptor<BrewLog>(
            sortBy: [SortDescriptor(\BrewLog.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try fetch(descriptor: descriptor)
    }
    
    /// Fetch logs for a specific recipe
    func fetchLogs(forRecipeId recipeId: UUID) throws -> [BrewLog] {
        let descriptor = FetchDescriptor<BrewLog>(
            predicate: #Predicate { log in
                log.recipe?.id == recipeId
            },
            sortBy: [SortDescriptor(\BrewLog.timestamp, order: .reverse)]
        )
        return try fetch(descriptor: descriptor)
    }
    
    /// Calculate average rating for all logs
    func calculateAverageRating() throws -> Double {
        let logs = try fetchAllLogs()
        guard !logs.isEmpty else { return 0 }
        let sum = logs.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(logs.count)
    }
    
    /// Validate a brew log before saving
    /// - Parameter log: The brew log to validate
    /// - Returns: Array of validation errors (empty if valid)
    func validate(_ log: BrewLog) -> [BrewLogValidationError] {
        var errors: [BrewLogValidationError] = []
        
        // Rating must be 1-5
        if log.rating < 1 || log.rating > 5 {
            errors.append(.invalidRating(log.rating))
        }
        
        // Recipe name snapshot cannot be empty
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
        
        // Note length limit (280 characters per PRD suggestion)
        if let note = log.note, note.count > 280 {
            errors.append(.noteTooLong(count: note.count))
        }
        
        return errors
    }
}
