//
//  TasteTagPill.swift
//  BrewGuide
//
//  Compact taste tag indicator pill for brew log rows.
//

import SwiftUI

/// Compact pill-style display for a taste tag.
/// Shows the tag name in a small, rounded badge.
struct TasteTagPill: View {
    let tasteTag: TasteTag
    
    var body: some View {
        Text(tasteTag.displayName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tertiary)
            .foregroundStyle(.secondary)
            .clipShape(.rect(cornerRadius: 8))
    }
}

#Preview("Too Bitter") {
    TasteTagPill(tasteTag: .tooBitter)
}

#Preview("Too Sour") {
    TasteTagPill(tasteTag: .tooSour)
}

#Preview("Too Weak") {
    TasteTagPill(tasteTag: .tooWeak)
}

#Preview("Too Strong") {
    TasteTagPill(tasteTag: .tooStrong)
}

#Preview("In Context") {
    HStack {
        Text("Ethiopian Light Roast")
            .font(.headline)
        Spacer()
        TasteTagPill(tasteTag: .tooSour)
    }
    .padding()
}
