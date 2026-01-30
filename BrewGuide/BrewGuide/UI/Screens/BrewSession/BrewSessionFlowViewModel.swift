//
//  BrewSessionFlowViewModel.swift
//  BrewGuide
//
//  View model for the brew session flow.
//  Manages state transitions, timer execution, and brew saving.
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "BrewSessionFlowViewModel")

/// View model for managing brew session state and timer execution.
@Observable
@MainActor
final class BrewSessionFlowViewModel {
    // MARK: - State
    
    /// Current brew session state (source of truth)
    private(set) var state: BrewSessionState
    
    /// Show exit confirmation dialog
    var showExitConfirmation = false
    
    /// Error banner for non-blocking failures
    var errorBanner: BrewSessionFlowErrorBanner?
    
    /// Saving state for post-brew save operation
    var isSavingPostBrew = false
    
    // MARK: - Private State
    
    /// Active timer task (cancelled on next, exit, completion)
    private var timerTask: Task<Void, Never>?
    
    /// Clock for timer tick control (injectable for testing)
    private let clock: any Clock<Duration>
    
    /// Tick counter to force UI updates for elapsed time
    private var tickCount: Int = 0
    
    // MARK: - Initialization
    
    init(plan: BrewPlan, clock: any Clock<Duration> = ContinuousClock()) {
        self.state = BrewSessionState(
            plan: plan,
            phase: .notStarted,
            currentStepIndex: 0,
            startedAt: nil,
            isInputsLocked: true
        )
        self.clock = clock
    }
    
    // MARK: - Computed Properties
    
    var currentStep: ScaledStep? {
        state.currentStep
    }
    
    var stepCount: Int {
        state.plan.scaledSteps.count
    }
    
    var isCompleted: Bool {
        state.phase == .completed
    }
    
    var isNextEnabled: Bool {
        // Next is always enabled (no countdown timer to wait for)
        currentStep != nil
    }
    
