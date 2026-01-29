## View Implementation Plan: RecipeDetailView

## 1. Overview
`RecipeDetailView` displays a single recipe’s details: name, default brew parameters (dose/yield/temp/grind + tactile descriptor), and the full ordered step list. It provides a **prominent “Use this recipe”** action that selects the recipe for brewing and returns to the brew entry flow (`ConfirmInputsView`). For **custom recipes**, it also provides **Edit** and **Delete (confirm)** actions. For **starter recipes**, it enforces immutability by **removing Edit/Delete** affordances and instead offering **Duplicate** to create an editable custom copy.

The screen must be optimized for “kitchen counter” use: readable at arm’s length, minimal cognitive load, and clear destructive confirmations. It must work offline (SwiftData local-first) and handle missing/deleted recipes gracefully.

## 2. View Routing
- **Route enum**: `RecipesRoute.recipeDetail(id: UUID)` (already defined in `BrewGuide/BrewGuide/UI/AppShell/NavigationRoutes.swift`).
- **Navigation host**: Recipes tab `NavigationStack(path:)` inside `AppRootView` maps `.recipeDetail(id:)` to `RecipeDetailView`.
- **Entry points**:
  - From `RecipeListView` row tap → `coordinator.recipesPath.append(.recipeDetail(id: recipeId))`.
  - (Optional) From `ConfirmInputsView` “selected recipe header” tap → same route (nice-to-have).
- **Exit/back behavior**:
  - Standard back navigation pops to the prior screen (usually `RecipeListView`).
  - “Use this recipe” should:
    - Persist selection (`PreferencesStore.lastSelectedRecipeId = recipeId`)
    - Pop back to the previous screen (`dismiss()`), or if your Recipes tab root is `ConfirmInputsView`, pop to that root (recommended: coordinator helper to pop to root).

## 3. Component Structure
High-level hierarchy (SwiftUI):

```
RecipeDetailView (screen entry; owns VM)
└─ RecipeDetailScreen
   ├─ LoadingStateView (ProgressView)
   ├─ ErrorStateView (ContentUnavailableView + Retry)
   └─ ScrollView/List content (when loaded)
      ├─ RecipeHeader
      │  ├─ Title
      │  └─ BadgeRow (Starter / Invalid / Conflicted Copy)
      ├─ DefaultsSummaryCard
      ├─ StepsSection
      │  └─ ForEach(steps) → RecipeStepRow
      └─ FooterSpacing (so CTA doesn’t overlap content)
   └─ PrimaryActionBar (safeAreaInset bottom)
      └─ Button: “Use this recipe”
```

Supporting/reusable components (recommended):
- `RecipeBadgePillRow`: consistent badge rendering used across Recipes UI.
- `RecipeDefaultsInline` or a dedicated `DefaultsSummaryCard` for this screen.
- `RecipeStepRow`: renders step number + instruction + optional timer + optional water target.
- `RecipeDetailToolbarActions`: renders `Duplicate` / `Edit` / `Delete` actions based on recipe origin.

## 4. Component Details

### RecipeDetailView
- **Purpose**: Screen entry that wires environment dependencies into the view model and owns the view-model lifecycle.
- **Main elements**:
  - `RecipeDetailScreen(...)`
  - `.toolbar { RecipeDetailToolbarActions(...) }`
  - `.confirmationDialog` (or `.alert`) for delete confirmation
  - `.alert` for invalid-recipe “cannot use” guidance (optional but recommended)
- **Handled events**:
  - `.task` on first appearance: initialize `RecipeDetailViewModel` and call `load()`
  - Pull-to-refresh (optional): `await viewModel.load()`
  - Toolbar actions: Duplicate/Edit/Delete
  - “Use this recipe”
- **Props**:
  - `recipeId: UUID` (source of truth for what to load)
  - Optional injection hooks for testability:
    - `repositoryFactory: (ModelContext) -> RecipeRepository` (default uses `RecipeRepository(context:)`)
    - `preferences: PreferencesStore` (default `.shared`)

### RecipeDetailScreen
- **Purpose**: Pure rendering based on view-model outputs; no SwiftData calls.
- **Main elements**:
  - Loading: `ProgressView("Loading recipe...")`
  - Error: `ContentUnavailableView("Error Loading Recipe", ...)` + “Retry”
  - Loaded content:
    - `RecipeHeader(detail: dto)`
    - `DefaultsSummaryCard(detail: dto)`
    - `StepsSection(steps: dto.steps)`
  - Bottom CTA bar (`PrimaryActionBar`)
- **Handled events**:
  - Retry: `onRetry()`
  - Use: `onUseRecipe()`
- **Props**:
  - `state: RecipeDetailViewState` (or individual fields: `isLoading`, `detail`, `error`)
  - `isUseEnabled: Bool`
  - `onRetry: () -> Void`
  - `onUseRecipe: () -> Void`

