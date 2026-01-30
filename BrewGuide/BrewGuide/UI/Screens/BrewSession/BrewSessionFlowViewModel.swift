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
    
    /// Show restart confirmation dialog (optional second confirmation after hold)
    var showRestartConfirmation = false
    
    /// Error banner for non-blocking failures
    var errorBanner: BrewSessionFlowErrorBanner?
    
    /// Saving state for post-brew save operation
    var isSavingPostBrew = false
    
    // MARK: - Private State
    
    /// Active timer task (cancelled on pause, next, restart, exit)
    private var timerTask: Task<Void, Never>?
    
    /// Clock for timer tick control (injectable for testing)
    private let clock: any Clock<Duration>
    
    // MARK: - Initialization
    
    init(plan: BrewPlan, clock: any Clock<Duration> = ContinuousClock()) {
        self.state = BrewSessionState(
            plan: plan,
            phase: .notStarted,
            currentStepIndex: 0,
            remainingTime: nil,
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
        // Next is enabled if:
        // 1. Step has no timer (untimed step)
        // 2. Timer has reached 0 (stepReadyToAdvance phase)
        guard let step = currentStep else { return false }
        
        if step.timerDurationSeconds == nil {
            return true
        }
        
        return state.phase == .stepReadyToAdvance
    }
    
    var isPauseResumeEnabled: Bool {
        // Pause/Resume is enabled only for timed steps
        guard let step = currentStep,
              step.timerDurationSeconds != nil else {
            return false
        }
        
        return state.phase == .active || state.phase == .paused
    }
    
    var timerDuration: TimeInterval? {
        currentStep?.timerDurationSeconds
    }
    
    /// Pre-formatted UI state for declarative rendering
    var ui: BrewSessionFlowUIState {
        let stepTitle = "Step \(state.currentStepIndex + 1) of \(stepCount)"
        let instructionText = currentStep?.instructionText ?? ""
        
        // Format water line
        var waterLine: String?
        if let step = currentStep, let water = step.waterAmountGrams {
            let waterFormatted = String(format: "%.0f g", water)
            let label = step.isCumulativeWaterTarget ? "total" : "pour"
            waterLine = "\(waterFormatted) \(label)"
        }
        
        // Format countdown text
        var countdownText: String?
        if let remaining = state.remainingTime {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            countdownText = String(format: "%d:%02d", minutes, seconds)
        }
        
        let isTimerVisible = currentStep?.timerDurationSeconds != nil
        let isReadyToAdvance = state.phase == .stepReadyToAdvance
        
        let primaryNextLabel = state.isLastStep ? "Finish" : "Next Step"
        let primaryPauseResumeLabel = state.phase == .active ? "Pause" : "Resume"
        
        return BrewSessionFlowUIState(
            stepTitle: stepTitle,
            instructionText: instructionText,
            waterLine: waterLine,
            countdownText: countdownText,
            isTimerVisible: isTimerVisible,
            isReadyToAdvance: isReadyToAdvance,
            primaryNextLabel: primaryNextLabel,
            primaryPauseResumeLabel: primaryPauseResumeLabel
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
        
        // Check if step has a timer
        guard let duration = step.timerDurationSeconds, duration > 0 else {
            // No timer - ready to advance immediately
            state.phase = .stepReadyToAdvance
            logger.debug("Step \(self.state.currentStepIndex + 1) has no timer - ready immediately")
            return
        }
        
        // Start timer
        state.remainingTime = duration
        state.phase = .active
        state.startedAt = Date()
        
        logger.info("Starting timer for step \(self.state.currentStepIndex + 1): \(duration)s")
        startTimerLoop()
    }
    
    /// Toggle between pause and resume
    func togglePauseResume() {
        switch state.phase {
        case .active:
            pauseTimer()
        case .paused:
            resumeTimer()
        default:
            logger.warning("togglePauseResume called in invalid phase: \(String(describing: self.state.phase))")
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
            state.remainingTime = nil
            
            logger.info("Advanced to step \(self.state.currentStepIndex + 1)")
            
            // Auto-start next step
            startStepIfNeeded()
        }
    }
    
    /// Restart the brew session from step 1
    func restart() {
        logger.info("Restarting brew session")
        
        cancelTimerTask()
        
        state.currentStepIndex = 0
        state.phase = .notStarted
        state.remainingTime = nil
        state.startedAt = nil
        
        // Auto-start first step
        startStepIfNeeded()
    }
    
    /// Handle app going to background
    func handleScenePhaseChange(isActive: Bool) {
        if !isActive && state.phase == .active {
            logger.info("App backgrounded - pausing timer")
            pauseTimer()
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
    
    private func pauseTimer() {
        guard state.phase == .active else { return }
        
        cancelTimerTask()
        state.phase = .paused
        
        logger.debug("Timer paused at \(self.state.remainingTime ?? 0)s remaining")
    }
    
    private func resumeTimer() {
        guard state.phase == .paused else { return }
        guard state.remainingTime != nil else { return }
        
        state.phase = .active
        logger.debug("Timer resumed")
        
        startTimerLoop()
    }
    
    private func startTimerLoop() {
        // Cancel any existing timer
        cancelTimerTask()
        
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            do {
                while !Task.isCancelled {
                    // Sleep for 100ms
                    try await clock.sleep(for: .milliseconds(100))
                    
                    guard !Task.isCancelled else { break }
                    
                    // Update remaining time
                    await self.tick()
                    
                    // Check if timer reached 0
                    if let remaining = self.state.remainingTime, remaining <= 0 {
                        await self.timerReachedZero()
                        break
                    }
                }
            } catch {
                // Task was cancelled or sleep failed
                logger.debug("Timer task cancelled or failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func tick() {
        guard var remaining = state.remainingTime else { return }
        guard state.phase == .active else { return }
        
        remaining -= 0.1
        state.remainingTime = max(0, remaining)
    }
    
    private func timerReachedZero() {
        state.remainingTime = 0
        state.phase = .stepReadyToAdvance
        
        cancelTimerTask()
        
        logger.info("Timer reached 0 for step \(self.state.currentStepIndex + 1)")
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
    let countdownText: String?
    let isTimerVisible: Bool
    let isReadyToAdvance: Bool
    let primaryNextLabel: String
    let primaryPauseResumeLabel: String
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
