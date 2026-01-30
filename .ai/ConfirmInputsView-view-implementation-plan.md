## View Implementation Plan — `ConfirmInputsView`

## 1. Overview
`ConfirmInputsView` is the **brew-entry** screen presented as a **full-screen modal** after the user taps a recipe’s **Brew** action (from recipe list or recipe detail). It lets the user confirm and adjust **pre-brew inputs** for that recipe before starting the guided brew.

It:
- Loads the selected recipe (passed in via presentation, and persisted as “last selected”)
- Allows editing (pre-start only): **dose (g)**, **target yield (g)**, **water temperature (°C)**, **grind label** (+ tactile descriptor).
- Computes a **derived ratio** (yield / dose).
- Shows **non-blocking warnings** when values are outside recommended V60 ranges (no clamping).
- Provides actions: **Change recipe**, **Reset to defaults**, **Start brew** (which creates a brew plan and transitions to the guided brew flow).
- Provides a modal dismissal affordance (e.g. **Cancel**), since it’s presented full-screen.

Key UX constraints from PRD:
- Kitchen-proof: large controls, minimal typing, one-handed primary action near bottom.
- Offline-first: all data is local (SwiftData); no network required.
- Accessibility: Dynamic Type + VoiceOver labels; 44×44pt touch targets.

## 2. View Routing
**Where it’s launched from:**
- `RecipeListView` row action: **Brew** (primary inline action on each recipe row).
- `RecipeDetailView` bottom CTA: **Brew this recipe** (replaces “Use this recipe” semantics for the brew entry flow).

**Presentation (full-screen modal):**
- Add a new app-level presentation state in `AppRootCoordinator`:
  - `activeConfirmInputs: ConfirmInputsPresentation?`
  - `presentConfirmInputs(recipeId:)`
  - `dismissConfirmInputs()`
- In `AppRootView`, present it via `.fullScreenCover(item: $coordinator.activeConfirmInputs) { … }`.

**In-modal navigation:**
- `ConfirmInputsView` should host its own `NavigationStack` (inside the modal) so “Change recipe” can navigate to a recipe picker without relying on tab navigation stacks.
- “Change recipe” pushes a modal-local `RecipeListView` (or a simplified `RecipePickerView`) onto that modal `NavigationStack`.
- Selecting a recipe inside the modal:
  - updates `PreferencesStore.shared.lastSelectedRecipeId`
  - updates the confirm-inputs view model to load the newly selected recipe
  - returns to `ConfirmInputsView` within the modal navigation stack.

**Transition to brew flow:**
- “Start brew” triggers plan creation and then shows `BrewSessionFlowView` (existing coordinator + `.fullScreenCover(item:)`).
- To avoid overlapping full-screen covers, `Start brew` must:
  - dismiss the confirm-inputs modal (`activeConfirmInputs = nil`)
  - then present the brew session modal (`activeBrewSession = …`)
  - (implementation detail) ensure this happens in a safe order (e.g. dismiss first, then present on the next run loop / `Task.yield()`).

## 3. Component Structure
High-level hierarchy (screen-level):

- `ConfirmInputsFlowView` (modal root wrapper; recommended)
  - `NavigationStack`
    - `ConfirmInputsView` (screen content)
      - `ConfirmInputsScreen` (pure rendering; receives view state + callbacks)
        - `SelectedRecipeHeader`
          - Recipe name + method badge
          - “Change recipe” button
        - `InputsCard`
          - `DoseInputRow`
          - `YieldInputRow`
          - `WaterTemperatureInputRow`
          - `GrindLabelSelectorRow`
          - `GrindDescriptorLine`
          - `RatioRow`
        - `WarningsSection` (non-blocking)
          - `WarningRow` × N
        - `BottomActionBar` (safe-area inset)
          - Primary: `StartBrewButton`
          - Secondary: `ResetDefaultsButton`
    - `RecipeListView` (or `RecipePickerView`) as a modal-local navigation destination for “Change recipe”

Suggested SwiftUI composition:
- Use a `ScrollView` for content + `.safeAreaInset(edge: .bottom)` for the fixed CTA bar (one-handed placement).

## 4. Component Details

### `ConfirmInputsView`
- **Purpose**: Screen entry point + dependency wiring (SwiftData `ModelContext`, coordinator) + lifecycle hooks.
- **Main elements**:
  - Owns `@State private var viewModel: ConfirmInputsViewModel`.
  - Displays:
    - loading state (`ProgressView`)
    - empty state (`ContentUnavailableView`) if no recipe exists yet
    - loaded screen: `ConfirmInputsScreen(state:onEvent:)`
