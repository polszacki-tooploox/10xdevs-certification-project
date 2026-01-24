# Product Requirements Document (PRD) - BrewGuide

## 1. Product Overview

### 1.1 Summary
BrewGuide is an iOS app that improves home coffee consistency by guiding beginner-to-intermediate brewers through a simple, timer-based V60 brew flow. The app provides one V60 starter recipe, allows users to duplicate and edit recipes with guardrails, automatically scales recipe quantities based on dose or target yield, and captures a lightweight post-brew log (rating + optional taste tag + note).

### 1.2 Target user and context
- Target user: beginner-to-intermediate home brewer focused on repeatability/consistency.
- Primary context of use: phone on a kitchen counter; wet hands; one-handed; low attention.
- Assumed equipment: grinder, 0.1 g scale, kettle with temperature readout, V60-style dripper and filters.

### 1.3 Platforms
- iOS-only for MVP.

### 1.4 Key product principles
- Kitchen-proof interaction: large primary actions; minimal typing; clear, sequential steps.
- Guardrails over power: structured recipes, validated edits, and clear warnings for out-of-range inputs.
- Repeatability first: log essential parameters and quick reflection after each brew.

### 1.5 Measurement note
Success targets are defined as planning goals. MVP does not include analytics instrumentation.

## 2. User Problem

### 2.1 Problem statement
Home coffee brewing is inconsistent because users struggle to translate a recipe into correct grind size, dose, water temperature, timing, and technique for a given brewer and coffee. Even when users follow a recipe, inconsistent execution (timing, step order, scaled amounts) leads to variable results.

### 2.2 Why this matters
- Beginners cannot reliably diagnose whether the issue is grind, ratio, temperature, or technique.
- Recipes often assume familiarity with steps (bloom timing, pour pacing, steep time, shot timing).
- Small input changes (dose/yield) require recalculations that users often do incorrectly.

### 2.3 Primary job-to-be-done
Help users execute a known-good recipe consistently, with minimal cognitive load during brewing, and capture a simple outcome signal (rating/tag/note) to guide the next adjustment.

## 3. Functional Requirements

### 3.1 Global requirements
1. Units
   - The app uses grams (g) for coffee dose, water additions, and target yield across the app.
   - Water temperature is entered and displayed in degrees Celsius (°C).

2. Kitchen-proof UX
   - Large, separated primary actions during brewing: Next step, Pause/Resume.
   - Restart requires confirmation and a press-and-hold action to prevent accidental resets.
   - Once a brew starts, editing of parameters is locked until brew completion or restart.

3. Accessibility and usability
   - Text and controls support Dynamic Type and VoiceOver for the core brew flow screens.
   - Touch targets meet iOS minimum guidelines (44x44 pt) for primary controls.

4. Offline capability (minimum)
   - App functions without network for core brewing and logging.
   - Sync (if enabled) runs opportunistically when connectivity is available.

### 3.2 Authentication and sync (MVP)
1. Authentication
   - Support Sign in with Apple.
   - Users can use the app without signing in; sign-in is required to enable cloud sync.

2. Data synchronized (essential only)
   - User identifier (from Sign in with Apple).
   - Custom recipes (duplicates of starter recipes).
   - Brew logs.
   - Basic preferences (last selected recipe).

3. Security and privacy requirements
   - Provide a user-visible way to delete synced data (account/data deletion request).

4. Conflict handling (MVP)
   - Local-first edits are allowed offline.
   - When syncing, if the same entity is edited on multiple devices, the app must resolve conflicts by:
     - Brew logs: treat as append-only; duplicates are allowed.
     - Recipes: if a conflict occurs, keep both by creating a duplicate recipe labeled as a conflicted copy (for example, “My V60 (Conflicted Copy)”).

### 3.3 Brew mode (MVP)
1. Supported brew method
   - V60 only

2. Entry behavior
   - On first run, the user lands directly on the V60 recipe selection/confirmation flow (starter recipe preselected).
   - The last selected recipe is remembered and preselected on next launch.

