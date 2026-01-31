//
//  RecipeEditDefaultsSection.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditDefaultsSection: View {
    let draft: RecipeEditDraft
    let fieldErrors: RecipeEditFieldErrors
    let emphasizeYield: Bool
    let isDisabled: Bool
    let onEvent: (RecipeEditEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recipe Defaults")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                RecipeEditNameFieldRow(
                    name: draft.name,
                    error: fieldErrors.name,
                    isDisabled: isDisabled,
                    onChange: { onEvent(.nameChanged($0)) }
                )
                .id(ValidationAnchor.name)
                
                RecipeEditNumericFieldRow(
                    title: "Default Dose",
                    placeholder: "Dose",
                    unit: "g",
                    value: draft.defaultDose,
                    error: fieldErrors.dose,
                    isDisabled: isDisabled,
                    format: .number.precision(.fractionLength(1)),
                    onChange: { onEvent(.doseChanged($0)) }
                )
                .id(ValidationAnchor.dose)
                
                RecipeEditYieldFieldRow(
                    value: draft.defaultTargetYield,
                    error: fieldErrors.yield,
                    emphasize: emphasizeYield,
                    isDisabled: isDisabled,
                    onChange: { onEvent(.yieldChanged($0)) }
                )
                .id(ValidationAnchor.yield)
                
                RecipeEditNumericFieldRow(
                    title: "Water Temperature",
                    placeholder: "Temperature",
                    unit: "°C",
                    value: draft.defaultWaterTemperature,
                    error: fieldErrors.temperature,
                    isDisabled: isDisabled,
                    format: .number.precision(.fractionLength(0)),
                    onChange: { onEvent(.temperatureChanged($0)) }
                )
                .id(ValidationAnchor.temperature)
                
                RecipeEditGrindLabelRow(
                    selection: draft.defaultGrindLabel,
                    isDisabled: isDisabled,
                    onChange: { onEvent(.grindLabelChanged($0)) }
                )
                .id(ValidationAnchor.grind)
                
                RecipeEditTactileDescriptorRow(
                    text: draft.grindTactileDescriptor,
                    isDisabled: isDisabled,
                    onChange: { onEvent(.tactileDescriptorChanged($0)) }
                )
                .id(ValidationAnchor.tactileDescriptor)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(.rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }
}

private struct RecipeEditNameFieldRow: View {
    let name: String
    let error: String?
    let isDisabled: Bool
    let onChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField(
                "Recipe name",
                text: Binding(
                    get: { name },
                    set: { onChange($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .disabled(isDisabled)
            .accessibilityIdentifier("RecipeNameField")
            
            if let error {
                RecipeEditInlineErrorText(message: error)
            }
        }
    }
}

private struct RecipeEditYieldFieldRow: View {
    let value: Double?
    let error: String?
    let emphasize: Bool
    let isDisabled: Bool
    let onChange: (Double?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeEditNumericFieldRow(
                title: "Target Yield",
                placeholder: "Yield",
                unit: "g",
                value: value,
                error: error,
                isDisabled: isDisabled,
                format: .number.precision(.fractionLength(0)),
                onChange: onChange
            )
        }
        .padding(12)
        .background(background)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            if emphasize {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
            }
        }
    }
    
    private var background: some ShapeStyle {
        if emphasize {
            return AnyShapeStyle(Color.red.opacity(0.06))
        }
        return AnyShapeStyle(Color.clear)
    }
}

private struct RecipeEditGrindLabelRow: View {
    let selection: GrindLabel
    let isDisabled: Bool
    let onChange: (GrindLabel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grind Label")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Grind Label", selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )) {
                ForEach(GrindLabel.allCases, id: \.self) { label in
                    Text(label.displayName).tag(label)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isDisabled)
        }
    }
}

private struct RecipeEditTactileDescriptorRow: View {
    let text: String
    let isDisabled: Bool
    let onChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tactile Descriptor (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField(
                "e.g., sand; slightly finer than sea salt",
                text: Binding(
                    get: { text },
                    set: { onChange($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .disabled(isDisabled)
        }
    }
}

