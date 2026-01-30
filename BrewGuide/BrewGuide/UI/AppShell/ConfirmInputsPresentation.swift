//
//  ConfirmInputsPresentation.swift
//  BrewGuide
//
//  Confirm Inputs modal presentation payload for fullScreenCover.
//

import Foundation

/// Represents an active confirm inputs modal presentation.
/// Used as the item binding for `.fullScreenCover(item:)`.
struct ConfirmInputsPresentation: Identifiable, Hashable {
    let id: UUID
    let recipeId: UUID
    
    init(id: UUID = UUID(), recipeId: UUID) {
        self.id = id
        self.recipeId = recipeId
    }
}
