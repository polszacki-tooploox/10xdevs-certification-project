# ConfirmInputsView API Reference

## Public API Surface

### 1. Coordinator Methods

#### Present Confirm Inputs Modal
```swift
coordinator.presentConfirmInputs(recipeId: UUID)
```
**Description**: Presents the confirm inputs modal for the specified recipe.

**Usage**:
```swift
// From RecipeListView
Button("Brew", action: {
    coordinator.presentConfirmInputs(recipeId: recipe.id)
})

// From RecipeDetailView
Button("Brew this recipe", action: {
    coordinator.presentConfirmInputs(recipeId: recipeId)
})
```

**Guards**: 
- Prevents re-entrancy if modal already active
- Logs warning if attempted while active

---

#### Dismiss Confirm Inputs Modal
```swift
coordinator.dismissConfirmInputs()
```
**Description**: Dismisses the confirm inputs modal.

**Usage**: Typically called automatically by the view on dismissal or when starting a brew.

---

### 2. ScalingService

#### Scale Inputs
```swift
func scaleInputs(
    request: ScaleInputsRequest,
    temperatureCelsius: Double
) -> ScaleInputsResponse
```

**Request Parameters**:
- `method: BrewMethod` - Brew method (V60)
- `recipeDefaultDose: Double` - Recipe's default dose
- `recipeDefaultTargetYield: Double` - Recipe's default yield
- `userDose: Double` - User's current dose value
- `userTargetYield: Double` - User's current yield value
- `lastEdited: BrewInputs.LastEditedField` - Which field was last edited (.dose or .yield)
- `temperatureCelsius: Double` - Water temperature for warnings

**Response Fields**:
- `scaledDose: Double` - Scaled dose rounded to 0.1g
- `scaledTargetYield: Double` - Scaled yield rounded to 1g
- `scaledWaterTargets: [Double]` - V60 water targets (bloom, pour 2, pour 3)
- `derivedRatio: Double` - Computed ratio (yield / dose)
- `warnings: [InputWarning]` - Non-blocking warnings

**Example**:
```swift
let request = ScaleInputsRequest(
    method: .v60,
    recipeDefaultDose: 15.0,
    recipeDefaultTargetYield: 250.0,
    userDose: 20.0,
    userTargetYield: 333.3,
    lastEdited: .dose
)

let response = scalingService.scaleInputs(
    request: request,
    temperatureCelsius: 94.0
)

// response.scaledDose = 20.0
// response.scaledTargetYield = 333.0 (rounded)
// response.derivedRatio = 16.65
// response.scaledWaterTargets = [60, 197, 333]
// response.warnings = [.ratioTooHigh(...)]
```

**Scaling Logic**:
- If `lastEdited == .dose`: `yield = dose × recipeRatio`
- If `lastEdited == .yield`: `dose = yield / recipeRatio`

**Rounding Rules**:
- Dose: rounded to nearest 0.1g
- Yield/Water: rounded to nearest 1g

**V60 Water Targets**:
- Bloom: `3 × dose`
- Second pour: `50% of remaining`
- Third pour: adjusted to match `targetYield` exactly

---

### 3. View State Types

#### ConfirmInputsViewState
```swift
struct ConfirmInputsViewState {
    let isLoading: Bool
    let recipeName: String
    let method: BrewMethod
    let isRecipeBrewable: Bool
    let brewabilityMessage: String?
    
    let doseGrams: Double
    let targetYieldGrams: Double
    let waterTemperatureCelsius: Double
    let grindLabel: GrindLabel
    let grindTactileDescriptor: String?
    
    let ratio: Double
    let warnings: [InputWarning]
    
    let isStartingBrew: Bool
    let canStartBrew: Bool
    let canEdit: Bool
}
```

---

#### ConfirmInputsEvent
```swift
enum ConfirmInputsEvent {
    case changeRecipeTapped
    case doseChanged(Double)
    case yieldChanged(Double)
    case temperatureChanged(Double)
    case grindChanged(GrindLabel)
    case resetTapped
    case startBrewTapped
}
```

---

