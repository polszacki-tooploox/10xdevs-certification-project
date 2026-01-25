//
//  ContentView.swift
//  BrewGuide
//
//  Created by Przemysław Olszacki on 24/01/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \BrewLog.timestamp, order: .reverse) private var recentLogs: [BrewLog]

    var body: some View {
        NavigationSplitView {
            List {
                Section("Recipes") {
                    ForEach(recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                    .font(.headline)
                                Text("\(recipe.defaultDose, format: .number.precision(.fractionLength(1)))g → \(recipe.defaultTargetYield, format: .number.precision(.fractionLength(0)))g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Recent Brews") {
                    ForEach(recentLogs.prefix(5)) { log in
                        NavigationLink {
                            BrewLogDetailView(log: log)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(log.recipeNameAtBrew)
                                    .font(.headline)
                                HStack {
                                    Text(log.timestamp, format: .dateTime)
                                        .font(.caption)
                                    Spacer()
                                    Text(String(repeating: "⭐️", count: log.rating))
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("BrewGuide")
        } detail: {
            Text("Select a recipe or brew log")
        }
    }
}

// MARK: - Placeholder Detail Views

struct RecipeDetailView: View {
    let recipe: Recipe
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Method", value: recipe.method.displayName)
                LabeledContent("Dose") {
                    Text("\(recipe.defaultDose, format: .number.precision(.fractionLength(1)))g")
                }
                LabeledContent("Yield") {
                    Text("\(recipe.defaultTargetYield, format: .number.precision(.fractionLength(0)))g")
                }
                LabeledContent("Ratio") {
                    Text("1:\(recipe.defaultRatio, format: .number.precision(.fractionLength(1)))")
                }
                LabeledContent("Temperature") {
                    Text("\(recipe.defaultWaterTemperature, format: .number.precision(.fractionLength(0)))°C")
                }
                LabeledContent("Grind", value: recipe.defaultGrindLabel.displayName)
                if let descriptor = recipe.grindTactileDescriptor {
                    LabeledContent("Grind Feel", value: descriptor)
                }
            }
            
            if let steps = recipe.steps?.sorted(by: { $0.orderIndex < $1.orderIndex }), !steps.isEmpty {
                Section("Steps") {
                    ForEach(steps, id: \.stepId) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step \(step.orderIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(step.instructionText)
                            if let duration = step.timerDurationSeconds {
                                Text("⏱ \(Int(duration))s")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            if let water = step.waterAmountGrams {
                                Text("💧 \(Int(water))g")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(recipe.name)
    }
}

struct BrewLogDetailView: View {
    let log: BrewLog
    
    var body: some View {
        List {
            Section("Brew Details") {
                LabeledContent("Date", value: log.timestamp, format: .dateTime)
                LabeledContent("Recipe", value: log.recipeNameAtBrew)
                LabeledContent("Method", value: log.method.displayName)
            }
            
            Section("Parameters") {
                LabeledContent("Dose") {
                    Text("\(log.doseGrams, format: .number.precision(.fractionLength(1)))g")
                }
                LabeledContent("Yield") {
                    Text("\(log.targetYieldGrams, format: .number.precision(.fractionLength(0)))g")
                }
                LabeledContent("Ratio") {
                    Text("1:\(log.ratio, format: .number.precision(.fractionLength(1)))")
                }
                LabeledContent("Temperature") {
                    Text("\(log.waterTemperatureCelsius, format: .number.precision(.fractionLength(0)))°C")
                }
                LabeledContent("Grind", value: log.grindLabel.displayName)
            }
            
            Section("Feedback") {
                LabeledContent("Rating", value: String(repeating: "⭐️", count: log.rating))
                if let tasteTag = log.tasteTag {
                    LabeledContent("Taste", value: tasteTag.displayName)
                    Text(tasteTag.adjustmentHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                if let note = log.note, !note.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note)
                    }
                }
            }
        }
        .navigationTitle("Brew Log")
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview.container)
}
