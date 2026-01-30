//
//  RecipeEditViewState.swift
//  BrewGuide
//
//  UI state and draft types for RecipeEditView.
//

import Foundation

struct RecipeEditViewState: Equatable, Sendable {
    var isLoading: Bool = true
    var draft: RecipeEditDraft?
    var validation: RecipeEditValidationState = .init()
    var isSaving: Bool = false
    
    var loadErrorMessage: String?
    var saveErrorMessage: String?
    
    var isDirty: Bool = false
}

struct RecipeEditDraft: Equatable, Sendable {
    let recipeId: UUID
    var name: String
    var defaultDose: Double?
    var defaultTargetYield: Double?
    var defaultWaterTemperature: Double?
    var defaultGrindLabel: GrindLabel
    var grindTactileDescriptor: String
    var steps: [RecipeStepDraft]
}

struct RecipeStepDraft: Equatable, Identifiable, Sendable {
    let id: UUID
    var orderIndex: Int
    var instructionText: String
    var timerDurationSeconds: Double?
    var waterAmountGrams: Double?
    var isCumulativeWaterTarget: Bool
}

struct RecipeEditFieldErrors: Equatable, Sendable {
    var name: String?
    var dose: String?
    var yield: String?
    var temperature: String?
    var steps: String?
}

struct RecipeEditWaterMismatchState: Equatable, Sendable {
    let expectedYield: Double
    let actualWaterTotal: Double
    let offendingStepIds: Set<UUID>
}

struct RecipeEditValidationState: Equatable, Sendable {
    var errors: [RecipeValidationError] = []
    
    var issueCount: Int = 0
    var firstAnchor: ValidationAnchor?
    
    var fieldErrors: RecipeEditFieldErrors = .init()
    var stepErrorMap: [UUID: [RecipeValidationError]] = [:]
    var stepInlineErrorMap: [UUID: [RecipeEditInlineError]] = [:]
    
    var waterMismatch: RecipeEditWaterMismatchState?
    var isValid: Bool = false
}

enum ValidationAnchor: Hashable, Sendable {
    case name
    case dose
    case yield
    case temperature
    case grind
    case tactileDescriptor
    case steps
    case step(id: UUID)
}

enum RecipeEditEvent: Sendable {
    case nameChanged(String)
    case doseChanged(Double?)
    case yieldChanged(Double?)
    case temperatureChanged(Double?)
    case grindLabelChanged(GrindLabel)
    case tactileDescriptorChanged(String)
    
    case addStepTapped
    case moveSteps(from: IndexSet, to: Int)
    case deleteStep(UUID)
    
    case stepInstructionChanged(stepId: UUID, text: String)
    case stepTimerEnabledChanged(stepId: UUID, isEnabled: Bool)
    case stepTimerChanged(stepId: UUID, seconds: Double?)
    case stepWaterEnabledChanged(stepId: UUID, isEnabled: Bool)
    case stepWaterChanged(stepId: UUID, grams: Double?)
    case stepCumulativeChanged(stepId: UUID, isCumulative: Bool)
    
    case cancelTapped
    case saveTapped
    case jumpToFirstIssueTapped
    case retryTapped
}

enum RecipeEditInlineErrorField: Sendable {
    case name
    case dose
    case yield
    case temperature
    case instruction
    case timer
    case water
    case steps
}

struct RecipeEditInlineError: Identifiable, Equatable, Sendable {
    let id: UUID
    let field: RecipeEditInlineErrorField
    let message: String
    
    init(field: RecipeEditInlineErrorField, message: String) {
        self.id = UUID()
        self.field = field
        self.message = message
    }
}

