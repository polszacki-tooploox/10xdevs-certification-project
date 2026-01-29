## View Implementation Plan: RecipeListView

## 1. Overview
`RecipeListView` is the recipe browser/selector screen reachable from the Recipes tab (Brew entry / `ConfirmInputsView`). It lists the single starter V60 recipe plus any custom recipes, supports navigating into recipe detail, and allows selecting exactly one recipe to use for brewing (persisting selection to preferences and returning to `ConfirmInputsView`). Custom recipes can be deleted with confirmation.

This view must be “kitchen-proof”: large tap targets, minimal friction, clear destructive confirmations, and offline-first behavior (no network required).

## 2. View Routing
- **Entry point**: Recipes tab root (`ConfirmInputsView`) toolbar button pushes `RecipesRoute.recipeList`.
- **Route enum**: `RecipesRoute.recipeList` (already defined in `BrewGuide/BrewGuide/UI/AppShell/NavigationRoutes.swift`).
- **Navigation host**: `AppRootView` → `RecipesTabRootView` (`NavigationStack(path:)`) already registers `.navigationDestination(for: RecipesRoute.self)` and maps `.recipeList` → `RecipeListView()`.
- **Exit/back behavior**:
  - Back navigation returns to `ConfirmInputsView` (pop one level).
  - “Use this recipe” should also return to `ConfirmInputsView` after persisting selection.

## 3. Component Structure
High-level hierarchy (SwiftUI):

```
RecipeListView
└─ RecipeListScreen
   ├─ LoadingStateView (optional)
   ├─ ErrorStateView (optional)
   └─ List
      ├─ Section("Starter")
      │  └─ ForEach(starterRecipes) → RecipeListRow
      ├─ Section("My Recipes")
      │  └─ ForEach(customRecipes) → RecipeListRow
      └─ ContentUnavailableView (empty state)
```

Supporting presentation components (recommended):
- `RecipeListRow`: row layout + badges + compact defaults.
- `RecipeBadgePillRow`: visual badges (Starter / Invalid / Conflicted Copy).
- `RecipeDefaultsInline`: compact defaults line (dose/yield/temp/grind; optional ratio).

## 4. Component Details

### RecipeListView
- **Purpose**: SwiftUI entry that wires environment dependencies (model context, coordinator) into the screen/view-model and owns view-model lifecycle.
- **Main elements**:
  - `RecipeListScreen(viewModel: ..., onNavigateToDetail: ..., onUseRecipe: ...)`
  - `confirmationDialog` for deletion confirmation
- **Handled events**:
  - `onAppear`/`.task`: trigger initial load via view-model
  - Pull-to-refresh (optional): re-run load
  - Delete confirmation actions
- **Props**:
  - `method: BrewMethod = .v60` (optional initializer parameter; default to `.v60` for MVP)
  - If you want the view to be testable, accept factories:
    - `repositoryFactory: (ModelContext) -> RecipeRepository`
    - `preferences: PreferencesStore` (default `.shared`)

### RecipeListScreen
- **Purpose**: Pure rendering of the list based on view-model state; does not talk to SwiftData directly.
- **Main elements**:
  - A `List` with sections:
    - Starter recipes (usually 1 in MVP)
    - Custom recipes
  - `ContentUnavailableView` for “no recipes” (unexpected for MVP; starter should be seeded)
  - Optional `ProgressView` while loading
  - Optional error panel with Retry
- **Handled events**:
  - Row tap: navigate to detail
  - Leading swipe action “Use” (recommended) to select recipe quickly
  - Trailing swipe action “Delete” for custom recipes only
  - Optional trailing swipe action “Duplicate” (nice-to-have; MVP can omit)
- **Props** (component interface):
  - `recipes: RecipeListSections` (or `[RecipeSummaryDTO]` + derived grouping)
  - `isLoading: Bool`
  - `error: RecipeListErrorState?` (message + retry action availability)
  - `onTapRecipe(id: UUID)`
  - `onUseRecipe(id: UUID)`
  - `onRequestDelete(id: UUID)` (requests confirmation; does not delete immediately)

