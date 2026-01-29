//
//  RecipeDefaultsInline.swift
//  BrewGuide
//
//  Compact inline display of recipe defaults (dose, yield, temp, grind).
//

import SwiftUI

/// Displays recipe default parameters in a compact row
struct RecipeDefaultsInline: View {
    let dose: Double
    let yield: Double
    let temperature: Double
    let grindLabel: GrindLabel
    let showRatio: Bool
    
    init(
        dose: Double,
        yield: Double,
        temperature: Double,
        grindLabel: GrindLabel,
        showRatio: Bool = false
    ) {
        self.dose = dose
        self.yield = yield
        self.temperature = temperature
        self.grindLabel = grindLabel
        self.showRatio = showRatio
    }
    
    private var ratio: Double {
        guard dose > 0 else { return 0 }
        return yield / dose
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Label(doseText, systemImage: "scalemass")
            Label(yieldText, systemImage: "drop")
            Label(temperatureText, systemImage: "thermometer")
            Label(grindLabel.displayName, systemImage: "circle.grid.cross")
            
            if showRatio {
                Label(ratioText, systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    // MARK: - Formatted Text
    
    private var doseText: String {
        dose.formatted(.number.precision(.fractionLength(1))) + "g"
    }
    
    private var yieldText: String {
        yield.formatted(.number.precision(.fractionLength(0))) + "g"
    }
    
    private var temperatureText: String {
        temperature.formatted(.number.precision(.fractionLength(0))) + "°C"
    }
    
    private var ratioText: String {
        "1:" + ratio.formatted(.number.precision(.fractionLength(1)))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        RecipeDefaultsInline(
            dose: 15.0,
            yield: 250.0,
            temperature: 94.0,
            grindLabel: .medium,
            showRatio: false
        )
        
        RecipeDefaultsInline(
            dose: 18.5,
            yield: 300.0,
            temperature: 92.0,
            grindLabel: .fine,
            showRatio: true
        )
    }
    .padding()
}
