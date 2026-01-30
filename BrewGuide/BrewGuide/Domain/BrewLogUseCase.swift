//
//  BrewLogUseCase.swift
//  BrewGuide
//
//  Use case for brew log operations (delete, validation).
//  Encapsulates business logic and coordinates with repositories.
//

import Foundation
import SwiftData

// Note: This file depends on:
// - BrewLogRepository (Persistence/Repositories/BrewLogRepository.swift)
// - BrewLogSummaryDTO (Domain/DTOs/BrewLogDTOs.swift)
// - BrewLog.toSummaryDTO() (Domain/DTOs/MappingExtensions.swift)

/// Use case for brew log operations.
/// Encapsulates log deletion and other mutations so the UI doesn't manipulate ModelContext directly.
@MainActor
final class BrewLogUseCase {
    private let repository: BrewLogRepository
    
    /// Initialize with a brew log repository
    init(repository: BrewLogRepository) {
        self.repository = repository
    }
    
    /// Delete a brew log by ID.
    /// Treats "log not found" as a non-fatal success (may have been deleted by sync/other device).
    /// - Parameter id: The UUID of the log to delete
    /// - Throws: Repository or save errors (not "not found")
    func deleteLog(id: UUID) throws {
        guard let log = try repository.fetchLog(byId: id) else {
            // Log not found - treat as success (may have been deleted elsewhere)
            return
        }
        
        repository.delete(log)
        try repository.save()
    }
    
    /// Fetch all logs as summary DTOs in chronological order (most recent first)
    /// - Returns: Array of brew log summary DTOs
    func fetchAllLogSummaries() throws -> [BrewLogSummaryDTO] {
        let logs = try repository.fetchAllLogs()
        return logs.map { $0.toSummaryDTO() }
    }
}
