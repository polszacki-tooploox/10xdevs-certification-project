# DTO Type Index

Quick reference for all DTO types in the BrewGuide application.

## Type Count Summary

- **Structs (DTOs):** 12
- **Structs (Command Models):** 3
- **Structs (Domain Services):** 1
- **Enums (Validation Errors):** 2
- **Enums (Warnings):** 1
- **Extensions:** 7
- **Total Types:** 26

---

## DTOs (Data Transfer Objects)

### Recipe DTOs
1. **RecipeSummaryDTO** - Lightweight recipe for lists
2. **RecipeDetailDTO** - Full recipe with steps
3. **RecipeStepDTO** - Individual recipe step

### BrewLog DTOs
4. **BrewLogSummaryDTO** - Lightweight log for lists
5. **BrewLogDetailDTO** - Full log with parameters

### Brew Session DTOs
6. **BrewInputs** - Editable brew parameters
7. **ScaledStep** - Step with scaled water
8. **BrewPlan** - Complete plan ready for execution
9. **BrewSessionState** - Active session state machine

### Scaling DTOs
10. **ScaleInputsRequest** - Scaling request payload
11. **ScaleInputsResponse** - Scaling response with warnings
12. **ScaledStep** - Step with scaled water amounts

---

## Command Models (CQRS Pattern)

### Recipe Commands
1. **CreateRecipeRequest** - Create new custom recipe
2. **UpdateRecipeRequest** - Update existing recipe

### BrewLog Commands
3. **CreateBrewLogRequest** - Save brew outcome

---

## Domain Services

1. **V60RecommendedRanges** - V60 parameter ranges & warnings

---

## Validation & Error Types

### Recipe Errors
1. **RecipeValidationError** (enum)
   - Cases: emptyName, invalidDose, invalidYield, noSteps, negativeTimer, negativeWaterAmount, waterTotalMismatch, starterCannotBeModified, starterCannotBeDeleted

2. **RecipeNotBrewableError** (struct)
   - Contains: recipeId, validationErrors[]

### BrewLog Errors
3. **BrewLogValidationError** (enum)
   - Cases: invalidRating, emptyRecipeName, invalidDose, invalidYield, noteTooLong

### Input Warnings
4. **InputWarning** (enum)
   - Cases: doseTooLow, doseTooHigh, yieldTooLow, yieldTooHigh, ratioTooLow, ratioTooHigh, temperatureTooLow, temperatureTooHigh

---

## Mapping Extensions

### Recipe → DTO
- `extension Recipe`
  - `toSummaryDTO(isValid:) -> RecipeSummaryDTO`
  - `toDetailDTO(isValid:) -> RecipeDetailDTO`
  - `toBrewInputs() -> BrewInputs`

### RecipeStep → DTO
- `extension RecipeStep`
  - `toDTO() -> RecipeStepDTO`

### BrewLog → DTO
- `extension BrewLog`
  - `toSummaryDTO() -> BrewLogSummaryDTO`
  - `toDetailDTO() -> BrewLogDetailDTO`

### DTO → Recipe
- `extension Recipe`
  - `init(from: CreateRecipeRequest)`
  - `update(from: UpdateRecipeRequest)`

### DTO → RecipeStep
- `extension RecipeStep`
  - `init(from: RecipeStepDTO, recipe: Recipe?)`

### DTO → BrewLog
- `extension BrewLog`
  - `init(from: CreateBrewLogRequest, recipe: Recipe?)`

### DTO → ScaledStep
- `extension RecipeStepDTO`
  - `toScaledStep(scaledWaterAmount:) -> ScaledStep`

---

## File Organization

```
Domain/DTOs/
├── RecipeDTOs.swift             (222 lines)
│   ├── RecipeSummaryDTO
│   ├── RecipeDetailDTO
│   ├── RecipeStepDTO
│   ├── CreateRecipeRequest
│   ├── UpdateRecipeRequest
│   ├── RecipeValidationError
│   └── RecipeNotBrewableError
│
├── BrewLogDTOs.swift            (143 lines)
│   ├── BrewLogSummaryDTO
│   ├── BrewLogDetailDTO
│   ├── CreateBrewLogRequest
│   └── BrewLogValidationError
│
├── BrewSessionDTOs.swift        (98 lines)
│   ├── BrewInputs
│   ├── ScaledStep
│   ├── BrewPlan
│   └── BrewSessionState
│
├── ScalingDTOs.swift            (135 lines)
│   ├── ScaleInputsRequest
│   ├── ScaleInputsResponse
│   ├── InputWarning
│   └── V60RecommendedRanges
│
├── MappingExtensions.swift      (187 lines)
│   ├── Recipe extensions
│   ├── RecipeStep extensions
│   ├── BrewLog extensions
│   └── RecipeStepDTO extensions
│
├── README.md                    (Documentation)
└── DTO_IMPLEMENTATION_SUMMARY.md (Comprehensive guide)
```

---

## Usage Quick Reference