### RecipeHeader
- **Purpose**: Show recipe name and high-signal badges (Starter / Invalid / Conflicted Copy).
- **Main elements**:
  - Title: `Text(dto.recipe.name)`
  - Badges: `RecipeBadgePillRow`
- **Handled events**: none
- **Props**:
  - `summary: RecipeSummaryDTO`

### DefaultsSummaryCard
- **Purpose**: Display recipe defaults in a compact, scannable card.
- **Main elements**:
  - Dose (g, 0.1 precision)
  - Target yield (g, 0 precision)
  - Temperature (°C, 0 precision)
  - Grind label + optional tactile descriptor
  - (Optional) Derived ratio `summary.defaultRatio` as a secondary line
- **Handled events**: none
- **Props**:
  - `detail: RecipeDetailDTO`

### StepsSection
- **Purpose**: Show ordered step list with numbers and quantitative cues.
- **Main elements**:
  - `ForEach(steps.sorted(by: \.orderIndex))` (DTO should already be ordered)
  - `RecipeStepRow(stepNumber: index + 1, step: step, totalYield: detail.recipe.defaultTargetYield)`
- **Handled events**: none
- **Props**:
  - `steps: [RecipeStepDTO]`
  - `defaultTargetYield: Double` (optional; can help label “Pour to X g” relative to final target)

### RecipeStepRow
- **Purpose**: Render one step with strong readability and “kitchen-proof” cues.
- **Main elements**:
  - Step number label (e.g., “Step 3”)
  - Instruction text
  - Timer pill (if `timerDurationSeconds != nil`): display as \(mm:ss\) or \(m:ss\)
  - Water pill (if `waterAmountGrams != nil`):
    - If `isCumulativeWaterTarget == true`: label as “Pour to \(grams) g”
    - Else: label as “Add \(grams) g”
- **Handled events**: none (avoid `onTapGesture`; keep it static)
- **Props**:
  - `stepNumber: Int`
  - `step: RecipeStepDTO`

### PrimaryActionBar
- **Purpose**: Keep “Use this recipe” prominent and consistent with brew entry flow.
- **Main elements**:
  - `.safeAreaInset(edge: .bottom)` container
  - `Button("Use this recipe", action: onUse)` styled as `.borderedProminent`
  - Optional helper text when disabled (e.g., “Fix this recipe before brewing”)
- **Handled events**:
  - Tap: `onUse()`
- **Props**:
  - `isEnabled: Bool`
  - `onUse: () -> Void`

### RecipeDetailToolbarActions
- **Purpose**: Expose contextual actions while enforcing starter immutability.
- **Main elements** (conditional):
  - If starter: `Duplicate` button
  - If custom:
    - `Edit` button
    - `Delete` button (destructive; triggers confirmation)
  - Optional: show nothing when loading
- **Handled events**:
  - Duplicate/Edit/Delete taps delegate to view-model methods
- **Props**:
  - `summary: RecipeSummaryDTO`
  - `onDuplicate: () -> Void`
  - `onEdit: () -> Void`
  - `onRequestDelete: () -> Void`

## 5. Types

### Existing DTOs (no changes required)
- `RecipeSummaryDTO` (`BrewGuide/BrewGuide/Domain/DTOs/RecipeDTOs.swift`)
  - `id: UUID`
  - `name: String`
  - `method: BrewMethod`
  - `isStarter: Bool`
  - `origin: RecipeOrigin`
  - `isValid: Bool`
  - `defaultDose: Double`
  - `defaultTargetYield: Double`
  - `defaultWaterTemperature: Double`
  - `defaultGrindLabel: GrindLabel`
  - `defaultRatio: Double` (computed)
- `RecipeDetailDTO` (`…/RecipeDTOs.swift`)
  - `recipe: RecipeSummaryDTO`
  - `grindTactileDescriptor: String?`
  - `steps: [RecipeStepDTO]`
- `RecipeStepDTO` (`…/RecipeDTOs.swift`)
  - `stepId: UUID`
  - `orderIndex: Int`
  - `instructionText: String`
  - `timerDurationSeconds: Double?`
  - `waterAmountGrams: Double?`
  - `isCumulativeWaterTarget: Bool`

### New UI types (recommended)

#### `RecipeDetailViewState`
Purpose: single rendering source of truth for the screen.
- `isLoading: Bool`
- `detail: RecipeDetailDTO?`
- `error: RecipeDetailErrorState?`

#### `RecipeDetailErrorState`
Purpose: provide user-facing messaging + retry affordance.
- `message: String`
- `isRetryable: Bool` (always `true` for local fetch errors; used to hide Retry when not applicable)

#### `RecipeDetailActionError`
Purpose: distinguish between load errors and action errors (duplicate/delete).
- `message: String`

