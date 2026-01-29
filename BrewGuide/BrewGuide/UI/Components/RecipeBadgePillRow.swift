//
//  RecipeBadgePillRow.swift
//  BrewGuide
//
//  Visual badges for recipe status indicators (Starter, Invalid, Conflicted Copy).
//

import SwiftUI

/// Displays badge pills for recipe status indicators
struct RecipeBadgePillRow: View {
    let isStarter: Bool
    let isValid: Bool
    let origin: RecipeOrigin
    
    var body: some View {
        HStack(spacing: 6) {
            if isStarter || origin == .starterTemplate {
                Badge(text: "Starter", color: .blue)
            }
            
            if !isValid {
                Badge(text: "Invalid", color: .red)
            }
            
            if origin == .conflictedCopy {
                Badge(text: "Conflicted Copy", color: .orange)
            }
        }
    }
}

// MARK: - Badge Component

private struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

// MARK: - Preview

#Preview("Various Badges") {
    VStack(spacing: 12) {
        RecipeBadgePillRow(isStarter: true, isValid: true, origin: .starterTemplate)
        RecipeBadgePillRow(isStarter: false, isValid: false, origin: .custom)
        RecipeBadgePillRow(isStarter: false, isValid: true, origin: .conflictedCopy)
        RecipeBadgePillRow(isStarter: true, isValid: false, origin: .starterTemplate)
    }
    .padding()
}
