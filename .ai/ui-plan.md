# UI Architecture for BrewGuide (MVP)

## 1. UI Structure Overview

BrewGuide’s MVP UI is an iPhone-first SwiftUI app optimized for “kitchen counter” use: minimal cognitive load, large primary controls, and a single-purpose guided brew flow. The app is **offline-first** (local persistence) with **optional sync** (Sign in with Apple + CloudKit) controlled entirely from **Settings**.

At the top level, the app uses **exactly 3 tabs**:

- **Recipes**: the primary “brew entry” experience (Confirm inputs), plus recipe browsing, detail, duplication, and editing.
- **Logs**: brew history list and detail, with deletion.
- **Settings**: sync (optional), sign-in/out, sync status + retry, and data deletion request entry point.

The **brew execution** is a **full-screen modal guided flow** (not a tab). During an active brew, the UI is deliberately constrained and guarded: no parameter visibility/editing, explicit exit confirmation, and restart protection (confirm + press-and-hold).

The UI consumes **DTO/snapshot-shaped data** and calls **use-cases** (internal “API plan”), keeping screen state independent of persistence details during edits and flows.

## 2. View List

Below, “API compatibility” references the internal repositories/use-cases described in `.ai/api-plan.md`.

### 2.1 App Shell

- **View name**: `AppRootView` (Tab shell)
- **Main purpose**: Provide persistent top-level navigation (Recipes/Logs/Settings).
- **Key information to display**: Tab bar only; each tab hosts its own navigation stack.
- **Key view components**:
  - Tab bar with 3 items: Recipes, Logs, Settings
  - Per-tab `NavigationStack`
  - Centralized presentation host for full-screen brew modal (can be triggered from Recipes tab root)
- **UX considerations**:
  - Preserve tab state when switching (avoid losing scroll position / edit drafts)
  - Ensure brew modal prevents accidental background navigation

### 2.2 Recipes Tab (includes Brew Entry)

- **View name**: `ConfirmInputsView` 
- **Main purpose**: Default entry screen to confirm/adjust pre-brew inputs for the **last-selected recipe** (starter on first run), compute scaled targets, and start the guided brew.
- **Key information to display**:
  - Selected recipe name
  - Editable inputs (pre-start only): dose (g), target yield (g), grind label (+ tactile descriptor), water temp (°C)
  - Derived ratio (yield/dose)
  - Non-blocking warnings for out-of-range inputs
- **Key view components**:
  - Selected recipe header with “Change recipe”
  - Numeric entry rows for dose/yield/temp (with units)
  - Grind label selector + descriptor line
  - Ratio display row
  - Warning list (non-blocking) triggered by scaling response
  - Primary button: Start brew
  - Secondary action: Reset to defaults
- **UX considerations**:
  - One-handed primary action placement (Start brew anchored near bottom)
  - Minimal typing: steppers/pickers where possible; numeric keypad for grams/°C
  - Warnings are advisory only (never block) and are phrased as “Recommended range…”
- **Accessibility considerations (MVP)**:
  - 44x44pt targets; clear labels for units and fields
- **Security considerations**:
  - No auth required; do not show any user identifiers
- **API compatibility**:
  - Load last-selected recipe via `PreferencesStore.getLastSelectedRecipeId()`
  - Fetch recipe detail via `RecipeRepository.fetchRecipe(byId:)` (through a use-case) to build DTOs
  - Compute scaling + warnings via `Scaling` (`ScaleInputsRequest/Response`)
  - Gate Start brew via `RecipeUseCase.assertRecipeIsBrewable(recipeId)`
  - Create brew plan via `BrewSessionUseCase.createPlan(...)`
 
- **View name**: `RecipeListView` (Recipes tab root)
- **Main purpose**: Browse and select recipes (starter + custom)
- **Key information to display**:
  - List grouped/ordered by name
