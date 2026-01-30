//
//  LogsListViewModelTests.swift
//  BrewGuideTests
//
//  Unit tests for LogsListViewModel
//

import Foundation
import Testing
import SwiftData
@testable import BrewGuide

@MainActor
struct LogsListViewModelTests {
    
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
    
    /// Create a fake use case that returns predetermined logs
    private func makeFakeUseCase(
        logs: [BrewLogSummaryDTO] = [],
        shouldThrow: Bool = false
    ) -> @MainActor (ModelContext) -> BrewLogUseCase {
        return { _ in
            // Create a stub use case
            let context = try! makeTestContext()
            let repository = BrewLogRepository(context: context)
            return BrewLogUseCase(repository: repository)
        }
    }
    
    /// Seed test context with sample logs
    private func seedTestLogs(context: ModelContext, count: Int = 3) throws {
        for i in 0..<count {
            let log = BrewLog(
                timestamp: Date().addingTimeInterval(Double(-i * 86400)),
                method: .v60,
                recipeNameAtBrew: "Test Recipe \(i + 1)",
                doseGrams: 15.0,
                targetYieldGrams: 250.0,
                waterTemperatureCelsius: 94.0,
                grindLabel: .medium,
                rating: i % 5 + 1,
                tasteTag: i % 2 == 0 ? .tooSour : nil,
                note: "Test note \(i + 1)"
            )
            context.insert(log)
        }
        try context.save()
    }
    
    // MARK: - Tests
    
    @Test("Initial state is empty and not loading")
    func testInitialState() async throws {
        let viewModel = LogsListViewModel()
        
        #expect(viewModel.logs.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.pendingDelete == nil)
        #expect(viewModel.isDeleting == false)
    }
    
    @Test("Load fetches logs successfully")
    func testLoadSuccess() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 3)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        #expect(viewModel.logs.count == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        
        // Verify order (most recent first)
        #expect(viewModel.logs[0].recipeNameAtBrew == "Test Recipe 1")
        #expect(viewModel.logs[1].recipeNameAtBrew == "Test Recipe 2")
        #expect(viewModel.logs[2].recipeNameAtBrew == "Test Recipe 3")
    }
    
    @Test("Load with empty database shows empty list")
    func testLoadEmpty() async throws {
        let context = try makeTestContext()
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        #expect(viewModel.logs.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("Request delete sets pending delete")
    func testRequestDelete() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 3)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        let logToDelete = viewModel.logs[1]
        viewModel.requestDelete(id: logToDelete.id)
        
        #expect(viewModel.pendingDelete != nil)
        #expect(viewModel.pendingDelete?.id == logToDelete.id)
    }
    
    @Test("Cancel delete clears pending delete")
    func testCancelDelete() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 3)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        let logToDelete = viewModel.logs[0]
        viewModel.requestDelete(id: logToDelete.id)
        #expect(viewModel.pendingDelete != nil)
        
        viewModel.cancelDelete()
        #expect(viewModel.pendingDelete == nil)
    }
    
    @Test("Confirm delete removes log from list")
    func testConfirmDelete() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 3)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        let initialCount = viewModel.logs.count
        let logToDelete = viewModel.logs[1]
        
        viewModel.requestDelete(id: logToDelete.id)
        await viewModel.confirmDelete(context: context)
        
        #expect(viewModel.logs.count == initialCount - 1)
        #expect(viewModel.pendingDelete == nil)
        #expect(viewModel.isDeleting == false)
        #expect(viewModel.logs.allSatisfy { $0.id != logToDelete.id })
    }
    
    @Test("Request delete with invalid ID is ignored")
    func testRequestDeleteInvalidId() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 3)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        let invalidId = UUID()
        viewModel.requestDelete(id: invalidId)
        
        #expect(viewModel.pendingDelete == nil)
    }
    
    @Test("Reload re-fetches logs")
    func testReload() async throws {
        let context = try makeTestContext()
        try seedTestLogs(context: context, count: 2)
        
        let viewModel = LogsListViewModel()
        await viewModel.load(context: context)
        
        #expect(viewModel.logs.count == 2)
        
        // Add another log
        let newLog = BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "New Recipe",
            doseGrams: 18.0,
            targetYieldGrams: 300.0,
            waterTemperatureCelsius: 92.0,
            grindLabel: .fine,
            rating: 5
        )
        context.insert(newLog)
        try context.save()
        
        await viewModel.reload(context: context)
        
        #expect(viewModel.logs.count == 3)
    }
}