### RecipeListRow
- **Purpose**: One-row, large-tap layout that remains readable with Dynamic Type and supports one-handed selection.
- **Main elements**:
  - **Title**: `Text(recipe.name)` (headline)
  - **Badges**: `RecipeBadgePillRow`:
    - Starter (`recipe.isStarter == true` or `recipe.origin == .starterTemplate`)
    - Invalid (`recipe.isValid == false`)
    - Conflicted copy (`recipe.origin == .conflictedCopy`)
  - **Compact defaults**: `RecipeDefaultsInline`:
    - Dose \(g, 0.1 precision\)
    - Yield \(g, 0 precision\)
    - Temp \(°C, 0 precision\)
    - Grind label
    - (Optional) ratio display, but keep it compact to avoid clutter
  - **Chevron** (optional) to indicate detail navigation
- **Handled events**:
  - Primary tap: navigate to detail (`onTap`)
  - Swipe leading “Use”: triggers `onUse`
  - Swipe trailing “Delete”: only for custom; triggers `onRequestDelete`
- **Validation handled**:
  - If `isValid == false`, still allow opening detail; allow “Use” only if your app gates brewing elsewhere (recommended).
    - If you want early guidance: allow “Use” but show an informational alert “This recipe is invalid and can’t be brewed until fixed.” (no silent failure).
- **Props**:
  - `recipe: RecipeSummaryDTO`
  - `onTap: () -> Void`
  - `onUse: () -> Void`
  - `onRequestDelete: (() -> Void)?` (nil for starter)
  - `onRequestDuplicate: (() -> Void)?` (optional, if supported)

### DeleteConfirmationDialog (presentation pattern)
- **Purpose**: Ensure deletions require explicit confirmation (PRD US-027).
- **Main elements**:
  - `confirmationDialog` title: “Delete recipe?” + message “This cannot be undone.”
  - Actions: Delete (destructive), Cancel
- **Handled events**:
  - Confirm delete triggers `viewModel.deleteRecipe(id:)`
  - Cancel clears pending delete state
- **Props**:
  - `pendingDeleteRecipeName: String?` (for clearer messaging)
  - `onConfirm`, `onCancel`

## 5. Types

### Existing DTOs (no changes required)
`RecipeSummaryDTO` (`BrewGuide/BrewGuide/Domain/DTOs/RecipeDTOs.swift`):
- `id: UUID`
- `name: String`
- `method: BrewMethod`
- `isStarter: Bool`
- `origin: RecipeOrigin` (`.starterTemplate`, `.custom`, `.conflictedCopy`)
- `isValid: Bool`
- `defaultDose: Double`
- `defaultTargetYield: Double`
- `defaultWaterTemperature: Double`
- `defaultGrindLabel: GrindLabel`
- `defaultRatio: Double` (computed)

### New ViewModel (recommended)
`@Observable @MainActor final class RecipeListViewModel`
- **Purpose**: Owns loading, grouping, selection, and delete flows using repositories + preferences (UI stays DTO-driven).
- **Fields**:
  - `method: BrewMethod` (default `.v60`)
  - `sections: RecipeListSections` (derived from recipes; starter + custom)
  - `isLoading: Bool`
  - `errorMessage: String?`
  - `pendingDelete: RecipeSummaryDTO?` (set when user initiates delete)
  - `isDeleting: Bool` (optional; disables destructive button while in progress)
- **Dependencies**:
  - `preferences: PreferencesStore` (default `.shared`)
  - `makeRepository: (ModelContext) -> RecipeRepository` (default `{ RecipeRepository(context: $0) }`)

### New helper types (recommended)
`struct RecipeListSections: Equatable`
- `starter: [RecipeSummaryDTO]`
- `custom: [RecipeSummaryDTO]`
- Optional: `all: [RecipeSummaryDTO]` if you want flattened access

`enum RecipeListErrorState: Equatable`
- `case loadFailed(message: String)`
- `case deleteFailed(message: String)`

`enum RecipeListAction`
- Optional, if you prefer event-based handling: `.tapRow(UUID)`, `.use(UUID)`, `.requestDelete(UUID)`, `.confirmDelete(UUID)`, `.retry`

