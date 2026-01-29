//
//  RecipeListRow.swift
//  BrewGuide
//
//  Row component for recipe list with large tap targets and swipe actions.
//

import SwiftUI

/// Row view for a single recipe in the list
/// Provides large tap targets, badges, compact defaults, and swipe actions
struct RecipeListRow: View {
    let recipe: RecipeSummaryDTO
    let onTap: () -> Void
    let onUse: () -> Void
    let onRequestDelete: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                // Badges
                if shouldShowBadges {
                    RecipeBadgePillRow(
                        isStarter: recipe.isStarter,
                        isValid: recipe.isValid,
                        origin: recipe.origin
                    )
                }
                
                // Compact defaults
                RecipeDefaultsInline(
                    dose: recipe.defaultDose,
                    yield: recipe.defaultTargetYield,
                    temperature: recipe.defaultWaterTemperature,
                    grindLabel: recipe.defaultGrindLabel,
                    showRatio: false
                )
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double tap to view recipe details")
        .swipeActions(edge: .leading) {
            Button {
                onUse()
            } label: {
                Label("Use", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
            .accessibilityLabel("Use this recipe for brewing")
        }
        .swipeActions(edge: .trailing) {
            if let onRequestDelete = onRequestDelete {
                Button(role: .destructive) {
                    onRequestDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityLabel("Delete this recipe")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowBadges: Bool {
        recipe.isStarter || !recipe.isValid || recipe.origin == .conflictedCopy
    }
    
    private var accessibilityLabelText: String {
        var components: [String] = [recipe.name]
        
        if recipe.isStarter {
            components.append("Starter recipe")
        }
        
        if !recipe.isValid {
            components.append("Invalid recipe")
        }
        
        components.append("Dose: \(recipe.defaultDose.formatted(.number.precision(.fractionLength(1)))) grams")
        components.append("Yield: \(recipe.defaultTargetYield.formatted(.number.precision(.fractionLength(0)))) grams")
        components.append("Temperature: \(recipe.defaultWaterTemperature.formatted(.number.precision(.fractionLength(0)))) degrees Celsius")
        components.append("Grind: \(recipe.defaultGrindLabel.displayName)")
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Recipe List Rows") {
    List {
        Section("Starter") {
            RecipeListRow(
                recipe: RecipeSummaryDTO(
                    id: UUID(),
                    name: "Balanced V60",
                    method: .v60,
                    isStarter: true,
                    origin: .starterTemplate,
                    isValid: true,
                    defaultDose: 15.0,
                    defaultTargetYield: 250.0,
                    defaultWaterTemperature: 94.0,
                    defaultGrindLabel: .medium
                ),
                onTap: {},
                onUse: {},
                onRequestDelete: nil
            )
        }
        
        Section("Custom") {
            RecipeListRow(
                recipe: RecipeSummaryDTO(
                    id: UUID(),
                    name: "My Custom Recipe",
                    method: .v60,
                    isStarter: false,
                    origin: .custom,
                    isValid: true,
                    defaultDose: 18.0,
                    defaultTargetYield: 300.0,
                    defaultWaterTemperature: 92.0,
                    defaultGrindLabel: .fine
                ),
                onTap: {},
                onUse: {},
                onRequestDelete: {}
            )
            
            RecipeListRow(
                recipe: RecipeSummaryDTO(
                    id: UUID(),
                    name: "Invalid Recipe",
                    method: .v60,
                    isStarter: false,
                    origin: .custom,
                    isValid: false,
                    defaultDose: 15.0,
                    defaultTargetYield: 250.0,
                    defaultWaterTemperature: 94.0,
                    defaultGrindLabel: .medium
                ),
                onTap: {},
                onUse: {},
                onRequestDelete: {}
            )
        }
    }
}
