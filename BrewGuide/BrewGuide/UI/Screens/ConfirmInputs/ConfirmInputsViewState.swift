//
//  ConfirmInputsViewState.swift
//  BrewGuide
//
//  View state types for ConfirmInputsView.
//

import Foundation

// MARK: - View State

/// UI-facing snapshot that drives ConfirmInputsScreen rendering.
struct ConfirmInputsViewState {
    let isLoading: Bool
    let recipeName: String
    let method: BrewMethod
    let isRecipeBrewable: Bool
    let brewabilityMessage: String?
    
    // Editable inputs
    let doseGrams: Double
    let targetYieldGrams: Double
    let waterTemperatureCelsius: Double
    let grindLabel: GrindLabel
    let grindTactileDescriptor: String?
    
    // Computed/derived
    let ratio: Double
    let warnings: [InputWarning]
    
    // UI states
    let isStartingBrew: Bool
    let canStartBrew: Bool
    let canEdit: Bool
}

// MARK: - Recipe Snapshot

/// Immutable recipe defaults relevant to the confirm inputs screen.
struct ConfirmInputsRecipeSnapshot {
    let recipeId: UUID
    let recipeName: String
    let method: BrewMethod
    let defaultDose: Double
    let defaultTargetYield: Double
    let defaultWaterTemperature: Double
    let defaultGrindLabel: GrindLabel
    let grindTactileDescriptor: String?
    let validationErrors: [RecipeValidationError]
    
    /// Whether this recipe can be used for brewing
    var isBrewable: Bool {
        validationErrors.isEmpty
    }
    
    /// Brewability message for UI display
    var brewabilityMessage: String? {
        guard !isBrewable else { return nil }
        
        let errorList = validationErrors
            .map { $0.localizedDescription }
            .joined(separator: "\n")
        return "Cannot start brewing:\n\(errorList)"
    }
}

// MARK: - Scaling State

/// Stores scaling output for reuse in plan creation.
struct ConfirmInputsScalingState {
    let scaledDose: Double
    let scaledTargetYield: Double
    let derivedRatio: Double
    let warnings: [InputWarning]
    let scaledWaterTargets: [Double]
}

// MARK: - UI State

/// Tracks cross-cutting UI concerns.
@Observable
final class ConfirmInputsUIState {
    var errorMessage: String?
    var isStartingBrew: Bool = false
    
    var showsError: Bool {
        errorMessage != nil
    }
    
    init(errorMessage: String? = nil, isStartingBrew: Bool = false) {
        self.errorMessage = errorMessage
        self.isStartingBrew = isStartingBrew
    }
}

// MARK: - Event

/// Event enum for user interactions.
enum ConfirmInputsEvent {
    case changeRecipeTapped
    case doseChanged(Double)
    case yieldChanged(Double)
    case temperatureChanged(Double)
    case grindChanged(GrindLabel)
    case resetTapped
    case startBrewTapped
}