#### InputWarning
```swift
enum InputWarning: Codable, Equatable {
    case doseTooLow(dose: Double, minRecommended: Double)
    case doseTooHigh(dose: Double, maxRecommended: Double)
    case yieldTooLow(yield: Double, minRecommended: Double)
    case yieldTooHigh(yield: Double, maxRecommended: Double)
    case ratioTooLow(ratio: Double, minRecommended: Double)
    case ratioTooHigh(ratio: Double, maxRecommended: Double)
    case temperatureTooLow(temp: Double, minRecommended: Double)
    case temperatureTooHigh(temp: Double, maxRecommended: Double)
    
    var message: String { /* ... */ }
}
```

---

### 4. V60 Recommended Ranges

```swift
struct V60RecommendedRanges {
    static let doseRange: ClosedRange<Double> = 12.0...40.0
    static let yieldRange: ClosedRange<Double> = 180.0...720.0
    static let ratioRange: ClosedRange<Double> = 14.0...18.0
    static let temperatureRange: ClosedRange<Double> = 90.0...96.0
    
    static func warnings(
        dose: Double,
        yield: Double,
        temperature: Double
    ) -> [InputWarning]
}
```

---

## Component Usage Examples

### Using ConfirmInputsFlowView

```swift
// In AppRootView.swift
.fullScreenCover(item: $coordinator.activeConfirmInputs) { presentation in
    ConfirmInputsFlowView(presentation: presentation)
        .environment(coordinator)
}
```

### Using Individual Components

#### SelectedRecipeHeader
```swift
SelectedRecipeHeader(
    recipeName: "Hoffman V60",
    methodName: "V60",
    isEnabled: true,
    onChangeRecipe: {
        // Navigate to recipe picker
    }
)
```

#### InputsCard
```swift
InputsCard(
    state: viewState,
    onEvent: { event in
        viewModel.handleEvent(event)
    }
)
```

#### WarningsSection
```swift
WarningsSection(warnings: [
    .doseTooHigh(dose: 45.0, maxRecommended: 40.0),
    .ratioTooLow(ratio: 12.5, minRecommended: 14.0)
])
```

#### BottomActionBar
```swift
BottomActionBar(
    isStartEnabled: true,
    isBusy: false,
    brewabilityMessage: nil,
    onStart: {
        Task {
            await viewModel.startBrew(coordinator: coordinator)
        }
    },
    onReset: {
        viewModel.handleEvent(.resetTapped)
    }
)
```

---

## Integration Patterns

### Pattern 1: Present from Recipe List

```swift
// RecipeListView
RecipeListRow(
    recipe: recipe,
    onTap: { /* navigate to detail */ },
    onBrew: {
        coordinator.presentConfirmInputs(recipeId: recipe.id)
    },
    onRequestDelete: { /* ... */ }
)
```

### Pattern 2: Present from Recipe Detail

```swift
// RecipeDetailView
Button("Brew this recipe") {
    coordinator.presentConfirmInputs(recipeId: recipeId)
}
```

### Pattern 3: Handle Recipe Selection in Modal

```swift
// ConfirmInputsView
private func handleEvent(_ event: ConfirmInputsEvent) {
    switch event {
    case .changeRecipeTapped:
        // Navigate to recipe list within modal's NavigationStack
        coordinator.recipesPath.append(RecipesRoute.recipeList)
        
    case .startBrewTapped:
        Task {
            await viewModel.startBrew(coordinator: coordinator)
            if !viewModel.ui.showsError {
                dismiss()
            }
        }
        
    default:
        viewModel.handleEvent(event)
    }
}
```

### Pattern 4: Selection Change Detection

```swift
// ConfirmInputsView
.onAppear {
    viewModel.refreshIfSelectionChanged(context: modelContext)
}

// ConfirmInputsViewModel
func refreshIfSelectionChanged(context: ModelContext) {
    let currentSelection = preferences.lastSelectedRecipeId
    
    guard let currentSelection, 
          currentSelection != lastLoadedRecipeId else {
        return
    }
    
    Task {
        await loadRecipe(recipeId: currentSelection, context: context)
    }
}
```

---

## Error Handling Patterns

### Loading Errors
```swift
if let errorState = viewModel.errorState {
    ContentUnavailableView {
        Label("Error Loading Recipe", systemImage: "exclamationmark.triangle")
    } description: {
        Text(errorState.message)
    } actions: {
        Button("Retry") {
            Task {
                await viewModel.load()
            }
        }
    }
}
```

