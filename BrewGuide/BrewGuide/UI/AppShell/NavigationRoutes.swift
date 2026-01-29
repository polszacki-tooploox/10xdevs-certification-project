//
//  NavigationRoutes.swift
//  BrewGuide
//
//  Type-safe navigation routes for each tab.
//

import Foundation

/// Navigation routes for the Recipes tab.
enum RecipesRoute: Hashable {
    case recipeList
    case recipeDetail(id: UUID)
    case recipeEdit(id: UUID)
}

/// Navigation routes for the Logs tab.
enum LogsRoute: Hashable {
    case logDetail(id: UUID)
}

/// Navigation routes for the Settings tab.
enum SettingsRoute: Hashable {
    case dataDeletionRequest
}
