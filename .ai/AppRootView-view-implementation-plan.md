# View Implementation Plan AppRootView

## 1. Overview
`AppRootView` is the top-level SwiftUI shell for BrewGuide. It provides **persistent tab navigation** with exactly three tabs (Recipes / Logs / Settings), each owning its own `NavigationStack`, and it acts as a **centralized presentation host** for:

- A **Confirm Inputs modal** (`ConfirmInputsView`) presented from the Recipes tab (so it is not the Recipes tab root).
- The **full-screen brew flow modal** (`BrewSessionFlowView`) that runs the guided steps and transitions to `PostBrewView`.

Key goals:
- Preserve each tab’s navigation state when switching tabs (avoid losing scroll position / drafts).
- Ensure modals prevent accidental background interaction during brewing.
- Keep UI state in `@Observable` coordinators/view models (`@MainActor`), with SwiftUI views rendering state and sending intents.

## 2. View Routing
- **App entry**: `BrewGuideApp` → `WindowGroup` root should present `AppRootView` (replacing the current `ContentView` placeholder).
- **Tabs**:
  - Recipes tab root: `RecipeListView`
  - Logs tab root: `LogsListView`
  - Settings tab root: `SettingsView`
- **Modals (presented from `AppRootView`)**:
  - **Confirm inputs modal**: `ConfirmInputsView` (sheet or full-screen cover; recommended: sheet with large detent for quick dismissal back to recipe list).
  - **Brew flow modal**: `BrewSessionFlowView` as a **full-screen cover** (internally transitions to `PostBrewView`).

## 3. Component Structure
High-level component tree:

```text
AppRootView
└─ TabView(selection: AppTab)
   ├─ Tab(Recipes)
   │  └─ NavigationStack(path: recipesPath)
   │     └─ RecipeListView (root)
   │        └─ (navigates to RecipeDetailView / RecipeEditView via recipesPath)
   ├─ Tab(Logs)
   │  └─ NavigationStack(path: logsPath)
   │     └─ LogsListView (root)
   │        └─ (navigates to LogDetailView via logsPath)
   └─ Tab(Settings)
      └─ NavigationStack(path: settingsPath)
         └─ SettingsView (root)
            └─ (navigates to DataDeletionRequestView via settingsPath)

AppRootView (presentation host)
├─ sheet(item: confirmInputs)
│  └─ ConfirmInputsView
└─ fullScreenCover(item: activeBrewSession)
   └─ BrewSessionFlowView
      └─ PostBrewView (within flow, after completion)
```

## 4. Component Details

### AppRootView
- **Component description / purpose**: Owns tab selection, per-tab navigation state, and centralized modal presentation (Confirm inputs + brew flow). Provides shared coordinators via environment so child screens can request navigation or modal presentation without tight coupling.
- **Main elements**:
  - `TabView(selection:)` using the modern `Tab` API (not `tabItem()`).
  - Three `NavigationStack`s (one per tab) with independent `NavigationPath` state.
  - `.sheet(item:)` to present `ConfirmInputsView`.
  - `.fullScreenCover(item:)` to present `BrewSessionFlowView`.
- **Handled events**:
  - **Tab selection**: user switches between Recipes/Logs/Settings.
  - **Navigation**: push/pop within each tab via `NavigationPath` and `navigationDestination(for:)`.
  - **Confirm inputs presentation**: child view requests “brew this recipe” → AppRootView presents `ConfirmInputsView`.
  - **Brew flow presentation**: `ConfirmInputsView` produces a `BrewPlan` and requests start → AppRootView presents `BrewSessionFlowView`.
  - **Dismissal**:
    - Confirm inputs dismissed by user or after brew begins.
    - Brew flow dismissed on completion/discard.
- **Props (component interface)**:
  - Prefer **no direct props**; inject coordinators/dependencies via environment.
  - Optional initializer for testing/previews: `init(coordinator: AppRootCoordinator, dependencies: AppDependencies)`.

### RecipesTabRoot (internal, optional helper view)
- **Component description / purpose**: Wrapper around the Recipes `NavigationStack` and `RecipeListView` root; binds the recipes navigation path from `AppRootCoordinator`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.recipesPath)`
  - Root content: `RecipeListView(...)`
  - `.navigationDestination(for: RecipesRoute.self)` mapping to `RecipeDetailView`, `RecipeEditView` (and any other Recipes routes).
- **Handled events**:
  - **Open recipe detail**: push `.recipeDetail(id:)`.
  - **Edit custom recipe**: push `.recipeEdit(id:)`.
  - **Start brewing**:
    - From `RecipeListView` row action or toolbar action (e.g., “Brew”): call `coordinator.presentConfirmInputs(for:)`.
    - Optional behavior for PRD US-001: on first appearance, auto-present Confirm inputs for “last selected recipe” (or starter on first run) while still keeping the list as the root view.
- **Props**:
  - None if coordinator/dependencies are read from the environment.

### LogsTabRoot (internal, optional helper view)
- **Description / purpose**: Hosts logs navigation path and routes to `LogDetailView`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.logsPath)`
  - `LogsListView(...)`
  - `.navigationDestination(for: LogsRoute.self)` mapping to `LogDetailView`.
- **Handled events**: tap log → push detail.
- **Props**: none (environment-driven).

