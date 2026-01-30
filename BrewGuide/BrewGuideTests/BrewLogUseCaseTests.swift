//
//  BrewLogUseCaseTests.swift
//  BrewGuideTests
//
//  Unit tests for BrewLogUseCase
//

import Foundation
import Testing
import SwiftData
@testable import BrewGuide

@MainActor
struct BrewLogUseCaseTests {
    
    // MARK: - Test Helpers
    
    /// Create an in-memory ModelContext for testing
    private func makeTestContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BrewLog.self, Recipe.self, RecipeStep.self,
            configurations: config
        )
        return ModelContext(container)
    }
    
    /// Create a test log in the context
    private func createTestLog(context: ModelContext, name: String = "Test Recipe") throws -> BrewLog {
        let log = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: name,
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 4,
            tasteTag: .tooSour,
            note: "Test note"
        )
        context.insert(log)
        try context.save()
        return log
    }
    
    // MARK: - Tests
    
    @Test("Delete log by ID removes it from database")
    func testDeleteLogSuccess() async throws {
        let context = try makeTestContext()
        let repository = BrewLogRepository(context: context)
        let useCase = BrewLogUseCase(repository: repository)
        
        let log = try createTestLog(context: context)
        let logId = log.id
        
        // Verify log exists
        let fetchedBefore = try repository.fetchLog(byId: logId)
        #expect(fetchedBefore != nil)
        
        // Delete via use case
        try useCase.deleteLog(id: logId)
        
        // Verify log is deleted
        let fetchedAfter = try repository.fetchLog(byId: logId)
        #expect(fetchedAfter == nil)
    }
    
    @Test("Delete non-existent log does not throw")
    func testDeleteNonExistentLog() async throws {
        let context = try makeTestContext()
        let repository = BrewLogRepository(context: context)
        let useCase = BrewLogUseCase(repository: repository)
        
        let nonExistentId = UUID()
        
        // Should not throw - treats as success
        try useCase.deleteLog(id: nonExistentId)
    }
    
    @Test("Fetch all log summaries returns DTOs")
    func testFetchAllLogSummaries() async throws {
        let context = try makeTestContext()
        let repository = BrewLogRepository(context: context)
        let useCase = BrewLogUseCase(repository: repository)
        
        // Create multiple logs
        _ = try createTestLog(context: context, name: "Recipe 1")
        _ = try createTestLog(context: context, name: "Recipe 2")
        _ = try createTestLog(context: context, name: "Recipe 3")
        
        let summaries = try useCase.fetchAllLogSummaries()
        
        #expect(summaries.count == 3)
        #expect(summaries.allSatisfy { $0.recipeNameAtBrew.starts(with: "Recipe") })
    }
    
    @Test("Fetch all log summaries returns empty array when no logs")
    func testFetchAllLogSummariesEmpty() async throws {
        let context = try makeTestContext()
        let repository = BrewLogRepository(context: context)
        let useCase = BrewLogUseCase(repository: repository)
        
        let summaries = try useCase.fetchAllLogSummaries()
        
        #expect(summaries.isEmpty)
    }
    
    @Test("Fetch all log summaries preserves order (most recent first)")
    func testFetchAllLogSummariesOrder() async throws {
        let context = try makeTestContext()
        let repository = BrewLogRepository(context: context)
        let useCase = BrewLogUseCase(repository: repository)
        
        // Create logs with different timestamps
        let log1 = BrewLog(
            timestamp: Date().addingTimeInterval(-172800), // 2 days ago
            method: .v60,
            recipeNameAtBrew: "Oldest",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 3
        )
        context.insert(log1)
        
        let log2 = BrewLog(
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            method: .v60,
            recipeNameAtBrew: "Middle",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 4
        )
        context.insert(log2)
        
        let log3 = BrewLog(
            timestamp: Date(), // Now
            method: .v60,
            recipeNameAtBrew: "Newest",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 5
        )
        context.insert(log3)
        
        try context.save()
        
        let summaries = try useCase.fetchAllLogSummaries()
        
        #expect(summaries.count == 3)
        #expect(summaries[0].recipeNameAtBrew == "Newest")
        #expect(summaries[1].recipeNameAtBrew == "Middle")
        #expect(summaries[2].recipeNameAtBrew == "Oldest")
    }
}
