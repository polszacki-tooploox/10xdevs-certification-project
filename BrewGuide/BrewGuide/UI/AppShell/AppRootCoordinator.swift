//
//  AppRootCoordinator.swift
//  BrewGuide
//
//  Coordinator for app-level navigation and presentation state.
//

import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "AppRootCoordinator")

/// Centralized coordinator for app-level UI state: tab selection, per-tab navigation, and brew modal presentation.
@Observable
@MainActor
final class AppRootCoordinator {
    // MARK: - Tab Selection
    
    var selectedTab: AppTab = .recipes
    
    // MARK: - Navigation Paths
    
    var recipesPath = NavigationPath()
    var logsPath = NavigationPath()
    var settingsPath = NavigationPath()
    
    // MARK: - Modal Presentations
    
    var activeBrewSession: BrewSessionPresentation?
    
    // MARK: - Computed Properties
    
    var isBrewSessionActive: Bool {
        activeBrewSession != nil
    }
    
    // MARK: - Navigation Methods
    
    /// Resets the navigation path for the specified tab to its root.
    func resetToRoot(tab: AppTab) {
        switch tab {
        case .recipes:
            recipesPath = NavigationPath()
        case .logs:
            logsPath = NavigationPath()
        case .settings:
            settingsPath = NavigationPath()
        }
    }
    
    // MARK: - Brew Modal Presentation
    
    /// Presents the brew flow modal with the given plan.
    /// Guards against re-entrancy: if a brew session is already active, logs and ignores the request.
    func presentBrewSession(plan: BrewPlan) {
        guard activeBrewSession == nil else {
            logger.warning("Attempted to present brew session while one is already active. Ignoring.")
            return
        }
        
        guard !plan.scaledSteps.isEmpty else {
            logger.error("Attempted to present brew session with empty steps. Ignoring.")
            return
        }
        
        activeBrewSession = BrewSessionPresentation(plan: plan)
        logger.info("Brew session presented with \(plan.scaledSteps.count) steps.")
    }
    
    /// Dismisses the current brew flow modal.
    func dismissBrewSession() {
        guard activeBrewSession != nil else {
            logger.debug("Attempted to dismiss brew session when none is active.")
            return
        }
        
        activeBrewSession = nil
        logger.info("Brew session dismissed.")
    }
}
