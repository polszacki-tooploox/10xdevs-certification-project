//
//  RecipeEditStepEditorCard.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditStepEditorCard: View {
    let step: RecipeStepDraft
    let stepNumber: Int
    let validationErrors: [RecipeValidationError]
    let inlineErrors: [RecipeEditInlineError]
    let isWaterMismatchOffender: Bool
    let isDisabled: Bool
    let onEvent: (RecipeEditEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Step \(stepNumber)")
                    .font(.headline)
                
                Spacer()
                
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onEvent(.deleteStep(step.id))
                }
                .disabled(isDisabled)
            }
            
            RecipeEditStepInstructionField(
                text: step.instructionText,
                isDisabled: isDisabled,
                onChange: { onEvent(.stepInstructionChanged(stepId: step.id, text: $0)) }
            )
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Timer",
                    isOn: Binding(
                        get: { step.timerDurationSeconds != nil },
                        set: { onEvent(.stepTimerEnabledChanged(stepId: step.id, isEnabled: $0)) }
                    )
                )
                .disabled(isDisabled)
                
                if step.timerDurationSeconds != nil {
                    RecipeEditInlineNumberField(
                        title: "Duration (seconds)",
                        placeholder: "Seconds",
                        unit: "s",
                        value: step.timerDurationSeconds,
                        isDisabled: isDisabled,
                        onChange: { onEvent(.stepTimerChanged(stepId: step.id, seconds: $0)) }
                    )
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Water",
                    isOn: Binding(
                        get: { step.waterAmountGrams != nil },
                        set: { onEvent(.stepWaterEnabledChanged(stepId: step.id, isEnabled: $0)) }
                    )
                )
                .disabled(isDisabled)
                
                if step.waterAmountGrams != nil {
                    RecipeEditInlineNumberField(
                        title: "Amount",
                        placeholder: "Grams",
                        unit: "g",
                        value: step.waterAmountGrams,
                        isDisabled: isDisabled,
                        onChange: { onEvent(.stepWaterChanged(stepId: step.id, grams: $0)) }
                    )
                    
                    Picker("Water mode", selection: Binding(
                        get: { step.isCumulativeWaterTarget },
                        set: { onEvent(.stepCumulativeChanged(stepId: step.id, isCumulative: $0)) }
                    )) {
                        Text("Pour to").tag(true)
                        Text("Add").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDisabled)
                }
            }
            
            RecipeEditStepErrorsBlock(
                inlineErrors: inlineErrors,
                validationErrors: validationErrors,
                isWaterMismatchOffender: isWaterMismatchOffender
            )
        }
        .padding()
        .background(background)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            if isWaterMismatchOffender {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }
    
    private var background: some ShapeStyle {
        if isWaterMismatchOffender {
            return AnyShapeStyle(Color.red.opacity(0.05))
        }
        return AnyShapeStyle(Color(.systemBackground))
    }
}

private struct RecipeEditStepInstructionField: View {
    let text: String
    let isDisabled: Bool
    let onChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instruction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField(
                "e.g., Bloom and stir gently",
                text: Binding(
                    get: { text },
                    set: { onChange($0) }
                ),
                axis: .vertical
            )
            .lineLimit(2...6)
            .textFieldStyle(.roundedBorder)
            .disabled(isDisabled)
        }
    }
}

private struct RecipeEditStepErrorsBlock: View {
    let inlineErrors: [RecipeEditInlineError]
    let validationErrors: [RecipeValidationError]
    let isWaterMismatchOffender: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(inlineErrors) { error in
                RecipeEditInlineErrorText(message: error.message)
            }
            
            ForEach(validationErrors.indices, id: \.self) { index in
                RecipeEditInlineErrorText(message: validationErrors[index].localizedDescription)
            }
            
            if isWaterMismatchOffender {
                RecipeEditInlineErrorText(message: "This step defines the final water target. It must match the yield.")
            }
        }
        .padding(.top, (inlineErrors.isEmpty && validationErrors.isEmpty && !isWaterMismatchOffender) ? 0 : 4)
    }
}

private struct RecipeEditInlineNumberField: View {
    let title: String
    let placeholder: String
    let unit: String
    let value: Double?
    let isDisabled: Bool
    let onChange: (Double?) -> Void
    
    @State private var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDisabled)
                
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            text = formattedText(value)
        }
        .onChange(of: value) { _, newValue in
            let newText = formattedText(newValue)
            if text != newText {
                text = newText
            }
        }
        .onChange(of: text) { _, newText in
            onChange(parseDouble(newText))
        }
    }
    
    private func parseDouble(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacing(",", with: "."))
    }
    
    private func formattedText(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

