//
//  LogsListViewModel.swift
//  BrewGuide
//
//  View model for LogsListView.
//  Owns loading, error state, and delete confirmation flow using use cases.
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "LogsListViewModel")

/// View model for the logs list screen.
/// Manages loading, error state, and delete confirmation flow.
@MainActor
@Observable
final class LogsListViewModel {
    // MARK: - State
    
    var logs: [BrewLogSummaryDTO] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var pendingDelete: BrewLogSummaryDTO? = nil
    var isDeleting: Bool = false
    
    // MARK: - Dependencies
    
    private let makeUseCase: @MainActor (ModelContext) -> BrewLogUseCase
    
    // MARK: - Initialization
    
    /// Initialize with dependency factories for testability
    /// - Parameter makeUseCase: Factory for creating BrewLogUseCase with a ModelContext
    init(
        makeUseCase: @escaping @MainActor (ModelContext) -> BrewLogUseCase = { context in
            let repository = BrewLogRepository(context: context)
            return BrewLogUseCase(repository: repository)
        }
    ) {
        self.makeUseCase = makeUseCase
    }
    
    // MARK: - Public Methods
    
    /// Load all brew logs from the repository
    /// - Parameter context: The ModelContext to use for persistence operations
    func load(context: ModelContext) async {
        guard !isLoading else {
            logger.debug("Load already in progress, ignoring duplicate call")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let useCase = makeUseCase(context)
            logs = try useCase.fetchAllLogSummaries()
            logger.info("Loaded \(self.logs.count) brew logs")
        } catch {
            errorMessage = "Failed to load brew logs. Please try again."
            logger.error("Failed to load logs: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Reload logs (alias for load, useful for pull-to-refresh)
    /// - Parameter context: The ModelContext to use for persistence operations
    func reload(context: ModelContext) async {
        await load(context: context)
    }
    
    /// Request deletion of a log (sets pending delete state, doesn't delete immediately)
    /// - Parameter id: The UUID of the log to delete
    func requestDelete(id: UUID) {
        guard let log = logs.first(where: { $0.id == id }) else {
            logger.warning("Attempted to delete log that doesn't exist in current list: \(id)")
            return
        }
        
        guard !isDeleting else {
            logger.debug("Delete already in progress, ignoring duplicate request")
            return
        }
        
        pendingDelete = log
        logger.debug("Delete requested for log: \(log.recipeNameAtBrew)")
    }
    
    /// Cancel the pending delete operation
    func cancelDelete() {
        pendingDelete = nil
        logger.debug("Delete cancelled")
    }
    
    /// Confirm and execute the pending delete operation
    /// - Parameter context: The ModelContext to use for persistence operations
    func confirmDelete(context: ModelContext) async {
        guard let logToDelete = pendingDelete else {
            logger.warning("confirmDelete called with no pending delete")
            return
        }
        
        guard !isDeleting else {
            logger.debug("Delete already in progress, ignoring duplicate confirm")
            return
        }
        
        isDeleting = true
        errorMessage = nil
        
        do {
            let useCase = makeUseCase(context)
            try useCase.deleteLog(id: logToDelete.id)
            
            // Remove from local list optimistically
            logs.removeAll { $0.id == logToDelete.id }
            
            logger.info("Successfully deleted log: \(logToDelete.recipeNameAtBrew)")
            
            // Clear pending delete state
            pendingDelete = nil
        } catch {
            errorMessage = "Couldn't delete log. Please try again."
            logger.error("Failed to delete log: \(error.localizedDescription)")
            
            // Keep pending delete state so user can retry
        }
        
        isDeleting = false
    }
}
