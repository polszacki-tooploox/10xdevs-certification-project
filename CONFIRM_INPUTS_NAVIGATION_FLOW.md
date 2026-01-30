# ConfirmInputsView Navigation Flow

## User Journey Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         App Launch                                   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AppRootView                                  │
│                      (TabView with 3 tabs)                          │
│                                                                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                   │
│  │  Recipes   │  │    Logs    │  │  Settings  │                   │
│  │    Tab     │  │    Tab     │  │    Tab     │                   │
│  └────────────┘  └────────────┘  └────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RecipeListView                                  │
│                                                                       │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Recipe 1                                     │                  │
│  │  Swipe → [Brew] [Delete]                    │◄─── User swipes   │
│  └──────────────────────────────────────────────┘      left        │
│                                                                       │
│  ┌──────────────────────────────────────────────┐                  │
│  │  Recipe 2                                     │                  │
│  │  Tap → Navigate to RecipeDetailView          │◄─── User taps    │
│  └──────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
        │                                    │
        │ Brew action                        │ Tap row
        │                                    │
        ▼                                    ▼
┌─────────────────────────┐    ┌───────────────────────────────────┐
│ coordinator.            │    │     RecipeDetailView              │
│ presentConfirmInputs    │    │                                    │
│ (recipeId)              │    │  ┌─────────────────────────────┐ │
└─────────────────────────┘    │  │  Recipe Details              │ │
        │                       │  │  • Defaults                  │ │
        │                       │  │  • Steps                     │ │
        │                       │  └─────────────────────────────┘ │
        │                       │                                    │
        │                       │  ┌─────────────────────────────┐ │
        │                       │  │  [Brew this recipe]          │◄┼─ User taps
        │                       │  └─────────────────────────────┘ │
        │                       └───────────────────────────────────┘
        │                                    │
        └────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│             .fullScreenCover → ConfirmInputsFlowView                │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  NavigationStack                                             │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  ConfirmInputsView                                      │ │  │
│  │  │                                                          │ │  │
│  │  │  ┌──────────────────────────────────────────────────┐  │ │  │
│  │  │  │  ConfirmInputsScreen                              │  │ │  │
│  │  │  │                                                    │  │ │  │
│  │  │  │  [Recipe Name]  [Method]  [Change Recipe] ←──────┼──┼─┼──┤ User taps
│  │  │  │                                   │                │  │ │  │    │
│  │  │  │  ┌─────────────────────────────┐ │                │  │ │  │    │
│  │  │  │  │  InputsCard                 │ │                │  │ │  │    │
│  │  │  │  │  • Dose: 15.0g             │ │                │  │ │  │    │
│  │  │  │  │  • Yield: 250g             │ │                │  │ │  │    │
│  │  │  │  │  • Ratio: 1:16.7           │ │                │  │ │  │    │
│  │  │  │  │  • Temperature: 94°C       │ │                │  │ │  │    │
│  │  │  │  │  • Grind: Medium           │ │                │  │ │  │    │
│  │  │  │  └─────────────────────────────┘ │                │  │ │  │    │
│  │  │  │                                   │                │  │ │  │    │
│  │  │  │  ┌─────────────────────────────┐ │                │  │ │  │    │
│  │  │  │  │  ⚠️ Warnings Section        │ │                │  │ │  │    │
│  │  │  │  │  • Ratio above recommended  │ │                │  │ │  │    │
│  │  │  │  └─────────────────────────────┘ │                │  │ │  │    │
│  │  │  │                                   │                │  │ │  │    │
│  │  │  │  ┌─────────────────────────────┐ │                │  │ │  │    │
│  │  │  │  │  [Start Brewing]            │◄┼────────────────┼──┼─┼──┼─── User taps
│  │  │  │  │  [Reset to Defaults]        │ │                │  │ │  │
│  │  │  │  └─────────────────────────────┘ │                │  │ │  │
│  │  │  └──────────────────────────────────┘                │  │ │  │
│  │  └──────────────────────────────────────────────────────┘  │ │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
        │                                              │
        │ Change Recipe                                │ Start Brewing
        ▼                                              ▼