## 6. State Management
Use Observation (`@Observable`) for the view-model and keep the view as a renderer:
- `RecipeListView` holds the view-model (e.g., `@State private var viewModel = RecipeListViewModel(method: .v60)`).
- Use `.task` to call `await viewModel.load(context: modelContext)` once on first appearance.
- Store pending destructive action state in the view-model (`pendingDelete`) so the dialog is driven by state, not ad-hoc logic.

No custom “hook” concept is needed in SwiftUI; the equivalent is:
- A view-model method set (`load`, `useRecipe`, `requestDelete`, `confirmDelete`) and
- small subviews for presentation.

## 7. API Integration
The view is offline-first and uses the internal repository API (SwiftData-backed).

### Requests (internal calls)
- **List**:
  - Repository: `RecipeRepository.fetchRecipes(for method: BrewMethod) throws -> [Recipe]`
  - Validation: `RecipeRepository.validate(_ recipe: Recipe) -> [RecipeValidationError]`
  - Mapping to DTO: `Recipe.toSummaryDTO(isValid:) -> RecipeSummaryDTO` (via `Domain/DTOs/MappingExtensions.swift`)

- **Delete custom recipe**:
  - Repository: `RecipeRepository.fetchRecipe(byId id: UUID) throws -> Recipe?`
  - Repository: `RecipeRepository.deleteCustomRecipe(_ recipe: Recipe) throws`

- **Persist selection**:
  - Preferences: `PreferencesStore.shared.lastSelectedRecipeId: UUID?` (setter)

### Responses / data shapes
- **List screen render**: `[RecipeSummaryDTO]` grouped into `RecipeListSections`
- **Delete**: `Void` on success; on failure show inline error message (keep list visible)

### Implementation details for loading
In `RecipeListViewModel.load(context:)`:
1. `isLoading = true`
2. `let recipes = try repository.fetchRecipes(for: method)`
3. For each `Recipe`:
   - `let isValid = repository.validate(recipe).isEmpty`
   - `let dto = recipe.toSummaryDTO(isValid: isValid)`
4. Split into sections:
   - `starter`: `dto.isStarter == true` (or `dto.origin == .starterTemplate`)
   - `custom`: others
5. Sort within each section by `name` using localized, user-friendly ordering (e.g. `localizedStandardCompare` on `String`).

## 8. User Interactions
- **Open recipe detail**:
  - User taps a row → `coordinator.recipesPath.append(.recipeDetail(id: recipe.id))`
  - Outcome: navigates to detail destination (currently `RecipeDetailNavigationView`).

- **Use this recipe**:
  - Recommended UI: leading swipe action “Use” (and/or a context menu action).
  - Action:
    - Set `PreferencesStore.shared.lastSelectedRecipeId = recipe.id`
    - Return to `ConfirmInputsView` by popping navigation:
      - Prefer `dismiss()` (simple pop) or `coordinator.resetToRoot(tab: .recipes)` (guaranteed return to root even if stacked deeper).
  - Outcome:
    - `ConfirmInputsView` loads the selected recipe as “current inputs” (or on next appearance/reload).

- **Delete custom recipe** (PRD US-027):
  - User triggers delete (swipe trailing “Delete” on custom recipes only).
  - App shows confirmation dialog.
  - On confirm:
    - View-model deletes via repository.
    - If deleted recipe was the last selected one:
      - Clear `PreferencesStore.shared.lastSelectedRecipeId` OR set it to the starter recipe ID (preferred if available).
  - Outcome: list updates, and brew entry won’t reference a deleted recipe.

- **Error retry**:
  - If load fails, show an inline error state with a “Retry” button that calls `load` again.

## 9. Conditions and Validation
Conditions to enforce at the UI/component level:
- **Deletion constraints**:
  - Starter recipes **must not** expose a delete affordance.
  - Only `origin == .custom` (and possibly `.conflictedCopy`) should show delete.
  - Verification: check `RecipeSummaryDTO.isStarter` and/or `origin`.

- **Selection persistence**:
  - When the user selects “Use”, the view **must** set `PreferencesStore.shared.lastSelectedRecipeId` to the chosen recipe ID before navigating back.

