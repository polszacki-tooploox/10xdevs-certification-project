//
//  PostBrewView.swift
//  BrewGuide
//
//  Post-brew feedback view for rating and notes.
//

import SwiftUI

/// View displayed after completing a brew session.
/// Allows user to rate the brew, add taste feedback, and notes.
struct PostBrewView: View {
    let plan: BrewPlan
    let onSave: (Int, TasteTag?, String?) async -> Void
    let onDiscard: () -> Void
    
    @State private var rating: Int = 3
    @State private var selectedTasteTag: TasteTag?
    @State private var notes: String = ""
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text("Brew Complete!")
                        .font(.title)
                        .bold()
                    
                    Text(plan.inputs.recipeName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                // Brew summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Brew Summary")
                        .font(.headline)
                    
                    HStack {
                        summaryItem(label: "Dose", value: formatDose(plan.inputs.doseGrams))
                        Spacer()
                        summaryItem(label: "Yield", value: formatYield(plan.inputs.targetYieldGrams))
                        Spacer()
                        summaryItem(label: "Ratio", value: formatRatio(plan.inputs.ratio))
                    }
                }
                .padding()
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 12))
                
                Divider()
                
                // Rating
                VStack(spacing: 16) {
                    Text("How was it?")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundStyle(star <= rating ? .yellow : .gray)
                            }
                        }
                    }
                }
                
                // Taste tags
                VStack(alignment: .leading, spacing: 12) {
                    Text("Taste Feedback (Optional)")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(TasteTag.allCases, id: \.self) { tag in
                            tasteTagButton(tag)
                        }
                    }
                    
                    if let tag = selectedTasteTag {
                        Text(tag.adjustmentHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.top, 4)
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.headline)
                    
                    TextField("Add notes about this brew...", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4...8)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task {
                            isSaving = true
                            await onSave(rating, selectedTasteTag, notes.isEmpty ? nil : notes)
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Save Brew")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving)
                    
                    Button("Discard", role: .destructive) {
                        onDiscard()
                    }
                    .disabled(isSaving)
                }
            }
            .padding()
        }
        .navigationTitle("Feedback")
    }
    
    // MARK: - Subviews
    
    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDose(_ dose: Double) -> String {
        String(format: "%.1fg", dose)
    }
    
    private func formatYield(_ yield: Double) -> String {
        String(format: "%.0fg", yield)
    }
    
    private func formatRatio(_ ratio: Double) -> String {
        String(format: "1:%.1f", ratio)
    }
    
    private func tasteTagButton(_ tag: TasteTag) -> some View {
        Button {
            if selectedTasteTag == tag {
                selectedTasteTag = nil
            } else {
                selectedTasteTag = tag
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tag.iconName)
                    .font(.title3)
                Text(tag.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTasteTag == tag ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTasteTag == tag ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TasteTag Extension

extension TasteTag {
    var iconName: String {
        switch self {
        case .tooBitter:
            return "exclamationmark.triangle"
        case .tooSour:
            return "face.dashed"
        case .tooWeak:
            return "arrow.down.circle"
        case .tooStrong:
            return "arrow.up.circle"
        }
    }
}

#Preview {
    let testInputs = BrewInputs(
        recipeId: UUID(),
        recipeName: "Test Recipe",
        method: .v60,
        doseGrams: 15.0,
        targetYieldGrams: 250.0,
        waterTemperatureCelsius: 93.0,
        grindLabel: .medium,
        lastEdited: .dose
    )
    
    let testStep = ScaledStep(
        stepId: UUID(),
        orderIndex: 0,
        instructionText: "Pour water",
        stepKind: .pour,
        durationSeconds: nil,
        targetElapsedSeconds: 30,
        waterAmountGrams: 50,
        isCumulativeWaterTarget: false
    )
    
    let testPlan = BrewPlan(inputs: testInputs, scaledSteps: [testStep])
    
    NavigationStack {
        PostBrewView(
            plan: testPlan,
            onSave: { _, _, _ in },
            onDiscard: {}
        )
    }
}
