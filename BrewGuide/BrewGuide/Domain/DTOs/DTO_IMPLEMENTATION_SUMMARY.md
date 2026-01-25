# DTO Implementation Summary

This document provides a comprehensive overview of all Data Transfer Objects (DTOs) implemented for the BrewGuide application, showing their connection to SwiftData models and their role in the API plan.

## Overview

All DTOs defined in the API plan have been implemented and organized into 5 files:
1. `RecipeDTOs.swift` - Recipe-related DTOs and command models
2. `BrewLogDTOs.swift` - Brew log DTOs and command models
3. `BrewSessionDTOs.swift` - Brew session state machine DTOs
4. `ScalingDTOs.swift` - Brew parameter scaling DTOs
5. `MappingExtensions.swift` - Bidirectional entity-DTO mappings

---

## DTO Catalog

### 1. Recipe DTOs

#### RecipeSummaryDTO
**Purpose:** Lightweight recipe representation for list views  
**Source Entity:** `Recipe` (SwiftData model)  
**Fields:**
- `id: UUID` ← `Recipe.id`
- `name: String` ← `Recipe.name`
- `method: BrewMethod` ← `Recipe.method`
- `isStarter: Bool` ← `Recipe.isStarter`
- `origin: RecipeOrigin` ← `Recipe.origin`
- `isValid: Bool` (computed via validation)
- `defaultDose: Double` ← `Recipe.defaultDose`
- `defaultTargetYield: Double` ← `Recipe.defaultTargetYield`
- `defaultWaterTemperature: Double` ← `Recipe.defaultWaterTemperature`
- `defaultGrindLabel: GrindLabel` ← `Recipe.defaultGrindLabel`

**Computed Properties:**
- `defaultRatio: Double` = yield / dose

**API Plan Reference:** Section 2.2.1 (List recipes response)

---

#### RecipeDetailDTO
**Purpose:** Full recipe with all steps for detail views  
**Source Entities:** `Recipe` + `RecipeStep[]` (SwiftData models)  
**Fields:**
- `recipe: RecipeSummaryDTO` (composition)
- `grindTactileDescriptor: String?` ← `Recipe.grindTactileDescriptor`
- `steps: [RecipeStepDTO]` ← `Recipe.steps` (sorted by orderIndex)

**API Plan Reference:** Section 2.2.2 (Get recipe detail response)

---

#### RecipeStepDTO
**Purpose:** Single recipe step representation  
**Source Entity:** `RecipeStep` (SwiftData model)  
**Fields:**
- `stepId: UUID` ← `RecipeStep.stepId`
- `orderIndex: Int` ← `RecipeStep.orderIndex`
- `instructionText: String` ← `RecipeStep.instructionText`
- `timerDurationSeconds: Double?` ← `RecipeStep.timerDurationSeconds`
- `waterAmountGrams: Double?` ← `RecipeStep.waterAmountGrams`
- `isCumulativeWaterTarget: Bool` ← `RecipeStep.isCumulativeWaterTarget`

**API Plan Reference:** Section 2.2 Common payload shapes

---

### 2. Recipe Command Models

#### CreateRecipeRequest
**Purpose:** Command for creating new custom recipes  
**Target Entity:** `Recipe` (creates new SwiftData model)  
**Fields:**
- `method: BrewMethod` → `Recipe.method`
- `name: String` → `Recipe.name`
- `defaultDose: Double` → `Recipe.defaultDose`
- `defaultTargetYield: Double` → `Recipe.defaultTargetYield`
- `defaultWaterTemperature: Double` → `Recipe.defaultWaterTemperature`
- `defaultGrindLabel: GrindLabel` → `Recipe.defaultGrindLabel`
- `grindTactileDescriptor: String?` → `Recipe.grindTactileDescriptor`
- `steps: [RecipeStepDTO]` → `Recipe.steps` (creates new RecipeStep[])

**Validation:** Built-in `validate()` method returns `[RecipeValidationError]`
- Empty name check
- Positive dose/yield check
- Non-empty steps check
- Non-negative timer/water amounts
- Water totals match yield (±1g tolerance)

**API Plan Reference:** Section 2.2.3 (Create custom recipe)

---