- **Handled events**:
  - `.task { await viewModel.onAppear(context:) }`
  - `.onAppear { viewModel.refreshIfSelectionChanged(context:) }` (ensures in-modal selection changes are picked up when returning from recipe picker)
  - Error presentation (alert/banner) bound to `viewModel.ui.error`.
- **Props**:
  - `presentation: ConfirmInputsPresentation` (or `initialRecipeId: UUID`) to load the recipe that initiated the modal.

### `ConfirmInputsScreen`
- **Purpose**: Pure SwiftUI rendering with no persistence knowledge. Renders state and forwards events.
- **Main elements**:
  - `ScrollView` with header, inputs, warnings.
  - `.safeAreaInset(edge: .bottom)` for `BottomActionBar`.
- **Handled events**:
  - `onTapChangeRecipe`
  - `onChangeDose`
  - `onChangeYield`
  - `onChangeTemperature`
  - `onChangeGrind`
  - `onTapResetDefaults`
  - `onTapStartBrew`
- **Props (interface)**:
  - `state: ConfirmInputsViewState`
  - `onEvent: (ConfirmInputsEvent) -> Void` (recommended to keep the interface small and scalable)

### `SelectedRecipeHeader`
- **Purpose**: Show selected recipe name and method; provide “Change recipe” affordance.
- **Main elements**:
  - `Text(state.recipeName)` (large, Dynamic Type friendly; avoid fixed sizes)
  - method label `Text(state.method.displayName)` (secondary style)
  - Button “Change recipe” (or “Recipes”) with system image (e.g. `list.bullet`)
- **Handled events**:
  - tap → `onEvent(.changeRecipeTapped)`
- **Validation**: none.
- **Props**:
  - `recipeName: String`
  - `methodName: String`
  - `isEnabled: Bool` (disabled during critical operations like loading/starting brew)

### `DoseInputRow`
- **Purpose**: Edit dose (grams) with minimal typing.
- **Main elements**:
  - Label “Dose”
  - A numeric control:
    - recommended: `Stepper` (step = 0.1) + a `TextField` with `.decimalPad` as fallback
  - Unit “g”
  - Optional helper text (e.g. “0.1g precision”)
- **Handled events**:
  - value change → `onEvent(.doseChanged(Double))`
- **Validation conditions**:
  - blocking validation (for Start): `dose > 0`
  - non-blocking warnings via recommended ranges (12–40g)
- **Props**:
  - `value: Double`
  - `isEditable: Bool`
  - `onChange: (Double) -> Void`

### `YieldInputRow`
- **Purpose**: Edit target yield (grams).
- **Main elements**:
  - Label “Target yield”
  - `Stepper` (step = 1) + optional numeric `TextField` fallback
  - Unit “g”
- **Handled events**:
  - value change → `onEvent(.yieldChanged(Double))`
- **Validation conditions**:
  - blocking: `yield > 0`
  - warnings: 180–720g
- **Props**: same pattern as `DoseInputRow`.

### `WaterTemperatureInputRow`
- **Purpose**: Edit water temperature (°C).
- **Main elements**:
  - Label “Water temperature”
  - `Stepper` (step = 1) + optional numeric `TextField` fallback
  - Unit “°C”
- **Handled events**:
  - value change → `onEvent(.temperatureChanged(Double))`
- **Validation conditions**:
  - blocking: `temperature > 0` (MVP)
  - warnings: 90–96°C
- **Props**: same pattern as `DoseInputRow`.

### `GrindLabelSelectorRow`
- **Purpose**: Choose grind label (fine/medium/coarse) using a picker that’s easy with wet hands.
- **Main elements**:
  - label “Grind”
  - recommended: `.segmented` `Picker` for 3 options, or a `Menu` on compact UI
  - descriptor line below (see `GrindDescriptorLine`)
- **Handled events**:
  - selection change → `onEvent(.grindChanged(GrindLabel))`
- **Validation**: always valid (no blocking validation).
- **Props**:
  - `selection: GrindLabel`
  - `isEditable: Bool`
  - `onChange: (GrindLabel) -> Void`

