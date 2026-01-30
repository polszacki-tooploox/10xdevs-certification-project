//
//  RecipeEditViewModel.swift
//  BrewGuide
//
//  View model for editing a custom recipe with guardrail-first validation.
//

import Foundation
import Observation

@MainActor
@Observable
final class RecipeEditViewModel {
    private let recipeId: UUID
    private let useCase: RecipeUseCaseProtocol
    
    private var baselineDraft: RecipeEditDraft?
    private var saveAttemptErrors: [RecipeValidationError] = []
    
    var state: RecipeEditViewState = .init()
    var didSaveSuccessfully: Bool = false
    
    init(recipeId: UUID, useCase: RecipeUseCaseProtocol) {
        self.recipeId = recipeId
        self.useCase = useCase
    }
    
    var canSave: Bool {
        state.validation.isValid && state.isDirty && !state.isSaving
    }
    
    func load() async {
        state.isLoading = true
        state.loadErrorMessage = nil
        state.saveErrorMessage = nil
        didSaveSuccessfully = false
        saveAttemptErrors = []
        
        do {
            let detail = try useCase.fetchRecipeDetail(id: recipeId)
            
            guard detail.recipe.isStarter == false else {
                state.isLoading = false
                state.loadErrorMessage = "Starter recipes can’t be edited. Duplicate it first."
                state.draft = nil
                state.validation = .init()
                return
            }
            
            let draft = RecipeEditDraft(
                recipeId: detail.recipe.id,
                name: detail.recipe.name,
                defaultDose: detail.recipe.defaultDose,
                defaultTargetYield: detail.recipe.defaultTargetYield,
                defaultWaterTemperature: detail.recipe.defaultWaterTemperature,
                defaultGrindLabel: detail.recipe.defaultGrindLabel,
                grindTactileDescriptor: detail.grindTactileDescriptor ?? "",
                steps: detail.steps
                    .sorted(by: { $0.orderIndex < $1.orderIndex })
                    .enumerated()
                    .map { index, step in
                        RecipeStepDraft(
                            id: step.stepId,
                            orderIndex: index,
                            instructionText: step.instructionText,
                            timerDurationSeconds: step.timerDurationSeconds,
                            waterAmountGrams: step.waterAmountGrams,
                            isCumulativeWaterTarget: step.isCumulativeWaterTarget
                        )
                    }
            )
            
            baselineDraft = draft
            state.draft = draft
            state.isDirty = false
            
            recomputeValidation()
            state.isLoading = false
        } catch let error as RecipeUseCaseError {
            state.isLoading = false
            state.draft = nil
            state.validation = .init()
            state.loadErrorMessage = error.errorDescription
        } catch {
            state.isLoading = false
            state.draft = nil
            state.validation = .init()
            state.loadErrorMessage = "Couldn’t load this recipe. Please try again."
        }
    }
    
    func handle(_ event: RecipeEditEvent) {
        switch event {
        case .retryTapped:
            Task { await load() }
            
        case .nameChanged(let name):
            mutateDraft { $0.name = name }
            
        case .doseChanged(let dose):
            mutateDraft { $0.defaultDose = dose }
            
        case .yieldChanged(let yield):
            mutateDraft { $0.defaultTargetYield = yield }
            
        case .temperatureChanged(let temp):
            mutateDraft { $0.defaultWaterTemperature = temp }
            
        case .grindLabelChanged(let label):
            mutateDraft { $0.defaultGrindLabel = label }
            
        case .tactileDescriptorChanged(let descriptor):
            mutateDraft { $0.grindTactileDescriptor = descriptor }
            
        case .addStepTapped:
            mutateDraft { draft in
                let newStep = RecipeStepDraft(
                    id: UUID(),
                    orderIndex: draft.steps.count,
                    instructionText: "",
                    timerDurationSeconds: nil,
                    waterAmountGrams: nil,
                    isCumulativeWaterTarget: true
                )
                draft.steps.append(newStep)
                normalizeOrderIndexes(&draft.steps)
            }
            
        case .moveSteps(let from, let to):
            mutateDraft { draft in
                move(&draft.steps, fromOffsets: from, toOffset: to)
                normalizeOrderIndexes(&draft.steps)
            }
            
        case .deleteStep(let stepId):
            mutateDraft { draft in
                draft.steps.removeAll(where: { $0.id == stepId })
                normalizeOrderIndexes(&draft.steps)
            }
            
        case .stepInstructionChanged(let stepId, let text):
            mutateStep(stepId: stepId) { $0.instructionText = text }
            
        case .stepTimerEnabledChanged(let stepId, let isEnabled):
            mutateStep(stepId: stepId) { step in
                if isEnabled {
                    if step.timerDurationSeconds == nil {
                        step.timerDurationSeconds = 0
                    }
                } else {
                    step.timerDurationSeconds = nil
                }
            }
            
        case .stepTimerChanged(let stepId, let seconds):
            mutateStep(stepId: stepId) { $0.timerDurationSeconds = seconds }
            
        case .stepWaterEnabledChanged(let stepId, let isEnabled):
            mutateStep(stepId: stepId) { step in
                if isEnabled {
                    if step.waterAmountGrams == nil {
                        step.waterAmountGrams = 0
                    }
                } else {
                    step.waterAmountGrams = nil
                }
            }
            
        case .stepWaterChanged(let stepId, let grams):
            mutateStep(stepId: stepId) { $0.waterAmountGrams = grams }
            
        case .stepCumulativeChanged(let stepId, let isCumulative):
            mutateStep(stepId: stepId) { $0.isCumulativeWaterTarget = isCumulative }
            
        case .cancelTapped, .saveTapped, .jumpToFirstIssueTapped:
            break
        }
    }
    
