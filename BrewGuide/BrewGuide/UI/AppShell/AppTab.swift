//
//  AppTab.swift
//  BrewGuide
//
//  App-level tab navigation type.
//

import Foundation

/// Represents the three main tabs in the app.
enum AppTab: Hashable, Codable {
    case recipes
    case logs
    case settings
}