### `GrindDescriptorLine`
- **Purpose**: Display tactile descriptor guidance for the selected recipe.
- **Main elements**:
  - If `grindTactileDescriptor != nil`: `Text(descriptor)` in secondary style.
  - If missing: hide the row (no placeholder).
- **Props**:
  - `descriptor: String?`

### `RatioRow`
- **Purpose**: Display derived ratio in a readable way.
- **Main elements**:
  - label “Ratio”
  - value formatted as `1:x.x` where \(x = yield/dose\)
  - Use modern formatting (avoid `String(format:)` in implementation).
- **Props**:
  - `ratio: Double`

### `WarningsSection`
- **Purpose**: Show advisory warnings; never blocks starting a brew if hard validation passes.
- **Main elements**:
  - Section header “Recommendations”
  - `WarningRow` list (each showing `InputWarning.message`)
  - Empty state: hide section entirely if no warnings
- **Handled events**: none.
- **Props**:
  - `warnings: [InputWarning]`

### `BottomActionBar`
- **Purpose**: Kitchen-proof, one-handed action placement with large tap targets.
- **Main elements**:
  - Primary `StartBrewButton` (prominent, full width)
  - Secondary `ResetDefaultsButton` (less prominent)
  - Optional inline text if recipe is not brewable (e.g., “Fix recipe to start brewing”)
- **Handled events**:
  - start → `onEvent(.startBrewTapped)`
  - reset → `onEvent(.resetTapped)`
- **Validation conditions**:
  - Primary enabled only when:
    - recipe is brewable (passes recipe validation)
    - hard input validation passes (dose/yield/temp > 0)
    - not loading, not starting brew
- **Props**:
  - `isStartEnabled: Bool`
  - `isBusy: Bool`
  - `onStart: () -> Void`
  - `onReset: () -> Void`

## 5. Types

### Existing types to reuse
- **Domain DTOs**
  - `BrewInputs` (`Domain/DTOs/BrewSessionDTOs.swift`)
  - `BrewPlan`, `ScaledStep`
  - `ScaleInputsRequest`, `ScaleInputsResponse`, `InputWarning`, `V60RecommendedRanges` (`Domain/DTOs/ScalingDTOs.swift`)
  - `RecipeNotBrewableError`, `RecipeValidationError` (`Domain/DTOs/RecipeDTOs.swift`)
- **Persistence**
  - `Recipe` SwiftData model (used via `RecipeRepository`)
- **Coordinator**
  - `AppRootCoordinator` (navigation + brew modal)

### New/updated ViewModel types

#### `ConfirmInputsViewModel` (updated from current inline implementation)
- **Location**: `BrewGuide/BrewGuide/UI/Screens/ConfirmInputs/ConfirmInputsViewModel.swift` (recommended to move it out of the view file).
- **Concurrency**: `@MainActor @Observable final class ConfirmInputsViewModel`.
- **Responsibilities**:
  - Load selected recipe (from modal presentation; persist as last-selected; fallback to starter only if necessary).
  - Maintain an editable `BrewInputs` draft + recipe defaults for scaling reference.
  - Perform scaling (“last edited wins”) and compute warnings.
  - Validate recipe brewability (block Start if invalid recipe).
  - Start brew by creating plan and calling coordinator.
- **Fields**:
  - `ui: ConfirmInputsUIState`
  - `recipeSnapshot: ConfirmInputsRecipeSnapshot?`
  - `inputsDraft: BrewInputs?` (editable)
  - `lastLoadedRecipeId: UUID?` (to detect selection changes)
  - `scaling: ConfirmInputsScalingState` (derived ratio, warnings, computed water targets if needed for plan creation)
  - Dependencies (injected or constructed in `onAppear`):
    - `preferences: PreferencesStore` (default `.shared`)
    - `recipeRepository: RecipeRepository`
    - `brewSessionUseCase: BrewSessionUseCase`
    - `scalingService: ScalingService` (new domain service; see below)
    - Optional: `recipeValidationService` (can be repository.validate)

#### `ConfirmInputsViewState` (UI-facing snapshot)
Use a single value type to drive `ConfirmInputsScreen`.
- **Fields**:
  - `isLoading: Bool`
  - `recipeName: String`
  - `method: BrewMethod`
  - `isRecipeBrewable: Bool`
  - `brewabilityMessage: String?` (shown when not brewable)
  - `doseGrams: Double`
  - `targetYieldGrams: Double`
  - `waterTemperatureCelsius: Double`
  - `grindLabel: GrindLabel`
  - `grindTactileDescriptor: String?`
  - `ratio: Double` (derived, from scaled values)
  - `warnings: [InputWarning]`
  - `isStartingBrew: Bool`
  - `canStartBrew: Bool` (computed for the CTA)

