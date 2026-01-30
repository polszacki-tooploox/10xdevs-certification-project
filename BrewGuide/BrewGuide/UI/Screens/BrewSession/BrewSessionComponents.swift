//
//  BrewSessionComponents.swift
//  BrewGuide
//
//  Reusable UI components for the brew session flow.
//

import SwiftUI

// MARK: - Brew Clock View

/// Persistent brew clock showing total elapsed time from first pour
struct BrewClockView: View {
    let elapsedText: String?
    
    var body: some View {
        if let elapsed = elapsedText {
            VStack(spacing: 4) {
                Text(elapsed)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .monospacedDigit()
                
                Text("Total Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

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

// MARK: - Brew Session Primary Controls

/// Simplified primary control with only Next/Finish button
struct BrewSessionPrimaryControls: View {
    let isLastStep: Bool
    let isNextEnabled: Bool
    let onNextStep: () -> Void
    
    var body: some View {
        Button {
            onNextStep()
        } label: {
            HStack {
                Text(nextButtonLabel)
                    .font(.headline)
                
                if isNextEnabled {
                    Image(systemName: isLastStep ? "checkmark" : "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isNextEnabled)
    }
    
    private var nextButtonLabel: String {
        isLastStep ? "Finish" : "Next Step"
    }
}

// MARK: - Brew Session Content

/// Main content view for active brew session
struct BrewSessionContent: View {
    let state: BrewSessionState
    let uiState: BrewSessionFlowUIState
    let onNextStep: () -> Void
    let onBloomPourComplete: () -> Void
    
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
                    // Brew clock (visible after first pour starts)
                    if uiState.elapsedText != nil {
                        BrewClockView(elapsedText: uiState.elapsedText)
                    }
                    
                    // Current step card
                    if let step = state.currentStep {
                        BrewNowStepCard(
                            step: step,
                            formattedWater: uiState.waterLine
                        )
                    }
                    
                    // Primary controls
                    if state.phase == .awaitingPourConfirmation {
                        // Bloom step: Show "Pour Complete" button
                        Button {
                            onBloomPourComplete()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Pour Complete")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        // Regular Next/Finish button
                        BrewSessionPrimaryControls(
                            isLastStep: state.isLastStep,
                            isNextEnabled: true,
                            onNextStep: onNextStep
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Previews

#Preview("Brew Clock") {
    BrewClockView(elapsedText: "2:34")
        .padding()
}

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
