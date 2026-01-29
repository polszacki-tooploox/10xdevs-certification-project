//
//  ConfirmInputsView.swift
//  BrewGuide
//
//  Recipes tab root: confirms brew inputs before starting a session.
//

import SwiftUI
import SwiftData

/// Root view for the Recipes tab.
/// Allows user to confirm/modify brew inputs before starting a brew session.
struct ConfirmInputsView: View {
    @Environment(AppRootCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: ConfirmInputsViewModel
    
    init() {
        _viewModel = State(initialValue: ConfirmInputsViewModel())
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading recipe...")
            } else if let inputs = viewModel.currentInputs {
                inputsFormView(inputs: inputs)
            } else {
                noRecipeSelectedView
            }
        }
        .navigationTitle("Brew")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Recipes", systemImage: "list.bullet") {
                    coordinator.recipesPath.append(RecipesRoute.recipeList)
                }
            }
        }
        .task {
            await viewModel.loadInitialRecipe(context: modelContext)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func inputsFormView(inputs: BrewInputs) -> some View {
        Form {
            Section {
                HStack {
                    Text(inputs.recipeName)
                        .font(.title2)
                        .bold()
                    Spacer()
                    Text(inputs.method.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Brew Parameters") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coffee Dose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Dose", value: Binding(
                            get: { viewModel.currentInputs?.doseGrams ?? 0 },
                            set: { viewModel.updateDose($0) }
                        ), format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("g")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Yield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Yield", value: Binding(
                            get: { viewModel.currentInputs?.targetYieldGrams ?? 0 },
                            set: { viewModel.updateYield($0) }
                        ), format: .number.precision(.fractionLength(0)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("g")
                    }
                }
                
                LabeledContent("Ratio") {
                    Text(formatRatio(inputs.ratio))
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Water Temperature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Temperature", value: Binding(
                            get: { viewModel.currentInputs?.waterTemperatureCelsius ?? 0 },
                            set: { viewModel.updateTemperature($0) }
                        ), format: .number.precision(.fractionLength(0)))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("°C")
                    }
                }
                
                Picker("Grind Size", selection: Binding(
                    get: { viewModel.currentInputs?.grindLabel ?? .medium },
                    set: { viewModel.updateGrind($0) }
                )) {
                    ForEach(GrindLabel.allCases, id: \.self) { grind in
                        Text(grind.displayName).tag(grind)
                    }
                }
            }
            
            Section {
                Button {
                    Task {
                        await viewModel.startBrew(
                            context: modelContext,
                            coordinator: coordinator
                        )
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isStartingBrew {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Start Brewing")
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isStartingBrew || !viewModel.areInputsValid)
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
    }
    
    private var noRecipeSelectedView: some View {
        ContentUnavailableView(
            "No Recipe Selected",
            systemImage: "cup.and.saucer",
            description: Text("Tap 'Recipes' to choose a recipe to brew.")
        )
    }
    
    // MARK: - Helpers
    
    private func formatRatio(_ ratio: Double) -> String {
        String(format: "1:%.1f", ratio)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class ConfirmInputsViewModel {
    var currentInputs: BrewInputs?
    var isLoading = false
    var isStartingBrew = false
    var errorMessage: String?
    
    var showError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }
    
    var areInputsValid: Bool {
        guard let inputs = currentInputs else { return false }
        return inputs.doseGrams > 0 && inputs.targetYieldGrams > 0 && inputs.waterTemperatureCelsius > 0
    }
    
    // MARK: - Load Initial Recipe
    
    func loadInitialRecipe(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        
        // Try to load last selected recipe, or fall back to first recipe
        let recipeId = PreferencesStore.shared.lastSelectedRecipeId
        
        let descriptor = FetchDescriptor<Recipe>(
            predicate: recipeId.map { id in #Predicate<Recipe> { $0.id == id } },
            sortBy: [SortDescriptor(\Recipe.name)]
        )
        
        guard let recipe = try? context.fetch(descriptor).first else {
            // No recipe found, try to get any recipe
            let anyDescriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\Recipe.name)])
            guard let anyRecipe = try? context.fetch(anyDescriptor).first else {
                return
            }
            loadInputs(from: anyRecipe)
            return
        }
        
        loadInputs(from: recipe)
    }
    
    func loadInputs(from recipe: Recipe) {
        currentInputs = BrewInputs(
            recipeId: recipe.id,
            recipeName: recipe.name,
            method: recipe.method,
            doseGrams: recipe.defaultDose,
            targetYieldGrams: recipe.defaultTargetYield,
            waterTemperatureCelsius: recipe.defaultWaterTemperature,
            grindLabel: recipe.defaultGrindLabel,
            lastEdited: .yield
        )
        
        // Save as last selected
        PreferencesStore.shared.lastSelectedRecipeId = recipe.id
    }
    
    // MARK: - Update Input Methods
    
    func updateDose(_ dose: Double) {
        guard var inputs = currentInputs else { return }
        inputs.lastEdited = .dose
        inputs.doseGrams = dose
        
        // Maintain ratio: update yield based on dose
        let ratio = inputs.ratio
        inputs.targetYieldGrams = inputs.doseGrams * ratio
        
        currentInputs = inputs
    }
    
    func updateYield(_ yield: Double) {
        guard var inputs = currentInputs else { return }
        inputs.lastEdited = .yield
        inputs.targetYieldGrams = yield
        currentInputs = inputs
    }
    
    func updateTemperature(_ temperature: Double) {
        guard var inputs = currentInputs else { return }
        inputs.waterTemperatureCelsius = temperature
        currentInputs = inputs
    }
    
    func updateGrind(_ grind: GrindLabel) {
        guard var inputs = currentInputs else { return }
        inputs.grindLabel = grind
        currentInputs = inputs
    }
    
    // MARK: - Start Brew
    
    func startBrew(context: ModelContext, coordinator: AppRootCoordinator) async {
        guard let inputs = currentInputs, areInputsValid else {
            errorMessage = "Invalid brew parameters"
            return
        }
        
        isStartingBrew = true
        defer { isStartingBrew = false }
        
        do {
            let repository = RecipeRepository(context: context)
            let useCase = BrewSessionUseCase(recipeRepository: repository)
            
            let plan = try await useCase.createPlan(from: inputs)
            
            // Save selection
            PreferencesStore.shared.lastSelectedRecipeId = inputs.recipeId
            
            // Present brew modal
            coordinator.presentBrewSession(plan: plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ConfirmInputsView()
    }
    .environment(AppRootCoordinator())
    .modelContainer(PersistenceController.preview.container)
}