#### `RecipeDetailPendingDeletion`
Purpose: drive confirmation dialog content.
- `recipeId: UUID`
- `recipeName: String`

### View-model

#### `RecipeDetailViewModel` (`@Observable`, `@MainActor`)
Purpose: orchestrate loading, mapping to DTOs, and actions (use/duplicate/edit/delete) without embedding business rules in views.

Fields:
- **Identity**
  - `let recipeId: UUID`
- **State**
  - `private(set) var state: RecipeDetailViewState`
  - `private(set) var pendingDeletion: RecipeDetailPendingDeletion?`
  - `private(set) var actionError: RecipeDetailActionError?`
  - `private(set) var isPerformingAction: Bool` (true during duplicate/delete)
- **Derived UI flags**
  - `var canUseRecipe: Bool` (loaded && `detail.recipe.isValid == true`)
  - `var canEdit: Bool` (loaded && not starter)
  - `var canDelete: Bool` (loaded && not starter)
  - `var canDuplicate: Bool` (loaded; true for starter and custom)
- **Dependencies**
  - `private let repository: RecipeRepository`
  - `private let preferences: PreferencesStore`

Methods:
- `func load() async`
  - Fetch `Recipe` via repository, validate, map to `RecipeDetailDTO`
- `func useRecipe()`
  - Persist selection (`preferences.lastSelectedRecipeId = recipeId`)
- `func requestDelete()`
  - Populate `pendingDeletion`
- `func confirmDelete() async -> Bool`
  - Delete custom recipe, save, return success (caller decides navigation pop)
- `func cancelDelete()`
- `func duplicateRecipe() async -> UUID?`
  - Duplicate, save, return new recipe ID

Notes:
- Use `RecipeRepository.validate(_:)` and map `Recipe.toDetailDTO(isValid:)` using `BrewGuide/BrewGuide/Domain/DTOs/MappingExtensions.swift`.
- Keep all UI-facing properties on the main actor (`@MainActor` per repo rules).

## 6. State Management
- **Pattern**: Domain-first MVVM with SwiftUI + `@Observable` view-models (`@MainActor`).
- **Ownership**:
  - `RecipeDetailView` owns the view model lifecycle using `@State private var viewModel: RecipeDetailViewModel?` (initialized once environment dependencies are available).
- **Loading flow**:
  - On first `.task`, create `RecipeRepository(context: modelContext)` and `RecipeDetailViewModel(recipeId: recipeId, repository: ..., preferences: .shared)`
  - Call `await viewModel.load()`
- **UI state**:
  - Loading: `state.isLoading == true`
  - Loaded: `state.detail != nil`
  - Error: `state.error != nil`
  - Delete dialog: `pendingDeletion != nil`
  - Action in progress: disable toolbar/buttons when `isPerformingAction == true`

No custom “hook” system is required in SwiftUI. If you want to reuse formatting logic, add small formatter helpers (e.g., `DurationFormatter`) under `UI/Styles/` or a feature-local file.

## 7. API Integration
This view integrates with the internal repositories (SwiftData-backed), not an HTTP API.

### Read: Recipe detail
- **Repository call**: `RecipeRepository.fetchRecipe(byId: UUID) throws -> Recipe?`
- **Mapping**:
  - `let validationErrors = repository.validate(recipe)`
  - `let dto = recipe.toDetailDTO(isValid: validationErrors.isEmpty)`
- **Response type consumed by UI**: `RecipeDetailDTO`

### Duplicate
- **Repository call**: `RecipeRepository.duplicate(_ source: Recipe) throws -> Recipe`
- **Persistence**: `try repository.save()`
- **UI behavior**:
  - On success, navigate to `RecipesRoute.recipeEdit(id: newRecipe.id)` (recommended) or to `RecipesRoute.recipeDetail(id: newRecipe.id)`

### Delete (custom only)
- **Repository call**: `RecipeRepository.deleteCustomRecipe(_ recipe: Recipe) throws`
- **Persistence**: `try repository.save()`
- **Guardrail**: starters throw `RecipeRepositoryError.cannotDeleteStarterRecipe` (should be unreachable if UI hides Delete)

### Select for brewing (“Use this recipe”)
- **Preferences store**: `PreferencesStore.shared.lastSelectedRecipeId = recipeId`
- **No network**; works offline.

## 8. User Interactions
- **Back navigation**: pops to previous screen; no data mutation.
- **Use this recipe**:
  - If recipe is valid: persist `lastSelectedRecipeId`, then dismiss/pop.
  - If recipe is invalid: show an alert explaining it can’t be brewed until fixed; offer “Edit” (custom only) and “Cancel”.
- **Duplicate**:
  - Creates a custom copy, saves it.
  - Navigate to edit (recommended) to immediately tweak the copy.
  - If duplication fails: show non-blocking error alert.
