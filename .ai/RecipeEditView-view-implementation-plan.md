## View Implementation Plan: RecipeEditView

## 1. Overview
`RecipeEditView` lets users **edit a custom V60 recipe** (not starter) including:
- Recipe defaults: **name**, **default dose (g)**, **default target yield (g)**, **default water temperature (°C)**, **grind label**, and optional **tactile descriptor**
- Ordered **step list**: instruction text plus optional timer and optional water amount (cumulative “pour to” targets supported)

The view is **guardrail-first**:
- Validation runs continuously while editing (no blocking popups).
- A **top summary banner** explains “Fix X issues to save”, and can **jump to the first issue**.
- Save is **disabled** until the draft is valid.
- Water-total mismatch (sum/target mismatch per rules) receives special emphasis by highlighting the yield field and the offending step(s).

This screen is **offline-first** (SwiftData local persistence). No auth is required.

## 2. View Routing
- **Route enum**: `RecipesRoute.recipeEdit(id: UUID)` (defined in `BrewGuide/BrewGuide/UI/AppShell/NavigationRoutes.swift`).
- **Navigation host**: Recipes tab `NavigationStack` registers `.navigationDestination(for: RecipesRoute.self)` mapping `.recipeEdit(id:)` → `RecipeEditView(recipeId:)`.
- **Entry points**:
  - From `RecipeDetailView` for custom recipes: toolbar “Edit” → push `.recipeEdit(id:)`.
  - From starter recipe duplication flow: after `RecipeRepository.duplicate(_)`, push `.recipeEdit(id: newRecipeId)` so users can immediately tweak.
- **Exit behavior**:
  - **Cancel**: discards the draft and pops.
  - If draft has unsaved changes: show a discard confirmation (“Discard changes?”) before popping (recommended, to prevent accidental loss).
  - **Save**: on success, persist changes and pop back to `RecipeDetailView` (or replace current with detail if needed).

## 3. Component Structure
High-level hierarchy (SwiftUI):

```
RecipeEditView (screen entry; owns VM)
└─ RecipeEditScreen (pure renderer)
   ├─ LoadingStateView / ErrorStateView
   └─ ScrollView + ScrollViewReader
      ├─ ValidationSummaryBanner (top; shows count + Jump)
      ├─ RecipeDefaultsSection
      │  ├─ NameFieldRow
      │  ├─ DoseFieldRow
      │  ├─ YieldFieldRow
      │  ├─ TemperatureFieldRow
      │  ├─ GrindLabelPickerRow
      │  └─ TactileDescriptorFieldRow
      ├─ StepsEditorSection
      │  ├─ StepsHeaderRow (+ Add step, Edit/Done reorder)
      │  └─ List/ForEach(steps) → StepEditorCard
      │     ├─ InstructionTextField
      │     ├─ TimerEditor (toggle + numeric/time input)
      │     ├─ WaterEditor (toggle + grams input + cumulative toggle)
      │     ├─ InlineErrors
      │     └─ DeleteStepButton
      └─ BottomSpacing
   └─ BottomActionBar (safeAreaInset bottom)
      ├─ Button: Cancel
      └─ Button: Save (disabled until valid)
```

Recommended shared components (reusable across screens):
- `InlineErrorText`: consistent error messaging under fields/cards.
- `ValidationSummaryBanner`: shared pattern used in other forms.
- `NumericFieldRow`: label + unit + numeric input + error.

## 4. Component Details

### RecipeEditView
- **Purpose**: Entry view that wires environment dependencies into `RecipeEditViewModel` and hosts navigation-related dialogs (discard confirmation, alerts).
- **Main elements**:
  - `RecipeEditScreen(state: ..., handlers: ...)`
  - `.toolbar` items (optional): “Cancel” and “Save” may live in bottom bar or nav bar; pick one consistent pattern (plan assumes bottom bar).
  - `confirmationDialog` / `alert` for:
    - Discard changes when dirty
    - “Cannot edit starter recipe” (defensive)
    - Unexpected persistence errors