- **Key view components**:
  - List rows with recipe name, badges, and compact defaults (dose/yield/temp/grind)
  - Row tap: open recipe detail
  - Selection control: “Use this recipe” (or row action) returning to Confirm inputs
  - Custom recipe swipe actions: Delete (confirm), possibly Duplicate
  - Add/duplicate entry point (MVP: primarily duplicate from starter detail; optional add button if supported)
- **UX considerations**:
  - Keep list simple; no pagination or caching in MVP
- **Security considerations**:
  - No auth required
- **API compatibility**:
  - Populate via `RecipeRepository.fetchRecipes(for:)` → `[RecipeSummaryDTO]`
  - Delete via `RecipeRepository.deleteCustomRecipe(...)` (through use-case)
  - Persist selection via `PreferencesStore.setLastSelectedRecipeId(...)`

- **View name**: `RecipeDetailView`
- **Main purpose**: View recipe defaults and full step list; provide duplication/editing actions with starter guardrails and conflict visibility.
- **Key information to display**:
  - Recipe name
  - Defaults: dose, target yield, temp, grind label + tactile descriptor
  - Full step list (ordered)
- **Key view components**:
  - Header with badges
  - Defaults summary card
  - Steps list with step numbers; for timed steps show time; for water steps show grams/targets
  - Primary action: “Use this recipe” (select and go to Confirm inputs)
  - Secondary actions:
    - Custom recipe: Edit, Delete (confirm)
- **UX considerations**:
  - “Use this recipe” should be prominent and consistent with the Confirm inputs flow
  - Starter immutability is enforced by removing Edit affordances (no dead ends)
- **Security considerations**:
  - No auth required
- **API compatibility**:
  - Fetch via `RecipeRepository.fetchRecipe(byId:)` → `RecipeDetailDTO`
  - Duplicate via `RecipeRepository.duplicate(_:)` (or `RecipeUseCase.duplicateRecipe(...)`)

- **View name**: `RecipeEditView` (Custom only)
- **Main purpose**: Edit custom recipe defaults and steps with guardrails; block save until valid; highlight errors inline and via summary banner.
- **Key information to display**:
  - Editable fields: name, default dose/yield/temp, grind label + descriptor, steps (instruction, timer, water grams/target)
  - Validation state:
    - Inline per-field errors
    - Summary banner: “Fix X issues to save”
    - Special emphasis for water-total mismatch with highlighted offending step(s)
- **Key view components**:
  - Form with inline validation messages under fields
  - Steps editor list:
    - Reorder (if supported) and edit step properties
    - Per-step validation (negative timers, invalid water entries, ordering issues)
  - Top validation banner summarizing count and “Jump to first issue”
  - Save button disabled until valid; Cancel discards draft
- **UX considerations**:
  - Immediate feedback while typing; avoid blocking popups for validation
  - Keep the “Save disabled” rationale explicit via banner (not silent)
- **Accessibility considerations (MVP)**:
  - Clear error messaging with consistent placement; avoid color-only error cues
- **Security considerations**:
  - No auth required
- **API compatibility**:
  - Save via `RecipeUseCase.updateCustomRecipe(UpdateRecipeRequest)` returning validation errors array
  - Validation rules align with API plan (timers non-negative; water totals match yield ±1g; starter immutability)

### 2.3 Brew Flow (Full-Screen Modal)

- **View name**: `BrewSessionFlowView` (full-screen modal host)
- **Main purpose**: Run a single-purpose guided brewing session with step progression and timer state; protect against accidental exit/restart.
- **Key information to display**:
  - Current step number and title/instruction
  - Water target for the step (if applicable)
  - Timer (if applicable): countdown + ready-to-advance state
  - Session progress indicator (e.g., step dots or “Step 2 of 6”)
- **Key view components**:
  - “Now” step card with large text
  - Countdown timer component for timed steps
  - Primary controls:
    - Next step (large)
    - Pause/Resume (large)
  - Secondary controls:
    - Restart (confirm + press-and-hold)
    - Exit attempt triggers confirmation prompt
  - **Inputs are not visible** while brewing (to reduce clutter and avoid mistaken edits)