#### UpdateRecipeRequest
**Purpose:** Command for updating existing custom recipes  
**Target Entity:** `Recipe` (updates existing SwiftData model)  
**Fields:**
- `id: UUID` (identifies target Recipe)
- `name: String` → `Recipe.name`
- `defaultDose: Double` → `Recipe.defaultDose`
- `defaultTargetYield: Double` → `Recipe.defaultTargetYield`
- `defaultWaterTemperature: Double` → `Recipe.defaultWaterTemperature`
- `defaultGrindLabel: GrindLabel` → `Recipe.defaultGrindLabel`
- `grindTactileDescriptor: String?` → `Recipe.grindTactileDescriptor`
- `steps: [RecipeStepDTO]` → `Recipe.steps` (full replacement)

**Validation:** Built-in `validate()` method (same rules as CreateRecipeRequest)

**Business Rules:**
- Cannot update starter recipes (must duplicate first)
- Updates `Recipe.modifiedAt` timestamp

**API Plan Reference:** Section 2.2.4 (Update custom recipe)

---

### 3. Recipe Validation & Errors

#### RecipeValidationError
**Purpose:** Typed validation errors for recipe operations  
**Cases:**
- `emptyName`
- `invalidDose` (≤ 0)
- `invalidYield` (≤ 0)
- `noSteps`
- `negativeTimer(stepIndex: Int)`
- `negativeWaterAmount(stepIndex: Int)`
- `waterTotalMismatch(expected: Double, actual: Double)`
- `starterCannotBeModified`
- `starterCannotBeDeleted`

**API Plan Reference:** Section 3.1 (Recipe validation)

---

#### RecipeNotBrewableError
**Purpose:** Error when recipe cannot be used for brewing  
**Fields:**
- `recipeId: UUID`
- `validationErrors: [RecipeValidationError]`

**API Plan Reference:** Section 2.2 (Prevent brewing with invalid recipe)

---

### 4. BrewLog DTOs

#### BrewLogSummaryDTO
**Purpose:** Lightweight log entry for list views  
**Source Entity:** `BrewLog` (SwiftData model)  
**Fields:**
- `id: UUID` ← `BrewLog.id`
- `timestamp: Date` ← `BrewLog.timestamp`
- `method: BrewMethod` ← `BrewLog.method`
- `recipeNameAtBrew: String` ← `BrewLog.recipeNameAtBrew`
- `rating: Int` ← `BrewLog.rating`
- `tasteTag: TasteTag?` ← `BrewLog.tasteTag`
- `recipeId: UUID?` ← `BrewLog.recipe?.id` (optional navigation)

**API Plan Reference:** Section 2.4.1 (List logs response)

---

#### BrewLogDetailDTO
**Purpose:** Full log entry with all brew parameters  
**Source Entity:** `BrewLog` (SwiftData model)  
**Fields:**
- `summary: BrewLogSummaryDTO` (composition)
- `doseGrams: Double` ← `BrewLog.doseGrams`
- `targetYieldGrams: Double` ← `BrewLog.targetYieldGrams`
- `waterTemperatureCelsius: Double` ← `BrewLog.waterTemperatureCelsius`
- `grindLabel: GrindLabel` ← `BrewLog.grindLabel`
- `note: String?` ← `BrewLog.note`

**Computed Properties:**
- `ratio: Double` = yield / dose

**API Plan Reference:** Section 2.4.3 (Get log detail response)

---

### 5. BrewLog Command Models

#### CreateBrewLogRequest
**Purpose:** Command for saving completed brew outcomes  
**Target Entity:** `BrewLog` (creates new SwiftData model)  
**Fields:**
- `timestamp: Date` → `BrewLog.timestamp` (defaults to now)
- `method: BrewMethod` → `BrewLog.method`
- `recipeId: UUID?` → `BrewLog.recipe` (optional navigation)
- `recipeNameAtBrew: String` → `BrewLog.recipeNameAtBrew` (snapshot)
- `doseGrams: Double` → `BrewLog.doseGrams` (snapshot)
- `targetYieldGrams: Double` → `BrewLog.targetYieldGrams` (snapshot)
- `waterTemperatureCelsius: Double` → `BrewLog.waterTemperatureCelsius` (snapshot)
- `grindLabel: GrindLabel` → `BrewLog.grindLabel` (snapshot)
- `rating: Int` → `BrewLog.rating` (1-5 required)
- `tasteTag: TasteTag?` → `BrewLog.tasteTag`
- `note: String?` → `BrewLog.note`

**Validation:** Built-in `validate()` method returns `[BrewLogValidationError]`
- Rating in 1…5 range
- Non-empty recipe name
- Positive dose/yield
- Note length ≤ 280 characters