    func saveTapped() async {
        guard let draft = state.draft else { return }
        guard state.isSaving == false else { return }
        
        // Recompute first so Save gating and anchors stay up-to-date.
        recomputeValidation()
        
        guard canSave else { return }
        
        guard
            let dose = draft.defaultDose,
            let yield = draft.defaultTargetYield,
            let temp = draft.defaultWaterTemperature
        else {
            // Should already be blocked by UI-only validation; keep defensive.
            state.saveErrorMessage = "Please fill in all required fields."
            recomputeValidation()
            return
        }
        
        state.isSaving = true
        state.saveErrorMessage = nil
        didSaveSuccessfully = false
        
        let steps: [RecipeStepDTO] = draft.steps
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated()
            .map { index, step in
                RecipeStepDTO(
                    stepId: step.id,
                    orderIndex: index,
                    instructionText: step.instructionText,
                    timerDurationSeconds: step.timerDurationSeconds,
                    waterAmountGrams: step.waterAmountGrams,
                    isCumulativeWaterTarget: step.isCumulativeWaterTarget
                )
            }
        
        let request = UpdateRecipeRequest(
            id: draft.recipeId,
            name: draft.name,
            defaultDose: dose,
            defaultTargetYield: yield,
            defaultWaterTemperature: temp,
            defaultGrindLabel: draft.defaultGrindLabel,
            grindTactileDescriptor: draft.grindTactileDescriptor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : draft.grindTactileDescriptor,
            steps: steps
        )
        
        let requestErrors = request.validate()
        guard requestErrors.isEmpty else {
            saveAttemptErrors = requestErrors
            state.isSaving = false
            recomputeValidation()
            return
        }
        
        do {
            let result = try useCase.updateCustomRecipe(request)
            switch result {
            case .success:
                baselineDraft = draft
                state.isDirty = false
                saveAttemptErrors = []
                recomputeValidation()
                state.isSaving = false
                didSaveSuccessfully = true
            case .failure(let validationErrors):
                saveAttemptErrors = validationErrors.errors
                state.isSaving = false
                recomputeValidation()
            }
        } catch let error as RecipeUseCaseError {
            state.isSaving = false
            state.saveErrorMessage = error.errorDescription
        } catch {
            state.isSaving = false
            state.saveErrorMessage = "Couldn’t save changes. Please try again."
        }
    }
    
    func clearSaveError() {
        state.saveErrorMessage = nil
    }
    
    // MARK: - Draft mutation helpers
    
    private func mutateDraft(_ mutate: (inout RecipeEditDraft) -> Void) {
        guard var draft = state.draft else { return }
        mutate(&draft)
        state.draft = draft
        updateDirtyStateAndValidation()
    }
    
    private func mutateStep(stepId: UUID, _ mutate: (inout RecipeStepDraft) -> Void) {
        mutateDraft { draft in
            guard let index = draft.steps.firstIndex(where: { $0.id == stepId }) else { return }
            mutate(&draft.steps[index])
            normalizeOrderIndexes(&draft.steps)
        }
    }
    
    private func updateDirtyStateAndValidation() {
        if let draft = state.draft, let baselineDraft {
            state.isDirty = (draft != baselineDraft)
        } else {
            state.isDirty = false
        }
        recomputeValidation()
    }
    
    // MARK: - Validation
    
    private func recomputeValidation() {
        guard let draft = state.draft else {
            state.validation = .init()
            return
        }
        
        var validationErrors: [RecipeValidationError] = []
        var fieldErrors = RecipeEditFieldErrors()
        var stepErrorMap: [UUID: [RecipeValidationError]] = [:]
        var stepInlineMap: [UUID: [RecipeEditInlineError]] = [:]
        
        var uiOnlyIssueCount = 0
        var firstAnchor: ValidationAnchor?
        
        // Name
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(.emptyName)
            fieldErrors.name = "Required"
            firstAnchor = firstAnchor ?? .name
        }
        
        // Dose
        if let dose = draft.defaultDose {
            if dose <= 0 {
                validationErrors.append(.invalidDose)
                fieldErrors.dose = "Must be greater than 0"
                firstAnchor = firstAnchor ?? .dose
            }
        } else {
            fieldErrors.dose = "Required"
            uiOnlyIssueCount += 1
            firstAnchor = firstAnchor ?? .dose
        }
        