- **UX considerations**:
  - Designed for wet hands and low attention: big controls, high contrast, minimal navigation
  - Explicit “are you sure?” on exit; restart is intentionally hard to trigger
  - When timer hits zero: clearly indicate readiness, but require manual “Next step” confirm
- **Accessibility considerations (MVP)**:
  - Prioritize readable typography and voice cues where available; ensure controls are discoverable by VoiceOver for core flow
  - Touch targets meet minimum sizing; avoid densely packed controls
- **Security considerations**:
  - No auth required
- **API compatibility**:
  - Session state driven by `BrewSessionUseCase` operations: start/pause/resume/nextStep/restart

- **View name**: `PostBrewView` (within modal after completion)
- **Main purpose**: Capture outcome (required rating, optional taste tag + note), show static hint mapping, and save/discard log.
- **Key information to display**:
  - Summary snapshot: recipe name, dose, yield, temp, grind label, timestamp
  - Rating selector (required 1–5)
  - Taste tag selector (optional)
  - Note field (optional, max 280 chars with live count)
  - Static hint text based on taste tag
- **Key view components**:
  - Summary card
  - Rating control (stars or segmented)
  - Taste tag chips (single-select, optional)
  - Note text area with counter + limit enforcement
  - Primary action: Save brew (disabled until rating selected)
  - Secondary: Discard (confirm if partially filled)
- **UX considerations**:
  - Saving is the default primary action; keep friction low
  - Make “required rating” explicit before the user attempts to save
- **Security considerations**:
  - Log is stored locally regardless of auth; syncing (if enabled) is background/transparent
- **API compatibility**:
  - Save via `BrewLogUseCase.saveBrewLog(CreateBrewLogRequest)` with validation (rating 1–5, note ≤ 280)
  - Hint via `TasteHintService.hint(for:)`

### 2.4 Logs Tab

- **View name**: `LogsListView`
- **Main purpose**: Show chronological history of brews; entry point to log detail; allow deletion with confirmation.
- **Key information to display**:
  - For each log: timestamp, recipeNameAtBrew, rating, optional taste tag
- **Key view components**:
  - List sorted most-recent-first
  - Row tap to log detail
  - Swipe delete (confirm)
- **UX considerations**:
  - Use snapshot fields (recipeNameAtBrew) to keep list stable even if recipes change
- **Security considerations**:
  - No auth required; deletion affects local data and syncs if enabled
- **API compatibility**:
  - List via `BrewLogRepository.fetchAllLogs()` → `[BrewLogSummaryDTO]`
  - Delete via `BrewLogUseCase.deleteLog(id)`

- **View name**: `LogDetailView`
- **Main purpose**: View full details of a brew log; allow deletion; optionally navigate to related recipe.
- **Key information to display**:
  - Timestamp, recipe name, parameters, rating, taste tag, note
  - Optional “View recipe” (if recipeId exists)
- **Key view components**:
  - Detail sections (Parameters, Outcome)
  - Delete button (confirm)
  - Optional navigation link to `RecipeDetailView`
- **UX considerations**:
  - Keep information scannable; parameters grouped
- **API compatibility**:
  - Fetch via `BrewLogRepository.fetchLog(byId:)` → `BrewLogDetailDTO`

### 2.5 Settings Tab

- **View name**: `SettingsView`
- **Main purpose**: Centralize optional sync/auth, display sync state, allow manual retry, and provide data deletion request path.
- **Key information to display**:
  - Sync status: Local only / Sync enabled
  - Sign-in state (signed out / signed in)
  - Sync toggle (only meaningful when signed in; otherwise explains requirement)
  - Last sync attempt (timestamp + outcome)
  - Retry sync action
  - Data deletion request entry point with explanation
- **Key view components**:
  - “Sync (optional)” section:
    - Sign in with Apple button (when signed out)
    - Sign out (when signed in)
    - Sync enabled toggle (persisted)
    - Status row + last attempt row
    - Retry sync button (only place to manually retry)
  - “Privacy” section:
    - Request deletion of synced data (navigates to confirmation/explanation)
