//
//  RecipeListView.swift
//  BrewGuide
//
//  Full recipe list view (navigable from ConfirmInputsView).
//

import SwiftUI
import SwiftData

/// Displays all recipes organized by origin (starter/custom).
/// Allows navigation to recipe detail and editing custom recipes.
struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRootCoordinator.self) private var coordinator
    
    @Query(sort: \Recipe.name) private var allRecipes: [Recipe]
    
    private var starterRecipes: [Recipe] {
        allRecipes.filter { $0.origin == .starterTemplate }
    }
    
    private var customRecipes: [Recipe] {
        allRecipes.filter { $0.origin == .custom }
    }
    
    var body: some View {
        List {
            if !starterRecipes.isEmpty {
                Section("Starter Recipes") {
                    ForEach(starterRecipes) { recipe in
                        RecipeRowView(recipe: recipe)
                    }
                }
            }
            
            if !customRecipes.isEmpty {
                Section("My Recipes") {
                    ForEach(customRecipes) { recipe in
                        RecipeRowView(recipe: recipe)
                    }
                    .onDelete(perform: deleteCustomRecipes)
                }
            }
            
            if allRecipes.isEmpty {
                ContentUnavailableView(
                    "No Recipes",
                    systemImage: "cup.and.saucer",
                    description: Text("Add your first recipe to get started.")
                )
            }
        }
        .navigationTitle("All Recipes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Recipe", systemImage: "plus") {
                    // TODO: Navigate to recipe creation
                }
            }
        }
    }
    
    private func deleteCustomRecipes(at offsets: IndexSet) {
        for index in offsets {
            let recipe = customRecipes[index]
            modelContext.delete(recipe)
        }
    }
}

/// Row view for a single recipe in the list.
private struct RecipeRowView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    let recipe: Recipe
    
    var body: some View {
        Button {
            coordinator.recipesPath.append(RecipesRoute.recipeDetail(id: recipe.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.headline)
                    
                    Text(recipe.method.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Label("\(recipe.defaultDose, format: .number.precision(.fractionLength(1)))g", systemImage: "scalemass")
                        Label("\(recipe.defaultTargetYield, format: .number.precision(.fractionLength(0)))g", systemImage: "drop")
                        Label("1:\(recipe.defaultRatio, format: .number.precision(.fractionLength(1)))", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                if recipe.origin == .custom {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                        .imageScale(.large)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RecipeListView()
    }
    .environment(AppRootCoordinator())
    .modelContainer(PersistenceController.preview.container)
}