### 3.4 Recipe library (MVP)
1. Starter recipes
   - Exactly one starter recipe (V60).
   - Starter recipes are not editable in-place; users must duplicate and edit.

2. Custom recipes
   - Users can duplicate a starter recipe, edit the duplicate, and save it as a custom recipe.
   - Users can delete custom recipes.
   - Users cannot delete starter recipes.

3. Recipe model (structured, step-based)
   - Each recipe includes:
     - Method (V60 only in MVP)
     - Name
     - Default dose (g)
     - Default target yield (g)
     - Default water temperature (°C)
     - Default grind label (fine/medium/coarse) and tactile descriptors
     - Step sequence with quantitative details and timers

4. Editing guardrails and validation
   - Validation runs when a user edits or saves a recipe.
   - If a recipe is invalid, the app blocks use until fixed.
   - Validation rules (minimum set):
     - All step timers are non-negative.
     - The sum of water addition step weights must equal target yield (within ±1 g tolerance after rounding).

### 3.5 Starter recipes (MVP defaults)
The following starter recipes are included and serve as editable templates via duplication.

1. V60 starter recipe (single cup)
   - Default dose: 15 g
   - Default target yield: 250 g
   - Ratio: 1:16.7
   - Water temperature: 94 °C
   - Grind guidance: medium (tactile: sand; slightly finer than sea salt)
   - Steps:
     - Step 1: Rinse filter and preheat (instruction)
     - Step 2: Add coffee, level bed (instruction)
     - Step 3: Bloom: pour 45 g, start timer 0:45 (water addition + timer)
     - Step 4: Pour to 150 g by 1:30 (water addition + timer guidance)
     - Step 5: Pour to 250 g by 2:15 (water addition + timer guidance)
     - Step 6: Wait for drawdown, target finish 3:00–3:30 (timer guidance)

### 3.6 Guided brewing flow (MVP)
1. Core flow
   - V60 recipe (starter selected by default) → Confirm inputs → Brew.

2. Confirm inputs screen
   - Inputs (editable before start):
     - Coffee dose (g)
     - Target yield (g)
     - Grind label (fine/medium/coarse) with tactile descriptors
     - Water temperature (°C)
   - Display derived values:
     - Ratio (yield / dose)
     - Method-specific warnings when inputs are out of recommended ranges
   - Primary actions:
     - Start brew
     - Change recipe

3. Brew execution screen
   - Shows the current step, step details (quantities, instructions), and a timer when applicable.
   - Controls:
     - Next step (primary)
     - Pause / Resume (primary)
     - Restart (guarded by confirmation + press-and-hold)
   - Parameter editing is locked after Start brew.

4. Timer behavior (MVP)
   - Supports Start, Pause, Resume, Restart.
   - When the timer reaches zero, the app signals completion (visual state change); user confirms by tapping Next step.

### 3.7 Scaling (MVP)
1. Scaling trigger
   - Scaling occurs on the Confirm inputs screen when the user edits dose or target yield.

2. Scaling model
   - Recipe steps are scaled proportionally based on the ratio implied by the recipe defaults, unless the recipe itself defines fixed step weights.
   - The app uses a “last edited wins” approach:
     - If the user edits dose last, target yield recalculates from the recipe’s ratio.
     - If the user edits target yield last, dose recalculates from the recipe’s ratio.

3. Rounding
   - Water additions and yield are rounded to the nearest 1 g.
   - Dose is rounded to the nearest 0.1 g (for scale compatibility).

4. Recommended ranges and guardrails - user is allowed to manually enter values outside of the default ranges.
   - V60:
     - Dose: 12–40 g
     - Target yield: 180–720 g
     - Ratio range: 1:14 to 1:18
     - Temperature: 90–96 °C

5. Step-level scaling rules (MVP)
   - V60:
     - Bloom water is 3x dose (rounded to nearest 1 g).
     - Remaining water is split into two pours with 50/50 distribution (rounded; adjust final pour to ensure totals match).

### 3.8 Brew log (MVP)
1. Log creation
   - After a brew completes, the default primary action is Save brew.