#### `ConfirmInputsUIState`
Tracks cross-cutting UI concerns.
- **Fields**:
  - `error: ConfirmInputsErrorBanner?` (or `String?` if using `.alert`)
  - `showsError: Bool` (if implementing `.alert`)

#### `ConfirmInputsRecipeSnapshot`
Represents immutable recipe defaults relevant to this screen.
- **Fields**:
  - `recipeId: UUID`
  - `recipeName: String`
  - `method: BrewMethod`
  - `defaultDose: Double`
  - `defaultTargetYield: Double`
  - `defaultWaterTemperature: Double`
  - `defaultGrindLabel: GrindLabel`
  - `grindTactileDescriptor: String?`
  - `validationErrors: [RecipeValidationError]` (computed via repository.validate)

#### `ConfirmInputsScalingState`
Stores scaling output so it can be reused for plan creation (and warning display).
- **Fields**:
  - `scaledDose: Double`
  - `scaledTargetYield: Double`
  - `derivedRatio: Double`
  - `warnings: [InputWarning]`
  - `scaledWaterTargets: [Double]` (optional for now unless you align plan creation to these targets)

#### `ConfirmInputsEvent`
Event enum that the view emits (optional but recommended).
- Cases:
  - `.changeRecipeTapped`
  - `.doseChanged(Double)`
  - `.yieldChanged(Double)`
  - `.temperatureChanged(Double)`
  - `.grindChanged(GrindLabel)`
  - `.resetTapped`
  - `.startBrewTapped`

#### `ConfirmInputsPresentation` (new; required for full-screen modal)
- **Location**: `BrewGuide/BrewGuide/UI/AppShell/ConfirmInputsPresentation.swift`
- **Purpose**: Item payload for `.fullScreenCover(item:)` and a stable entry contract for `ConfirmInputsFlowView`.
- **Fields**:
  - `id: UUID` (presentation identity)
  - `recipeId: UUID` (the recipe selected via Brew action)

### New Domain service required (to meet PRD scaling behavior)

#### `ScalingService`
- **Location**: `BrewGuide/BrewGuide/Domain/Scaling/ScalingService.swift`
- **API**:
  - `func scaleInputs(request: ScaleInputsRequest, temperatureCelsius: Double) -> ScaleInputsResponse`
- **Responsibilities**:
  - Implements PRD “last edited wins”:
    - if `.dose` edited last → \(yield = dose * recipeRatio\)
    - if `.yield` edited last → \(dose = yield / recipeRatio\)
  - Applies rounding rules:
    - dose to nearest 0.1g
    - yield/water to nearest 1g
  - Computes V60-specific cumulative water targets per PRD:
    - bloom = \(3×dose\)
    - remaining = yield − bloom
    - split remaining into two pours 50/50; adjust final pour so last cumulative == yield
  - Produces warnings using `V60RecommendedRanges.warnings(dose:yield:temperature:)`

Note: `ScaleInputsRequest` currently doesn’t include temperature; passing `temperatureCelsius` separately keeps DTO stable while meeting PRD warning requirements.

## 6. State Management
Use a single `@Observable @MainActor` view model as the source of truth. Recommended state approach:

- **Loading**:
  - `ui.isLoading = true` during initial fetch.
  - When done, set `recipeSnapshot` + `inputsDraft` and immediately compute scaling output.

- **Inputs draft**:
  - Store as `BrewInputs` for consistency with the domain layer.
  - On any edit:
    - update the edited field
    - set `inputsDraft.lastEdited` appropriately (`.dose` or `.yield`)
    - recompute scaling via `ScalingService` and then **write back** `scaledDose`/`scaledTargetYield` into `inputsDraft` so the displayed numbers stay consistent and rounded.

- **Selection change detection**:
  - Keep `lastLoadedRecipeId`.
  - On `onAppear` (or `.task(id:)`), read `PreferencesStore.shared.lastSelectedRecipeId`. If it differs from `lastLoadedRecipeId`, reload recipe + reset draft.

- **Start brew state**:
  - `ui.isStartingBrew = true` while creating the plan and presenting the modal.
  - Disable editing + buttons while starting to prevent double-taps and re-entrancy.