- **Handled events**:
  - `.task` on first appearance → `await viewModel.load()`
  - Cancel tapped → `viewModel.cancelTapped()` (may request confirmation)
  - Save tapped → `await viewModel.saveTapped()`
- **Props**:
  - `recipeId: UUID`
  - Optional injection hooks for testability:
    - `makeRepository: (ModelContext) -> RecipeRepository` (default `{ RecipeRepository(context: $0) }`)
    - `makeUseCase: (RecipeRepository) -> RecipeUseCaseProtocol` (default wraps repository; see Types)

### RecipeEditScreen
- **Purpose**: Pure rendering based on a single UI snapshot; contains no persistence logic.
- **Main elements**:
  - Loading: `ProgressView("Loading…")`
  - Error: `ContentUnavailableView` + “Retry”
  - Loaded:
    - `ValidationSummaryBanner`
    - `RecipeDefaultsSection`
    - `StepsEditorSection`
    - `BottomActionBar`
- **Handled events**:
  - Field changes delegate to view-model via event methods (or bindings that call setters).
  - Jump-to-first-issue scroll.
- **Props**:
  - `state: RecipeEditViewState`
  - `onEvent: (RecipeEditEvent) -> Void`
  - `onRetry: () -> Void`

### ValidationSummaryBanner
- **Purpose**: Make save-disabled rationale explicit and provide fast navigation to the first problem.
- **Main elements**:
  - Text:
    - If valid: hidden (or shows subtle “All set” if desired).
    - If invalid: “Fix \(issueCount) issues to save”
  - Optional secondary line when water mismatch exists: “Water total must match yield (±1g).”
  - Button: “Jump to first issue”
- **Handled events**:
  - Jump tapped → call `onJump(target: ValidationAnchor)`
- **Props**:
  - `issueCount: Int`
  - `isVisible: Bool`
  - `highlightStyle: ValidationHighlightStyle` (e.g., `.standard` vs `.waterMismatch`)
  - `onJumpToFirstIssue: () -> Void`

### RecipeDefaultsSection
- **Purpose**: Edit recipe-level fields with inline validation.
- **Main elements**:
  - Name field
  - Dose / Yield / Temperature numeric rows with units
  - Grind label picker and descriptor
- **Handled events**:
  - `nameChanged(String)`
  - `doseChanged(Double?)`
  - `yieldChanged(Double?)`
  - `temperatureChanged(Double?)`
  - `grindLabelChanged(GrindLabel)`
  - `tactileDescriptorChanged(String)`
- **Props**:
  - `draft: RecipeEditDraft`
  - `fieldErrors: RecipeEditFieldErrors`
  - `waterMismatchEmphasis: Bool` (to visually emphasize yield row when mismatch exists)

### StepsEditorSection
- **Purpose**: Edit ordered steps, including reordering, per-step optional timer/water, and per-step errors.
- **Main elements**:
  - Header row:
    - Title: “Steps”
    - “Add step” button
    - Optional `EditButton()` to toggle reorder mode
  - Steps list/cards:
    - Each step shows editable fields and inline errors.
    - Reordering via `.onMove(perform:)` in `List` or `ForEach` with reorder support.
- **Handled events**:
  - Add step
  - Reorder steps
  - Delete step
  - Step field edits
- **Props**:
  - `steps: [RecipeStepDraft]`
  - `stepErrors: [UUID: [RecipeValidationError]]` (or mapped UI errors)
  - `waterMismatchOffendingStepIds: Set<UUID>`
  - `onEvent: (RecipeEditEvent) -> Void`

### StepEditorCard
- **Purpose**: Edit a single step and show any step-specific validation.
- **Main elements**:
  - Instruction text field (required)
  - Timer editor:
    - Toggle “Timer”
    - If enabled: duration input (seconds or mm:ss UI)
  - Water editor:
    - Toggle “Water”
    - If enabled: grams input
    - Toggle or segmented control:
      - “Pour to” (cumulative target) vs “Add” (incremental)
  - Inline errors (under relevant sub-fields)
  - Delete button (destructive)
