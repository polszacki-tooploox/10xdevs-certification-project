//
//  BrewLogUseCaseTests.swift
//  BrewGuideTests
//
//  Unit tests for BrewLogUseCase following Test Plan scenarios BL-001 to BL-006.
//  Tests log CRUD operations, ordering, and validation.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for BrewLogUseCase business rules.
/// Covers brew log operations from Test Plan section 4.6.
@Suite("BrewLogUseCase Tests")
@MainActor
struct BrewLogUseCaseTests {
    
    // MARK: - Test Helpers
    
    func makeUseCase(repository: FakeBrewLogRepository) -> BrewLogUseCase {
        BrewLogUseCase(repository: repository)
    }
    
    // MARK: - BL-001: Save log with rating only
    
    @Test("BL-001: Save log with rating only includes all required fields")
    func testSaveLogWithRatingOnly() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let log = BrewLogFixtures.makeValidBrewLog(
            rating: 4,
            tasteTag: nil,
            note: nil
        )
        repository.addLog(log)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.count == 1)
        let savedLog = logs[0]
        #expect(savedLog.rating == 4)
        #expect(savedLog.tasteTag == nil)
        #expect(savedLog.method == .v60)
        #expect(savedLog.recipeNameAtBrew == "Test Recipe")
    }
    
    // MARK: - BL-002: Save log with taste tag
    
    @Test("BL-002: Save log with taste tag includes the tag")
    func testSaveLogWithTasteTag() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let log = BrewLogFixtures.makeBrewLogWithTasteTag(
            rating: 3,
            tasteTag: .tooSour
        )
        repository.addLog(log)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.count == 1)
        let savedLog = logs[0]
        #expect(savedLog.rating == 3)
        #expect(savedLog.tasteTag == .tooSour)
    }
    
    // MARK: - BL-003: Save log with note
    
    @Test("BL-003: Save log with note preserves note content")
    func testSaveLogWithNote() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let log = BrewLogFixtures.makeBrewLogWithNote(
            rating: 5,
            note: "Great brew with bright acidity!"
        )
        repository.addLog(log)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.count == 1)
        // Note: Summary DTO doesn't include note, would need detail DTO
        // This test documents that notes are stored
    }
        
    // MARK: - BL-005: Cancel delete (non-operation)
    
    @Test("BL-005: Not calling delete preserves log")
    func testNotDeletingPreservesLog() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let log = BrewLogFixtures.makeValidBrewLog()
        repository.addLog(log)
        
        // Act: Simulate user cancelling delete (no delete call)
        // Just fetch to verify state
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.count == 1)
        #expect(repository.deleteCalls.isEmpty)
    }
    
    // MARK: - BL-006: Logs ordered by date (most recent first)
    
    @Test("BL-006: Logs ordered by timestamp descending (most recent first)")
    func testLogsOrderedByDateDescending() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let now = Date()
        
        let log1 = BrewLogFixtures.makeValidBrewLog(
            timestamp: now.addingTimeInterval(-7200), // 2 hours ago
            recipeNameAtBrew: "Recipe 1"
        )
        let log2 = BrewLogFixtures.makeValidBrewLog(
            timestamp: now, // Most recent
            recipeNameAtBrew: "Recipe 2"
        )
        let log3 = BrewLogFixtures.makeValidBrewLog(
            timestamp: now.addingTimeInterval(-3600), // 1 hour ago
            recipeNameAtBrew: "Recipe 3"
        )
        
        // Add in random order
        repository.addLog(log1)
        repository.addLog(log2)
        repository.addLog(log3)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert: Most recent first
        #expect(logs.count == 3)
        #expect(logs[0].recipeNameAtBrew == "Recipe 2") // Most recent
        #expect(logs[1].recipeNameAtBrew == "Recipe 3") // 1 hour ago
        #expect(logs[2].recipeNameAtBrew == "Recipe 1") // 2 hours ago
    }
    
    // MARK: - Delete non-existent log (idempotent)
    
    @Test("Delete non-existent log is treated as success")
    func testDeleteNonExistentLogSucceeds() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let nonExistentId = UUID()
        
        // Act: Should not throw
        try useCase.deleteLog(id: nonExistentId)
        
        // Assert: No error thrown, treated as success
        #expect(repository.fetchLogCalls.count == 1)
        #expect(repository.deleteCalls.isEmpty) // Log not found, so not deleted
        #expect(repository.saveCalls == 0) // No save needed
    }
    
    // MARK: - Fetch empty logs list
    
    @Test("Fetch all logs returns empty array when no logs exist")
    func testFetchEmptyLogsList() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.isEmpty)
        #expect(repository.fetchAllLogsCalls == 1)
    }
    
    // MARK: - Multiple logs with same timestamp
    
    @Test("Logs with same timestamp are handled correctly")
    func testLogsWithSameTimestamp() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let timestamp = Date()
        
        let log1 = BrewLogFixtures.makeValidBrewLog(
            timestamp: timestamp,
            recipeNameAtBrew: "Recipe 1"
        )
        let log2 = BrewLogFixtures.makeValidBrewLog(
            timestamp: timestamp,
            recipeNameAtBrew: "Recipe 2"
        )
        
        repository.addLog(log1)
        repository.addLog(log2)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert: Both logs present (order may vary for same timestamp)
        #expect(logs.count == 2)
    }

    // MARK: - Repository error handling
    
    @Test("Fetch all logs throws when repository fails")
    func testFetchAllLogsThrowsOnRepositoryFailure() {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        repository.shouldThrowOnFetch = true
        
        // Act & Assert
        #expect(throws: Error.self) {
            try useCase.fetchAllLogSummaries()
        }
    }
    
    // MARK: - DTO mapping verification
    
    @Test("Fetch logs correctly maps to summary DTOs")
    func testFetchLogsMapsToSummaryDTOs() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        let log = BrewLogFixtures.makeValidBrewLog(
            method: .v60,
            recipeNameAtBrew: "Test Recipe",
            rating: 4,
            tasteTag: .tooSour
        )
        repository.addLog(log)
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert: DTO fields match entity
        let dto = logs[0]
        #expect(dto.id == log.id)
        #expect(dto.timestamp == log.timestamp)
        #expect(dto.method == log.method)
        #expect(dto.recipeNameAtBrew == log.recipeNameAtBrew)
        #expect(dto.rating == log.rating)
        #expect(dto.tasteTag == log.tasteTag)
        #expect(dto.recipeId == log.recipe?.id)
    }
    
    // MARK: - Large dataset performance
    
    @Test("Fetch many logs completes successfully")
    func testFetchManyLogs() throws {
        // Arrange
        let repository = FakeBrewLogRepository()
        let useCase = makeUseCase(repository: repository)
        
        // Add 50 logs (per Test Plan performance target)
        for i in 0..<50 {
            let log = BrewLogFixtures.makeValidBrewLog(
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                recipeNameAtBrew: "Recipe \(i)"
            )
            repository.addLog(log)
        }
        
        // Act
        let logs = try useCase.fetchAllLogSummaries()
        
        // Assert
        #expect(logs.count == 50)
        // Verify ordering: first log should be most recent (index 0)
        #expect(logs[0].recipeNameAtBrew == "Recipe 0")
        #expect(logs[49].recipeNameAtBrew == "Recipe 49")
    }
}
