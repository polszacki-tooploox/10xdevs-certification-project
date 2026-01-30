//
//  BrewLogRatingView.swift
//  BrewGuide
//
//  Accessible, scalable star rating display for brew logs.
//

import SwiftUI

/// Displays a 1-5 star rating in an accessible, Dynamic Type-friendly way.
/// Uses filled/empty star system icons with appropriate color styling.
struct BrewLogRatingView: View {
    let rating: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= clampedRating ? "star.fill" : "star")
                    .foregroundStyle(star <= clampedRating ? .yellow : .secondary)
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(clampedRating) out of 5")
    }
    
    /// Clamp rating to 0...5 for defensive rendering
    private var clampedRating: Int {
        max(0, min(5, rating))
    }
}

#Preview("Rating 5") {
    BrewLogRatingView(rating: 5)
}

#Preview("Rating 3") {
    BrewLogRatingView(rating: 3)
}

#Preview("Rating 1") {
    BrewLogRatingView(rating: 1)
}

#Preview("Rating 0 (Invalid)") {
    BrewLogRatingView(rating: 0)
}

#Preview("Rating 6 (Invalid)") {
    BrewLogRatingView(rating: 6)
}