- **Edit (custom only)**:
  - Navigate to `RecipesRoute.recipeEdit(id: recipeId)`.
- **Delete (custom only)**:
  - Show confirmation dialog:
    - Title: “Delete recipe?”
    - Message: “This cannot be undone.”
    - Actions: Delete (destructive), Cancel
  - On confirm: delete + save, then pop back (recipe no longer exists).
- **Pull-to-refresh** (optional):
  - Re-run `load()`; useful after conflicts/sync or edits.

## 9. Conditions and Validation
- **Starter immutability** (PRD + API plan):
  - If `detail.recipe.isStarter == true` OR `detail.recipe.origin == .starterTemplate`:
    - Hide Edit/Delete controls.
    - Show Duplicate control.
- **Custom deletion**:
  - Only show Delete for non-starter, non-template recipes.
  - Confirm before deleting (PRD US-027).
- **Brewability gate** (PRD US-026):
  - If `detail.recipe.isValid == false`:
    - Disable “Use this recipe”
    - Provide clear explanation and a path to edit/fix (custom only).
- **Step rendering rules**:
  - Timer: show only if `timerDurationSeconds != nil` and \(>= 0\).
  - Water: show only if `waterAmountGrams != nil` and \(>= 0\).
  - Ordering: render in ascending `orderIndex`.
- **Accessibility constraints**:
  - Ensure primary controls meet 44×44pt minimum.
  - Use Dynamic Type-friendly layouts (avoid hard-coded font sizes).

## 10. Error Handling
- **Recipe not found**:
  - Likely deleted or missing seed; show `ContentUnavailableView("Recipe Not Found", ...)` with a short explanation.
  - Optionally provide a “Back” button (navigation already provides).
- **Load failure (SwiftData fetch throws)**:
  - Show error state with Retry.
  - Log via `OSLog` in the view model.
- **Action failures**:
  - Duplicate failed: show alert “Could not duplicate recipe. Please try again.”
  - Delete failed: show alert; keep the screen (do not pop) so user can retry or back out.
- **Race conditions**:
  - Recipe deleted while on screen: next refresh/load results in not found; downgrade to not-found state.
  - Duplicate then immediate navigation: ensure `repository.save()` completes before navigating.

## 11. Implementation Steps
1. **Create screen files** under `BrewGuide/BrewGuide/UI/Screens/Recipes/RecipeDetail/` (feature-first grouping).
   - `RecipeDetailView.swift` (entry)
   - `RecipeDetailViewModel.swift`
   - `Components/RecipeHeader.swift`, `DefaultsSummaryCard.swift`, `RecipeStepRow.swift`, `PrimaryActionBar.swift` (optional foldering)
2. **Define view-model state types**:
   - `RecipeDetailViewState`, `RecipeDetailErrorState`, `RecipeDetailPendingDeletion`
3. **Implement `RecipeDetailViewModel`**:
   - `load()`:
     - `fetchRecipe(byId:)`
     - validate + map via `recipe.toDetailDTO(isValid:)`
     - set `state.detail` or `state.error`
   - `useRecipe()`:
     - update `PreferencesStore.shared.lastSelectedRecipeId`
   - `duplicateRecipe()`:
     - fetch entity, call `duplicate`, `save`, return new ID
   - delete flow:
     - `requestDelete()` → `pendingDeletion`
     - `confirmDelete()` → `deleteCustomRecipe` + `save`
4. **Implement `RecipeDetailScreen` rendering**:
   - Loading/error/loaded states
   - Steps list UI per spec (numbers + timer + water target)
   - Bottom “Use this recipe” bar with disabled state when invalid or loading
5. **Add toolbar actions**:
   - Starter: Duplicate only
   - Custom: Edit + Delete
6. **Wire navigation**:
   - Ensure `AppRootView`’s `.navigationDestination(for: RecipesRoute.self)` renders `RecipeDetailView(recipeId:)` for `.recipeDetail(id:)` (replace any placeholder wrapper that passes a `Recipe` directly, so the screen uses repository → DTO as intended).
7. **Connect “Use this recipe” to brew entry**:
   - Set preference, then dismiss/pop.
   - If Recipes tab root is `ConfirmInputsView`, ensure it re-reads `PreferencesStore.lastSelectedRecipeId` on appear (or via an explicit refresh trigger) so selection is reflected immediately.
8. **Add confirmations and alerts**:
   - Delete confirmation dialog
   - Invalid recipe “cannot use” alert with Edit path
9. **Add lightweight unit tests** (recommended):
   - View-model mapping and state transitions using a fake `RecipeRepository` (or in-memory SwiftData container in tests).
   - Scenarios: load success, load not found, delete custom success, delete starter blocked, invalid recipe disables use.