### Creating a Recipe
```swift
let request = CreateRecipeRequest(
    method: .v60,
    name: "Morning Brew",
    defaultDose: 15.0,
    defaultTargetYield: 250.0,
    defaultWaterTemperature: 94.0,
    defaultGrindLabel: .medium,
    grindTactileDescriptor: nil,
    steps: [...]
)

let errors = request.validate()
if errors.isEmpty {
    let recipe = Recipe(from: request)
    // Save via repository
}
```

### Displaying Recipe in List
```swift
let recipe: Recipe = ... // from SwiftData
let dto = recipe.toSummaryDTO(isValid: true)

List(recipeDTOs) { dto in
    RecipeRow(recipe: dto)
}
```

### Starting a Brew Session
```swift
let inputs = recipe.toBrewInputs()
// User edits inputs...

let plan = createBrewPlan(inputs: inputs, recipe: recipe)
var state = BrewSessionState(
    plan: plan,
    phase: .notStarted,
    currentStepIndex: 0,
    remainingTime: nil,
    startedAt: nil,
    isInputsLocked: true
)
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
    note: "Nice but bright"
)

let errors = request.validate()
if errors.isEmpty {
    let log = BrewLog(from: request, recipe: recipe)
    // Save via repository
}
```

---

## Conformances Summary

### Protocol Conformances
- **Codable**: All DTOs (for serialization)
- **Hashable**: All DTOs (for SwiftUI diffing)
- **Identifiable**: DTOs used in lists (RecipeSummaryDTO, RecipeDetailDTO, RecipeStepDTO, BrewLogSummaryDTO, BrewLogDetailDTO, ScaledStep)
- **Error**: Validation error enums (RecipeValidationError, BrewLogValidationError, RecipeNotBrewableError)
- **Equatable**: Error enums (for testing)

### Computed Properties
- **defaultRatio** (RecipeSummaryDTO) - yield / dose
- **ratio** (BrewLogDetailDTO) - yield / dose
- **ratio** (BrewInputs) - yield / dose
- **totalWaterGrams** (BrewPlan) - from steps
- **currentStep** (BrewSessionState) - active step
- **isLastStep** (BrewSessionState) - boolean
- **progress** (BrewSessionState) - 0.0 to 1.0
- **recipeRatio** (ScaleInputsRequest) - recipeYield / recipeDose
- **computedRatio** (ScaleInputsResponse) - scaledYield / scaledDose

---

## Testing Hooks

All DTOs are pure Swift types (no SwiftData dependency), making them testable:

```swift
// Validation testing
let request = CreateRecipeRequest(/* invalid data */)
let errors = request.validate()
#expect(errors.contains(.emptyName))

// Mapping testing
let recipe = Recipe(/* test data */)
let dto = recipe.toSummaryDTO()
#expect(dto.id == recipe.id)

// Computed property testing
let inputs = BrewInputs(/* 15g dose, 250g yield */)
#expect(inputs.ratio ≈ 16.67)

// State machine testing
var state = BrewSessionState(/* initial state */)
state.phase = .active
#expect(state.currentStep != nil)
```

---

## Type Dependencies

```
SwiftData Models (Persistence Layer)
  ↓
DTOs (Domain Layer)
  ↓
View Models (UI Layer)
  ↓
SwiftUI Views
```

### Entity Dependencies
- RecipeSummaryDTO ← Recipe
- RecipeDetailDTO ← Recipe + RecipeStep[]
- RecipeStepDTO ← RecipeStep
- BrewLogSummaryDTO ← BrewLog
- BrewLogDetailDTO ← BrewLog
- BrewInputs ← Recipe (initial values)
- ScaledStep ← RecipeStepDTO (transformed)
- BrewPlan ← BrewInputs + ScaledStep[]

### Enum Dependencies (all standalone)
- BrewMethod (persistence enum)
- GrindLabel (persistence enum)
- RecipeOrigin (persistence enum)
- TasteTag (persistence enum)

---

## Statistics

- **Total Lines of Code:** 785 lines
- **Average Lines per File:** 157 lines
- **Documentation Files:** 2 (README.md, DTO_IMPLEMENTATION_SUMMARY.md)
- **Code Coverage:** 100% of API plan DTOs implemented
- **Validation Rules:** 14 blocking + 8 non-blocking warnings
- **Mapping Methods:** 10 entity→DTO + 6 DTO→entity

---

## Maintenance Notes

1. **Adding New DTOs:**
   - Add to appropriate file based on domain area
   - Implement Codable, Hashable, and Identifiable as needed
   - Add mapping extensions in MappingExtensions.swift
   - Update this index

2. **Adding Validation Rules:**
   - Add to validation error enum
   - Implement in command model's validate() method
   - Add localized description case
   - Update tests

3. **Modifying Existing DTOs:**
   - Ensure Codable compatibility if persisted
   - Update mapping extensions
   - Check computed properties
   - Update tests

4. **Version Compatibility:**
   - DTOs are Codable for future serialization
   - Use default values for backward compatibility
   - Optional properties for nullable fields
   - Enums with raw values for stable coding keys
