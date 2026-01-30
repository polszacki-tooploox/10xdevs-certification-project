//
//  BrewSessionFlowView.swift
//  BrewGuide
//
//  Full-screen brew execution flow with step progression and timer management.
//  Follows PRD requirements for kitchen-proof UI with large controls and safeguards.
//

import SwiftUI
import SwiftData

/// Full-screen view for the guided brew session flow.
/// Presented as a modal from AppRootView.
struct BrewSessionFlowView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    let presentation: BrewSessionPresentation
    
    @State private var viewModel: BrewSessionFlowViewModel
    
    init(presentation: BrewSessionPresentation) {
        self.presentation = presentation
        _viewModel = State(initialValue: BrewSessionFlowViewModel(plan: presentation.plan))
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Brewing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !viewModel.isCompleted {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Exit", role: .destructive) {
                                viewModel.requestExit()
                            }
                        }
                    }
                }
                .alert("Exit Brewing?", isPresented: $viewModel.showExitConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Exit", role: .destructive) {
                        viewModel.confirmExit {
                            coordinator.dismissBrewSession()
                        }
                    }
                } message: {
                    Text("Your brew progress will be lost.")
                }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            viewModel.handleScenePhaseChange(isActive: newPhase == .active)
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isCompleted {
            postBrewView
        } else {
            brewingView
        }
    }
    
    // MARK: - Brewing View
    
    private var brewingView: some View {
        BrewSessionContent(
            state: viewModel.state,
            uiState: viewModel.ui,
            onNextStep: {
                viewModel.nextStep()
            },
            onBloomPourComplete: {
                viewModel.confirmBloomPourComplete()
            }
        )
    }
    
    // MARK: - Post-Brew View
    
    private var postBrewView: some View {
        PostBrewView(
            plan: presentation.plan,
            onSave: { rating, tasteTag, notes in
                do {
                    try await viewModel.saveBrewOutcome(
                        rating: rating,
                        tasteTag: tasteTag,
                        note: notes,
                        context: modelContext
                    )
                    coordinator.dismissBrewSession()
                } catch {
                    // Error handling - show error and keep user on post-brew view
                    viewModel.errorBanner = .saveFailed(message: error.localizedDescription)
                }
            },
            onDiscard: {
                coordinator.dismissBrewSession()
            }
        )
    }
}

// MARK: - Preview

#Preview("Full Flow") {
    let testInputs = BrewInputs(
        recipeId: UUID(),
        recipeName: "Test Recipe",
        method: .v60,
        doseGrams: 15.0,
        targetYieldGrams: 250.0,
        waterTemperatureCelsius: 93.0,
        grindLabel: .medium,
        lastEdited: .dose
    )
    
    let testSteps = [
        ScaledStep(
            stepId: UUID(),
            orderIndex: 0,
            instructionText: "Rinse filter and preheat",
            stepKind: .preparation,
            durationSeconds: nil,
            targetElapsedSeconds: nil,
            waterAmountGrams: nil,
            isCumulativeWaterTarget: false
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 1,
            instructionText: "Add coffee, level bed",
            stepKind: .preparation,
            durationSeconds: nil,
            targetElapsedSeconds: nil,
            waterAmountGrams: nil,
            isCumulativeWaterTarget: false
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 2,
            instructionText: "Bloom: pour 50g, wait 45s",
            stepKind: .bloom,
            durationSeconds: 45,
            targetElapsedSeconds: nil,
            waterAmountGrams: 50,
            isCumulativeWaterTarget: false
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 3,
            instructionText: "Pour to 150g by 1:30",
            stepKind: .pour,
            durationSeconds: nil,
            targetElapsedSeconds: 90,
            waterAmountGrams: 150,
            isCumulativeWaterTarget: true
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 4,
            instructionText: "Pour to 250g by 2:15",
            stepKind: .pour,
            durationSeconds: nil,
            targetElapsedSeconds: 135,
            waterAmountGrams: 250,
            isCumulativeWaterTarget: true
        )
    ]
    
    let testPlan = BrewPlan(inputs: testInputs, scaledSteps: testSteps)
    let presentation = BrewSessionPresentation(plan: testPlan)
    
    BrewSessionFlowView(presentation: presentation)
        .environment(AppRootCoordinator())
        .modelContainer(PersistenceController.preview.container)
}