No custom hook equivalents are needed in SwiftUI; keep logic in the view model and expose a `ConfirmInputsViewState` computed property for rendering.

## 7. API Integration
This screen uses the internal “application API” (repositories + use-cases) described in `.ai/api-plan.md`.

### Data loading
- **Preferences**:
  - Read `PreferencesStore.shared.lastSelectedRecipeId` (UUID?)
- **Recipe fetch**:
  - `RecipeRepository.fetchRecipe(byId:) throws -> Recipe?`
  - Fallback: `RecipeRepository.fetchStarterRecipe(for: .v60) throws -> Recipe?`
  - Final fallback: fetch first recipe sorted by name (if needed)
- **Validation (brewability)**:
  - `RecipeRepository.validate(_ recipe: Recipe) -> [RecipeValidationError]`
  - Brewability rule on this screen: “brewable” iff validation errors are empty.

### Scaling
- **Request type**: `ScaleInputsRequest`
  - `method: BrewMethod`
  - `recipeDefaultDose: Double`
  - `recipeDefaultTargetYield: Double`
  - `userDose: Double`
  - `userTargetYield: Double`
  - `lastEdited: BrewInputs.LastEditedField`
- **Response type**: `ScaleInputsResponse`
  - `scaledDose: Double`
  - `scaledTargetYield: Double`
  - `scaledWaterTargets: [Double]`
  - `derivedRatio: Double`
  - `warnings: [InputWarning]`
- **Call site**:
  - `let response = scalingService.scaleInputs(request: request, temperatureCelsius: inputsDraft.waterTemperatureCelsius)`

### Start brew
- **Preconditions**:
  - Recipe is brewable (validation errors empty).
  - Inputs hard-valid: dose/yield/temp > 0.
- **Plan creation**:
  - Use `BrewSessionUseCase.createPlan(from: inputsDraft)` (existing) **or** align `BrewSessionUseCase` to use the same scaling output (preferred long-term).
  - If keeping `createPlan(from:)` as-is initially, ensure it doesn’t violate PRD step scaling rules (follow-up work may be required to update it to the V60-specific scaling model).
- **Presentation**:
  - `coordinator.presentBrewSession(plan:)`

## 8. User Interactions

- **Tap “Brew” on a recipe**
  - Presents `ConfirmInputsView` as a **full-screen modal**, seeded with that recipe’s id.
  - Persists selection as last-selected.
  - Shows current defaults as editable values.

- **Tap “Change recipe”**
  - Navigates within the modal to a recipe picker (`RecipeListView` or `RecipePickerView`).

- **Edit dose**
  - Updates `inputsDraft.doseGrams`, sets `lastEdited = .dose`.
  - Recomputes scaled yield (and ratio), applying rounding.
  - Updates warnings list.

- **Edit target yield**
  - Updates `inputsDraft.targetYieldGrams`, sets `lastEdited = .yield`.
  - Recomputes scaled dose (and ratio), applying rounding.
  - Updates warnings list.

- **Edit water temperature**
  - Updates `inputsDraft.waterTemperatureCelsius`.
  - Recomputes warnings (temperature range) without changing dose/yield scaling direction.

- **Change grind label**
  - Updates `inputsDraft.grindLabel`.
  - No scaling impact; ratio unchanged.

- **Tap “Reset to defaults”**
  - Restores dose/yield/temp/grind to recipe defaults.
  - Sets `lastEdited` to a consistent default (recommend `.dose` to keep behavior deterministic).
  - Recomputes scaling and clears warnings if within range.

- **Tap “Start brew”**
  - If blocked (not brewable or hard-invalid inputs): show error banner/alert and do nothing.
  - Otherwise:
    - create plan
    - dismiss confirm-inputs modal
    - present brew modal (`BrewSessionFlowView`)
    - inputs become effectively locked because user leaves the screen into brew modal (PRD locking requirement is enforced during the brew flow).

- **Tap “Cancel” (modal dismissal)**
  - Dismisses the full-screen modal with no side effects beyond persisting last-selected recipe.

## 9. Conditions and Validation

### Hard validation (blocks Start brew)
Enforced in view model; reflected in CTA enabled state.
- **Dose**: `doseGrams > 0`
- **Yield**: `targetYieldGrams > 0`
- **Temperature**: `waterTemperatureCelsius > 0`
- **Recipe brewability**: `RecipeRepository.validate(recipe).isEmpty == true`

