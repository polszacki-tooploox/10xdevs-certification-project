//
//  BrewSessionPresentation.swift
//  BrewGuide
//
//  Brew modal presentation payload for fullScreenCover.
//

import Foundation

/// Represents an active brew modal presentation.
/// Used as the item binding for `.fullScreenCover(item:)`.
struct BrewSessionPresentation: Identifiable, Hashable {
    let id: UUID
    let plan: BrewPlan
    
    init(id: UUID = UUID(), plan: BrewPlan) {
        self.id = id
        self.plan = plan
    }
}
