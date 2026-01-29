//
//  AppRootView.swift
//  BrewGuide
//
//  Top-level app shell with persistent tab navigation and centralized brew modal presentation.
//

import SwiftUI
import SwiftData

/// Top-level app shell providing:
/// - Three persistent tabs (Recipes / Logs / Settings) with independent navigation stacks
/// - Centralized brew flow modal presentation
struct AppRootView: View {
    @State private var coordinator = AppRootCoordinator()
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Brew", systemImage: "cup.and.saucer.fill", value: .recipes) {
                RecipesTabRootView()
            }
            
            Tab("Logs", systemImage: "book.fill", value: .logs) {
                LogsTabRootView()
            }
            
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsTabRootView()
            }
        }
        .environment(coordinator)
        .fullScreenCover(item: $coordinator.activeBrewSession) { presentation in
            BrewSessionFlowView(presentation: presentation)
                .environment(coordinator)
        }
    }
}

// MARK: - Tab Root Views

/// Wrapper for the Recipes tab navigation stack.
private struct RecipesTabRootView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.recipesPath) {
            ConfirmInputsView()
                .navigationDestination(for: RecipesRoute.self) { route in
                    switch route {
                    case .recipeList:
                        RecipeListView()
                    case .recipeDetail(let id):
                        RecipeDetailNavigationView(recipeId: id)
                    case .recipeEdit(let id):
                        RecipeEditView(recipeId: id)
                    }
                }
        }
    }
}

/// Wrapper for the Logs tab navigation stack.
private struct LogsTabRootView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.logsPath) {
            LogsListView()
                .navigationDestination(for: LogsRoute.self) { route in
                    switch route {
                    case .logDetail(let id):
                        LogDetailNavigationView(logId: id)
                    }
                }
        }
    }
}

/// Wrapper for the Settings tab navigation stack.
private struct SettingsTabRootView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.settingsPath) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .dataDeletionRequest:
                        DataDeletionRequestView()
                    }
                }
        }
    }
}

// MARK: - Placeholder Navigation Destination Views

/// Navigation wrapper for recipe detail that fetches the recipe by ID.
private struct RecipeDetailNavigationView: View {
    let recipeId: UUID
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if let recipe = fetchRecipe() {
            RecipeDetailView(recipe: recipe)
        } else {
            ContentUnavailableView(
                "Recipe Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("This recipe may have been deleted.")
            )
        }
    }
    
    private func fetchRecipe() -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == recipeId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

/// Navigation wrapper for log detail that fetches the log by ID.
private struct LogDetailNavigationView: View {
    let logId: UUID
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if let log = fetchLog() {
            BrewLogDetailView(log: log)
        } else {
            ContentUnavailableView(
                "Log Not Found",
                systemImage: "exclamationmark.triangle",
                description: Text("This log may have been deleted.")
            )
        }
    }
    
    private func fetchLog() -> BrewLog? {
        let descriptor = FetchDescriptor<BrewLog>(
            predicate: #Predicate { $0.id == logId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

/// Placeholder view for recipe editing (to be implemented).
private struct RecipeEditView: View {
    let recipeId: UUID
    
    var body: some View {
        VStack {
            Text("Edit Recipe")
                .font(.title)
            Text("Recipe ID: \(recipeId.uuidString)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("TODO: Implement recipe edit view")
                .foregroundStyle(.tertiary)
        }
        .navigationTitle("Edit Recipe")
    }
}

// MARK: - Preview

#Preview {
    AppRootView()
        .modelContainer(PersistenceController.preview.container)
}