- **List contents**:
  - Filter list by `method == .v60` for MVP.
  - Verification: view-model uses `fetchRecipes(for: method)` and does not display recipes from other methods.

- **Validity signaling** (PRD US-026):
  - Invalid recipes must be visibly marked in the list (badge like “Invalid”).
  - Verification: compute `isValid` using `RecipeRepository.validate(recipe).isEmpty`.
  - Optional UX: if user attempts “Use” on invalid recipe, show an informational alert explaining it can’t be brewed until fixed (even if the final gating happens on Start brew).

- **Ordering**:
  - Sort recipes by name within each section.
  - Starters first overall (matches API plan).

## 10. Error Handling
Potential error scenarios and handling:
- **Fetch recipes throws** (SwiftData failure, modelContext issue):
  - Show inline error state (keep navigation usable), with Retry.
  - Log with `OSLog` if desired.

- **Delete fails**:
  - `RecipeRepositoryError.cannotDeleteStarterRecipe` should be impossible if UI hides delete on starter; still handle defensively by showing a user message.
  - Other persistence failures: show alert/toast-style message and keep the row.

- **Recipe missing on delete** (race: already deleted elsewhere / sync):
  - Treat as success from UI perspective: reload list; clear pending delete; show “Recipe not found” only if needed.

- **Selection points to missing recipe**:
  - `ConfirmInputsViewModel.loadInitialRecipe` already falls back to “any recipe”; the list view should additionally clear stale `lastSelectedRecipeId` if it detects it points to a missing recipe after load (optional improvement).

## 11. Implementation Steps
1. **Create `RecipeListViewModel`** in `BrewGuide/BrewGuide/UI/Screens/RecipeListViewModel.swift` (new file):
   - Implement `load(context:)` to fetch, validate, map to `RecipeSummaryDTO`, group into `RecipeListSections`, and set `errorMessage` on failure.
   - Implement `requestDelete(recipeId:)` (sets `pendingDelete`).
   - Implement `confirmDelete(context:)` (fetch by id, delete with repo, handle lastSelectedRecipeId cleanup, reload).
   - Implement `useRecipe(id:)` (set preferences).

2. **Refactor `RecipeListView`** (`BrewGuide/BrewGuide/UI/Screens/RecipeListView.swift`) to be DTO-driven:
   - Remove direct `@Query` usage for list data (keep `ModelContext` for repository).
   - Instantiate and bind `RecipeListViewModel`.
   - Add `.task { await viewModel.load(context: modelContext) }`.

3. **Build presentational subviews** in `BrewGuide/BrewGuide/UI/Components/` (new files recommended):
   - `RecipeListRow` (pure rendering of `RecipeSummaryDTO`)
   - `RecipeBadgePillRow`
   - `RecipeDefaultsInline`
   - Ensure large tap targets and Dynamic Type friendliness.

4. **Wire navigation and selection**:
   - Row tap appends `.recipeDetail(id:)` to `coordinator.recipesPath`.
   - Leading swipe “Use” calls `viewModel.useRecipe(id:)` then returns to root (`dismiss()` or `coordinator.resetToRoot(tab: .recipes)`).

5. **Add delete flow with confirmation**:
   - Show delete swipe only for `origin != .starterTemplate`.
   - On delete swipe: set `pendingDelete`.
   - Present `confirmationDialog` bound to `pendingDelete != nil`.
   - On confirm: call `await viewModel.confirmDelete(context: modelContext)`.

6. **Add empty/error states**:
   - Empty: `ContentUnavailableView("No Recipes", ...)` (should rarely occur in MVP, but must be safe).
   - Error: show message + Retry button.

7. **Accessibility pass**:
   - Add `accessibilityLabel`/`accessibilityHint` for “Use” and “Delete”.
   - Ensure swipe actions have clear labels and the row remains usable with VoiceOver.

8. **(Optional) Unit tests** for `RecipeListViewModel`:
   - Provide fake repository + preferences store to test:
     - grouping/sorting
     - invalid badge computation behavior
     - lastSelectedRecipeId set on use
     - lastSelected cleanup on delete