2. Data captured per log entry
   - Timestamp
   - Method (V60)
   - Recipe used (starter vs custom, and recipe identifier/name)
   - Dose (g)
   - Target yield (g)
   - Water temperature (°C)
   - Grind label (fine/medium/coarse)
   - Rating (1–5)
   - Optional quick taste tag (one of: too bitter, too sour, too weak, too strong)
   - Optional short note (free text)

3. Log viewing
   - Users can view a chronological list of logs.
   - Users can view log detail.
   - Users can delete a log entry.

4. Post-brew adjustment hint (non-personalized)
   - After saving (or on the post-brew screen), show a simple, method-agnostic hint based on the selected quick taste tag:
     - Too sour: try slightly finer or hotter
     - Too bitter: try slightly coarser or cooler
     - Too weak: try higher dose or finer
     - Too strong: try lower dose or coarser
     - Perfect: great job - no tips!
   - Hints are static and do not adapt over time in MVP.

## 4. Product Boundaries

### 4.1 In scope (MVP)
- iOS application.
- Method: V60 only.
- One starter recipe total (V60).
- Guided brewing flow with timers, next-step progression, and pause/resume/restart.
- Parameter input and method-specific grind guidance using simple labels and tactile descriptors.
- Scaling of recipe quantities based on dose or yield with recommended ranges and warnings (no clamping).
- Lightweight brew logging with rating + optional quick tag + optional note.
- Sign in with Apple and cloud sync of essential data only (as defined in Functional Requirements).

### 4.2 Out of scope (MVP)
- AeroPress and Espresso brew modes.
- Grinder-specific calibration and advanced grind guidance.
- AI personalization, recommendations, or automatic diagnosis.
- Advanced espresso features (pressure profiling, flow curves, shot diagnostics, puck prep coaching).
- Inventory management (beans, roast dates), shopping lists, subscriptions.
- Social/sharing features, community recipes, multi-user accounts, cross-platform support.
- Integrations with smart scales, Bluetooth thermometers, or espresso machine connectivity.
- Background/lock-screen timer guarantees and rich interruption handling.
- Analytics instrumentation for the success targets.

### 4.3 Explicit non-goals for MVP UX
- No lock-screen/background timer guarantees.
- No machine-specific or grinder-specific recommendations beyond static, descriptive guidance.

## 5. User Stories

### US-001
- ID: US-001
- Title: Land on V60 brew entry screen
- Description: As a user, I want to open the app and immediately access the V60 brew flow so I can start brewing quickly.
- Acceptance Criteria:
  - On app launch, the user lands on the V60 recipe selection/confirmation flow.
  - The V60 starter recipe is preselected by default.
  - The last selected recipe is remembered and preselected on next app launch.

### US-002
- ID: US-002
- Title: View V60 starter recipe details
- Description: As a user, I want to view the V60 starter recipe defaults and step list so I can understand what I’m about to brew.
- Acceptance Criteria:
  - Exactly one starter recipe exists (V60).
  - The recipe view shows default dose, target yield, temperature, grind guidance, and the full step list.
  - The starter recipe is labeled as starter and cannot be edited in-place.

### US-003
- ID: US-003
- Title: Browse and select a V60 recipe
- Description: As a user, I want to choose between the V60 starter recipe and my V60 custom recipes so I can brew the one I prefer.
- Acceptance Criteria:
  - The recipe list shows the V60 starter recipe and all V60 custom recipes.
  - The app allows selecting exactly one recipe to proceed to Confirm inputs.

### US-004
- ID: US-004
- Title: Confirm brew inputs before starting
- Description: As a user, I want to confirm and adjust dose, target yield, grind guidance, and water temperature before starting so the brew matches my intent and equipment.
- Acceptance Criteria:
  - Dose, target yield, grind label, and temperature are editable before starting.
  - The screen displays the derived ratio (target yield / dose).
  - A Start brew action is available when inputs are valid.

