//
//  FakeBrewLogRepository.swift
//  BrewGuideTests
//
//  Fake implementation of BrewLogRepository for unit testing.
//  Provides in-memory storage and call tracking without SwiftData dependencies.
//

import Foundation
import SwiftData
@testable import BrewGuide

struct FakeError: Error {

}

/// Fake brew log repository for testing.
/// Provides deterministic in-memory storage and tracks all interactions.
@MainActor
final class FakeBrewLogRepository: BrewLogRepositoryProtocol {
    // In-memory storage
    private var logs: [UUID: BrewLog] = [:]
    
    // Call tracking
    private(set) var fetchLogCalls: [UUID] = []
    private(set) var fetchAllLogsCalls: Int = 0
    private(set) var deleteCalls: [BrewLog] = []
    private(set) var saveCalls: Int = 0
    
    // Error injection
    var shouldThrowOnFetch: Bool = false
    var shouldThrowOnSave: Bool = false
    var fetchError = FakeError()
    var saveError = FakeError()

    init() {
    }
    
    // MARK: - BrewLogRepositoryProtocol
    
    func fetchLog(byId id: UUID) throws -> BrewLog? {
        fetchLogCalls.append(id)
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return logs[id]
    }
    
    func fetchAllLogs() throws -> [BrewLog] {
        fetchAllLogsCalls += 1
        
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        // Return sorted by timestamp descending (most recent first)
        return logs.values.sorted { $0.timestamp > $1.timestamp }
    }
    
    func fetchLogs(for method: BrewMethod) throws -> [BrewLog] {
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return logs.values
            .filter { $0.method == method }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    func fetchLogs(forRecipeId recipeId: UUID) throws -> [BrewLog] {
        if shouldThrowOnFetch {
            throw fetchError
        }
        
        return logs.values
            .filter { $0.id == recipeId }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    func insert(_ log: BrewLog) {
        logs[log.id] = log
    }
    
    func delete(_ log: BrewLog) {
        deleteCalls.append(log)
        logs.removeValue(forKey: log.id)
    }
    
    func save() throws {
        saveCalls += 1
        
        if shouldThrowOnSave {
            throw saveError
        }
    }
    
    // MARK: - Test Helpers
    
    /// Add a log to the in-memory store
    func addLog(_ log: BrewLog) {
        logs[log.id] = log
    }
    
    /// Get a log directly (bypasses call tracking)
    func getLog(byId id: UUID) -> BrewLog? {
        logs[id]
    }
    
    /// Clear all stored logs
    func clearLogs() {
        logs.removeAll()
    }
    
    /// Reset all call tracking
    func resetCallTracking() {
        fetchLogCalls.removeAll()
        fetchAllLogsCalls = 0
        deleteCalls.removeAll()
        saveCalls = 0
    }
}