### SettingsTabRoot (internal, optional helper view)
- **Description / purpose**: Hosts settings navigation path and routes to `DataDeletionRequestView`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.settingsPath)`
  - `SettingsView(...)`
  - `.navigationDestination(for: SettingsRoute.self)` mapping to `DataDeletionRequestView`.
- **Handled events**: taps in Settings push screens.
- **Props**: none (environment-driven).

### ConfirmInputsModalHost (implemented inside AppRootView via `sheet`)
- **Description / purpose**: Centralized presentation of `ConfirmInputsView` as a modal so it is not the Recipes tab root.
- **Main elements**:
  - `.sheet(item: $coordinator.confirmInputs)` → `ConfirmInputsView(...)`
  - Recommended: use a large detent and visible dismissal affordance (kitchen-proof + low friction).
- **Handled events**:
  - **Dismiss**: user cancels or swipes down → `coordinator.dismissConfirmInputs()`.
  - **Start brew**: `ConfirmInputsView` requests start with a `BrewPlan` → coordinator:
    - dismisses confirm modal
    - presents brew flow full-screen (`presentBrewSession(plan:)`)
- **Props**:
  - Payload from coordinator (`ConfirmInputsPresentation`) (see Types).

### BrewModalHost (implemented inside AppRootView via `fullScreenCover`)
- **Description / purpose**: Centralized presentation point for the full-screen guided brew flow; prevents tab UI interaction while brewing by covering the entire screen.
- **Main elements**:
  - `.fullScreenCover(item: $coordinator.activeBrewSession)` → `BrewSessionFlowView(...)`
- **Handled events**:
  - `onFinish` / `onDiscard`: clear `activeBrewSession` (and optionally route to Logs tab as a UX enhancement).
- **Props**:
  - `BrewSessionPresentation` payload passed from coordinator (see Types).

## 5. Types

### AppTab (new)
Used to control `TabView` selection.

```swift
enum AppTab: Hashable, Codable {
    case recipes
    case logs
    case settings
}
```

### Navigation routes (new, type-safe)

```swift
enum RecipesRoute: Hashable {
    case recipeDetail(id: UUID)
    case recipeEdit(id: UUID)
}

enum LogsRoute: Hashable {
    case logDetail(id: UUID)
}