- **UX considerations**:
  - Communicate that the app remains fully usable offline/local-only
  - Failures are shown inline with a clear next action (“Retry sync”)
- **Accessibility considerations (MVP)**:
  - Clear, readable status text; avoid jargon
- **Security considerations**:
  - Do not display Apple user identifiers
  - Make the consequences of sign-out and deletion explicit (what happens locally vs cloud)
- **API compatibility**:
  - Auth via `AuthUseCase.signInWithApple()`, `AuthUseCase.signOut()`
  - Sync toggle via `SyncUseCase.enableSync()/disableSync()` and `SyncSettingsStore`
  - Retry sync via `SyncUseCase` (same operation invoked explicitly)
  - Data deletion request via `SyncUseCase.requestDataDeletion()`

- **View name**: `DataDeletionRequestView` (Settings sub-screen)
- **Main purpose**: Explain what data deletion means and collect explicit confirmation to request deletion.
- **Key information to display**:
  - What data is deleted (recipes, logs, preferences) and what remains (local-only usage possible)
  - Any limitations (timing, requires sign-in, may take time)
- **Key view components**:
  - Explanatory text
  - Confirm “Request deletion” (guarded)
  - Success/failure state inline; next steps
- **UX considerations**:
  - Avoid frightening language; be precise and transparent
- **Security considerations**:
  - Require sign-in for cloud deletion; never block local usage

## 3. User Journey Map

### 3.1 Primary Journey: Brew a V60 and save a log

1. **App launch** → user lands on **Confirm inputs** for the **last-selected recipe** (starter on first run).
2. User optionally taps **Change recipe** → **Recipe list**.
3. User browses list and may:
   - Tap a recipe row → **Recipe detail**, then **Use this recipe**
   - Or directly select “Use this recipe” from list (if provided)
4. Back on **Confirm inputs**, user adjusts:
   - Dose or target yield → app scales automatically using last-edited-wins
   - Grind label and temperature
5. If values are out of recommended ranges, user sees **non-blocking warnings**.
6. User taps **Start brew**:
   - If recipe is invalid → start is blocked with explanation + “Edit to fix” path
7. App presents **Brew session** as a **full-screen modal**:
   - Inputs are hidden/locked
   - User advances steps with **Next step**, uses **Pause/Resume**
   - Exiting prompts confirmation; restart requires confirm + press-and-hold
8. Completing the final step transitions to **Post-brew** (still inside modal).
9. User selects **rating (required)**, optionally a taste tag and note (≤ 280 chars).
10. User taps **Save brew**:
    - If validation fails (e.g., missing rating, note too long) → inline error; stay on screen
11. On success, modal dismisses (or offers “View log”), and the log appears in **Logs** tab.

### 3.2 Secondary Journeys

- **Browse recipe details before brewing**:
  - Confirm inputs → Change recipe → Recipe list → Recipe detail (read steps/defaults) → Use this recipe

- **Duplicate starter recipe and edit**:
  - Recipe detail (starter) → Duplicate → Recipe edit → Save → appears as custom in list

- **Fix an invalid custom recipe**:
  - Recipe list shows “Invalid” badge → open detail → Edit to fix → inline errors + summary banner → Save enabled when valid

- **View and manage logs**:
  - Logs tab → Logs list → Log detail → optional “View recipe” → delete with confirmation

- **Enable sync (optional)**:
  - Settings → Sync (optional) → Sign in with Apple → toggle sync on → status shows enabled → failures shown inline; retry only here

- **Handle conflicts**:
  - After sync resolves conflicts, Recipes list shows a **Conflicted Copy** recipe explicitly labeled; user can open and manage it like any other custom recipe

## 4. Layout and Navigation Structure

### 4.1 Navigation model

