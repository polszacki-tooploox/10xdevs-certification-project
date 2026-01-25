# API Plan

This document defines the **database access API** for BrewGuide on iOS (SwiftUI + SwiftData + optional CloudKit private DB sync). It is written as an **internal application API** (repositories + use-cases) rather than an HTTP API. If a server API is ever introduced, the same resources and payload shapes can be reused as DTOs.

---

## 1. Resources

- **recipes** → SwiftData `Recipe` (`BrewGuide/BrewGuide/Persistence/Models/Recipe.swift`)
- **recipeSteps** → SwiftData `RecipeStep` (`…/RecipeStep.swift`) (owned by `Recipe`, cascade delete)
- **brewLogs** → SwiftData `BrewLog` (`…/BrewLog.swift`)
- **enums/value-objects** → `BrewMethod`, `RecipeOrigin`, `GrindLabel`, `TasteTag`
- **preferences** (not SwiftData) → `UserDefaults` / Keychain
  - `lastSelectedRecipeId: UUID?`
  - `syncEnabled: Bool`
  - `appleUserId: String?` (or stable user identifier from Sign in with Apple)

---

## 2. API

### 2.1 Conventions

- **API style**: internal “application API” surface, split into:
  - **Repositories**: SwiftData access and persistence.
  - **Use-cases**: orchestration + business rules.
  - **Domain services**: pure functions/state machines (scaling, hints, brew session).
- **Error model**: typed errors (`enum …Error: LocalizedError`) + validation arrays for “fixable” issues.
- **DTOs/payloads**: request/response structs (Codable-friendly) to keep UI independent from SwiftData models when needed.

#### Common payload shapes (DTOs)

- `RecipeSummaryDTO`
  - `id: UUID`, `name: String`, `method: BrewMethod`, `isStarter: Bool`, `origin: RecipeOrigin`, `isValid: Bool`
  - `defaultDose: Double`, `defaultTargetYield: Double`, `defaultWaterTemperature: Double`, `defaultGrindLabel: GrindLabel`

- `RecipeDetailDTO`
  - `recipe: RecipeSummaryDTO`
  - `grindTactileDescriptor: String?`
  - `steps: [RecipeStepDTO]` (sorted by `orderIndex`)

- `RecipeStepDTO`
  - `stepId: UUID`, `orderIndex: Int`
  - `instructionText: String`
  - `timerDurationSeconds: Double?`
  - `waterAmountGrams: Double?`
  - `isCumulativeWaterTarget: Bool`

- `BrewLogSummaryDTO`
  - `id: UUID`, `timestamp: Date`, `method: BrewMethod`
  - `recipeNameAtBrew: String`, `rating: Int`, `tasteTag: TasteTag?`

- `BrewLogDetailDTO`
  - `summary: BrewLogSummaryDTO`
  - `doseGrams: Double`, `targetYieldGrams: Double`, `waterTemperatureCelsius: Double`, `grindLabel: GrindLabel`
  - `note: String?`
  - `recipeId: UUID?` (optional navigation)

---

### 2.2 Resource: Recipes

#### Description
Structured brew recipes (starter + custom). Starter recipes are templates: **not deletable and not editable in-place**.

#### Query parameters (logical; for repository methods)
- `method: BrewMethod` (required for list screens; MVP `.v60`)
- `includeInvalid: Bool` (default true, but UI may filter/flag)
- `sort: starterFirstThenName` (default)

#### CRUD + operations

1. **List recipes**
   - Method: `RecipeRepository.fetchRecipes(for method: BrewMethod) throws -> [Recipe]`
   - Response: `[RecipeSummaryDTO]` (derived in use-case)
   - Performance: fetch by predicate `method == …`, then sort starters first + name.

2. **Get recipe detail**
   - Method: `RecipeRepository.fetchRecipe(byId id: UUID) throws -> Recipe?`
   - Response: `RecipeDetailDTO` with steps sorted by `orderIndex`.

3. **Create custom recipe**
   - Request (`CreateRecipeRequest`):
     - `method`, `name`, defaults (dose/yield/temp/grind), `grindTactileDescriptor?`, `steps: [RecipeStepDTO]`
   - Use-case:
     - `RecipeUseCase.createCustomRecipe(request) -> Result<Recipe, [RecipeValidationError]>`
   - Validation (block save):
     - name non-empty, dose/yield > 0, steps non-empty, timers non-negative, water totals match yield (±1g).

4. **Update custom recipe**
   - Request (`UpdateRecipeRequest`):
     - `id`, mutable fields + steps (full replacement or patch strategy)
   - Use-case:
     - `RecipeUseCase.updateCustomRecipe(request) -> Result<Recipe, [RecipeValidationError]>`
   - Rules:
     - If `isStarter == true`, reject and require duplication flow.
     - Update `modifiedAt`.

5. **Delete custom recipe**
   - Method: `RecipeRepository.deleteCustomRecipe(_ recipe: Recipe) throws`
   - Rule: starters cannot be deleted.

#### Business endpoints (non-CRUD)

