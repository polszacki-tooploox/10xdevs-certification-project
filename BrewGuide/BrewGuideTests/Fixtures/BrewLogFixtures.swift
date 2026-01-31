//
//  BrewLogFixtures.swift
//  BrewGuideTests
//
//  Fixture builders for BrewLog entities for testing.
//

import Foundation
@testable import BrewGuide

/// Fixture factory for creating test brew logs with sensible defaults.
struct BrewLogFixtures {
    
    // MARK: - Valid Brew Logs
    
    /// Creates a valid brew log with default parameters
    static func makeValidBrewLog(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: BrewMethod = .v60,
        recipeNameAtBrew: String = "Test Recipe",
        doseGrams: Double = 15.0,
        targetYieldGrams: Double = 250.0,
        waterTemperatureCelsius: Double = 94.0,
        grindLabel: GrindLabel = .medium,
        rating: Int = 4,
        tasteTag: TasteTag? = nil,
        note: String? = nil,
        recipe: Recipe? = nil
    ) -> BrewLog {
        BrewLog(
            id: id,
            timestamp: timestamp,
            method: method,
            recipeNameAtBrew: recipeNameAtBrew,
            doseGrams: doseGrams,
            targetYieldGrams: targetYieldGrams,
            waterTemperatureCelsius: waterTemperatureCelsius,
            grindLabel: grindLabel,
            rating: rating,
            tasteTag: tasteTag,
            note: note,
            recipe: recipe
        )
    }
    
    /// Creates a brew log with a taste tag
    static func makeBrewLogWithTasteTag(
        id: UUID = UUID(),
        rating: Int = 3,
        tasteTag: TasteTag = .tooSour
    ) -> BrewLog {
        makeValidBrewLog(id: id, rating: rating, tasteTag: tasteTag)
    }
    
    /// Creates a brew log with a note
    static func makeBrewLogWithNote(
        id: UUID = UUID(),
        rating: Int = 5,
        note: String = "Great brew!"
    ) -> BrewLog {
        makeValidBrewLog(id: id, rating: rating, note: note)
    }
    
    /// Creates multiple brew logs with different timestamps for ordering tests
    static func makeBrewLogsWithTimestamps(count: Int = 3) -> [BrewLog] {
        let now = Date()
        return (0..<count).map { index in
            makeValidBrewLog(
                id: UUID(),
                timestamp: now.addingTimeInterval(TimeInterval(-index * 3600)), // 1 hour apart
                recipeNameAtBrew: "Recipe \(index + 1)"
            )
        }
    }
}
