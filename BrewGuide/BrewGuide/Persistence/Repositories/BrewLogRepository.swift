import Foundation
import SwiftData

/// Protocol for brew log repository operations
@MainActor
protocol BrewLogRepositoryProtocol {
    func fetchAllLogs() throws -> [BrewLog]
    func fetchLog(byId id: UUID) throws -> BrewLog?
    func fetchLogs(for method: BrewMethod) throws -> [BrewLog]
    func fetchLogs(forRecipeId recipeId: UUID) throws -> [BrewLog]
    func insert(_ log: BrewLog)
    func delete(_ log: BrewLog)
    func save() throws
}

/// Repository for BrewLog persistence operations.
@MainActor
final class BrewLogRepository: BaseRepository<BrewLog>, BrewLogRepositoryProtocol {
    
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
}