- **Handled events**:
  - `stepInstructionChanged(stepId, String)`
  - `stepTimerEnabledChanged(stepId, Bool)` / `stepTimerChanged(stepId, Double?)`
  - `stepWaterEnabledChanged(stepId, Bool)` / `stepWaterChanged(stepId, Double?)`
  - `stepWaterModeChanged(stepId, Bool /* isCumulative */)`
  - `deleteStep(stepId)`
- **Props**:
  - `step: RecipeStepDraft`
  - `errors: [RecipeEditInlineError]`
  - `isWaterMismatchOffender: Bool`
  - `stepNumber: Int` (1-based display)

### BottomActionBar
- **Purpose**: Provide consistent, reachable primary actions.
- **Main elements**:
  - Cancel (secondary)
  - Save (primary; `.borderedProminent`)
  - Optional helper text when save disabled: “Fix issues above to enable Save”
- **Handled events**:
  - Cancel → `onCancel()`
  - Save → `onSave()`
- **Props**:
  - `isSaving: Bool`
  - `canSave: Bool`
  - `onCancel: () -> Void`
  - `onSave: () -> Void`

## 5. Types

### Existing types (already implemented)
From `BrewGuide/BrewGuide/Domain/DTOs/RecipeDTOs.swift`:
- `RecipeDetailDTO`
- `RecipeStepDTO`
- `UpdateRecipeRequest`
- `RecipeValidationError` (includes: `.emptyName`, `.invalidDose`, `.invalidYield`, `.noSteps`, `.negativeTimer(stepIndex:)`, `.negativeWaterAmount(stepIndex:)`, `.waterTotalMismatch(expected:actual:)`, `.starterCannotBeModified`, …)

From `BrewGuide/BrewGuide/Persistence/Repositories/RecipeRepository.swift`:
- `RecipeRepository.fetchRecipe(byId:)`
- `RecipeRepository.validate(_:) -> [RecipeValidationError]`

### New view-model and UI types

#### `RecipeEditViewState`
Purpose: single UI snapshot driving rendering.
- `isLoading: Bool`
- `draft: RecipeEditDraft?`
- `validation: RecipeEditValidationState`
- `isSaving: Bool`
- `loadErrorMessage: String?`
- `saveErrorMessage: String?` (non-validation error: persistence failure)
- `isDirty: Bool`

#### `RecipeEditDraft`
Purpose: editable, UI-owned representation independent from SwiftData entities.
- `recipeId: UUID`
- `name: String`
- `defaultDose: Double?`
- `defaultTargetYield: Double?`
- `defaultWaterTemperature: Double?`
- `defaultGrindLabel: GrindLabel`
- `grindTactileDescriptor: String`
- `steps: [RecipeStepDraft]`

Notes:
- Keep numeric fields as `Double?` while typing to represent “empty” cleanly; convert to `Double` for request creation using defaults (or treat empty as invalid with an error).

#### `RecipeStepDraft`
Purpose: editable step with stable identity for list diffing and targeted validation highlighting.
- `id: UUID` (maps to `RecipeStepDTO.stepId`)
- `orderIndex: Int` (kept in sync with array order)
- `instructionText: String`
- `timerDurationSeconds: Double?`
- `waterAmountGrams: Double?`
- `isCumulativeWaterTarget: Bool`

#### `RecipeEditValidationState`
Purpose: pre-validation + server/use-case validation results, plus UI mapping for anchoring.
- `errors: [RecipeValidationError]` (union of draft validation + latest save attempt validation)
- `issueCount: Int` (usually `errors.count`, but may de-duplicate repeated cases)
- `firstAnchor: ValidationAnchor?`
- `fieldErrors: RecipeEditFieldErrors`
- `stepErrorMap: [UUID: [RecipeValidationError]]`
- `waterMismatch: RecipeEditWaterMismatchState?`
- `isValid: Bool`