### US-005
- ID: US-005
- Title: Automatically scale a V60 recipe when dose changes
- Description: As a user, when I change the coffee dose before starting, I want the app to automatically adjust target yield and step quantities so I can scale the V60 recipe accurately.
- Acceptance Criteria:
  - If dose is edited last, target yield updates automatically using the recipe ratio.
  - V60 water addition steps update to match the new target yield.
  - Updated values are rounded according to the rounding rules.

### US-006
- ID: US-006
- Title: Automatically scale a V60 recipe when target yield changes
- Description: As a user, when I change target yield before starting, I want the app to automatically adjust dose and step quantities so the V60 recipe remains consistent.
- Acceptance Criteria:
  - If target yield is edited last, dose updates automatically using the recipe ratio.
  - V60 water addition steps update to match the new target yield.
  - Updated values are rounded according to the rounding rules.

### US-007
- ID: US-007
- Title: Warn on out-of-range inputs without blocking
- Description: As a user, I want warnings when I enter values outside recommended V60 ranges, while still being able to proceed.
- Acceptance Criteria:
  - Recommended V60 ranges are shown when violated.
  - The user can proceed without clamping.
  - A Reset to defaults action is available.

### US-009
- ID: US-009
- Title: Start a guided V60 brew
- Description: As a user, I want to start the guided brew so I can follow step-by-step V60 instructions and timers.
- Acceptance Criteria:
  - Tapping Start brew begins the brew flow.
  - Once started, inputs become read-only until brew completion or restart.
  - The first step is displayed with quantities and a timer when applicable.

### US-010
- ID: US-010
- Title: Lock parameter editing after brew starts
- Description: As a user, I want the app to prevent editing brew inputs once brewing begins so I don’t accidentally change parameters mid-flow.
- Acceptance Criteria:
  - During an active brew, dose/yield/grind/temperature fields are not editable.
  - If the user tries to edit via any control, the app indicates inputs are locked until completion or restart.

### US-011
- ID: US-011
- Title: Advance to the next step
- Description: As a user, I want to advance through steps using a large Next step control so I can progress with minimal interaction.
- Acceptance Criteria:
  - A Next step control is present throughout the brew flow.
  - Tapping Next step advances to the next recipe step.
  - On the final step, Next step completes the brew and opens the post-brew screen.

### US-012
- ID: US-012
- Title: Use timers for timed steps
- Description: As a user, I want the app to run timers for timed steps so I can execute time-sensitive actions accurately.
- Acceptance Criteria:
  - Timed steps display a countdown timer.
  - When the timer reaches zero, the app clearly indicates the step is ready to advance and awaits user confirmation via Next step.

### US-013
- ID: US-013
- Title: Pause and resume a brew timer
- Description: As a user, I want to pause and resume the timer so I can handle brief interruptions without losing my place.
- Acceptance Criteria:
  - Pause stops the countdown and switches the control to Resume.
  - Resume continues from the paused time.
  - Pausing does not unlock editing of brew parameters.

### US-014
- ID: US-014
- Title: Restart a brew with safeguards
- Description: As a user, I want to restart a brew if I make a mistake, with safeguards to prevent accidental restarts.
- Acceptance Criteria:
  - Restart is available during the brew flow.
  - Restart requires a confirmation step and a press-and-hold gesture.
  - Restart returns the brew to step 1 and resets timers.

### US-015
- ID: US-015
- Title: Prevent accidental exit from an active brew
- Description: As a user, I want a clear warning if I try to leave an active brew so I don’t lose my place.
- Acceptance Criteria:
  - If the user attempts to navigate away during an active brew, the app shows a confirmation prompt.
  - The prompt offers options to stay on the brew screen or leave.

### US-016
- ID: US-016
- Title: Complete a brew and land on post-brew screen
- Description: As a user, I want a clear completion state after the last step so I can save my brew or discard it.
- Acceptance Criteria:
  - Completing the final step shows a post-brew summary screen.
  - The summary displays recipe, dose, yield, temperature, and grind label.
  - The primary action is Save brew.
  - A secondary action allows discarding without saving.