**API Plan Reference:** Section 2.4.4 (Create log / Save brew)

---

#### BrewLogValidationError
**Purpose:** Typed validation errors for brew log operations  
**Cases:**
- `invalidRating(Int)` (not in 1…5)
- `emptyRecipeName`
- `invalidDose` (≤ 0)
- `invalidYield` (≤ 0)
- `noteTooLong(count: Int)` (> 280 chars)

**API Plan Reference:** Section 3.2 (BrewLog validation)

---

### 6. Brew Session DTOs

#### BrewInputs
**Purpose:** Editable brew parameters for Confirm Inputs screen  
**Source Entity:** `Recipe` (derives defaults, then user-editable)  
**Fields:**
- `recipeId: UUID` ← `Recipe.id`
- `recipeName: String` ← `Recipe.name`
- `method: BrewMethod` ← `Recipe.method`
- `doseGrams: Double` (var, editable) ← `Recipe.defaultDose`
- `targetYieldGrams: Double` (var, editable) ← `Recipe.defaultTargetYield`
- `waterTemperatureCelsius: Double` (var, editable) ← `Recipe.defaultWaterTemperature`
- `grindLabel: GrindLabel` (var, editable) ← `Recipe.defaultGrindLabel`
- `lastEdited: LastEditedField` (tracks scaling direction)

**Computed Properties:**
- `ratio: Double` = yield / dose

**API Plan Reference:** Section 2.5 (Brew Session core types)

---

#### ScaledStep
**Purpose:** Recipe step with scaled water amount  
**Source DTO:** `RecipeStepDTO` (transformed via scaling logic)  
**Fields:**
- `stepId: UUID` ← `RecipeStepDTO.stepId`
- `orderIndex: Int` ← `RecipeStepDTO.orderIndex`
- `instructionText: String` ← `RecipeStepDTO.instructionText`
- `timerDurationSeconds: Double?` ← `RecipeStepDTO.timerDurationSeconds`
- `waterAmountGrams: Double?` (scaled & rounded to 1g)
- `isCumulativeWaterTarget: Bool` ← `RecipeStepDTO.isCumulativeWaterTarget`

**API Plan Reference:** Section 2.5 (BrewPlan type)

---

#### BrewPlan
**Purpose:** Complete brew plan ready for execution  
**Composition:** `BrewInputs` + `[ScaledStep]`  
**Fields:**
- `inputs: BrewInputs`
- `scaledSteps: [ScaledStep]`

**Computed Properties:**
- `totalWaterGrams: Double` (from final cumulative or sum of incremental)

**API Plan Reference:** Section 2.5 (BrewPlan type)

---

#### BrewSessionState
**Purpose:** Current state of active brew session (state machine)  
**Fields:**
- `plan: BrewPlan` (immutable once started)
- `phase: Phase` (enum: notStarted, active, paused, stepReadyToAdvance, completed)
- `currentStepIndex: Int` (0-based)
- `remainingTime: TimeInterval?` (for timed steps)
- `startedAt: Date?` (session start timestamp)
- `isInputsLocked: Bool` (true once started)

**Computed Properties:**
- `currentStep: ScaledStep?`
- `isLastStep: Bool`
- `progress: Double` (0.0 to 1.0)

**API Plan Reference:** Section 2.5 (BrewSessionState type & operations)

---

### 7. Scaling DTOs

#### ScaleInputsRequest
**Purpose:** Request for scaling brew inputs  
**Source:** User-edited `BrewInputs` + `Recipe` defaults  
**Fields:**
- `method: BrewMethod` ← `BrewInputs.method`
- `recipeDefaultDose: Double` ← `Recipe.defaultDose`
- `recipeDefaultTargetYield: Double` ← `Recipe.defaultTargetYield`
- `userDose: Double` ← `BrewInputs.doseGrams`
- `userTargetYield: Double` ← `BrewInputs.targetYieldGrams`
- `lastEdited: BrewInputs.LastEditedField`

**Computed Properties:**
- `recipeRatio: Double` = recipeDefaultTargetYield / recipeDefaultDose

**API Plan Reference:** Section 2.6 (ScaleInputsRequest)

---

