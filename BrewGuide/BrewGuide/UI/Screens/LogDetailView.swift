//
//  LogDetailView.swift
//  BrewGuide
//
//  View for displaying the full details of a completed brew log.
//  Provides actions: delete (with confirmation), optional "View recipe".
//

import SwiftUI
import SwiftData

/// Displays the full details of a completed brew log, allowing deletion and optional recipe navigation.
/// Conforms to PRD US-022 (view log detail) and US-023 (delete log with confirmation).
struct LogDetailView: View {
    let log: BrewLog
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRootCoordinator.self) private var coordinator
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            // Brew Details Section
            Section("Brew Details") {
                LabeledContent("Date", value: log.timestamp, format: .dateTime)
                LabeledContent("Recipe", value: log.recipeNameAtBrew)
                LabeledContent("Method", value: log.method.displayName)
            }
            
            // Parameters Section
            Section("Parameters") {
                LabeledContent("Dose") {
                    Text(log.doseGrams, format: .number.precision(.fractionLength(1)))
                        + Text(" g")
                }
                
                LabeledContent("Yield") {
                    Text(log.targetYieldGrams, format: .number.precision(.fractionLength(0)))
                        + Text(" g")
                }
                
                LabeledContent("Ratio") {
                    Text("1:")
                        + Text(log.ratio, format: .number.precision(.fractionLength(1)))
                }
                
                LabeledContent("Temperature") {
                    Text(log.waterTemperatureCelsius, format: .number.precision(.fractionLength(0)))
                        + Text(" °C")
                }
                
                LabeledContent("Grind", value: log.grindLabel.displayName)
            }
            
            // Feedback Section
            Section("Feedback") {
                LabeledContent("Rating") {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= log.rating ? "star.fill" : "star")
                                .foregroundStyle(star <= log.rating ? .yellow : .secondary)
                                .font(.caption)
                        }
                    }
                }
                
                if let tasteTag = log.tasteTag {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Taste", value: tasteTag.displayName)
                        
                        Text(tasteTag.adjustmentHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if let note = log.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note)
                    }
                }
            }
            
            // Actions Section
            Section {
                if log.recipe != nil {
                    Button {
                        navigateToRecipe()
                    } label: {
                        Label("View Recipe", systemImage: "cup.and.saucer")
                    }
                }
                
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Log", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Brew Log")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this brew log?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    /// Navigates to the recipe detail if the recipe still exists.
    private func navigateToRecipe() {
        guard let recipe = log.recipe else { return }
        
        // Switch to recipes tab and navigate to the recipe detail
        coordinator.selectedTab = .recipes
        coordinator.recipesPath.append(RecipesRoute.recipeDetail(id: recipe.id))
    }
    
    /// Deletes the log and dismisses the view.
    private func deleteLog() {
        modelContext.delete(log)
        
        // Attempt to save the deletion; log errors but don't block dismissal
        do {
            try modelContext.save()
        } catch {
            // In a production app, this error should be communicated to the user
            // For MVP, we log and proceed with dismissal
            print("Error deleting log: \(error)")
        }
        
        dismiss()
    }
}

// MARK: - Preview

#Preview("With Recipe") {
    NavigationStack {
        LogDetailView(log: BrewLog(
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "V60 Starter",
            doseGrams: 15.0,
            targetYieldGrams: 250.0,
            waterTemperatureCelsius: 94.0,
            grindLabel: .medium,
            rating: 4,
            tasteTag: .tooSour,
            note: "Great brew! Used Ethiopian beans from local roaster.",
            recipe: Recipe(
                id: UUID(),
                isStarter: true,
                origin: .starterTemplate,
                method: .v60,
                name: "V60 Starter",
                defaultDose: 15.0,
                defaultTargetYield: 250.0,
                defaultWaterTemperature: 94.0,
                defaultGrindLabel: .medium,
                grindTactileDescriptor: "Like sand; slightly finer than sea salt"
            )
        ))
    }
    .modelContainer(PersistenceController.preview.container)
    .environment(AppRootCoordinator())
}

#Preview("Without Recipe & Note") {
    NavigationStack {
        LogDetailView(log: BrewLog(
            timestamp: Date().addingTimeInterval(-86400),
            method: .v60,
            recipeNameAtBrew: "My Custom Recipe (Deleted)",
            doseGrams: 18.0,
            targetYieldGrams: 300.0,
            waterTemperatureCelsius: 92.0,
            grindLabel: .fine,
            rating: 3,
            tasteTag: nil,
            note: nil,
            recipe: nil
        ))
    }
    .modelContainer(PersistenceController.preview.container)
    .environment(AppRootCoordinator())
}