- **Tab bar (persistent)**: Recipes / Logs / Settings
- **Per-tab stacks**:
  - Recipes stack: Confirm inputs (root) → Recipe list → Recipe detail → Recipe edit
  - Logs stack: Logs list (root) → Log detail → (optional) Recipe detail
  - Settings stack: Settings (root) → Data deletion request

### 4.2 Modal flow

- **Full-screen modal**: Brew session flow
  - Presented from Confirm inputs
  - Internally navigates: Brew steps → Post-brew
  - Protected exit behavior:
    - Attempt to dismiss during active brewing shows confirmation prompt
    - Restart requires confirmation + press-and-hold

### 4.3 State persistence across navigation

- **Last-selected recipe** persisted in preferences; Confirm inputs always reflects it on launch.
- **Draft editing state** in Recipe edit is local to the edit screen and is discarded on Cancel.
- **Sync retry** is intentionally scoped to Settings; other screens display inline, non-blocking states only (no global retry UI).

## 5. Key Components

These components are shared patterns used across multiple views (names are conceptual, not implementation commitments).

- **PrimaryActionButton**: Large, bottom-anchored primary CTA (Start brew / Next step / Save brew).
- **InlineErrorText + FieldErrorState**: Consistent per-field validation messaging.
- **ValidationSummaryBanner**: “Fix X issues to save” with optional jump-to-first-issue.
- **RangeWarningBanner / WarningList**: Non-blocking warnings for recommended-range violations.
- **NumericInputRow**: Labeled numeric entry with unit (g/°C), stepper support where appropriate.
- **GrindLabelSelector**: Simple label picker with tactile descriptor display.
- **RecipeBadgeSet**: Starter / Invalid / Conflicted Copy badges used in lists and headers.
- **PressAndHoldConfirmButton**: Guarded destructive action (Restart brew).
- **ExitConfirmationDialog**: Confirm leaving active brew session.
- **StepCard**: Current step display (instruction + water target + time guidance).
- **CountdownTimerView**: Countdown + “Ready to advance” state (requires manual Next).
- **LogSummaryRow**: Timestamp + recipeNameAtBrew + rating + taste tag.
- **SyncStatusRow**: Local only / Sync enabled, last sync attempt, inline failure messaging, retry action.

---

## Appendix A: Key Requirements Extracted from the PRD (UI-Relevant)

- **Global**
  - Units: grams (dose/water/yield) and °C (temperature)
  - Kitchen-proof UX: large primary actions; restart safeguards; inputs locked after start
  - Accessibility/usability: minimum touch targets; core flow should be readable and operable
  - Offline-first: core flows work without network
- **Auth + Sync**
  - Sign in with Apple; optional for use, required for sync
  - Sync data: custom recipes, brew logs, preferences (last selected recipe)
  - Conflict handling: recipes keep both (Conflicted Copy); logs append-only
  - Provide a user-visible synced data deletion request path
- **Recipes**
  - One starter V60 recipe; not editable in-place; duplicate to edit
  - Custom recipes can be edited and deleted
  - Structured step model with timers and water targets
  - Validation blocks save and blocks brew; water totals must match target yield (±1g), timers non-negative
- **Confirm Inputs + Scaling**
  - Confirm inputs screen: dose, yield, grind label, temp; derived ratio; warnings out-of-range but do not block
  - Scaling: last edited wins; rounding (dose 0.1g; yield/water 1g); V60-specific water split rule
- **Brew Flow**
  - Guided steps; Next step; Pause/Resume; Restart guarded; lock inputs
  - Timer reaches zero → clear completion state; user confirms with Next
- **Logs**
  - Post-brew: Save default; rating required; optional taste tag + note (≤ 280)
  - Logs list and detail; delete with confirmation
  - Static hint mapping based on taste tag

## Appendix B: Main “API Endpoints” (Internal) and Purposes

