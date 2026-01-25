# Domain DTOs

This directory contains Data Transfer Objects (DTOs) for the BrewGuide application. DTOs serve as the contract between the UI layer and the persistence layer, decoupling SwiftUI views from SwiftData models.

## Architecture Overview

```
UI Layer (SwiftUI Views)
       ↕ DTOs
Domain Layer (Use Cases & Business Logic)
       ↕ DTOs
Persistence Layer (SwiftData Models)
```

## Files

### RecipeDTOs.swift
Contains DTOs and command models for recipe management:
- `RecipeSummaryDTO` - Lightweight recipe representation for list views
- `RecipeDetailDTO` - Full recipe with steps for detail views
- `RecipeStepDTO` - Individual recipe step
- `CreateRecipeRequest` - Command for creating new recipes
- `UpdateRecipeRequest` - Command for updating existing recipes
- `RecipeValidationError` - Typed validation errors
- `RecipeNotBrewableError` - Error when recipe cannot be used for brewing

### BrewLogDTOs.swift
Contains DTOs and command models for brew log management:
- `BrewLogSummaryDTO` - Lightweight log entry for list views
- `BrewLogDetailDTO` - Full log entry with all parameters
- `CreateBrewLogRequest` - Command for saving brew outcomes
- `BrewLogValidationError` - Typed validation errors

### BrewSessionDTOs.swift
Contains DTOs for the brew execution state machine:
- `BrewInputs` - Editable brew parameters (Confirm Inputs screen)
- `ScaledStep` - A recipe step with scaled water amounts
- `BrewPlan` - Complete brew plan ready for execution
- `BrewSessionState` - Current state of active brew session with phase tracking

### ScalingDTOs.swift
Contains DTOs for brew parameter scaling logic:
- `ScaleInputsRequest` - Request for scaling brew inputs
- `ScaleInputsResponse` - Scaled parameters with warnings
- `InputWarning` - Non-blocking warnings about out-of-range values
- `V60RecommendedRanges` - V60 brewing parameter ranges (MVP)

### MappingExtensions.swift
Contains bidirectional mapping extensions between SwiftData entities and DTOs:
- **Entity → DTO**: `Recipe.toSummaryDTO()`, `BrewLog.toDetailDTO()`, etc.
- **DTO → Entity**: `Recipe(from: CreateRecipeRequest)`, `BrewLog(from: CreateBrewLogRequest)`, etc.
- **Domain conversions**: `Recipe.toBrewInputs()`, `RecipeStepDTO.toScaledStep()`, etc.

## Key Design Principles

### 1. Decoupling
DTOs decouple the UI from SwiftData models, allowing:
- UI to evolve independently of persistence schema
- Testing without SwiftData/Core Data stack
- Clear API boundaries for use cases

### 2. Validation at Boundary
Command models (e.g., `CreateRecipeRequest`) include validation logic that executes before persistence:
```swift
let request = CreateRecipeRequest(...)
let errors = request.validate()
if errors.isEmpty {
    // Proceed with save
}
```

### 3. Immutability Where Possible
Most DTOs are `struct` types with `let` properties, making them:
- Thread-safe by default
- Easier to reason about
- Suitable for SwiftUI's value-based architecture

### 4. Typed Errors
Validation errors are strongly typed enums with localized descriptions:
```swift
enum RecipeValidationError: Error {
    case emptyName
    case invalidDose
    case waterTotalMismatch(expected: Double, actual: Double)
    // ...
}
```

### 5. CloudKit Compatibility
DTOs mirror the snapshot strategy used in SwiftData models:
- `BrewLog` stores brew-time parameters as snapshots
- Recipe duplication during conflicts creates new IDs
- All relationships are optional

## Usage Examples

### Creating a Recipe
```swift
let request = CreateRecipeRequest(
    method: .v60,
    name: "Morning Brew",
    defaultDose: 15.0,
    defaultTargetYield: 250.0,
    defaultWaterTemperature: 94.0,
    defaultGrindLabel: .medium,
    grindTactileDescriptor: "Like fine sand",
    steps: [...]
)

let errors = request.validate()
guard errors.isEmpty else {
    // Show validation errors to user
    return
}

let recipe = Recipe(from: request)
// Save via repository
```

### Mapping Entity to DTO
```swift
let recipe: Recipe = ... // from SwiftData
let dto = recipe.toDetailDTO(isValid: true)

// Use DTO in SwiftUI view
RecipeDetailView(recipe: dto)
```

### Saving a Brew Log
```swift
let request = CreateBrewLogRequest(
    method: .v60,
    recipeId: recipe.id,
    recipeNameAtBrew: recipe.name,
    doseGrams: 15.0,
    targetYieldGrams: 250.0,
    waterTemperatureCelsius: 94.0,
    grindLabel: .medium,
    rating: 4,
    tasteTag: .tooSour,
    note: "Slightly bright, might try hotter next time"
)

let errors = request.validate()
guard errors.isEmpty else {
    // Show validation errors
    return
}

let brewLog = BrewLog(from: request, recipe: recipe)
// Save via repository
```

### Brew Session Flow
```swift
// 1. Create inputs from recipe
let inputs = recipe.toBrewInputs()

// 2. User edits on Confirm Inputs screen
var editedInputs = inputs
editedInputs.doseGrams = 18.0
editedInputs.lastEdited = .dose

// 3. Create scaling request
let scaleRequest = ScaleInputsRequest(
    method: .v60,
    recipeDefaultDose: recipe.defaultDose,
    recipeDefaultTargetYield: recipe.defaultTargetYield,
    userDose: editedInputs.doseGrams,
    userTargetYield: editedInputs.targetYieldGrams,
    lastEdited: editedInputs.lastEdited
)

// 4. Scale inputs (via use case)
let scaleResponse = scaleInputs(request: scaleRequest)

// 5. Create brew plan with scaled steps
let plan = BrewPlan(
    inputs: editedInputs,
    scaledSteps: scaledSteps
)

// 6. Start brew session
var sessionState = BrewSessionState(
    plan: plan,
    phase: .notStarted,
    currentStepIndex: 0,
    remainingTime: nil,
    startedAt: nil,
    isInputsLocked: true
)

// 7. Execute brew (via state machine)
sessionState.phase = .active
sessionState.startedAt = Date()
```

## Testing

DTOs are easily testable without SwiftData:

```swift
@Test func validateRecipeRequest() throws {
    let request = CreateRecipeRequest(
        method: .v60,
        name: "",  // Invalid
        defaultDose: -5.0,  // Invalid
        defaultTargetYield: 250.0,
        defaultWaterTemperature: 94.0,
        defaultGrindLabel: .medium,
        grindTactileDescriptor: nil,
        steps: []  // Invalid
    )
    
    let errors = request.validate()
    
    #expect(errors.contains(.emptyName))
    #expect(errors.contains(.invalidDose))
    #expect(errors.contains(.noSteps))
}
```

## See Also

- [API Plan](../../../../.ai/api-plan.md) - Complete API specification
- [Database Documentation](../../../../PRD/database_documentation.md) - SwiftData model reference
- [Persistence README](../../Persistence/README.md) - Repository patterns
