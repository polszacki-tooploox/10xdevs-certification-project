//
//  RecipeEditValidationSummaryBanner.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditValidationSummaryBanner: View {
    let issueCount: Int
    let isVisible: Bool
    let isWaterMismatch: Bool
    let onJumpToFirstIssue: () -> Void
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fix \(issueCount) issue\(issueCount == 1 ? "" : "s") to save")
                    .font(.subheadline)
                    .bold()
                
                if isWaterMismatch {
                    Text("Water total must match yield (±1g).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button("Jump to first issue", systemImage: "arrow.down", action: onJumpToFirstIssue)
                    .font(.subheadline)
                    .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    private var background: some ShapeStyle {
        if isWaterMismatch {
            return AnyShapeStyle(Color.red.opacity(0.08))
        }
        return AnyShapeStyle(Color.orange.opacity(0.10))
    }
}