#### `RecipeEditWaterMismatchState`
Purpose: special emphasis behavior when water total mismatch exists.
- `expectedYield: Double`
- `actualWaterTotal: Double`
- `offendingStepIds: Set<UUID>` (usually the step(s) with the max cumulative water target)

#### `RecipeEditFieldErrors`
Purpose: inline per-field strings, independent of raw validation enum cases.
- `name: String?`
- `dose: String?`
- `yield: String?`
- `temperature: String?` (optional; only if you enforce a min > 0)
- `steps: String?` (e.g., “Add at least one step”)

#### `ValidationAnchor`
Purpose: scroll targets for “Jump to first issue”.
Suggested cases:
- `.name`
- `.dose`
- `.yield`
- `.temperature`
- `.grind`
- `.tactileDescriptor`
- `.step(id: UUID)`

#### `RecipeEditEvent`
Purpose: explicit event surface (optional, but recommended for testability).
Cases:
- `nameChanged(String)`
- `doseChanged(Double?)`
- `yieldChanged(Double?)`
- `temperatureChanged(Double?)`
- `grindLabelChanged(GrindLabel)`
- `tactileDescriptorChanged(String)`
- `addStepTapped`
- `moveSteps(from: IndexSet, to: Int)`
- `deleteStep(UUID)`
- `stepInstructionChanged(stepId: UUID, text: String)`
- `stepTimerChanged(stepId: UUID, seconds: Double?)`
- `stepWaterChanged(stepId: UUID, grams: Double?)`
- `stepCumulativeChanged(stepId: UUID, isCumulative: Bool)`
- `cancelTapped`
- `saveTapped`
- `jumpToFirstIssueTapped`

### Use case integration type
To match the API plan intent and existing `BrewLogUseCase` pattern, introduce a recipe use case abstraction (even if the first implementation simply wraps repository operations).

#### `protocol RecipeUseCaseProtocol`
- `func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO`
- `func updateCustomRecipe(_ request: UpdateRecipeRequest) -> Result<Void, [RecipeValidationError]>`

#### `final class RecipeUseCase: RecipeUseCaseProtocol` (recommended)
Dependencies:
- `private let repository: RecipeRepository`
Responsibilities:
- Enforce **starter immutability** (reject update if `recipe.isStarter == true`).
- Validate `UpdateRecipeRequest` via `request.validate()` and return validation errors.
- Apply updates:
  - `recipe.update(from: request)`
  - Replace steps by deleting existing steps and inserting new `RecipeStep(from:dto:recipe:)` with updated `orderIndex` and relationships
- Persist with `try repository.save()`

## 6. State Management
- **Pattern**: Domain-first MVVM with `@Observable` view model (`@MainActor`), SwiftUI view renders `RecipeEditViewState`.
- **Ownership**:
  - `RecipeEditView` owns the view model lifecycle (create once when `ModelContext` is available).
- **Draft lifecycle**:
  - On load success, VM creates `RecipeEditDraft` from `RecipeDetailDTO`.
  - VM keeps a `baselineDraft` (or baseline hash) to compute `isDirty`.
- **Validation lifecycle**:
  - VM runs “live” validation on every edit:
    - Field-level checks (empty/<=0/negative)
    - Step-level checks (negative timer/water)
    - Water total mismatch checks (based on current draft)
  - On save attempt, VM merges any `UpdateRecipeRequest.validate()` and use-case validation errors into `validation.errors`.
- **Save flow state**:
  - When saving: `isSaving = true`, disable editing + buttons.
  - On success: `isSaving = false`, `isDirty = false`, dismiss/pop.
  - On failure:
    - If validation errors: show them inline + summary banner.
    - If persistence error: show `saveErrorMessage` alert.

## 7. API Integration
This view is offline-first and uses internal SwiftData-backed repositories/use-cases (not HTTP).