### Non-blocking warnings (never block Start)
Shown in `WarningsSection` (advisory only):
- V60 recommended ranges:
  - Dose: 12–40g
  - Yield: 180–720g
  - Ratio: 1:14 to 1:18 (i.e. `yield/dose` in 14…18)
  - Temp: 90–96°C

### UI effects of conditions
- If hard-invalid inputs:
  - Start button disabled.
  - Optionally show subtle inline hint (e.g., “Enter a dose greater than 0g”).
- If recipe not brewable:
  - Start button disabled.
  - Show a clear message:
    - If custom recipe: offer navigation to edit (future if edit view exists).
    - If starter: this should not occur; treat as an error and provide retry.
- If warnings exist:
  - Show warnings list; keep Start enabled (if hard validation passes).

## 10. Error Handling

### Loading errors
Potential scenarios:
- No recipes exist (seed failure) → show `ContentUnavailableView` with “No recipes available” and a “Retry” button.
- Repository fetch throws → show retryable error state (same UI).

### Start brew errors
Potential scenarios:
- Recipe deleted between selection and start → show alert “Recipe not found” and prompt user to choose a recipe.
- Plan creation fails (e.g., `noSteps`, method mismatch) → show alert/banner with `error.localizedDescription`.
- Double-tap / re-entrancy → guarded by `ui.isStartingBrew` + coordinator guard in `presentBrewSession`.

### Scaling edge cases
- Default dose is 0 (invalid recipe) → recipe not brewable; block Start; show validation message.
- Bloom water \(3×dose\) exceeds yield → produce scaled targets where remaining becomes 0 (or clamp remaining at 0) and add a warning (recommend adding a new warning case if needed). Until such a warning exists, treat it as an error state and suggest “Increase yield or decrease dose”.

## 11. Implementation Steps
1. **Route the screen correctly**
   - Add `ConfirmInputsPresentation` + `activeConfirmInputs` to `AppRootCoordinator`.
   - Present `ConfirmInputsFlowView` via `.fullScreenCover(item: $coordinator.activeConfirmInputs)`.
   - Update `RecipeListView` and `RecipeDetailView` to expose a **Brew** action that calls `coordinator.presentConfirmInputs(recipeId:)`.
2. **Extract / create the view model file**
   - Move the existing inline `ConfirmInputsViewModel` out of `ConfirmInputsView.swift` into `UI/Screens/ConfirmInputs/ConfirmInputsViewModel.swift`.
   - Convert it to emit a single `ConfirmInputsViewState` for rendering.
3. **Implement deterministic scaling via a domain service**
   - Add `ScalingService.scaleInputs(request:temperatureCelsius:) -> ScaleInputsResponse` using PRD rules and `V60RecommendedRanges`.
4. **Wire scaling into the view model**
   - On dose/yield changes, rebuild `ScaleInputsRequest`, call scaling service, write scaled values back into `inputsDraft`, and publish updated warnings + ratio.
5. **Implement “Reset to defaults”**
   - Use `ConfirmInputsRecipeSnapshot` defaults to restore the draft; recompute scaling.
6. **Add warnings UI**
   - Render `InputWarning.message` in a non-blocking section; hide when empty.
7. **Implement brewability gating**
   - Validate the selected recipe on load; disable Start if invalid; show message and (optionally) a path to fix (edit) when available.
8. **Implement Start brew flow**
   - On tap, re-check hard validation + brewability.
   - Create a `BrewPlan` (via `BrewSessionUseCase.createPlan(from:)` initially).
   - Dismiss confirm-inputs modal, then call `coordinator.presentBrewSession(plan:)`.
9. **Handle recipe selection changes**
   - On return from the in-modal recipe picker, detect changed `PreferencesStore.shared.lastSelectedRecipeId` and reload.
10. **Polish for kitchen-proof UX**
   - Ensure bottom CTA uses `.safeAreaInset`.
   - Ensure primary actions meet 44×44pt and are visually separated.
11. **Accessibility pass**
   - Add VoiceOver labels/values for each input (“Dose, 15 grams”).
   - Confirm Dynamic Type doesn’t truncate critical content.
12. **Unit tests (recommended)**
   - Add deterministic unit tests for `ScalingService` (last-edited logic, rounding, water target computation, warnings).
   - Add view model tests using fake repositories/preferences to validate state transitions (load → edit dose → warnings update → reset).

