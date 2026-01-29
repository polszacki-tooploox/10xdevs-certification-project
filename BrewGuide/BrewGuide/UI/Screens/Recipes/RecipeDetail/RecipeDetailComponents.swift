//
//  RecipeDetailComponents.swift
//  BrewGuide
//
//  Supporting components for RecipeDetailView.
//

import SwiftUI

// MARK: - Recipe Header

/// Displays recipe name and status badges
struct RecipeHeader: View {
    let summary: RecipeSummaryDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.name)
                .font(.title2)
                .fontWeight(.bold)
            
            RecipeBadgePillRow(
                isStarter: summary.isStarter,
                isValid: summary.isValid,
                origin: summary.origin
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Defaults Summary Card

/// Displays recipe default brew parameters in a scannable card
struct DefaultsSummaryCard: View {
    let detail: RecipeDetailDTO
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("Defaults")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Parameters Grid
            VStack(spacing: 12) {
                DefaultRow(
                    label: "Dose",
                    value: Text(detail.recipe.defaultDose, format: .number.precision(.fractionLength(1))) + Text(" g")
                )
                
                DefaultRow(
                    label: "Target Yield",
                    value: Text(detail.recipe.defaultTargetYield, format: .number.precision(.fractionLength(0))) + Text(" g")
                )
                
                DefaultRow(
                    label: "Temperature",
                    value: Text(detail.recipe.defaultWaterTemperature, format: .number.precision(.fractionLength(0))) + Text(" °C")
                )
                
                DefaultRow(
                    label: "Grind",
                    value: grindText
                )
                
                DefaultRow(
                    label: "Ratio",
                    value: Text("1:\(detail.recipe.defaultRatio, format: .number.precision(.fractionLength(1)))")
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
    
    private var grindText: Text {
        if let descriptor = detail.grindTactileDescriptor, !descriptor.isEmpty {
            return Text(detail.recipe.defaultGrindLabel.displayName) + Text(" (") + Text(descriptor) + Text(")")
        } else {
            return Text(detail.recipe.defaultGrindLabel.displayName)
        }
    }
}

/// Single default parameter row
private struct DefaultRow: View {
    let label: String
    let value: Text
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            value
                .fontWeight(.medium)
        }
    }
}

// MARK: - Steps Section

/// Displays ordered recipe steps
struct StepsSection: View {
    let steps: [RecipeStepDTO]
    let defaultTargetYield: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("Steps")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Steps List
            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    RecipeStepRow(
                        stepNumber: index + 1,
                        step: step
                    )
                }
            }
        }
    }
}

// MARK: - Recipe Step Row

/// Renders a single recipe step with number, instruction, timer, and water cues
struct RecipeStepRow: View {
    let stepNumber: Int
    let step: RecipeStepDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Step number and instruction
            HStack(alignment: .top, spacing: 8) {
                Text("\(stepNumber).")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                
                Text(step.instructionText)
                    .font(.body)
            }
            
            // Pills for timer and water
            HStack(spacing: 8) {
                if let timerSeconds = step.timerDurationSeconds, timerSeconds >= 0 {
                    StepPill(
                        icon: "timer",
                        text: formatDuration(timerSeconds),
                        color: .blue
                    )
                }
                
                if let waterGrams = step.waterAmountGrams, waterGrams >= 0 {
                    StepPill(
                        icon: "drop.fill",
                        text: formatWater(waterGrams, isCumulative: step.isCumulativeWaterTarget),
                        color: .cyan
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatWater(_ grams: Double, isCumulative: Bool) -> String {
        let formatted = String(format: "%.0f g", grams)
        return isCumulative ? "Pour to \(formatted)" : "Add \(formatted)"
    }
}

/// Small pill for step metadata (timer/water)
private struct StepPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Primary Action Bar

/// Bottom-pinned "Use this recipe" button
struct PrimaryActionBar: View {
    let isEnabled: Bool
    let onUse: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if !isEnabled {
                Text("Fix this recipe before brewing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button(action: onUse) {
                Text("Use this recipe")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Toolbar Actions

/// Contextual toolbar actions (Duplicate/Edit/Delete)
struct RecipeDetailToolbarActions: View {
    let summary: RecipeSummaryDTO?
    let isPerformingAction: Bool
    let onDuplicate: () -> Void
    let onEdit: () -> Void
    let onRequestDelete: () -> Void
    
    var body: some View {
        Group {
            if let summary {
                if summary.isStarter || summary.origin == .starterTemplate {
                    // Starter recipes: Duplicate only
                    Button("Duplicate", systemImage: "doc.on.doc") {
                        onDuplicate()
                    }
                    .disabled(isPerformingAction)
                } else {
                    // Custom recipes: Edit + Delete
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            onEdit()
                        }
                        
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            onDuplicate()
                        }
                        
                        Divider()
                        
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            onRequestDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isPerformingAction)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Recipe Header") {
    RecipeHeader(summary: RecipeSummaryDTO(
        id: UUID(),
        name: "Classic V60",
        method: .v60,
        isStarter: true,
        origin: .starterTemplate,
        isValid: true,
        defaultDose: 15.0,
        defaultTargetYield: 250.0,
        defaultWaterTemperature: 94.0,
        defaultGrindLabel: .medium
    ))
    .padding()
}

#Preview("Defaults Card") {
    DefaultsSummaryCard(detail: RecipeDetailDTO(
        recipe: RecipeSummaryDTO(
            id: UUID(),
            name: "Classic V60",
            method: .v60,
            isStarter: true,
            origin: .starterTemplate,
            isValid: true,
            defaultDose: 15.0,
            defaultTargetYield: 250.0,
            defaultWaterTemperature: 94.0,
            defaultGrindLabel: .medium
        ),
        grindTactileDescriptor: "sand; slightly finer than sea salt",
        steps: []
    ))
    .padding()
}

#Preview("Step Row") {
    RecipeStepRow(
        stepNumber: 1,
        step: RecipeStepDTO(
            stepId: UUID(),
            orderIndex: 0,
            instructionText: "Pour 50g water in circular motion to bloom",
            timerDurationSeconds: 30,
            waterAmountGrams: 50,
            isCumulativeWaterTarget: true
        )
    )
    .padding()
}

#Preview("Action Bar") {
    VStack {
        Spacer()
        PrimaryActionBar(isEnabled: true, onUse: {})
        PrimaryActionBar(isEnabled: false, onUse: {})
    }
}