#### ScaleInputsResponse
**Purpose:** Scaled and rounded brew parameters with warnings  
**Fields:**
- `scaledDose: Double` (rounded to 0.1g)
- `scaledTargetYield: Double` (rounded to 1g)
- `scaledWaterTargets: [Double]` (rounded to 1g, final adjusted)
- `derivedRatio: Double` (yield / dose)
- `warnings: [InputWarning]` (non-blocking)

**Computed Properties:**
- `computedRatio: Double` (from scaled values)

**Scaling Rules (V60 MVP):**
- Last-edited wins (dose or yield)
- Dose rounded to 0.1g, yield to 1g
- Bloom = 3×dose (rounded to 1g)
- Remaining water split 50/50, final pour adjusted to match yield

**API Plan Reference:** Section 2.6 (ScaleInputsResponse)

---

#### InputWarning
**Purpose:** Non-blocking warning about out-of-range values  
**Cases:**
- `doseTooLow(dose: Double, minRecommended: Double)`
- `doseTooHigh(dose: Double, maxRecommended: Double)`
- `yieldTooLow(yield: Double, minRecommended: Double)`
- `yieldTooHigh(yield: Double, maxRecommended: Double)`
- `ratioTooLow(ratio: Double, minRecommended: Double)`
- `ratioTooHigh(ratio: Double, maxRecommended: Double)`
- `temperatureTooLow(temp: Double, minRecommended: Double)`
- `temperatureTooHigh(temp: Double, maxRecommended: Double)`

**API Plan Reference:** Section 2.6 (warnings field)

---

#### V60RecommendedRanges
**Purpose:** V60 brewing parameter ranges (MVP)  
**Ranges:**
- Dose: 12–40g
- Yield: 180–720g
- Ratio: 1:14 to 1:18
- Temperature: 90–96°C

**Method:**
- `warnings(dose:yield:temperature:) -> [InputWarning]`

**API Plan Reference:** Section 3.3 (Non-blocking warnings)

---

## Mapping Extensions

### Entity → DTO (Read Operations)

| Entity | Method | Returns | Usage |
|--------|--------|---------|-------|
| `Recipe` | `toSummaryDTO(isValid:)` | `RecipeSummaryDTO` | List views |
| `Recipe` | `toDetailDTO(isValid:)` | `RecipeDetailDTO` | Detail views |
| `Recipe` | `toBrewInputs()` | `BrewInputs` | Confirm Inputs initialization |
| `RecipeStep` | `toDTO()` | `RecipeStepDTO` | Step representation |
| `BrewLog` | `toSummaryDTO()` | `BrewLogSummaryDTO` | List views |
| `BrewLog` | `toDetailDTO()` | `BrewLogDetailDTO` | Detail views |

### DTO → Entity (Write Operations)

| DTO | Initializer | Creates | Usage |
|-----|------------|---------|-------|
| `CreateRecipeRequest` | `Recipe(from:)` | `Recipe` | Create new recipe |
| `UpdateRecipeRequest` | `Recipe.update(from:)` | (mutates Recipe) | Update existing |
| `RecipeStepDTO` | `RecipeStep(from:recipe:)` | `RecipeStep` | Create step |
| `CreateBrewLogRequest` | `BrewLog(from:recipe:)` | `BrewLog` | Save brew outcome |

### Domain Transformations

| Source | Method | Returns | Usage |
|--------|--------|---------|-------|
| `RecipeStepDTO` | `toScaledStep(scaledWaterAmount:)` | `ScaledStep` | Scaling logic |

---

## Validation Summary

### Recipe Validation (Blocking)
Implemented in: `CreateRecipeRequest.validate()`, `UpdateRecipeRequest.validate()`

Rules:
- ✓ Name non-empty
- ✓ Dose > 0
- ✓ Yield > 0
- ✓ At least 1 step
- ✓ No negative timers
- ✓ No negative water amounts
- ✓ Water totals match yield (±1g tolerance)

### BrewLog Validation (Blocking)
Implemented in: `CreateBrewLogRequest.validate()`

Rules:
- ✓ Rating in 1…5
- ✓ Recipe name non-empty
- ✓ Dose > 0
- ✓ Yield > 0
- ✓ Note ≤ 280 characters

### Input Warnings (Non-blocking)
Implemented in: `V60RecommendedRanges.warnings(dose:yield:temperature:)`

Warnings for V60:
- ✓ Dose outside 12–40g
- ✓ Yield outside 180–720g
- ✓ Ratio outside 1:14–1:18
- ✓ Temperature outside 90–96°C

---

## Conformances