### Load
- **Repository call**: `RecipeRepository.fetchRecipe(byId: recipeId) throws -> Recipe?`
- **Validation**: `RecipeRepository.validate(recipe) -> [RecipeValidationError]`
- **Mapping**: `recipe.toDetailDTO(isValid: validationErrors.isEmpty) -> RecipeDetailDTO`
- **Custom-only guardrail**:
  - If `recipe.isStarter == true`: show non-editable error UI and provide “Duplicate” (optional) or instruct user to go back (defensive).

### Save
- **Request type**: `UpdateRecipeRequest` (from `RecipeDTOs.swift`)
  - `id`, `name`, `defaultDose`, `defaultTargetYield`, `defaultWaterTemperature`, `defaultGrindLabel`, `grindTactileDescriptor`, `steps: [RecipeStepDTO]`
- **Validation**: `UpdateRecipeRequest.validate() -> [RecipeValidationError]`
- **Use-case call** (target API): `RecipeUseCase.updateCustomRecipe(request) -> Result<Void, [RecipeValidationError]>`
  - Success: persist and return `.success(())`
  - Failure: `.failure([RecipeValidationError])` for fixable issues

## 8. User Interactions
- **Edit text fields**:
  - Immediate inline validation under the field (no modal alerts).
  - Summary banner updates live.
- **Add step**:
  - Appends a new step at end with:
    - `instructionText = ""`
    - no timer/water by default
  - Automatically scrolls to the new step (recommended).
- **Reorder steps**:
  - Enabled via standard reorder interaction (EditButton + drag handles) or always-on reorder if you provide handles.
  - After reorder: update all `orderIndex` values to be contiguous 0…n-1.
  - Re-run validation.
- **Toggle timer/water**:
  - Enabling creates default values (e.g., timer = 0 seconds, water = 0 grams) but should still validate; consider leaving nil until user enters a value (preferred to avoid “0” silently counting toward totals).
  - Disabling sets value back to `nil` and clears any related validation errors.
- **Delete step**:
  - Confirm deletion if you expect frequent mis-taps (optional; MVP can delete without confirmation if undo exists; otherwise confirm is safer).
  - If deleting would result in zero steps, validation should block save and show “Add at least one step”.
- **Cancel**:
  - If not dirty: pop immediately.
  - If dirty: show confirmation dialog with “Discard changes” (destructive) and “Keep editing”.
- **Save**:
  - Disabled until draft is valid.
  - When tapped: save and pop on success.
  - On validation failure: remain on screen and jump to first issue (optional automatic jump; at minimum keep banner button).
- **Jump to first issue**:
  - Scrolls to the relevant anchor and (optionally) focuses the field.

## 9. Conditions and Validation
Validation must align with PRD + existing `RecipeValidationError` and `UpdateRecipeRequest.validate()`:

### Recipe-level (blocks save)
- **Name**: non-empty after trimming → `.emptyName`
- **Defaults**:
  - `defaultDose > 0` → `.invalidDose`
  - `defaultTargetYield > 0` → `.invalidYield`
- **Steps**: at least 1 → `.noSteps`
- **Starter immutability**: editing a starter is rejected → `.starterCannotBeModified`

### Step-level (blocks save)
- **Timer**: if present, must be \(>= 0\) → `.negativeTimer(stepIndex:)`
- **Water**: if present, must be \(>= 0\) → `.negativeWaterAmount(stepIndex:)`
- **Ordering**: enforce contiguous `orderIndex` based on UI ordering (treat as internal invariant; fix automatically rather than show an error).

### Water total mismatch (special emphasis)
Current repository/request validation assumes **cumulative water targets** and checks:
- \( \max(waterAmountGrams) \) must match `defaultTargetYield` within ±1g.
- If mismatch: `.waterTotalMismatch(expected: defaultTargetYield, actual: maxWater)`

UI expectations for mismatch:
- Highlight the **yield field** and the step(s) that define the final cumulative water target:
  - Offender heuristic: any step where `isCumulativeWaterTarget == true` and `waterAmountGrams == maxWater` (within a small epsilon).
- Banner should include a dedicated callout for water mismatch.

### “Can Save” gating
`canSave == validation.isValid && !isSaving && isDirty` (recommended: allow saving even if not dirty? typically disable if no changes).