enum SettingsRoute: Hashable {
    case dataDeletionRequest
}
```

### ConfirmInputsPresentation (new)
Represents “Confirm inputs is currently presented.”

```swift
struct ConfirmInputsPresentation: Identifiable, Hashable {
    let id: UUID
    let inputs: BrewInputs
}
```

Notes:
- Uses the existing DTO `BrewInputs` (`Domain/DTOs/BrewSessionDTOs.swift`) to keep the modal stable and persistence-independent.
- `id` is created per presentation.

### Brew session presentation payload (new)

```swift
struct BrewSessionPresentation: Identifiable, Hashable {
    let id: UUID
    let plan: BrewPlan
}
```

Notes:
- Uses the existing DTO `BrewPlan` (`Domain/DTOs/BrewSessionDTOs.swift`).

### AppRootCoordinator (new `@Observable`, `@MainActor`)
Single source of truth for `AppRootView` UI state: selected tab, navigation paths per tab, and modal presentations.

Fields:
- `var selectedTab: AppTab`
- `var recipesPath: NavigationPath`
- `var logsPath: NavigationPath`
- `var settingsPath: NavigationPath`
- `var confirmInputs: ConfirmInputsPresentation?`
- `var activeBrewSession: BrewSessionPresentation?`

API (methods):
- `func presentConfirmInputs(inputs: BrewInputs)`
- `func dismissConfirmInputs()`
- `func presentBrewSession(plan: BrewPlan)` (guards against re-entrancy)
- `func dismissBrewSession()`
- Optional: `func resetToRoot(tab: AppTab)`

Concurrency notes:
- Mark the class `@MainActor`.
- Only mutate `NavigationPath` and modal state on the main actor.

### AppDependencies (optional)
If you centralize dependency injection:
- Persistence: `RecipeRepository`, `BrewLogRepository` (existing).
- Use-case facades (recommended long-term, even if thin initially):
  - `BrewSessionUseCase` (create plan, step progression orchestration)
  - `RecipeUseCase` (assert brewable, duplication/editing validation)
  - `BrewLogUseCase` (save/delete logs)
  - `AuthUseCase`, `SyncUseCase` (Settings)

## 6. State Management
Recommended approach:
- `AppRootView` owns a single coordinator instance:
  - `@State private var coordinator = AppRootCoordinator()`
- Provide it via `.environment(coordinator)` so child screens can request navigation and modal presentation:
  - `@Environment(AppRootCoordinator.self) private var coordinator`

State ownership:
- **AppRootCoordinator**:
  - selected tab
  - three navigation paths
  - confirm inputs modal presentation
  - brew session modal presentation
- **Feature view models** (outside this plan) should own domain logic; `AppRootView` only coordinates presentation.

## 7. API Integration
`AppRootView` should not call repositories or network services directly. It integrates via **presentation contracts**:

- **Present Confirm inputs** (from Recipes tab root):
  - Trigger: user taps a “Brew” action for a recipe in `RecipeListView`.
  - Payload: `BrewInputs` (existing DTO), constructed by Recipes feature using:
    - selected `Recipe`/`RecipeDetailDTO` defaults
    - preferences (`PreferencesStore.getLastSelectedRecipeId()`) as needed
  - `AppRootView` responsibility: present `ConfirmInputsView` by setting `coordinator.confirmInputs`.

- **Start brew flow** (from Confirm inputs modal):
  - Request type: `BrewInputs` (existing)
  - Response type: `BrewPlan` (existing)
  - Recommended operation: `BrewSessionUseCase.createPlan(inputs:) -> BrewPlan`
  - `AppRootView` responsibility: accept `BrewPlan` and present the brew flow via `coordinator.presentBrewSession(plan:)` (and dismiss Confirm inputs).

## 8. User Interactions
Within `AppRootView` scope:
- **Switch tabs**:
  - Outcome: selected tab changes; navigation stacks are preserved.
- **Open Confirm inputs from Recipes**:
  - User taps “Brew” for a recipe (or a default “Brew” action that uses last-selected).
  - Outcome: `ConfirmInputsView` appears as a modal over the Recipes list.
- **Start brew from Confirm inputs**:
  - Outcome: Confirm inputs modal dismisses; `BrewSessionFlowView` is presented full-screen (tab bar cannot be interacted with).
- **Finish/discard brew**:
  - Outcome: brew modal dismisses; user returns to the previous tab state (optionally switch to Logs as a product choice).

## 9. Conditions and Validation
Conditions `AppRootView` / coordinator must enforce or support:
- **Exactly 3 tabs**: Recipes / Logs / Settings.
- **Recipes tab root is `RecipeListView`**: Confirm inputs must never be the root of the Recipes tab.
- **Per-tab state preservation**:
  - Maintain separate `NavigationPath`s for each tab.
  - Do not reset a tab’s `NavigationPath` on tab switch.
- **Modal exclusivity**:
  - Do not present Confirm inputs while a brew session is active (ignore or queue; recommended: ignore with a log).
  - If Confirm inputs is visible and brew starts, dismiss Confirm inputs before showing the brew full-screen cover.
- **Brew modal guardrails**:
  - Only present brew modal when `plan.scaledSteps` is non-empty.
  - Brew flow should disable interactive dismissal and provide explicit exit confirmation (implemented inside brew flow, not in AppRootView).

## 10. Error Handling
`AppRootView` should keep error handling minimal:
- **Invalid presentation payload**:
  - If Confirm inputs payload is missing critical values (e.g. dose/yield ≤ 0), do not present; rely on the initiating screen’s validation and log via `OSLog`.
  - If brew `BrewPlan` has no steps, do not present; rely on the initiating screen to surface an actionable message.
- **Re-entrancy**:
  - Guard `presentConfirmInputs` and `presentBrewSession` when already presenting.
- **Not found routes**:
  - Navigation destinations (detail/edit screens) handle missing entities (deleted recipe/log) with inline “Not found” UI and a path back; AppRootView only routes.

## 11. Implementation Steps
1. **Add app-shell types**:
   - `AppTab`, `RecipesRoute`, `LogsRoute`, `SettingsRoute`
   - `ConfirmInputsPresentation`, `BrewSessionPresentation`
2. **Implement `AppRootCoordinator`** as `@Observable @MainActor`:
   - Store `selectedTab`, three `NavigationPath`s, and both modal states (`confirmInputs`, `activeBrewSession`).
   - Add `present/dismiss` methods with simple re-entrancy guards.
3. **Implement `AppRootView`**:
   - `TabView(selection:)` with exactly 3 `Tab`s.
   - Each tab uses a dedicated `NavigationStack(path:)`.
   - Add `.sheet(item: $coordinator.confirmInputs)` for `ConfirmInputsView`.
   - Add `.fullScreenCover(item: $coordinator.activeBrewSession)` for `BrewSessionFlowView`.
   - Inject coordinator via `.environment(coordinator)`.
4. **Update app entry**:
   - Change `BrewGuideApp` to present `AppRootView()` instead of `ContentView()`.
5. **Wire Recipes root interactions** (in Recipes feature code, not in `AppRootView`):
   - From `RecipeListView`, create a `BrewInputs` snapshot and call `coordinator.presentConfirmInputs(inputs:)`.
   - Optionally auto-present Confirm inputs for last-selected recipe on launch while keeping `RecipeListView` visible as the underlying root.
6. **Wire Confirm inputs → brew start** (in Confirm inputs feature code):
   - On Start brew success (`BrewPlan` returned), call `coordinator.dismissConfirmInputs()` then `coordinator.presentBrewSession(plan:)`.
7. **Verify UX invariants**:
   - Switching tabs preserves each tab’s navigation.
   - Confirm inputs is always modal (Recipes root remains list).
   - Starting brew always presents full-screen flow and blocks background tab interaction.
# View Implementation Plan AppRootView

## 1. Overview
`AppRootView` is the top-level SwiftUI shell for BrewGuide. It provides **persistent tab navigation** with exactly three tabs (Recipes / Logs / Settings), each owning its own `NavigationStack`, and it acts as a **centralized presentation host** for the full-screen brew flow modal (`BrewSessionFlowView`) that can be triggered from the Recipes root.

Key goals:
- Preserve each tab’s navigation state when switching tabs.
- Provide one place to present/dismiss the brew modal safely (and prevent accidental background navigation while brewing).
- Keep UI state in `@Observable` view models (domain-first MVVM); views render state and forward intents.

## 2. View Routing
- **App entry**: `BrewGuideApp` → `WindowGroup` root should present `AppRootView` (replacing the current `ContentView` placeholder).
- **Tabs**:
  - Recipes tab root: `ConfirmInputsView`
  - Logs tab root: `LogsListView`
  - Settings tab root: `SettingsView`
- **Modal**:
  - Full-screen modal over the entire tab shell: `BrewSessionFlowView` (and it internally transitions to `PostBrewView` after completion).

## 3. Component Structure
High-level component tree:

```text
AppRootView
└─ TabView(selection: AppTab)
   ├─ Tab(Recipes)
   │  └─ NavigationStack(path: recipesPath)
   │     └─ ConfirmInputsView
   │        └─ (navigates to RecipeListView / RecipeDetailView / RecipeEditView via recipesPath)
   ├─ Tab(Logs)
   │  └─ NavigationStack(path: logsPath)
   │     └─ LogsListView
   │        └─ (navigates to LogDetailView via logsPath)
   └─ Tab(Settings)
      └─ NavigationStack(path: settingsPath)
         └─ SettingsView
            └─ (navigates to DataDeletionRequestView via settingsPath)

