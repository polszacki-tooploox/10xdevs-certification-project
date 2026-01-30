//
//  RecipeEditInlineErrorText.swift
//  BrewGuide
//

import SwiftUI

struct RecipeEditInlineErrorText: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .imageScale(.small)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(message)
    }
}