## 10. Error Handling
- **Recipe not found** (deleted or bad ID):
  - Show `ContentUnavailableView("Recipe Not Found", ...)` + Back.
- **Attempt to edit a starter** (should not happen):
  - Show a message and provide:
    - “Duplicate to edit” button (optional) or
    - navigate back.
- **Persistence/save error** (SwiftData failure):
  - Show an alert with a retry option; keep draft intact.
- **Validation errors from save**:
  - Do not dismiss.
  - Show banner + inline field/step errors.
  - Keep Save disabled until resolved.
- **Race conditions**:
  - If recipe becomes invalid due to external edits/sync while editing:
    - treat it like any other invalid draft; require fixes before save.
  - If recipe deleted while editing:
    - save should fail gracefully; show “Recipe no longer exists” and pop or offer to duplicate as new (optional).

## 11. Implementation Steps
1. **Create feature folder** (recommended):
   - `BrewGuide/BrewGuide/UI/Screens/Recipes/RecipeEdit/`
   - Files:
     - `RecipeEditView.swift`
     - `RecipeEditViewModel.swift`
     - `RecipeEditViewState.swift` (types: `RecipeEditViewState`, `RecipeEditDraft`, etc.)
     - `Components/ValidationSummaryBanner.swift`
     - `Components/RecipeDefaultsSection.swift`
     - `Components/StepsEditorSection.swift`
     - `Components/StepEditorCard.swift`
     - `Components/BottomActionBar.swift`
2. **Define draft and validation types** in `RecipeEditViewState.swift`:
   - `RecipeEditDraft`, `RecipeStepDraft`, `RecipeEditValidationState`, `ValidationAnchor`
3. **Implement `RecipeEditViewModel` (`@Observable`, `@MainActor`)**:
   - Dependencies: `RecipeUseCaseProtocol` (or repository directly for load + save)
   - Methods:
     - `load()` to fetch `RecipeDetailDTO` and seed draft
     - `handle(_ event: RecipeEditEvent)` for all mutations
     - `recomputeValidation()` on each edit
     - `saveTapped()` builds `UpdateRecipeRequest` and calls use-case; merges returned errors into `validation`
4. **Implement live validation mapping**:
   - Convert `RecipeValidationError` to:
     - `fieldErrors` (e.g., `.emptyName` → name error)
     - `stepErrorMap` keyed by `RecipeStepDraft.id`:
       - Use `stepIndex` (orderIndex) mapping to current draft step identity.
   - Compute `firstAnchor` deterministically (e.g., prefer name → dose → yield → steps).
5. **Build `RecipeEditScreen` UI**:
   - Use `ScrollViewReader` and attach `.id(anchor)` to each field/step container.
   - Place `ValidationSummaryBanner` at top and wire jump action to `proxy.scrollTo(...)`.
   - Render inline errors under the corresponding rows/cards.
6. **Steps editing UX**:
   - Implement add/delete/reorder.
   - Ensure reorder updates `orderIndex` and preserves stable `id`.
   - Ensure step numbers display 1-based index, while errors use `.negativeTimer(stepIndex:)` which is currently based on 0-based `orderIndex` (display should match `localizedDescription` which already adds 1).
7. **Save/Cancel UX**:
   - Add `BottomActionBar` via `.safeAreaInset(edge: .bottom)`.
   - Add discard confirmation for dirty cancel/back.
8. **Wire navigation**:
   - Ensure `AppRootView`/Recipes stack routes `.recipeEdit(id:)` correctly.
   - Ensure `RecipeDetailView` uses the route for custom “Edit”.
   - Ensure duplicate flow routes to edit.
9. **Add targeted unit tests** (recommended, Swift Testing):
   - Draft validation logic:
     - Empty name → `.emptyName`
     - Negative timer/water → correct error
     - Water mismatch identifies offending step IDs
   - Save gating:
     - `canSave` false when invalid / saving / not dirty
   - Event handling:
     - Reorder updates contiguous `orderIndex`