AppRootView (overlay)
└─ fullScreenCover(item: activeBrewSession)
   └─ BrewSessionFlowView
      └─ PostBrewView (within flow, after completion)
```

## 4. Component Details

### AppRootView
- **Description / purpose**: Owns tab selection, per-tab navigation state, and brew modal presentation. Provides shared app-level UI coordinators via environment so child screens can request navigation or modal presentation without tight coupling.
- **Main elements**:
  - `TabView(selection:)` using the modern `Tab` API (not `tabItem()`).
  - Three `NavigationStack`s (one per tab) with independent `NavigationPath` state.
  - `.fullScreenCover(item:)` that presents the brew flow when requested.
- **Handled events**:
  - **Tab selection**: user switches between Recipes/Logs/Settings.
  - **Navigation**: push/pop within each tab via `NavigationPath` and `navigationDestination(for:)`.
  - **Brew modal presentation**: child view requests starting a brew → AppRootView presents `BrewSessionFlowView`.
  - **Brew modal dismissal**: brew completed/discarded or user exits (with confirmation inside brew flow) → AppRootView clears modal state.
- **Validation / conditions**:
  - Only present the brew modal when the presentation payload is valid (e.g. has a `BrewPlan` with at least one step).
  - While an active brew is running, interactive dismissal should be disabled at the modal root (enforced by the brew flow view) to prevent accidental swipes.
- **Props (component interface)**:
  - Prefer **no direct props** for app-wide state; inject via environment:
    - `AppRootCoordinator` (new `@Observable` type) via `.environment(coordinator)`
    - `AppDependencies` (optional, if you centralize repositories/use-cases) via `.environment(dependencies)`
  - If you do want explicit wiring, use:
    - `init(coordinator: AppRootCoordinator, dependencies: AppDependencies)`

### RecipesTabRoot (internal, optional helper view)
- **Description / purpose**: Thin wrapper around `NavigationStack` + `ConfirmInputsView` that binds the recipes navigation path from `AppRootCoordinator`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.recipesPath)`
  - `ConfirmInputsView(...)`
  - `.navigationDestination(for: RecipesRoute.self)` mapping to `RecipeListView`, `RecipeDetailView`, `RecipeEditView`
- **Handled events**:
  - Push routes based on taps in the Recipes flow.
  - Accept “start brew” intent from `ConfirmInputsView` by calling the coordinator’s `presentBrewSession(...)`.
- **Props**:
  - None if it reads coordinator/dependencies from the environment.

### LogsTabRoot (internal, optional helper view)
- **Description / purpose**: Hosts logs navigation path and routes to `LogDetailView`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.logsPath)`
  - `LogsListView(...)`
  - `.navigationDestination(for: LogsRoute.self)` mapping to `LogDetailView`
- **Handled events**:
  - Push log detail route when a log row is selected.
- **Props**:
  - None if it reads coordinator/dependencies from the environment.

### SettingsTabRoot (internal, optional helper view)
- **Description / purpose**: Hosts settings navigation path and routes to `DataDeletionRequestView`.
- **Main elements**:
  - `NavigationStack(path: $coordinator.settingsPath)`
  - `SettingsView(...)`
  - `.navigationDestination(for: SettingsRoute.self)` mapping to `DataDeletionRequestView`
- **Handled events**:
  - Push deletion request screen from Settings.
- **Props**:
  - None if it reads coordinator/dependencies from the environment.

### BrewModalHost (implemented inside AppRootView via `fullScreenCover`)
- **Description / purpose**: Centralized presentation point for the full-screen brew flow; prevents tab UI interaction while brewing by covering the entire screen.
- **Main elements**:
  - `.fullScreenCover(item: $coordinator.activeBrewSession)`
  - `BrewSessionFlowView(...)` constructed from the presentation payload
- **Handled events**:
  - `onFinish`: clear `activeBrewSession` and optionally route to Logs tab (optional UX enhancement).
  - `onDiscard`: clear `activeBrewSession` without saving (flow-specific confirmation belongs to `PostBrewView`).
- **Props**:
  - `activeBrewSession` payload passed from coordinator (see Types).

## 5. Types

### AppTab (new)
Used to control `TabView` selection.

```swift
enum AppTab: Hashable, Codable {
    case recipes
    case logs
    case settings
}
```

### Navigation routes (new, type-safe)
Use explicit route enums to avoid pushing raw model types into `NavigationPath` and to keep navigation deterministic/testable.

```swift
enum RecipesRoute: Hashable {
    case recipeList
    case recipeDetail(id: UUID)
    case recipeEdit(id: UUID)
}

