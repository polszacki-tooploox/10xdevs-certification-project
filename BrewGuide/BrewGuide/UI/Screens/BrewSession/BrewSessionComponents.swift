//
//  BrewSessionComponents.swift
//  BrewGuide
//
//  Reusable UI components for the brew session flow.
//

import SwiftUI

// MARK: - Brew Session Progress View

/// Lightweight progress indicator showing current step position
struct BrewSessionProgressView: View {
    let currentStepIndex: Int
    let stepCount: Int
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            
            Text("Step \(currentStepIndex + 1) of \(stepCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Brew Now Step Card

/// Prominent card displaying current brew instruction and water target
struct BrewNowStepCard: View {
    let step: ScaledStep
    let formattedWater: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Instruction text
            Text(step.instructionText)
                .font(.title2)
                .multilineTextAlignment(.leading)
            
            // Water amount (if present)
            if let waterText = formattedWater {
                HStack(spacing: 8) {
                    Image(systemName: step.isCumulativeWaterTarget ? "drop.fill" : "drop")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    
                    Text(waterText)
                        .font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Brew Timer Panel

/// Countdown timer display with ready state indication
struct BrewTimerPanel: View {
    let remaining: TimeInterval
    let duration: TimeInterval
    let phase: BrewSessionState.Phase
    
    var body: some View {
        VStack(spacing: 16) {
            // Countdown display
            Text(formatTime(remaining))
                .font(.system(size: 72, design: .rounded))
                .bold()
                .monospacedDigit()
                .foregroundStyle(timeColor)
            
            // Ready indicator
            if remaining <= 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Ready")
                        .font(.title3)
                        .bold()
                }
                .foregroundStyle(.green)
            }
            
            // Progress bar
            if duration > 0 {
                ProgressView(value: 1.0 - (remaining / duration))
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
                    .tint(progressColor)
            }
        }
        .padding()
    }
    
    private var timeColor: Color {
        if remaining <= 0 {
            return .green
        } else if remaining <= 5 {
            return .red
        } else {
            return .primary
        }
    }
    
    private var progressColor: Color {
        phase == .paused ? .secondary : .accentColor
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Brew Session Primary Controls

/// Large primary action buttons (Next and Pause/Resume)
struct BrewSessionPrimaryControls: View {
    let phase: BrewSessionState.Phase
    let isLastStep: Bool
    let isNextEnabled: Bool
    let isPauseResumeEnabled: Bool
    let onNextStep: () -> Void
    let onPauseResume: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Next step button (always visible)
            Button {
                onNextStep()
            } label: {
                HStack {
                    Text(nextButtonLabel)
                        .font(.headline)
                    
                    if isNextEnabled {
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isNextEnabled)
            
            // Pause/Resume button (visible for timed steps)
            if isPauseResumeEnabled || phase == .active || phase == .paused {
                Button {
                    onPauseResume()
                } label: {
                    HStack {
                        Image(systemName: pauseResumeIcon)
                        Text(pauseResumeLabel)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isPauseResumeEnabled)
            }
        }
    }
    
    private var nextButtonLabel: String {
        isLastStep ? "Finish" : "Next Step"
    }
    
    private var pauseResumeLabel: String {
        phase == .active ? "Pause" : "Resume"
    }
    
    private var pauseResumeIcon: String {
        phase == .active ? "pause.fill" : "play.fill"
    }
}

// MARK: - Brew Session Secondary Controls

/// Secondary controls with safeguards (Restart with hold-to-confirm)
struct BrewSessionSecondaryControls: View {
    let isEnabled: Bool
    let onConfirmed: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HoldToConfirmButton(
                title: "Hold to Restart",
                systemImage: "arrow.counterclockwise",
                holdDuration: .seconds(1.5),
                role: .destructive,
                onConfirmed: onConfirmed
            )
            .disabled(!isEnabled)
            
            Text("Restart resets to step 1 and clears timers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Brew Session Content

/// Main content view for active brew session
struct BrewSessionContent: View {
    let state: BrewSessionState
    let uiState: BrewSessionFlowUIState
    let onNextStep: () -> Void
    let onPauseResume: () -> Void
    let onRestartHoldConfirmed: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            BrewSessionProgressView(
                currentStepIndex: state.currentStepIndex,
                stepCount: state.plan.scaledSteps.count,
                progress: state.progress
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // Current step card
                    if let step = state.currentStep {
                        BrewNowStepCard(
                            step: step,
                            formattedWater: uiState.waterLine
                        )
                    }
                    
                    // Timer panel (if timed step)
                    if uiState.isTimerVisible, let remaining = state.remainingTime {
                        BrewTimerPanel(
                            remaining: remaining,
                            duration: state.currentStep?.timerDurationSeconds ?? 0,
                            phase: state.phase
                        )
                    }
                    
                    // Primary controls
                    BrewSessionPrimaryControls(
                        phase: state.phase,
                        isLastStep: state.isLastStep,
                        isNextEnabled: state.phase == .stepReadyToAdvance || 
                                      state.currentStep?.timerDurationSeconds == nil,
                        isPauseResumeEnabled: state.phase == .active || state.phase == .paused,
                        onNextStep: onNextStep,
                        onPauseResume: onPauseResume
                    )
                    
                    // Secondary controls
                    BrewSessionSecondaryControls(
                        isEnabled: state.phase != .completed,
                        onConfirmed: onRestartHoldConfirmed
                    )
                }
                .padding()
            }
        }
    }
}

// MARK: - Previews

#Preview("Progress View") {
    BrewSessionProgressView(
        currentStepIndex: 2,
        stepCount: 5,
        progress: 0.6
    )
}

#Preview("Step Card") {
    BrewNowStepCard(
        step: ScaledStep(
            stepId: UUID(),
            orderIndex: 0,
            instructionText: "Pour water in a circular motion for bloom",
            stepKind: .bloom,
            durationSeconds: 30,
            targetElapsedSeconds: nil,
            waterAmountGrams: 50,
            isCumulativeWaterTarget: false
        ),
        formattedWater: "50 g pour"
    )
    .padding()
}

#Preview("Timer Panel - Active") {
    BrewTimerPanel(
        remaining: 25,
        duration: 30,
        phase: .active
    )
}

#Preview("Timer Panel - Ready") {
    BrewTimerPanel(
        remaining: 0,
        duration: 30,
        phase: .stepReadyToAdvance
    )
}