- **Recipes**
  - `fetchRecipes(for:)` → list recipes for method (MVP V60)
  - `fetchRecipe(byId:)` → recipe detail with ordered steps
  - `createCustomRecipe(...)` → create a custom recipe with validation
  - `updateCustomRecipe(...)` → update a custom recipe with validation; reject starter edits
  - `deleteCustomRecipe(...)` → delete custom recipe (not starter)
  - `duplicate(recipe)` → create a copy (including conflicted copy naming when needed)
  - `validate(recipeDraft)` → return `[RecipeValidationError]`
  - `assertRecipeIsBrewable(recipeId)` → gate brewing with actionable errors
- **Scaling**
  - `scaleInputs(request)` → scaled dose/yield/water targets + derived ratio + warnings
- **Brew Session**
  - `createPlan(...)` → build a brew plan for a recipe and inputs
  - `start/pause/resume/nextStep/restart` → state machine operations for the guided flow
- **Brew Logs**
  - `fetchAllLogs()` / `fetchLog(byId:)` → list/detail from snapshots
  - `saveBrewLog(request)` → validate and save post-brew log
  - `deleteLog(id)` → delete log (with UI confirmation)
  - `hint(for:)` → static taste-tag hint text
- **Preferences**
  - `get/setLastSelectedRecipeId`
  - `get/setSyncEnabled`
  - `getAppleUserId` (internal; not displayed)
- **Auth + Sync**
  - `signInWithApple()` / `signOut()`
  - `enableSync()` / `disableSync()`
  - `requestDataDeletion()`

## Appendix C: PRD User Stories → UI Mapping

- **US-001**: App launch to Confirm inputs → `ConfirmInputsView` (Recipes tab root) + preferences-backed last selection
- **US-002**: View starter details + steps → `RecipeDetailView` (starter; no Edit)
- **US-003**: Browse/select recipe → `RecipeListView` selection → `ConfirmInputsView`
- **US-004**: Confirm editable inputs + ratio → `ConfirmInputsView` input rows + ratio row
- **US-005/US-006**: Scaling last-edited-wins → `ConfirmInputsView` scaling response updates
- **US-007**: Warnings without blocking + reset defaults → `WarningList` + `Reset to defaults` action
- **US-009**: Start guided brew → `Start brew` → `BrewSessionFlowView` full-screen modal
- **US-010**: Lock editing after start → brew modal hides inputs; no editing affordances
- **US-011**: Next step control → `Next step` primary button in brew modal
- **US-012**: Timed steps + completion state → `CountdownTimerView` + “ready” state + manual Next
- **US-013**: Pause/Resume → `Pause/Resume` primary control in brew modal
- **US-014**: Restart safeguards → confirm + `PressAndHoldConfirmButton`
- **US-015**: Prevent accidental exit → exit confirmation dialog on dismiss attempt
- **US-016**: Completion to post-brew summary → `PostBrewView` after final step
- **US-017**: Save log with required rating → `PostBrewView` rating required; Save disabled until set
- **US-018**: Optional taste tag → `PostBrewView` tag chips single-select
- **US-019**: Optional note + 280 char limit → `PostBrewView` note field + counter + limit enforcement
- **US-020**: Static hint mapping → `PostBrewView` hint text area
- **US-021**: Logs list → `LogsListView`
- **US-022**: Log detail → `LogDetailView`
- **US-023**: Delete log with confirmation → swipe delete + confirm; detail delete + confirm
- **US-024**: Duplicate starter recipe → `RecipeDetailView` (starter) “Duplicate” → `RecipeEditView`
- **US-025**: Edit custom recipe with validation → `RecipeEditView` inline errors + summary banner; save gating
- **US-026**: Prevent brewing invalid recipe → `RecipeListView` invalid badge + `ConfirmInputsView` start blocked + “Edit to fix”
- **US-027**: Delete custom recipe with confirmation → list/detail delete flows
- **US-028**: Sign in with Apple to enable sync → `SettingsView` Sync section sign-in CTA
- **US-029**: Handle sign-in cancel/fail → `SettingsView` inline error state + retry; app remains local-only
- **US-030**: Sign out → `SettingsView` sign-out action + sync disabled indicator
- **US-031**: Sync entities when online → `SettingsView` status indicates enabled; no blocking UI elsewhere
- **US-032**: Sync failures gracefully → `SettingsView` inline failure + “Retry sync”; elsewhere remains usable
- **US-033**: Recipe conflicts keep both → `RecipeBadgeSet` + naming “(Conflicted Copy)” in list/detail
- **US-034**: Use app offline → all primary flows (Confirm inputs, brew, save log, browse recipes/logs) require no network; settings communicates “Local only”
- **US-035**: Delete synced data → `DataDeletionRequestView` in Settings with explanation + confirm request