enum LogsRoute: Hashable {
    case logDetail(id: UUID)
}

enum SettingsRoute: Hashable {
    case dataDeletionRequest
}
```

### Brew session presentation payload (new)
Represents “a brew flow is currently presented.” It should be `Identifiable` so `fullScreenCover(item:)` can be used.

Recommended shape:

```swift
struct BrewSessionPresentation: Identifiable, Hashable {
    let id: UUID
    let plan: BrewPlan
}
```

Notes:
- Use the existing domain DTO `BrewPlan` from `Domain/DTOs/BrewSessionDTOs.swift`.
- `id` can be a new session UUID created when starting the brew.

### AppRootCoordinator (new `@Observable`, `@MainActor`)
Single source of truth for `AppRootView` UI state: selected tab, navigation paths per tab, and current brew modal presentation.

Fields:
- `var selectedTab: AppTab`
- `var recipesPath: NavigationPath`
- `var logsPath: NavigationPath`
- `var settingsPath: NavigationPath`
- `var activeBrewSession: BrewSessionPresentation?`

API (methods):
- `func resetToRoot(tab: AppTab)` (optional utility; used for “tap tab again to pop to root” if desired)
- `func navigate(_ route: RecipesRoute)` / similar helpers per tab (optional; screens can also append directly to path)
- `func presentBrewSession(plan: BrewPlan)`:
  - Creates `BrewSessionPresentation(id: UUID(), plan: plan)`
  - Assigns it to `activeBrewSession`
- `func dismissBrewSession()`:
  - Sets `activeBrewSession = nil`

Concurrency notes:
- Mark the class `@MainActor` (required by repo rules).
- `NavigationPath` and SwiftUI selection state should only be mutated on the main actor.

### AppDependencies (optional, if you centralize dependency injection)
If you want a single place to access repositories/use-cases from UI:
- `RecipeRepository` / `BrewLogRepository` (existing persistence layer types)
- Use-case facades (recommended to add, even if thin wrappers initially):
  - `RecipeUseCase`
  - `BrewSessionUseCase`
  - `BrewLogUseCase`
  - `AuthUseCase`, `SyncUseCase` (for Settings tab)

`AppRootView` itself should not perform business logic; it only holds and provides dependencies.

## 6. State Management
Use a coordinator-style view model injected into the environment.

Recommended approach:
- Create a single `@State private var coordinator = AppRootCoordinator()` inside `AppRootView`.
- Inject it via `.environment(coordinator)` so children can read it with `@Environment(AppRootCoordinator.self) private var coordinator`.

State variables owned by `AppRootCoordinator`:
- **Tab selection**: `selectedTab`
- **Per-tab navigation**: `recipesPath`, `logsPath`, `settingsPath`
- **Modal presentation**: `activeBrewSession`

No custom hooks are needed (SwiftUI + Observation covers it). If you need to keep coordinator alive across previews/tests, allow `AppRootView` to accept an injected coordinator.

## 7. API Integration
`AppRootView` itself should not call repositories or network services.

Integration points it must support (by providing environment objects / bindings):
- **Start brew flow** (triggered from `ConfirmInputsView` in Recipes tab):
  - Input type: `BrewInputs` (existing DTO)
  - Output type: `BrewPlan` (existing DTO)
  - Operation (recommended use-case surface): `BrewSessionUseCase.createPlan(inputs:) -> BrewPlan`
  - AppRootView responsibility: accept `BrewPlan` and present the modal via `coordinator.presentBrewSession(plan:)`.

Modal response handling:
- On successful completion and log save: modal should dismiss (and optionally switch to Logs tab).
- On discard: modal dismisses without side effects.

## 8. User Interactions
Within `AppRootView` scope:
- **Switch tabs**:
  - Outcome: selected tab changes; the navigation state for each tab is preserved.
- **Navigate within a tab**:
  - Outcome: only the selected tab’s navigation stack changes; other tabs keep their last path.
- **Start brew from Recipes root**:
  - Outcome: `BrewSessionFlowView` is presented full screen; tab bar is not interactable while presented.
- **Finish/discard brew**:
  - Outcome: modal dismisses; underlying tab and navigation state remain unchanged unless explicitly changed (e.g., switching to Logs).

## 9. Conditions and Validation
Conditions `AppRootView` / coordinator must enforce or support:
- **Exactly 3 tabs**: Recipes / Logs / Settings (no more, no fewer).
- **Default landing**: open on Recipes tab (supports PRD US-001 by making `ConfirmInputsView` the default visible root).
- **Preserve tab state**:
  - Maintain separate `NavigationPath`s for each tab.
  - Do not reinitialize paths when switching tabs.
- **Brew modal presentation guardrails**:
  - Only present when a `BrewPlan` exists and contains at least one step (`!plan.scaledSteps.isEmpty`).
  - While active brew is ongoing, interactive dismissal should be disabled in the presented flow (AppRootView must use `fullScreenCover` and allow the flow to control dismiss policy).

## 10. Error Handling
`AppRootView` should keep error handling minimal and localized:
- **Invalid brew presentation payload** (e.g. empty `scaledSteps`):
  - Do not present the modal; log via `OSLog` and rely on the initiating screen (Confirm inputs) to show an actionable UI error.
- **Unexpected route payloads** (e.g. invalid UUID for detail screens):
  - Navigation destinations should handle “not found” states (e.g. recipe deleted) with an inline empty/error view and a path back. AppRootView simply routes.
- **Concurrency / re-entrancy**:
  - Guard `presentBrewSession` against being called while another brew is already active (either replace the existing session or ignore with a log; prefer ignore to prevent state loss).

## 11. Implementation Steps
1. **Create coordinator types**:
   - Add `AppTab`, `RecipesRoute`, `LogsRoute`, `SettingsRoute`, `BrewSessionPresentation`, and `AppRootCoordinator` under `BrewGuide/BrewGuide/UI/` (e.g. `UI/AppShell/`).
2. **Implement `AppRootView`**:
   - Use `TabView(selection:)` with the `Tab` builder API.
   - For each tab, create a `NavigationStack(path:)` binding to the coordinator’s corresponding `NavigationPath`.
   - Add `navigationDestination(for:)` for each route enum.
   - Add a `fullScreenCover(item:)` bound to `coordinator.activeBrewSession`.
3. **Wire environment injection**:
   - In `AppRootView.body`, inject `coordinator` via `.environment(coordinator)`.
   - (Optional) Inject `AppDependencies` if you centralize repositories/use-cases.
4. **Hook up app entry**:
   - Update `BrewGuideApp` to present `AppRootView()` in `WindowGroup` instead of `ContentView()`.
5. **Integrate modal triggers**:
   - In `ConfirmInputsView` (Recipes root), when the user taps Start brew and the use-case returns `BrewPlan`, call `coordinator.presentBrewSession(plan:)`.
6. **Integrate modal dismissal**:
   - In `BrewSessionFlowView`, call back to `coordinator.dismissBrewSession()` on completion/discard (or use an `onFinish` closure that AppRootView maps to `dismissBrewSession()`).
7. **Verify tab-state preservation**:
   - Navigate deep in Recipes, switch to Logs, navigate there, switch back; confirm the Recipes stack remains where it was.
8. **Verify brew modal behavior**:
   - Start brew and confirm the tab UI cannot be interacted with.
   - Attempt interactive dismissal; ensure the brew flow prevents accidental dismissal during an active brew (flow-level confirmation and `interactiveDismissDisabled` as appropriate).
## View Implementation Plan — AppRootView

## 1. Overview
`AppRootView` is the app’s top-level SwiftUI shell. It provides **persistent tab navigation** with exactly **three tabs** (Recipes / Logs / Settings), keeps **independent navigation stacks** per tab to preserve state while switching, and hosts a **centralized full-screen brew modal** that can be presented from the Recipes tab root without risking background navigation during an active brew.

## 2. View Routing
- **Entry point**: `BrewGuideApp` (or equivalent app entry) should set the `WindowGroup` root to `AppRootView`.
- **Tab default**: The initial selected tab is **Recipes** (supports US-001 “land on brew entry screen”).
- **Modal presentation**: The brew execution flow is presented **as a full-screen cover from `AppRootView`**, triggered by Recipes flow via an injected coordinator.

## 3. Component Structure
- `AppRootView`
  - `TabView(selection:)`
    - `RecipesTabRootView`
      - `NavigationStack(path:)`
        - Root: `ConfirmInputsView` (Recipes tab root per UI plan)
        - Destinations: recipes list/detail/edit routes (owned by Recipes feature)
    - `LogsTabRootView`
      - `NavigationStack(path:)`
        - Root: logs list (e.g. `BrewLogListView`)
        - Destinations: log detail routes (owned by Logs feature)
    - `SettingsTabRootView`
      - `NavigationStack(path:)`
        - Root: settings screen (e.g. `SettingsView`)
        - Destinations: auth/sync/data deletion routes (owned by Settings feature)
  - Presentation host:
    - `.fullScreenCover(item:)` for the brew modal destination

## 4. Component Details

### AppRootView
- **Component description**: Top-level tab shell and global presentation host.
- **Main elements**:
  - `TabView(selection: $selectedTab)` using the modern SwiftUI `Tab` API (not `tabItem()`).
  - Three tab roots, each wrapped in a `NavigationStack(path:)` with a **dedicated `NavigationPath`** to preserve per-tab navigation history.
  - A centralized `.fullScreenCover(item: $brewModalCoordinator.destination)` to present the brew flow above all tabs.
- **Handled events**:
  - **Tab selection change**: updates `selectedTab`.
  - **Brew presentation request** (indirect): `brewModalCoordinator` changes `destination` from `nil` → non-`nil`.
  - **Brew dismissal**: `brewModalCoordinator` sets `destination` to `nil` after brew completion/discard.
- **Props (component interface)**:
  - Prefer **no external props**; `AppRootView` should be constructed with dependencies via environment (e.g. `AppDependencies`) and/or local `@State` coordinator instances.
  - Optional (only if your app wiring requires it): `initialTab: AppTab = .recipes`.

### RecipesTabRootView
- **Component description**: Holds the Recipes feature `NavigationStack` and its root screen.
- **Main elements**:
  - `NavigationStack(path: $recipesPath) { ConfirmInputsView(...) }`
  - `navigationDestination(for:)` for Recipes routes (recipe list, detail, edit).
- **Handled events**:
  - Navigation pushes/pops within Recipes.
  - A “Start brew” action in `ConfirmInputsView` ultimately triggers the brew modal via `BrewModalCoordinator` (see “State Management”).
- **Props**:
  - `path: Binding<NavigationPath>` (or store internally in `AppRootView` and pass binding).

### LogsTabRootView
- **Component description**: Holds Logs feature navigation and root list.
- **Main elements**:
  - `NavigationStack(path: $logsPath) { BrewLogListView(...) }`
  - `navigationDestination(for:)` for log detail route(s).
- **Handled events**:
  - Navigation to log detail.
  - Log deletion confirmations are handled inside Logs feature (not `AppRootView`).
- **Props**:
  - `path: Binding<NavigationPath>` (optional depending on where you store it).

### SettingsTabRootView
- **Component description**: Holds Settings feature navigation and root settings screen.
- **Main elements**:
  - `NavigationStack(path: $settingsPath) { SettingsView(...) }`
  - `navigationDestination(for:)` for sign-in/out, sync status/retry, deletion request flow.
- **Handled events**:
  - Settings navigation pushes/pops inside Settings feature.
- **Props**:
  - `path: Binding<NavigationPath>` (optional depending on where you store it).

### BrewModalHost (implemented as modifiers on AppRootView)
- **Component description**: A centralized presentation host for the guided brew flow that overlays the entire app UI.
- **Main elements**:
  - `.fullScreenCover(item: $brewModalCoordinator.destination) { destination in BrewFlowView(viewModel: ...) }`
  - `.interactiveDismissDisabled(true)` to avoid accidental dismissal (the brew flow provides explicit “leave” confirmation per PRD).
- **Handled events**:
  - Present: `destination` becomes non-`nil`.
  - Dismiss: brew flow signals completion/discard; coordinator resets destination.
- **Props**:
  - Driven entirely by `BrewModalCoordinator` state.

## 5. Types

### AppTab
Enum representing the three tabs.
- **Type**: `enum AppTab: Hashable`
- **Cases**:
  - `.recipes`
  - `.logs`
  - `.settings`
- **Usage**:
  - `@State var selectedTab: AppTab = .recipes`
  - `TabView(selection:)` + `Tab(value:)`

### BrewModalDestination
Identifiable payload that the modal host uses to drive `.fullScreenCover(item:)`.
- **Type**: `struct BrewModalDestination: Identifiable, Equatable`
- **Fields**:
  - `id: UUID` (unique per presentation; enables SwiftUI identity)
  - `plan: BrewPlan` (Domain; created by `BrewSessionUseCase.createPlan(...)`)
  - `inputs: BrewInputs` (Domain; snapshot of confirmed inputs)
  - `recipeDetail: RecipeDetailDTO?` (optional; if the brew UI needs step text/metadata that isn’t fully carried by `BrewPlan`)
- **Notes**:
  - Keep the destination “DTO-shaped”; avoid embedding SwiftData models.

### BrewModalCoordinator
Owns modal presentation state and provides a single API to present/dismiss the brew flow.
- **Type**: `@Observable @MainActor final class BrewModalCoordinator`
- **Stored state**:
  - `var destination: BrewModalDestination?`
  - `var isPresenting: Bool { destination != nil }` (derived convenience)
- **Functions**:
  - `func present(plan: BrewPlan, inputs: BrewInputs, recipeDetail: RecipeDetailDTO?)`
    - Sets `destination` if `destination == nil` (ignore or log if already presenting).
  - `func dismiss()`
    - Sets `destination = nil`.
- **Integration contract**:
  - Recipes flow is responsible for validating inputs and producing `BrewPlan` (via `BrewSessionUseCase.createPlan`), then calls `present(...)`.
  - Brew flow calls `dismiss()` only after it completes/discards safely.

### Navigation route enums (owned by features, referenced here for wiring)
To keep `AppRootView` simple and testable, **each tab owns its own route type** used with `navigationDestination(for:)`.
- Examples (names may differ in your codebase):
  - `enum RecipesRoute: Hashable { case recipeList; case recipeDetail(UUID); case editRecipe(UUID) }`
  - `enum LogsRoute: Hashable { case logDetail(UUID) }`
  - `enum SettingsRoute: Hashable { case signIn; case syncStatus; case dataDeletion }`

## 6. State Management

### AppRootView state
- **`@State private var selectedTab: AppTab = .recipes`**
  - Drives the currently selected tab.
- **`@State private var recipesPath = NavigationPath()`**
  - Preserves Recipes navigation stack and scroll/edit drafts within that tab.
- **`@State private var logsPath = NavigationPath()`**
  - Preserves Logs navigation stack state.
- **`@State private var settingsPath = NavigationPath()`**
  - Preserves Settings navigation stack state.
- **`@State private var brewModalCoordinator = BrewModalCoordinator()`**
  - Single source of truth for brew modal presentation.

### Environment injection
- Provide `brewModalCoordinator` to descendants using `.environment(brewModalCoordinator)` so `ConfirmInputsView` (Recipes root) can request presentation.
- Keep business logic out of `AppRootView`; it should only render and coordinate presentation.

### No custom hooks
SwiftUI doesn’t use “hooks”; no custom reusable state helpers are required for `AppRootView` beyond the coordinator. (If your project uses a dependency container pattern, wire it at the app entry and inject via `environment(...)`.)

## 7. API Integration
`AppRootView` does **not** call repositories/use-cases directly. It integrates via **presentation contracts**:
- **Brew modal “endpoint” (internal use-case)**:
  - `BrewSessionUseCase.createPlan(recipeId, inputsDraft) -> Result<BrewPlan, RecipeNotBrewableError>`
  - The **Recipes** feature triggers this and passes the resulting `BrewPlan` into `BrewModalCoordinator.present(...)`.
- **Preferences**:
  - Initial recipe selection and “last selected recipe” are handled in Recipes root (`ConfirmInputsView`) via `PreferencesStore.getLastSelectedRecipeId()` (not in `AppRootView`).

## 8. User Interactions
- **Switch tabs**:
  - User taps Recipes / Logs / Settings.
  - Expected: each tab returns to its previous navigation state (including scroll positions and drafts, as supported by SwiftUI state retention).
- **Start brew (from Recipes root)**:
  - User taps “Start brew” in `ConfirmInputsView`.
  - Expected: `BrewModalCoordinator.destination` becomes non-`nil`; brew UI appears as full-screen modal.
- **During brew modal**:
  - Expected: the modal overlays the entire app; user cannot accidentally interact with underlying tabs/navigation.
  - Dismissal is controlled by brew flow (completion/discard) rather than swipe-down.

## 9. Conditions and Validation
`AppRootView` enforces these UI-level conditions:
- **Exactly 3 tabs**: Recipes, Logs, Settings (no more, no less).
- **Per-tab navigation stacks**: each tab has its own `NavigationStack(path:)` backed by a unique `NavigationPath`.
- **Centralized brew modal host**:
  - Presentation only when `brewModalCoordinator.destination != nil`.
  - `.interactiveDismissDisabled(true)` to prevent accidental dismiss; brew flow must provide explicit “leave” confirmation per PRD (US-015) and restart safeguards per PRD (US-014) within the brew screens.
- **MainActor correctness**:
  - `BrewModalCoordinator` is `@MainActor` and must be mutated only on the main thread.

## 10. Error Handling
While `AppRootView` should not own domain errors, it must handle presentation edge cases safely:
- **Duplicate presentation requests**:
  - If `brewModalCoordinator.destination != nil` and `present(...)` is called again, ignore the request and log via `OSLog` (or replace only if explicitly designed).
- **Inconsistent dismissal**:
  - If the brew flow attempts to dismiss while already dismissed, no-op.
- **Unexpected view recreation**:
  - Keep coordinator and navigation paths in `@State` (not recomputed) to avoid losing modal/nav state.

## 11. Implementation Steps
1. Create `AppTab` (`Hashable`) with `.recipes`, `.logs`, `.settings`.
2. Implement `BrewModalCoordinator` as `@Observable @MainActor` with `destination: BrewModalDestination?`, `present(...)`, and `dismiss()`.
3. Implement `BrewModalDestination` as `Identifiable` and “DTO-shaped” (holds `BrewPlan`, `BrewInputs`, and optional `RecipeDetailDTO`).
4. Implement `AppRootView`:
   - Add `@State` for `selectedTab`, three `NavigationPath`s, and `brewModalCoordinator`.
   - Render `TabView(selection:)` with exactly 3 `Tab` items.
   - Each `Tab` contains a dedicated `NavigationStack(path:)` with its feature root.
   - Attach `.fullScreenCover(item: $brewModalCoordinator.destination)` as the centralized brew presentation host.
5. Inject `brewModalCoordinator` into the environment from `AppRootView` so Recipes can present the brew modal.
6. In Recipes root (`ConfirmInputsView` / its view model), on successful “Start brew”:
   - Call `RecipeUseCase.assertRecipeIsBrewable(recipeId)` and/or use `BrewSessionUseCase.createPlan(...)`.
   - On success, call `brewModalCoordinator.present(plan:inputs:recipeDetail:)`.
7. In the brew flow (modal content), ensure:
   - It calls `brewModalCoordinator.dismiss()` only after completion/discard.
   - It provides explicit “leave active brew” confirmation per PRD (US-015) and uses `.interactiveDismissDisabled(true)` at the modal level.
8. Add lightweight unit tests for coordinator behavior (present/dismiss idempotency) and ensure `@MainActor` isolation is respected.