        // Yield
        if let yield = draft.defaultTargetYield {
            if yield <= 0 {
                validationErrors.append(.invalidYield)
                fieldErrors.yield = "Must be greater than 0"
                firstAnchor = firstAnchor ?? .yield
            }
        } else {
            fieldErrors.yield = "Required"
            uiOnlyIssueCount += 1
            firstAnchor = firstAnchor ?? .yield
        }
        
        // Temperature (UI-only required)
        if let temp = draft.defaultWaterTemperature {
            if temp <= 0 {
                fieldErrors.temperature = "Must be greater than 0"
                uiOnlyIssueCount += 1
                firstAnchor = firstAnchor ?? .temperature
            }
        } else {
            fieldErrors.temperature = "Required"
            uiOnlyIssueCount += 1
            firstAnchor = firstAnchor ?? .temperature
        }
        
        // Steps presence
        if draft.steps.isEmpty {
            validationErrors.append(.noSteps)
            fieldErrors.steps = "Add at least one step"
            firstAnchor = firstAnchor ?? .steps
        }
        
        // Step-level validation (UI-only + enum-backed)
        for step in draft.steps {
            if step.instructionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stepInlineMap[step.id, default: []].append(
                    RecipeEditInlineError(field: .instruction, message: "Instruction is required")
                )
                uiOnlyIssueCount += 1
                firstAnchor = firstAnchor ?? .step(id: step.id)
            }
            
            if let seconds = step.timerDurationSeconds, seconds < 0 {
                validationErrors.append(.negativeTimer(stepIndex: step.orderIndex))
                firstAnchor = firstAnchor ?? .step(id: step.id)
            }
            
            if let grams = step.waterAmountGrams, grams < 0 {
                validationErrors.append(.negativeWaterAmount(stepIndex: step.orderIndex))
                firstAnchor = firstAnchor ?? .step(id: step.id)
            }
        }
        
        // Water mismatch (special emphasis)
        var waterMismatch: RecipeEditWaterMismatchState?
        if let expectedYield = draft.defaultTargetYield, expectedYield > 0 {
            let hasCumulative = draft.steps.contains(where: { $0.isCumulativeWaterTarget })
            let maxWater = draft.steps.compactMap(\.waterAmountGrams).max()
            if hasCumulative, let maxWater {
                let difference = abs(maxWater - expectedYield)
                if difference > 1.0 {
                    validationErrors.append(.waterTotalMismatch(expected: expectedYield, actual: maxWater))
                    
                    let offenders = draft.steps
                        .filter { step in
                            step.isCumulativeWaterTarget
                                && abs((step.waterAmountGrams ?? -Double.greatestFiniteMagnitude) - maxWater) < 0.0001
                        }
                        .map(\.id)
                    
                    waterMismatch = RecipeEditWaterMismatchState(
                        expectedYield: expectedYield,
                        actualWaterTotal: maxWater,
                        offendingStepIds: Set(offenders)
                    )
                    
                    firstAnchor = firstAnchor ?? .yield
                }
            }
        }
        
        // Map enum-backed step errors to step IDs using orderIndex.
        let orderToStepId: [Int: UUID] = Dictionary(
            uniqueKeysWithValues: draft.steps.map { ($0.orderIndex, $0.id) }
        )
        
        for error in validationErrors {
            switch error {
            case .negativeTimer(let stepIndex), .negativeWaterAmount(let stepIndex):
                if let stepId = orderToStepId[stepIndex] {
                    stepErrorMap[stepId, default: []].append(error)
                }
            default:
                break
            }
        }
        
        // Merge in validation errors from the last save attempt (if any).
        for saveError in saveAttemptErrors {
            if !validationErrors.contains(where: { $0 == saveError }) {
                validationErrors.append(saveError)
            }
        }
        
        let isValid = validationErrors.isEmpty && uiOnlyIssueCount == 0
        let issueCount = validationErrors.count + uiOnlyIssueCount
        
        state.validation = RecipeEditValidationState(
            errors: validationErrors,
            issueCount: issueCount,
            firstAnchor: firstAnchor,
            fieldErrors: fieldErrors,
            stepErrorMap: stepErrorMap,
            stepInlineErrorMap: stepInlineMap,
            waterMismatch: waterMismatch,
            isValid: isValid
        )
    }
}

private func normalizeOrderIndexes(_ steps: inout [RecipeStepDraft]) {
    for (index, _) in steps.enumerated() {
        steps[index].orderIndex = index
    }
}

private func move<T>(_ array: inout [T], fromOffsets: IndexSet, toOffset: Int) {
    let moving = fromOffsets.map { array[$0] }
    for index in fromOffsets.sorted(by: >) {
        array.remove(at: index)
    }
    
    var destination = toOffset
    let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
    destination -= removedBeforeDestination
    
    array.insert(contentsOf: moving, at: destination)
}