## Appendix D: Requirements → UI Elements (Explicit Mapping)

- **Units (g, °C)** → numeric input rows with unit labels; log parameter displays; recipe defaults displays
- **Kitchen-proof UX** → large primary CTAs; separated Next/Pause controls; guarded restart; simplified brew screen; minimal text entry
- **Lock inputs after start** → brew modal hides inputs; no editable controls; explicit messaging if needed
- **Restart safeguards** → confirmation + press-and-hold restart control
- **Exit protection** → dismiss interception with confirmation prompt during active session
- **Out-of-range warnings (non-blocking)** → warning list on Confirm inputs; proceed still allowed
- **Recipe starter immutability** → hide Edit for starter; provide Duplicate as the path to customization
- **Validation blocks save and brew** → `RecipeEditView` inline errors + summary banner + Save disabled; invalid badge and Start brew gating with fix path
- **Scaling behavior** → Confirm inputs auto-recompute on dose/yield changes; show derived ratio
- **Post-brew required rating** → Save disabled until rating; inline requirement text
- **Note max length** → live counter + input limiting at 280
- **Static taste-tag hint** → hint panel based on selected tag
- **Sync optional & settings-only retry** → Settings Sync section with status + retry; no global retry UI
- **Conflict visibility** → list/detail badges and naming convention “(Conflicted Copy)”
- **Data deletion request** → Settings sub-screen with explicit explanation + confirm request

## Appendix E: Edge Cases / Error States (UI Handling)

- **Recipe fetch failure**: inline empty/error state with a non-blocking retry (except sync retry remains Settings-only).
- **No recipes available (unexpected)**: show fallback message and re-seed prompt (MVP should seed starter).
- **Invalid recipe selected as last-used**: Confirm inputs shows “Can’t start” state with explanation + “Edit to fix” (custom) or “Duplicate to fix” (starter-based custom flow).
- **Scaling produces extreme values**: show warnings; keep Start available unless values are invalid (≤ 0).
- **Brew interrupted (app backgrounded / screen locked)**: on return, show session resumed state; do not promise lock-screen accuracy (MVP non-goal).
- **Accidental modal dismiss attempt**: confirm prompt; default to staying in brew.
- **Save log fails validation**: keep user on Post-brew with inline errors (rating missing, note too long).
- **Delete actions**: always require confirmation (logs and custom recipes).
- **Sign-in canceled/failed**: inline message in Settings; remain in Local only mode; offer retry.
- **Sync fails**: show status “Sync unavailable” + last attempt outcome; provide “Retry sync” only in Settings; other screens remain usable.
- **Conflict created by sync**: surface as a distinct recipe with Conflicted Copy badge/subtitle; user can rename/edit/delete like any custom recipe.

## Appendix F: Anticipated User Pain Points and UI Mitigations

- **“I just want to start brewing”** → Launch to Confirm inputs with prominent Start brew; recipe change is one tap away.
- **Wet hands / accidental taps** → large controls; destructive actions guarded; simplified brew screen.
- **Confusion about what changed when scaling** → derived ratio visible; scaled values update immediately; warnings explain recommended ranges.
- **Validation frustration in recipe editing** → inline errors + summary banner; Save disabled until valid; specific step highlighting for water-total mismatches.
- **Fear of signing in / privacy concerns** → Settings frames sync as optional; clear Local-only status; explicit data deletion request flow.
- **Sync errors interrupting core use** → sync failures are informational and isolated to Settings with manual retry only there.
