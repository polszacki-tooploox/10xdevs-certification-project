//
//  RecipeEditStepsEditorSection.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditStepsEditorSection: View {
    let steps: [RecipeStepDraft]
    let stepErrors: [UUID: [RecipeValidationError]]
    let stepInlineErrors: [UUID: [RecipeEditInlineError]]
    let waterMismatchOffendingStepIds: Set<UUID>
    let isDisabled: Bool
    let onEvent: (RecipeEditEvent) -> Void
    
    var body: some View {
        ForEach(steps) { step in
            RecipeEditStepEditorCard(
                step: step,
                stepNumber: step.orderIndex + 1,
                validationErrors: stepErrors[step.id] ?? [],
                inlineErrors: stepInlineErrors[step.id] ?? [],
                isWaterMismatchOffender: waterMismatchOffendingStepIds.contains(step.id),
                isDisabled: isDisabled,
                onEvent: onEvent
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id(ValidationAnchor.step(id: step.id))
        }
        .onMove { from, to in
            onEvent(.moveSteps(from: from, to: to))
        }
    }
}