### Start Brew Errors
```swift
.alert("Error", isPresented: Binding(
    get: { viewModel.ui.showsError },
    set: { if !$0 { viewModel.ui.errorMessage = nil } }
)) {
    Button("OK") {
        viewModel.ui.errorMessage = nil
    }
} message: {
    if let error = viewModel.ui.errorMessage {
        Text(error)
    }
}
```

### Validation Errors
```swift
BottomActionBar(
    isStartEnabled: viewState.canStartBrew,
    isBusy: viewState.isStartingBrew,
    brewabilityMessage: viewState.isRecipeBrewable 
        ? nil 
        : viewState.brewabilityMessage,
    onStart: { /* ... */ },
    onReset: { /* ... */ }
)
```

---

## Testing Utilities

### Mock View State
```swift
let mockState = ConfirmInputsViewState(
    isLoading: false,
    recipeName: "Test Recipe",
    method: .v60,
    isRecipeBrewable: true,
    brewabilityMessage: nil,
    doseGrams: 15.0,
    targetYieldGrams: 250.0,
    waterTemperatureCelsius: 94.0,
    grindLabel: .medium,
    grindTactileDescriptor: "Like table salt",
    ratio: 16.7,
    warnings: [],
    isStartingBrew: false,
    canStartBrew: true,
    canEdit: true
)
```

### Mock Scaling Service
```swift
class MockScalingService: ScalingService {
    var mockResponse: ScaleInputsResponse?
    
    override func scaleInputs(
        request: ScaleInputsRequest,
        temperatureCelsius: Double
    ) -> ScaleInputsResponse {
        mockResponse ?? super.scaleInputs(
            request: request,
            temperatureCelsius: temperatureCelsius
        )
    }
}
```

---

## Performance Considerations

### Scaling Computation
- **Cost**: O(1) - simple arithmetic operations
- **Frequency**: On every dose/yield/temperature change
- **Optimization**: Already optimized; no caching needed

### Warnings Generation
- **Cost**: O(1) - 8 range checks
- **Frequency**: On every scaling recomputation
- **Optimization**: Already optimized; no caching needed

### Recipe Loading
- **Cost**: O(n) where n = number of recipes (for fallback)
- **Frequency**: On view appear and selection change
- **Optimization**: Uses indexed fetch when recipe ID known

---

## Accessibility Labels

### Dose Input
```swift
.accessibilityLabel("Coffee dose in grams")
.accessibilityValue("\(doseGrams, format: .number.precision(.fractionLength(1))) grams")
```

### Warnings
```swift
.accessibilityLabel("Warning")
.accessibilityValue(warning.message)
```

### Action Buttons
```swift
Button("Start Brewing") { /* ... */ }
    .accessibilityLabel("Start brewing coffee")
    .accessibilityHint("Creates brew plan and begins guided session")
```

---

## Common Pitfalls

### ❌ Don't: Mutate inputs directly
```swift
// Bad
viewModel.inputsDraft?.doseGrams = 20.0
```

### ✅ Do: Use event handlers
```swift
// Good
viewModel.handleEvent(.doseChanged(20.0))
```

---

### ❌ Don't: Present modal twice
```swift
// Bad - no guard
func presentConfirmInputs(recipeId: UUID) {
    activeConfirmInputs = ConfirmInputsPresentation(recipeId: recipeId)
}
```

### ✅ Do: Guard against re-entrancy
```swift
// Good - with guard
func presentConfirmInputs(recipeId: UUID) {
    guard activeConfirmInputs == nil else {
        logger.warning("Modal already active")
        return
    }
    activeConfirmInputs = ConfirmInputsPresentation(recipeId: recipeId)
}
```

---

### ❌ Don't: Forget to dismiss before presenting brew
```swift
// Bad - overlapping modals
coordinator.presentBrewSession(plan: plan)
// ConfirmInputs modal still open!
```

### ✅ Do: Dismiss first, then present
```swift
// Good - dismiss then present
await viewModel.startBrew(coordinator: coordinator)
if !viewModel.ui.showsError {
    dismiss() // Dismisses ConfirmInputs
    // Coordinator presents BrewSession
}
```
