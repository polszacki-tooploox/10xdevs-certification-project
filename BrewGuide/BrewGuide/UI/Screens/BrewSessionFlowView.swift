//
//  BrewSessionFlowView.swift
//  BrewGuide
//
//  Full-screen brew execution flow with step progression.
//

import SwiftUI
import SwiftData

/// Full-screen view for the guided brew session flow.
/// Presented as a modal from AppRootView.
struct BrewSessionFlowView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    
    let presentation: BrewSessionPresentation
    
    @State private var viewModel: BrewSessionViewModel
    
    init(presentation: BrewSessionPresentation) {
        self.presentation = presentation
        _viewModel = State(initialValue: BrewSessionViewModel(plan: presentation.plan))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isCompleted {
                    PostBrewView(
                        plan: presentation.plan,
                        onSave: { rating, tasteTag, notes in
                            await viewModel.saveBrew(
                                rating: rating,
                                tasteTag: tasteTag,
                                notes: notes,
                                context: modelContext
                            )
                            coordinator.dismissBrewSession()
                        },
                        onDiscard: {
                            coordinator.dismissBrewSession()
                        }
                    )
                } else {
                    brewStepView
                }
            }
            .navigationTitle("Brewing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.isCompleted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Exit", role: .destructive) {
                            viewModel.showExitConfirmation = true
                        }
                    }
                }
            }
            .alert("Exit Brewing?", isPresented: $viewModel.showExitConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Exit", role: .destructive) {
                    coordinator.dismissBrewSession()
                }
            } message: {
                Text("Your brew progress will be lost.")
            }
        }
        .interactiveDismissDisabled(true)
    }
    
    // MARK: - Brew Step View
    
    private var brewStepView: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Step counter
                    Text("Step \(viewModel.currentStepIndex + 1) of \(viewModel.plan.scaledSteps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Current step
                    if let step = viewModel.currentStep {
                        stepCard(step)
                    }
                    
                    // Timer display
                    if let remainingTime = viewModel.remainingTime {
                        timerDisplay(remainingTime)
                    }
                    
                    // Controls
                    controlButtons
                }
                .padding()
            }
        }
    }
    
    private func stepCard(_ step: ScaledStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.instructionText)
                .font(.title2)
                .multilineTextAlignment(.leading)
            
            if let water = step.waterAmountGrams {
                HStack {
                    Image(systemName: step.isCumulativeWaterTarget ? "drop.fill" : "drop")
                        .foregroundStyle(.blue)
                    Text("\(Int(water))g")
                        .font(.headline)
                    Text(step.isCumulativeWaterTarget ? "total" : "pour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 12))
    }
    
    private func timerDisplay(_ time: TimeInterval) -> some View {
        VStack(spacing: 8) {
            Text(formatTime(time))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(time <= 5 ? .red : .primary)
            
            if let duration = viewModel.currentStep?.timerDurationSeconds {
                ProgressView(value: 1.0 - (time / duration))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
            }
        }
    }
    
    private var controlButtons: some View {
        VStack(spacing: 16) {
            switch viewModel.phase {
            case .notStarted:
                Button {
                    viewModel.startTimer()
                } label: {
                    Label("Start Timer", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
            case .active:
                Button {
                    viewModel.pauseTimer()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
            case .paused:
                Button {
                    viewModel.resumeTimer()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
            case .stepReadyToAdvance:
                Button {
                    viewModel.advanceToNextStep()
                } label: {
                    Label(viewModel.isLastStep ? "Finish" : "Next Step", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
            case .completed:
                EmptyView()
            }
            
            // Skip button (for steps without timer or if paused)
            if viewModel.currentStep?.timerDurationSeconds == nil || viewModel.phase == .notStarted {
                Button {
                    viewModel.advanceToNextStep()
                } label: {
                    Text(viewModel.isLastStep ? "Finish Brewing" : "Skip to Next Step")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class BrewSessionViewModel {
    let plan: BrewPlan
    
    var phase: BrewSessionState.Phase = .notStarted
    var currentStepIndex = 0
    var remainingTime: TimeInterval?
    var showExitConfirmation = false
    
    private var timer: Timer?
    
    init(plan: BrewPlan) {
        self.plan = plan
    }
    
    var currentStep: ScaledStep? {
        guard currentStepIndex < plan.scaledSteps.count else { return nil }
        return plan.scaledSteps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == plan.scaledSteps.count - 1
    }
    
    var isCompleted: Bool {
        phase == .completed
    }
    
    var progress: Double {
        Double(currentStepIndex + 1) / Double(plan.scaledSteps.count)
    }
    
    // MARK: - Timer Control
    
    func startTimer() {
        guard let duration = currentStep?.timerDurationSeconds else {
            phase = .stepReadyToAdvance
            return
        }
        
        remainingTime = duration
        phase = .active
        startTimerTick()
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        phase = .paused
    }
    
    func resumeTimer() {
        phase = .active
        startTimerTick()
    }
    
    private func startTimerTick() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard var time = remainingTime, time > 0 else {
            timer?.invalidate()
            timer = nil
            phase = .stepReadyToAdvance
            remainingTime = 0
            return
        }
        
        time -= 0.1
        remainingTime = max(0, time)
    }
    
    // MARK: - Step Progression
    
    func advanceToNextStep() {
        timer?.invalidate()
        timer = nil
        
        if isLastStep {
            phase = .completed
        } else {
            currentStepIndex += 1
            phase = .notStarted
            remainingTime = nil
        }
    }
    
    // MARK: - Save Brew
    
    func saveBrew(rating: Int, tasteTag: TasteTag?, notes: String?, context: ModelContext) async {
        let repository = BrewLogRepository(context: context)
        
        let log = BrewLog(
            method: plan.inputs.method,
            recipeNameAtBrew: plan.inputs.recipeName,
            doseGrams: plan.inputs.doseGrams,
            targetYieldGrams: plan.inputs.targetYieldGrams,
            waterTemperatureCelsius: plan.inputs.waterTemperatureCelsius,
            grindLabel: plan.inputs.grindLabel,
            rating: rating,
            tasteTag: tasteTag,
            note: notes
        )
        
        repository.insert(log)
        try? repository.save()
    }
}

#Preview {
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
            instructionText: "Pour 50g water in circular motion for bloom",
            timerDurationSeconds: 30,
            waterAmountGrams: 50,
            isCumulativeWaterTarget: false
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 1,
            instructionText: "Pour to 150g total",
            timerDurationSeconds: 45,
            waterAmountGrams: 150,
            isCumulativeWaterTarget: true
        ),
        ScaledStep(
            stepId: UUID(),
            orderIndex: 2,
            instructionText: "Pour remaining water to 250g",
            timerDurationSeconds: nil,
            waterAmountGrams: 250,
            isCumulativeWaterTarget: true
        )
    ]
    
    let testPlan = BrewPlan(inputs: testInputs, scaledSteps: testSteps)
    let presentation = BrewSessionPresentation(plan: testPlan)
    
    return BrewSessionFlowView(presentation: presentation)
        .environment(AppRootCoordinator())
        .modelContainer(PersistenceController.preview.container)
}
