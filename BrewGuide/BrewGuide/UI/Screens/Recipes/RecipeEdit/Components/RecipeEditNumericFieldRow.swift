//
//  RecipeEditNumericFieldRow.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditNumericFieldRow: View {
    let title: String
    let placeholder: String
    let unit: String
    let value: Double?
    let error: String?
    let isDisabled: Bool
    let format: FloatingPointFormatStyle<Double>
    let onChange: (Double?) -> Void
    
    @State private var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDisabled)
                    .accessibilityLabel(title)
                
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            
            if let error {
                RecipeEditInlineErrorText(message: error)
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
        return value.formatted(format)
    }
}

