//
//  ConfirmInputsComponents.swift
//  BrewGuide
//
//  Reusable components for the Confirm Inputs screen.
//

import SwiftUI

// MARK: - Selected Recipe Header

struct SelectedRecipeHeader: View {
    let recipeName: String
    let methodName: String
    let isEnabled: Bool
    let onChangeRecipe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipeName)
                        .font(.title2)
                        .bold()
                    
                    Text(methodName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Change", systemImage: "list.bullet", action: onChangeRecipe)
                    .disabled(!isEnabled)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Input Row Components

struct DoseInputRow: View {
    let value: Double
    let isEditable: Bool
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coffee Dose")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField(
                    "Dose",
                    value: Binding(
                        get: { value },
                        set: { onChange($0) }
                    ),
                    format: .number.precision(.fractionLength(1))
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditable)
                
                Text("g")
                    .foregroundStyle(.secondary)
            }
            
            Text("Precision: 0.1g")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct YieldInputRow: View {
    let value: Double
    let isEditable: Bool
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Yield")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField(
                    "Yield",
                    value: Binding(
                        get: { value },
                        set: { onChange($0) }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditable)
                
                Text("g")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WaterTemperatureInputRow: View {
    let value: Double
    let isEditable: Bool
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Water Temperature")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField(
                    "Temperature",
                    value: Binding(
                        get: { value },
                        set: { onChange($0) }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditable)
                
                Text("°C")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GrindLabelSelectorRow: View {
    let selection: GrindLabel
    let isEditable: Bool
    let onChange: (GrindLabel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grind Size")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Grind Size", selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )) {
                ForEach(GrindLabel.allCases, id: \.self) { grind in
                    Text(grind.displayName).tag(grind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!isEditable)
        }
    }
}

struct GrindDescriptorLine: View {
    let descriptor: String?
    
    var body: some View {
        if let descriptor {
            Text(descriptor)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}

struct RatioRow: View {
    let ratio: Double
    
    var body: some View {
        LabeledContent("Brew Ratio") {
            Text(formatRatio(ratio))
                .font(.headline)
        }
    }
    
    private func formatRatio(_ ratio: Double) -> String {
        let formatted = ratio.formatted(.number.precision(.fractionLength(1)))
        return "1:\(formatted)"
    }
}

// MARK: - Warnings Section

struct WarningsSection: View {
    let warnings: [InputWarning]
    
    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommendations")
                    .font(.headline)
                
                ForEach(warnings.indices, id: \.self) { index in
                    WarningRow(warning: warnings[index])
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct WarningRow: View {
    let warning: InputWarning
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .imageScale(.small)
            
            Text(warning.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Bottom Action Bar

struct BottomActionBar: View {
    let isStartEnabled: Bool
    let isBusy: Bool
    let brewabilityMessage: String?
    let onStart: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if let message = brewabilityMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onStart) {
                HStack {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Start Brewing")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isStartEnabled || isBusy)
            .padding(.horizontal)
            
            Button("Reset to Defaults", action: onReset)
                .font(.subheadline)
                .disabled(isBusy)
        }
        .padding(.vertical)
        .background(.regularMaterial)
    }
}

// MARK: - Inputs Card

struct InputsCard: View {
    let state: ConfirmInputsViewState
    let onEvent: (ConfirmInputsEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DoseInputRow(
                value: state.doseGrams,
                isEditable: state.canEdit,
                onChange: { onEvent(.doseChanged($0)) }
            )
            
            Divider()
            
            YieldInputRow(
                value: state.targetYieldGrams,
                isEditable: state.canEdit,
                onChange: { onEvent(.yieldChanged($0)) }
            )
            
            Divider()
            
            RatioRow(ratio: state.ratio)
            
            Divider()
            
            WaterTemperatureInputRow(
                value: state.waterTemperatureCelsius,
                isEditable: state.canEdit,
                onChange: { onEvent(.temperatureChanged($0)) }
            )
            
            Divider()
            
            GrindLabelSelectorRow(
                selection: state.grindLabel,
                isEditable: state.canEdit,
                onChange: { onEvent(.grindChanged($0)) }
            )
            
            GrindDescriptorLine(descriptor: state.grindTactileDescriptor)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal)
    }
}