All DTOs conform to:
- `Codable` - For serialization (future network sync, persistence)
- `Hashable` - For SwiftUI diffing and Set/Dictionary usage
- Most DTOs conform to `Identifiable` - For SwiftUI list rendering

Validation errors conform to:
- `Error` - Standard Swift error protocol
- `Equatable` - For testing and comparison
- Have `localizedDescription` for user-facing error messages

---

## Testing Strategy

All DTOs are pure Swift types (no SwiftData dependency), making them easily testable:

### Unit Test Coverage
- ✓ Validation logic (blocking errors)
- ✓ Warning generation (non-blocking)
- ✓ Computed properties (ratios, progress)
- ✓ Edge cases (empty lists, nil values, boundary conditions)

### Integration Test Coverage
- ✓ Entity → DTO mapping (via extensions)
- ✓ DTO → Entity creation (via initializers)
- ✓ Round-trip conversions

Example test structure:
```swift
@Test func recipeValidationRejectsEmptyName() {
    let request = CreateRecipeRequest(/* invalid data */)
    let errors = request.validate()
    #expect(errors.contains(.emptyName))
}

@Test func brewLogMapsToDTO() {
    let brewLog = BrewLog(/* test data */)
    let dto = brewLog.toDetailDTO()
    #expect(dto.summary.id == brewLog.id)
    #expect(dto.ratio == brewLog.ratio)
}
```

---

## API Plan Coverage

✅ **Complete**: All DTOs defined in API plan have been implemented

| API Plan Section | DTO/Type | Status |
|------------------|----------|--------|
| 2.2 Recipe DTOs | RecipeSummaryDTO | ✅ Implemented |
| 2.2 Recipe DTOs | RecipeDetailDTO | ✅ Implemented |
| 2.2 Recipe DTOs | RecipeStepDTO | ✅ Implemented |
| 2.2.3 Create Recipe | CreateRecipeRequest | ✅ Implemented |
| 2.2.4 Update Recipe | UpdateRecipeRequest | ✅ Implemented |
| 2.4 BrewLog DTOs | BrewLogSummaryDTO | ✅ Implemented |
| 2.4 BrewLog DTOs | BrewLogDetailDTO | ✅ Implemented |
| 2.4.4 Create Log | CreateBrewLogRequest | ✅ Implemented |
| 2.5 Brew Session | BrewInputs | ✅ Implemented |
| 2.5 Brew Session | BrewPlan | ✅ Implemented |
| 2.5 Brew Session | BrewSessionState | ✅ Implemented |
| 2.5 Brew Session | ScaledStep | ✅ Implemented |
| 2.6 Scaling | ScaleInputsRequest | ✅ Implemented |
| 2.6 Scaling | ScaleInputsResponse | ✅ Implemented |
| 2.6 Scaling | InputWarning | ✅ Implemented |
| 3.1 Validation | RecipeValidationError | ✅ Implemented |
| 3.2 Validation | BrewLogValidationError | ✅ Implemented |
| 3.3 Warnings | V60RecommendedRanges | ✅ Implemented |

---

## Files Created

1. **BrewGuide/Domain/DTOs/RecipeDTOs.swift** (218 lines)
   - Recipe DTOs, command models, validation errors

2. **BrewGuide/Domain/DTOs/BrewLogDTOs.swift** (103 lines)
   - BrewLog DTOs, command models, validation errors

3. **BrewGuide/Domain/DTOs/BrewSessionDTOs.swift** (86 lines)
   - Brew session state machine DTOs

4. **BrewGuide/Domain/DTOs/ScalingDTOs.swift** (156 lines)
   - Scaling request/response, warnings, V60 ranges

5. **BrewGuide/Domain/DTOs/MappingExtensions.swift** (174 lines)
   - Bidirectional entity-DTO mappings

6. **BrewGuide/Domain/DTOs/README.md** (Documentation)
   - Usage guide, examples, architecture overview

**Total:** 737 lines of production code + comprehensive documentation

---

## Next Steps

With DTOs implemented, the following can now be built:

1. **Repositories** - Using DTOs for query results and command execution
2. **Use Cases** - Orchestrating business logic with DTOs
3. **View Models** - Using DTOs to decouple views from SwiftData
4. **Domain Services** - Scaling logic, validation, state machines
5. **Unit Tests** - Testing business logic without SwiftData stack

The DTO layer provides a solid foundation for implementing the full domain-first MVVM architecture described in the cursor rules.
