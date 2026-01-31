//
//  RecipeEditActionBar.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditActionBar: View {
    let isSaving: Bool
    let canSave: Bool
    let isDirty: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if !canSave, isDirty, !isSaving {
                Text("Fix issues above to enable Save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .disabled(isSaving)
                    .accessibilityIdentifier("RecipeEditCancelButton")
                
                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Save")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .accessibilityIdentifier("RecipeEditSaveButton")
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.regularMaterial)
    }
}