┌─────────────────────────┐            ┌──────────────────────────────┐
│  Navigate to            │            │  1. Create BrewPlan          │
│  RecipeListView         │            │  2. dismiss()                │
│  (within modal)         │            │  3. coordinator.             │
│                         │            │     presentBrewSession(plan) │
│  User selects recipe    │            └──────────────────────────────┘
│    ↓                    │                            │
│  Updates                │                            ▼
│  lastSelectedRecipeId   │            ┌──────────────────────────────┐
│    ↓                    │            │  .fullScreenCover →          │
│  Returns to             │            │  BrewSessionFlowView         │
│  ConfirmInputsView      │            │                              │
│    ↓                    │            │  (Guided brew session)       │
│  Detects change         │            └──────────────────────────────┘
│    ↓                    │
│  Reloads recipe         │
└─────────────────────────┘
```

## State Transitions

### Recipe Loading
```
Initial State → Loading → Loaded
                   ↓
                 Error (retryable)
```

### Input Editing
```
User edits dose:
  inputs.doseGrams = newValue
  inputs.lastEdited = .dose
  → recompute scaling
    → yield = dose × recipe.ratio
    → warnings updated
    → UI reflects new scaled values

User edits yield:
  inputs.targetYieldGrams = newValue
  inputs.lastEdited = .yield
  → recompute scaling
    → dose = yield / recipe.ratio
    → warnings updated
    → UI reflects new scaled values
```

### Start Brew Flow
```
User taps "Start Brewing":
  1. Validate hard constraints (dose/yield/temp > 0)
  2. Check recipe brewability
  3. If valid:
     a. Create BrewPlan via BrewSessionUseCase
     b. Dismiss ConfirmInputsView
     c. Present BrewSessionFlowView
  4. If invalid:
     a. Show error alert
     b. Keep modal open
```

### Modal Dismissal
```
User taps "Cancel":
  dismiss() → coordinator.dismissConfirmInputs()
  
Automatic dismissal on successful start:
  dismiss() → (brew modal presents)
```

## Navigation Paths

### Path 1: Recipe List → Confirm Inputs → Brew
```
RecipeListView
  ↓ swipe left, tap "Brew"
coordinator.presentConfirmInputs(recipeId)
  ↓ modal presented
ConfirmInputsFlowView
  ↓ user adjusts inputs
  ↓ taps "Start Brewing"
BrewSessionFlowView
```

### Path 2: Recipe Detail → Confirm Inputs → Brew
```
RecipeListView
  ↓ tap row
RecipeDetailView
  ↓ tap "Brew this recipe"
coordinator.presentConfirmInputs(recipeId)
  ↓ modal presented
ConfirmInputsFlowView
  ↓ user adjusts inputs
  ↓ taps "Start Brewing"
BrewSessionFlowView
```

### Path 3: Change Recipe Within Modal
```
ConfirmInputsFlowView
  ↓ tap "Change Recipe"
RecipeListView (within modal's NavigationStack)
  ↓ tap recipe
  ↓ updates lastSelectedRecipeId
  ↓ navigates back
ConfirmInputsView
  ↓ detects selection change
  ↓ reloads new recipe
```

## Testing Scenarios

### Scenario 1: Basic Brew Flow
1. Launch app → Recipes tab
2. Tap any recipe row
3. Tap "Brew this recipe"
4. Verify confirm inputs modal appears
5. Verify default values match recipe
6. Tap "Start Brewing"
7. Verify brew session starts

### Scenario 2: Edit and Scale
1. Open confirm inputs
2. Edit dose to 20g
3. Verify yield updates to maintain ratio
4. Verify warnings appear if out of range
5. Edit yield to 300g
6. Verify dose updates to maintain ratio
7. Verify warnings update

### Scenario 3: Reset to Defaults
1. Open confirm inputs
2. Edit several fields
3. Tap "Reset to Defaults"
4. Verify all fields restore to recipe defaults
5. Verify warnings recalculate

### Scenario 4: Change Recipe
1. Open confirm inputs with Recipe A
2. Tap "Change Recipe"
3. Select Recipe B from list
4. Verify modal returns to confirm inputs
5. Verify Recipe B is now loaded
6. Verify inputs show Recipe B defaults

### Scenario 5: Invalid Recipe
1. Open confirm inputs
2. Set dose to 0
3. Verify "Start Brewing" is disabled
4. Verify message explains why
5. Set dose to valid value
6. Verify "Start Brewing" is enabled

### Scenario 6: Warnings Don't Block
1. Open confirm inputs
2. Set dose to 50g (above recommended 40g)
3. Verify warning appears
4. Verify "Start Brewing" still enabled
5. Tap "Start Brewing"
6. Verify brew starts successfully

### Scenario 7: Cancel Modal
1. Open confirm inputs
2. Make changes to inputs
3. Tap "Cancel"
4. Verify modal dismisses
5. Open confirm inputs again
6. Verify changes were not persisted
7. Verify defaults restored