### US-017
- ID: US-017
- Title: Save a brew log with rating
- Description: As a user, I want to save my brew with a 1–5 rating so I can track outcomes over time.
- Acceptance Criteria:
  - Saving requires selecting a rating from 1 to 5.
  - The saved log includes timestamp, method (V60), recipe, dose, yield, temperature, grind label, and rating.
  - After saving, the user can view the saved log entry.

### US-018
- ID: US-018
- Title: Add a quick taste tag
- Description: As a user, I want to optionally add a quick taste tag so I can capture what went wrong without typing a long note.
- Acceptance Criteria:
  - The user can select zero or one tag from: too bitter, too sour, too weak, too strong.
  - The selected tag is stored with the brew log.
  - The user can change or clear the tag before saving.

### US-019
- ID: US-019
- Title: Add an optional note to a brew log
- Description: As a user, I want to optionally add a short note so I can remember details like beans, grind change, or what I’d do next time.
- Acceptance Criteria:
  - The note field is optional.
  - Notes are limited to a fixed maximum length (for example, 280 characters) and enforce that limit.
  - The note is stored with the brew log.

### US-020
- ID: US-020
- Title: See a simple post-brew adjustment hint
- Description: As a user, I want a simple hint after brewing based on my taste tag so I know what to try next time.
- Acceptance Criteria:
  - If a taste tag is selected, a static hint is displayed after saving (or on the post-brew screen).
  - Hints do not reference personalization or learning.
  - Hints follow the defined mapping in Functional Requirements.

### US-021
- ID: US-021
- Title: View brew log list
- Description: As a user, I want to view a list of my past brews so I can recall what I did and how it turned out.
- Acceptance Criteria:
  - The app shows a chronological list of brew logs.
  - Each list item shows at minimum: date/time, rating, and recipe name.
  - The user can open a log detail view from the list.

### US-022
- ID: US-022
- Title: View brew log detail
- Description: As a user, I want to view the details of a specific brew log so I can see the exact parameters used and my notes.
- Acceptance Criteria:
  - Log detail shows recipe, dose, yield, temperature, grind label, rating, optional taste tag, optional note, and timestamp.

### US-023
- ID: US-023
- Title: Delete a brew log entry
- Description: As a user, I want to delete an incorrect or accidental log entry so my history stays accurate.
- Acceptance Criteria:
  - The user can delete a log entry from the list or detail view.
  - Deletion requires a confirmation prompt.
  - Deleted logs are removed locally and, if sync is enabled, the deletion is synced.

### US-024
- ID: US-024
- Title: Duplicate the V60 starter recipe
- Description: As a user, I want to duplicate the V60 starter recipe so I can tweak it while keeping the original intact.
- Acceptance Criteria:
  - A Duplicate action creates a new custom recipe based on the V60 starter recipe.
  - The starter recipe remains unchanged.
  - The custom recipe appears in the V60 recipe list.

### US-025
- ID: US-025
- Title: Edit a custom V60 recipe with validation
- Description: As a user, I want to edit my custom recipe defaults and steps while staying within usable constraints.
- Acceptance Criteria:
  - The user can edit: name, default dose, default yield, temperature, grind guidance, and step timers/weights.
  - Saving runs validation rules.
  - If validation fails, the app shows specific errors and does not save invalid changes.

### US-026
- ID: US-026
- Title: Prevent brewing with an invalid custom recipe
- Description: As a user, I want the app to prevent starting a brew with an invalid recipe so I don’t get stuck mid-brew.
- Acceptance Criteria:
  - Invalid recipes are clearly marked in the recipe list.
  - Starting a brew is blocked for invalid recipes with a clear explanation and a path to edit/fix.

### US-027
- ID: US-027
- Title: Delete a custom V60 recipe
- Description: As a user, I want to delete custom recipes I no longer use so the recipe list stays clean.
- Acceptance Criteria:
  - The user can delete a custom recipe.
  - Deleting requires confirmation.
  - The starter recipe cannot be deleted.

### US-028
- ID: US-028
- Title: Sign in with Apple to enable sync
- Description: As a user, I want to sign in with Apple so I can sync my recipes and brew logs across devices securely.
- Acceptance Criteria:
  - The app supports Sign in with Apple.
  - After successful sign-in, sync is enabled and runs without blocking core usage.
  - The app does not require sign-in to brew or view logs on the current device.

