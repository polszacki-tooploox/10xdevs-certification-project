//
//  ConfirmInputsViewModel.swift
//  BrewGuide
//
//  View model for ConfirmInputsView following domain-first MVVM architecture.
//

import Foundation
import SwiftData

/// View model for the confirm inputs screen.
/// Manages recipe loading, input editing with scaling, validation, and brew plan creation.
@Observable
@MainActor
final class ConfirmInputsViewModel {
    
    // MARK: - State
    
    var ui = ConfirmInputsUIState()
    private(set) var recipeSnapshot: ConfirmInputsRecipeSnapshot?
    private(set) var inputsDraft: BrewInputs?
    private(set) var scaling: ConfirmInputsScalingState?
    private var lastLoadedRecipeId: UUID?
    
    // MARK: - Dependencies
    
    private let preferences: PreferencesStore
    private let scalingService: ScalingService
    private let brewSessionUseCase: BrewSessionUseCaseProtocol
    
    // MARK: - Initialization
    
    init(
        preferences: PreferencesStore = .shared,
        scalingService: ScalingService = ScalingService(),
        brewSessionUseCase: BrewSessionUseCaseProtocol
    ) {
        self.preferences = preferences
        self.scalingService = scalingService
        self.brewSessionUseCase = brewSessionUseCase
    }
    
    // MARK: - Computed View State
    
    /// Computes the UI-facing view state from internal state.
    var viewState: ConfirmInputsViewState? {
        guard let snapshot = recipeSnapshot,
              let inputs = inputsDraft,
              let scaling = scaling else {
            return nil
        }
        
        let canEdit = !ui.isStartingBrew
        let canStart = snapshot.isBrewable
            && areInputsValid(inputs)
            && !ui.isStartingBrew
        
        return ConfirmInputsViewState(
            isLoading: false,
            recipeName: snapshot.recipeName,
            method: snapshot.method,
            isRecipeBrewable: snapshot.isBrewable,
            brewabilityMessage: snapshot.brewabilityMessage,
            doseGrams: inputs.doseGrams,
            targetYieldGrams: inputs.targetYieldGrams,
            waterTemperatureCelsius: inputs.waterTemperatureCelsius,
            grindLabel: inputs.grindLabel,
            grindTactileDescriptor: snapshot.grindTactileDescriptor,
            ratio: scaling.derivedRatio,
            warnings: scaling.warnings,
            isStartingBrew: ui.isStartingBrew,
            canStartBrew: canStart,
            canEdit: canEdit
        )
    }
    
    var isLoading: Bool {
        recipeSnapshot == nil
    }
    
    // MARK: - Lifecycle
    
    /// Load initial recipe on view appear.
    func onAppear(recipeId: UUID?) async {
        // Determine which recipe to load
        let targetRecipeId = recipeId ?? preferences.lastSelectedRecipeId
        
        await loadRecipe(recipeId: targetRecipeId)
    }
    
    /// Refresh if selection changed (called when returning from recipe picker).
    func refreshIfSelectionChanged() {
        let currentSelection = preferences.lastSelectedRecipeId
        
        guard let currentSelection, currentSelection != lastLoadedRecipeId else {
            return
        }
        
        Task {
            await loadRecipe(recipeId: currentSelection)
        }
    }
    
    // MARK: - Recipe Loading
    