1. **Duplicate recipe**
   - Method: `RecipeRepository.duplicate(_ source: Recipe) throws -> Recipe`
   - Naming:
     - Default: `"\(source.name) Copy"`
     - For conflicts: `"\(source.name) (Conflicted Copy)"` (see Sync section)
   - Response: `RecipeDetailDTO`

2. **Validate recipe (draft)**
   - Method: `RecipeRepository.validate(_ recipe: Recipe) -> [RecipeValidationError]`
   - Use-case: also accepts a DTO draft (no SwiftData object yet) and returns same errors.

3. **Prevent brewing with invalid recipe**
   - Method: `RecipeUseCase.assertRecipeIsBrewable(recipeId) -> Result<Void, RecipeNotBrewableError>`
   - Error includes: validation errors + actionable messaging.

---

### 2.3 Resource: Recipe Steps

#### Description
Ordered steps owned by a recipe. Relationship is optional for CloudKit compatibility; treat `Recipe` as the aggregate root.

#### Query parameters
- `recipeId: UUID`
- `ordered: Bool` (default true)

#### Access patterns (recommended)
- Avoid standalone CRUD for steps in UI; instead, update steps through `RecipeUseCase.updateCustomRecipe(...)`.
- Internally support:
  - `RecipeStepsService.sortedSteps(for recipe: Recipe) -> [RecipeStep]` (sort by `orderIndex`)

#### Validation rules (step-level)
- `orderIndex` must be unique within a recipe and 0-based contiguous (recommended; enforce in use-case)
- `timerDurationSeconds == nil || timerDurationSeconds >= 0`
- `waterAmountGrams == nil || waterAmountGrams >= 0` (recommended; enforce)

---

### 2.4 Resource: Brew Logs

#### Description
Append-only-ish history of completed brews, using a **snapshot strategy** so edits/deletions to recipes don’t corrupt history.

#### Query parameters
- `method: BrewMethod?`
- `recipeId: UUID?` (optional filter)
- `limit: Int?` (fetchLimit)
- `before: Date?` (future cursor/pagination)

#### CRUD + operations

1. **List logs (most recent first)**
   - Method: `BrewLogRepository.fetchAllLogs() throws -> [BrewLog]`
   - Response: `[BrewLogSummaryDTO]`
   - Performance: `SortDescriptor(\.timestamp, order: .reverse)`

2. **List logs by method**
   - Method: `BrewLogRepository.fetchLogs(for method: BrewMethod) throws -> [BrewLog]`

3. **Get log detail**
   - Method: `BrewLogRepository.fetchLog(byId id: UUID) throws -> BrewLog?`
   - Response: `BrewLogDetailDTO`

4. **Create log (Save brew)**
   - Request (`CreateBrewLogRequest`):
     - `timestamp` (default now)
     - `method`
     - `recipeId?` (optional navigation reference)
     - `recipeNameAtBrew` (snapshot, required)
     - `doseGrams`, `targetYieldGrams`, `waterTemperatureCelsius`, `grindLabel`
     - `rating` (required 1–5)
     - `tasteTag?`, `note?`
   - Use-case:
     - `BrewLogUseCase.saveBrewLog(request) -> Result<BrewLog, [BrewLogValidationError]>`
   - Validation (block save):
     - rating in 1…5; recipe name non-empty; dose/yield > 0; note length ≤ 280.

5. **Delete log**
   - Method: `BaseRepository.delete(_:)` via `BrewLogUseCase.deleteLog(id)` with confirmation in UI.

#### Business endpoints (non-CRUD)

1. **Post-brew hint**
   - Method: `TasteHintService.hint(for tasteTag: TasteTag?) -> String?`
   - Mapping:
     - `tooSour` → “Try slightly finer or hotter”
     - `tooBitter` → “Try slightly coarser or cooler”
     - `tooWeak` → “Try higher dose or finer”
     - `tooStrong` → “Try lower dose or coarser”
     - none/perfect → “Great job — no tips!”

2. **Stats (optional)**
   - Method: `BrewLogRepository.calculateAverageRating() throws -> Double`
   - Future: average by recipeId/method, count over time, etc.

---

### 2.5 Business API: Brew Session (state machine; not persistence)

#### Description
Guided brewing flow with step progression and timer state. This should live in **Domain** and be testable without SwiftData.

#### Core types
- `BrewInputs`
  - `recipeId`, `recipeName`, `method`
  - `doseGrams`, `targetYieldGrams`, `waterTemperatureCelsius`, `grindLabel`
  - `lastEdited: .dose | .yield` (for scaling)

- `BrewPlan`
  - `scaledSteps: [ScaledStep]` (derived from recipe steps + scaling rules)

- `BrewSessionState`
  - `phase: .notStarted | .active | .paused | .stepReadyToAdvance | .completed`
  - `currentStepIndex`, `remainingTime`, `startedAt`, `isInputsLocked`

#### Operations (“endpoints”)
- `BrewSessionUseCase.createPlan(recipeId, inputsDraft) -> Result<BrewPlan, RecipeNotBrewableError>`
- `BrewSessionUseCase.start(plan) -> BrewSessionState` (locks inputs)
- `BrewSessionUseCase.pause() / resume() / restart(confirm+hold)` (UI enforces safeguards)
- `BrewSessionUseCase.nextStep() -> BrewSessionState` (final step → completed)