### US-029
- ID: US-029
- Title: Handle sign-in cancellation or failure
- Description: As a user, if I cancel or sign-in fails, I want to keep using the app locally and understand what happened.
- Acceptance Criteria:
  - If sign-in is cancelled or fails, the app remains usable in local-only mode.
  - The app shows a clear error message and provides a retry option.

### US-030
- ID: US-030
- Title: Sign out
- Description: As a signed-in user, I want to sign out so I can stop syncing and use the app locally.
- Acceptance Criteria:
  - The user can sign out from settings.
  - After sign-out, local data remains available on the device.
  - The UI clearly indicates sync is disabled.

### US-031
- ID: US-031
- Title: Sync custom recipes and brew logs when online
- Description: As a signed-in user, I want my custom recipes and brew logs to sync so I can access them on another device.
- Acceptance Criteria:
  - When connectivity is available, local changes are uploaded and remote changes are downloaded.
  - The app remains usable during sync operations.
  - Only the entities defined in Functional Requirements are synced.

### US-032
- ID: US-032
- Title: Handle sync failures gracefully
- Description: As a user, if sync fails due to network or service issues, I want the app to keep working and retry later.
- Acceptance Criteria:
  - Core brewing, recipe editing, and logging continue to work when sync fails.
  - The app indicates sync is currently unavailable and will retry.
  - Sync retries occur when connectivity returns or the user triggers a retry from settings.

### US-033
- ID: US-033
- Title: Resolve recipe sync conflicts by keeping both versions
- Description: As a user, when the same recipe is edited on two devices, I want the app to preserve both versions so I don’t lose changes.
- Acceptance Criteria:
  - On conflict, the app creates a second custom recipe labeled as a conflicted copy.
  - The user can see and open both recipes.
  - No recipe edits are silently discarded.

### US-034
- ID: US-034
- Title: Use the app offline
- Description: As a user, I want to use the app without internet so I can brew and log anywhere.
- Acceptance Criteria:
  - Confirm inputs, brew flow, and saving logs work without network.
  - If signed in, the app queues sync changes and syncs later when connectivity returns.

### US-035
- ID: US-035
- Title: Delete my synced data
- Description: As a user, I want to request deletion of my synced data so I can control my privacy.
- Acceptance Criteria:
  - Settings provides a clear path to request data deletion.
  - The request explains what data will be deleted (recipes, logs, preferences).
  - After deletion completes, signing in on a new install does not restore deleted entities.

## 6. Success Metrics

### 6.1 Planning targets (not instrumented in MVP)
- Completion rate: at least 60% of users who start a brew flow complete it to the end (V60).
- Logging rate: at least 40% of completed brews are saved to the log with a rating or note.
- Consistency improvement: users report improved consistency with an average rating of at least 3.5/5 across logged brews after the first week of usage.

### 6.2 Qualitative success indicators (MVP)
- Users can complete a brew with minimal confusion during step transitions.
- Users understand what to change next time from the static post-brew hint (without expecting personalization).
- Users can successfully create and use a custom recipe without breaking the brew flow due to invalid edits.

### 6.3 PRD checklist review
- Is each user story testable?
  - Yes. Each story has concrete acceptance criteria with observable UI states, behaviors, and data outcomes.
- Are the acceptance criteria clear and specific?
  - Yes. Criteria specify required screens, inputs, constraints, and expected results (including edge cases like backgrounding and sync failures).
- Do we have enough user stories to build a fully functional application?
  - Yes. Stories cover V60 recipe selection, scaling/guardrails, guided brewing timers and controls, logging, recipe duplication/editing/validation, authentication, sync, offline use, and data deletion.
- Have we included authentication and authorization requirements (if applicable)?
  - Yes. Sign in with Apple is required for sync, optional for local use, includes failure handling, sign out, and deletion of synced data. Authorization is implicit via user identity scoping of synced entities.