    private func loadRecipe(recipeId: UUID?) async {
        do {
            // Use the use case to load recipe with fallback to starter
            let recipe = try brewSessionUseCase.loadRecipeForBrewing(
                id: recipeId,
                fallbackMethod: .v60
            )
            
            // Validate recipe
            let validationErrors = RecipeValidator.validate(recipe)
            
            // Create snapshot
            recipeSnapshot = ConfirmInputsRecipeSnapshot(
                recipeId: recipe.id,
                recipeName: recipe.name,
                method: recipe.method,
                defaultDose: recipe.defaultDose,
                defaultTargetYield: recipe.defaultTargetYield,
                defaultWaterTemperature: recipe.defaultWaterTemperature,
                defaultGrindLabel: recipe.defaultGrindLabel,
                grindTactileDescriptor: recipe.grindTactileDescriptor,
                validationErrors: validationErrors
            )
            
            // Create inputs draft from defaults
            inputsDraft = brewSessionUseCase.createInputs(from: recipe)
            
            // Compute initial scaling
            recomputeScaling()
            
            // Track loaded recipe
            lastLoadedRecipeId = recipe.id
            preferences.lastSelectedRecipeId = recipe.id
            
        } catch {
            ui.errorMessage = "Failed to load recipe: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Input Updates
    
    func handleEvent(_ event: ConfirmInputsEvent) {
        switch event {
        case .changeRecipeTapped:
            // Navigation handled by view
            break
            
        case .doseChanged(let newDose):
            updateDose(newDose)
            
        case .yieldChanged(let newYield):
            updateYield(newYield)
            
        case .temperatureChanged(let newTemp):
            updateTemperature(newTemp)
            
        case .grindChanged(let newGrind):
            updateGrind(newGrind)
            
        case .resetTapped:
            resetToDefaults()
            
        case .startBrewTapped:
            // Handled separately via async method
            break
        }
    }
    
    private func updateDose(_ newDose: Double) {
        guard var inputs = inputsDraft else { return }
        
        inputs.doseGrams = newDose
        inputs.lastEdited = .dose
        inputsDraft = inputs
        
        recomputeScaling()
    }
    
    private func updateYield(_ newYield: Double) {
        guard var inputs = inputsDraft else { return }
        
        inputs.targetYieldGrams = newYield
        inputs.lastEdited = .yield
        inputsDraft = inputs
        
        recomputeScaling()
    }
    
    private func updateTemperature(_ newTemp: Double) {
        guard var inputs = inputsDraft else { return }
        
        inputs.waterTemperatureCelsius = newTemp
        inputsDraft = inputs
        
        recomputeScaling()
    }
    
    private func updateGrind(_ newGrind: GrindLabel) {
        guard var inputs = inputsDraft else { return }
        
        inputs.grindLabel = newGrind
        inputsDraft = inputs
        
        // No scaling impact
    }
    
    private func resetToDefaults() {
        guard let snapshot = recipeSnapshot else { return }
        
        inputsDraft = BrewInputs(
            recipeId: snapshot.recipeId,
            recipeName: snapshot.recipeName,
            method: snapshot.method,
            doseGrams: snapshot.defaultDose,
            targetYieldGrams: snapshot.defaultTargetYield,
            waterTemperatureCelsius: snapshot.defaultWaterTemperature,
            grindLabel: snapshot.defaultGrindLabel,
            lastEdited: .yield
        )
        
        recomputeScaling()
    }
    
    // MARK: - Scaling
    
    private func recomputeScaling() {
        guard let snapshot = recipeSnapshot,
              let inputs = inputsDraft else {
            return
        }
        
        let request = ScaleInputsRequest(
            method: snapshot.method,
            recipeDefaultDose: snapshot.defaultDose,
            recipeDefaultTargetYield: snapshot.defaultTargetYield,
            userDose: inputs.doseGrams,
            userTargetYield: inputs.targetYieldGrams,
            lastEdited: inputs.lastEdited
        )
        
        let response = scalingService.scaleInputs(
            request: request,
            temperatureCelsius: inputs.waterTemperatureCelsius
        )
        
        // Write scaled values back into draft
        inputsDraft?.doseGrams = response.scaledDose
        inputsDraft?.targetYieldGrams = response.scaledTargetYield
        
        // Store scaling state
        scaling = ConfirmInputsScalingState(
            scaledDose: response.scaledDose,
            scaledTargetYield: response.scaledTargetYield,
            derivedRatio: response.derivedRatio,
            warnings: response.warnings,
            scaledWaterTargets: response.scaledWaterTargets
        )
    }
    
    // MARK: - Validation
    
    private func areInputsValid(_ inputs: BrewInputs) -> Bool {
        inputs.doseGrams > 0
            && inputs.targetYieldGrams > 0
            && inputs.waterTemperatureCelsius > 0
    }
    
    // MARK: - Start Brew
    
    func startBrew(coordinator: AppRootCoordinator) async {
        guard let snapshot = recipeSnapshot,
              let inputs = inputsDraft,
              snapshot.isBrewable,
              areInputsValid(inputs) else {
            ui.errorMessage = "Cannot start brewing with invalid inputs"
            return
        }
        
        ui.isStartingBrew = true
        defer { ui.isStartingBrew = false }
        
        do {
            let plan = try await brewSessionUseCase.createPlan(from: inputs)
            
            // Present brew session
            coordinator.presentBrewSession(plan: plan)
            
        } catch {
            ui.errorMessage = error.localizedDescription
        }
    }
}