---

### 2.6 Business API: Scaling (Confirm Inputs)

#### Description
Deterministic scaling logic; independent from persistence.

#### Request/response payloads

- `ScaleInputsRequest`
  - `method: BrewMethod` (MVP `.v60`)
  - `recipeDefaultDose: Double`
  - `recipeDefaultTargetYield: Double`
  - `userDose: Double`
  - `userTargetYield: Double`
  - `lastEdited: .dose | .yield`

- `ScaleInputsResponse`
  - `scaledDose: Double` (rounded to 0.1g)
  - `scaledTargetYield: Double` (rounded to 1g)
  - `scaledWaterTargets: [Double]` (rounded to 1g; final adjusted to match total)
  - `derivedRatio: Double` (yield/dose)
  - `warnings: [InputWarning]` (out-of-range but non-blocking)

#### Rules (V60 MVP)
- Last-edited wins:
  - If dose edited last → yield = dose * recipeRatio
  - If yield edited last → dose = yield / recipeRatio
- Rounding:
  - Dose: nearest 0.1g
  - Yield and water: nearest 1g
- Water steps scaling (PRD MVP rule):
  - Bloom = 3×dose (rounded to 1g)
  - Remaining water = yield − bloom
  - Split remaining into two pours 50/50; adjust last pour to ensure final cumulative == yield

---

### 2.7 Resource: Preferences (local settings)

#### Description
Non-SwiftData state needed for UX and sync toggles.

#### Operations
- `PreferencesStore.getLastSelectedRecipeId() -> UUID?`
- `PreferencesStore.setLastSelectedRecipeId(_ id: UUID?)`
- `SyncSettingsStore.isSyncEnabled() -> Bool`
- `SyncSettingsStore.setSyncEnabled(_ enabled: Bool)`
- `AuthSessionStore.appleUserId() -> String?` (or stable user identifier)

#### Notes
- MVP may keep these local-only even when CloudKit sync is enabled, consistent with the DB documentation.

---

### 2.8 Auth + Sync + Conflict policy (CloudKit private DB)

#### Description
Cloud sync is optional and **requires Sign in with Apple**. Recipes + logs may sync; starter recipes are seeded locally.

#### Operations (logical “endpoints”)
- `AuthUseCase.signInWithApple() -> Result<AuthSession, AuthError>`
- `AuthUseCase.signOut()`
- `SyncUseCase.enableSync() -> Result<Void, SyncError>`
- `SyncUseCase.disableSync()`
- `SyncUseCase.requestDataDeletion() -> Result<Void, SyncError>` (local + CloudKit deletion request path)

#### Conflict resolution (recipes)
- When detecting a recipe conflict (same logical recipe edited on two devices), keep both:
  - Create a new recipe with:
    - `origin = .conflictedCopy`
    - `name = "\(originalName) (Conflicted Copy)"` (or “(Conflicted Copy 2)” if needed)
    - New `id`, cloned steps with new `stepId`
- Logs: treat as append-only; duplicates allowed.

---

## 3. Validation & Guardrails (centralized)

### 3.1 Recipe validation (block save + block brew)
- **Name**: non-empty
- **Defaults**: dose > 0; yield > 0
- **Steps**: at least 1 step
- **Timers**: no negative durations
- **Water totals**:
  - If recipe uses cumulative water targets: `max(waterAmountGrams)` should match `defaultTargetYield` within ±1g
  - If recipe uses incremental amounts (future): `sum(waterAmountGrams)` should match within ±1g
- **Starter immutability**:
  - Cannot delete starter
  - Cannot edit starter in-place (must duplicate)

### 3.2 BrewLog validation (block save)
- rating in 1…5
- recipeNameAtBrew non-empty
- doseGrams > 0; targetYieldGrams > 0
- note length ≤ 280 chars

### 3.3 Non-blocking warnings (Confirm Inputs)
- V60 recommended ranges (warn only, no clamping):
  - Dose: 12–40g
  - Yield: 180–720g
  - Ratio: 1:14 to 1:18
  - Temp: 90–96°C

---

## 4. Performance & Indexing Considerations

- Prefer predicate + sort in `FetchDescriptor`:
  - `Recipe.method` predicate for recipe list
  - `BrewLog.timestamp` descending sort for logs list
- Use `fetchLimit` for “recent logs” and future pagination.
- Use snapshot fields in `BrewLog` lists (avoid joins); `recipe` relationship is optional for navigation only.

---

## 5. Assumptions / Open Questions

- The plan assumes “API” means **internal database access API** (repositories/use-cases) for a local-first iOS app, not a network service.
- Conflict detection triggers for SwiftData+CloudKit are not defined in MVP; the plan defines the **resolution behavior** once a conflict is detected.
- “Perfect” taste tag isn’t currently in `TasteTag`; MVP can treat “no tag selected” as “no tips” or add a `perfect` tag later.