    /// Pre-formatted UI state for declarative rendering
    var ui: BrewSessionFlowUIState {
        // Force re-computation when tickCount changes (triggers SwiftUI re-render)
        _ = tickCount
        
        let stepTitle = "Step \(state.currentStepIndex + 1) of \(stepCount)"
        let instructionText = currentStep?.instructionText ?? ""
        
        // Format water line
        var waterLine: String?
        if let step = currentStep, let water = step.waterAmountGrams {
            let waterFormatted = String(format: "%.0f g", water)
            let label = step.isCumulativeWaterTarget ? "total" : "pour"
            waterLine = "\(waterFormatted) \(label)"
        }
        
        // Format elapsed time (total brew clock)
        var elapsedText: String?
        if let elapsed = state.elapsedTime {
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            elapsedText = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Compute pacing indicator for pour steps
        var pacingIndicator: PacingIndicator?
        if let step = currentStep,
           step.stepKind == .pour,
           let targetElapsed = step.targetElapsedSeconds,
           let elapsed = state.elapsedTime {
            let timeRemaining = targetElapsed - elapsed
            if timeRemaining < -10 {
                pacingIndicator = .behind
            } else if timeRemaining > 30 {
                pacingIndicator = .ahead
            } else {
                pacingIndicator = .onPace
            }
        }
        
        let primaryNextLabel = state.isLastStep ? "Finish" : "Next Step"
        
        return BrewSessionFlowUIState(
            stepTitle: stepTitle,
            instructionText: instructionText,
            waterLine: waterLine,
            elapsedText: elapsedText,
            primaryNextLabel: primaryNextLabel,
            pacingIndicator: pacingIndicator
        )
    }
    
    // MARK: - Public Intent Methods
    
    /// Called when the view appears
    func onAppear() {
        logger.info("Brew session view appeared with \(self.stepCount) steps")
        
        // Auto-start first step if it has a timer
        startStepIfNeeded()
    }
    
    /// Request to exit the brew session
    func requestExit() {
        // Only show confirmation if brew is active (not completed)
        guard !isCompleted else { return }
        
        showExitConfirmation = true
    }
    
    /// Confirm exit and dismiss
    func confirmExit(dismiss: () -> Void) {
        logger.info("Exit confirmed - cancelling timer and dismissing")
        cancelTimerTask()
        dismiss()
    }
    
    /// Start the timer for the current step if needed
    func startStepIfNeeded() {
        guard state.phase == .notStarted else { return }
        guard let step = currentStep else { return }
        
        switch step.stepKind {
        case .preparation:
            // No timer - ready to advance immediately
            // DON'T start brew clock - no water pouring yet
            state.phase = .stepReadyToAdvance
            logger.debug("Preparation step - ready immediately")
            
        case .bloom:
            // Show "Pour now" prompt, brew clock starts after user confirms pour
            state.phase = .awaitingPourConfirmation
            logger.debug("Bloom step - awaiting pour confirmation")
            
        case .pour:
            // Start brew clock when water pouring begins (if not already running from bloom)
            if state.startedAt == nil {
                state.startedAt = Date()
                logger.debug("Starting brew clock on first pour step")
            }
            
            // Always ensure timer loop is running for brew clock updates
            if timerTask == nil {
                startTimerLoop()
            }
            state.phase = .active
            logger.debug("Pour step - tracking elapsed time to milestone \(step.targetElapsedSeconds ?? 0)")
            
        case .wait:
            // Continue brew clock, ready to advance
            if timerTask == nil && state.startedAt != nil {
                startTimerLoop()
            }
            state.phase = .stepReadyToAdvance
            logger.debug("Wait step - ready to advance")
            
        case .agitate:
            // Brief action - ready to advance immediately
            // But continue timer loop for brew clock updates
            if state.startedAt != nil && timerTask == nil {
                startTimerLoop()
            }
            state.phase = .stepReadyToAdvance
            logger.debug("Agitate step - ready immediately")
        }
    }
    
    /// Advance to the next step or complete the session
    func nextStep() {
        cancelTimerTask()
        
        if state.isLastStep {
            // Complete the session
            state.phase = .completed
            logger.info("Brew session completed")
        } else {
            // Move to next step
            state.currentStepIndex += 1
            state.phase = .notStarted
            
            logger.info("Advanced to step \(self.state.currentStepIndex + 1)")
            
            // Auto-start next step
            startStepIfNeeded()
        }
    }
    
    /// Called when user confirms bloom pour is complete - starts brew clock
    func confirmBloomPourComplete() {
        guard state.phase == .awaitingPourConfirmation else { return }
        guard let step = currentStep, step.stepKind == .bloom else { return }
        
        // Start brew clock when user confirms they've poured water for bloom
        if state.startedAt == nil {
            state.startedAt = Date()
            logger.debug("Starting brew clock on bloom pour confirmation")
        }
        
        // Start timer loop for brew clock updates and mark step ready to advance
        startTimerLoop()
        state.phase = .stepReadyToAdvance
        logger.info("Bloom pour confirmed - brew clock started")
    }
    
    /// Handle app going to background (timer continues)
    func handleScenePhaseChange(isActive: Bool) {
        if !isActive {
            logger.debug("App backgrounded - brew clock continues tracking elapsed time")
        }
    }
    
    /// Save the brew outcome (called from PostBrewView)
    func saveBrewOutcome(
        rating: Int,
        tasteTag: TasteTag?,
        note: String?,
        context: ModelContext
    ) async throws {
        isSavingPostBrew = true
        defer { isSavingPostBrew = false }
        
        logger.info("Saving brew log: rating=\(rating)")
        
        let repository = BrewLogRepository(context: context)
        
        let log = BrewLog(
            method: state.plan.inputs.method,
            recipeNameAtBrew: state.plan.inputs.recipeName,
            doseGrams: state.plan.inputs.doseGrams,
            targetYieldGrams: state.plan.inputs.targetYieldGrams,
            waterTemperatureCelsius: state.plan.inputs.waterTemperatureCelsius,
            grindLabel: state.plan.inputs.grindLabel,
            rating: rating,
            tasteTag: tasteTag,
            note: note
        )
        
        repository.insert(log)
        try repository.save()
        
        logger.info("Brew log saved successfully")
    }
    
    // MARK: - Private Timer Methods
    
    private func startTimerLoop() {
        // Don't start a new loop if one is already running
        guard timerTask == nil else { return }
        
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            do {
                while !Task.isCancelled {
                    // Sleep for 100ms
                    try await clock.sleep(for: .milliseconds(100))
                    
                    guard !Task.isCancelled else { break }
                    
                    // Force UI update for elapsed time by incrementing tick counter
                    // This triggers @Observable to notify SwiftUI
                    self.tickCount += 1
                }
            } catch {
                // Task was cancelled or sleep failed
                logger.debug("Timer task cancelled or failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelTimerTask() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - UI State

/// Pre-formatted UI state for declarative SwiftUI rendering
struct BrewSessionFlowUIState {
    let stepTitle: String
    let instructionText: String
    let waterLine: String?
    
    // Timer display
    let elapsedText: String?             // Total brew time (MM:SS)
    
    let primaryNextLabel: String
    
    // Pacing indicator for pour steps
    let pacingIndicator: PacingIndicator?
}

enum PacingIndicator {
    case onPace
    case ahead
    case behind
}

// MARK: - Error Banner

enum BrewSessionFlowErrorBanner: Identifiable {
    case cannotStartTimer
    case saveFailed(message: String)
    
    var id: String {
        switch self {
        case .cannotStartTimer:
            return "cannotStartTimer"
        case .saveFailed(let message):
            return "saveFailed_\(message)"
        }
    }
    
    var message: String {
        switch self {
        case .cannotStartTimer:
            return "Unable to start timer"
        case .saveFailed(let msg):
            return "Save failed: \(msg)"
        }
    }
}
