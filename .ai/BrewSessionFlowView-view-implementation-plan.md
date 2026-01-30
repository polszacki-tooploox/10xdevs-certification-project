# View Implementation Plan BrewSessionFlowView

## 1. Overview
`BrewSessionFlowView` is a full-screen modal that runs a guided brew session (V60 in MVP) with step-by-step progression and optional countdown timers. It is optimized for “kitchen-proof” use: large primary actions, minimal navigation, no parameter editing during the session, and safeguards against accidental exit or restart. When the final step completes, it transitions in-place to `PostBrewView` to capture the outcome (rating + optional taste tag + optional note) and save/discard the brew log.

## 2. View Routing
- **Entry point**: `ConfirmInputsViewModel.startBrew(context:coordinator:)` creates a `BrewPlan` using `BrewSessionUseCase.createPlan(from:)`, then calls `AppRootCoordinator.presentBrewSession(plan:)`.
- **Presentation**: `AppRootView` presents the flow via:
  - `.fullScreenCover(item: $coordinator.activeBrewSession) { presentation in BrewSessionFlowView(presentation: presentation) }`
- **Dismissal**:
  - User selects **Exit** → confirmation prompt → `coordinator.dismissBrewSession()`
  - Brew completes → `PostBrewView` Save/Discard → `coordinator.dismissBrewSession()`

## 3. Component Structure
High-level composition (SwiftUI “components” = `View` structs):

```
AppRootView
└─ fullScreenCover(item: activeBrewSession)
   └─ BrewSessionFlowView (screen)
      ├─ BrewSessionHeaderBar (toolbar title + Exit)
      ├─ BrewSessionContent
      │  ├─ BrewSessionProgressView
      │  ├─ BrewNowStepCard
      │  ├─ BrewTimerPanel (only when step has timer)
      │  ├─ BrewSessionPrimaryControls (Next, Pause/Resume)
      │  └─ BrewSessionSecondaryControls (Restart hold-to-confirm)
      └─ PostBrewView (when completed)
```

## 4. Component Details

### BrewSessionFlowView
- **Description**: Full-screen modal host for the brew session state machine and the post-brew outcome screen.
- **Main elements**:
  - `NavigationStack` (for a toolbar/title only; no push navigation expected inside the modal)
  - Conditional body:
    - Brewing state → `BrewSessionContent`
    - Completed state → `PostBrewView`
  - `.interactiveDismissDisabled(true)` to prevent accidental swipe-to-dismiss
  - Exit confirmation UI via `alert` or `confirmationDialog`
- **Handled events**:
  - `onAppear`: initialize view model with `presentation.plan`
  - Exit tapped: present exit confirmation if brew is active/not completed
  - Confirm exit: stop timer task, dismiss modal via coordinator
  - Post-brew save/discard: forward to view model and dismiss modal
- **Props**:
  - `presentation: BrewSessionPresentation`

### BrewSessionContent
- **Description**: “Brewing” screen content when the session is not completed.
- **Main elements**:
  - `BrewSessionProgressView` (progress indicator + “Step X of Y”)
  - `BrewNowStepCard` (large instruction + optional water target)
  - `BrewTimerPanel` (if `currentStep.timerDurationSeconds != nil`)
  - Primary + secondary control groups sized for wet-hands use
- **Handled events**:
  - None directly; delegates to view model via closures.
- **Props**:
  - `state: BrewSessionState`
  - `uiState: BrewSessionFlowUIState` (derived display state)
  - Event closures:
    - `onNextStep()`
    - `onPauseResume()`
    - `onRestartHoldConfirmed()`

### BrewSessionProgressView
- **Description**: Lightweight progress indicator for session orientation.
- **Main elements**:
  - `ProgressView(value: state.progress)`
  - “Step \(index + 1) of \(count)” text (Dynamic Type-friendly)
- **Handled events**: none
- **Props**:
  - `currentStepIndex: Int`
  - `stepCount: Int`
  - `progress: Double`

### BrewNowStepCard
- **Description**: Prominent “Now” card with the current instruction and water target when applicable.
- **Main elements**:
  - Instruction text (large, multiline, high contrast)
  - Optional water row:
    - icon
    - formatted grams
    - label (“pour” vs “total”)
- **Handled events**: none
- **Props**:
  - `step: ScaledStep`
  - `formattedWater: String?` (already formatted for display)

### BrewTimerPanel
- **Description**: Countdown timer UI with clear “ready” state and optional progress bar.
- **Main elements**:
  - Countdown text using Dynamic Type-safe style (no fixed font sizes)
  - “Ready” callout when remaining time reaches 0
  - Linear progress (optional) based on `remaining / duration`
- **Handled events**: none
- **Props**:
  - `remaining: TimeInterval`
  - `duration: TimeInterval`
  - `phase: BrewSessionState.Phase` (for “active/paused/ready” styling)

### BrewSessionPrimaryControls
- **Description**: The two large, separated primary actions required by the PRD: Next step and Pause/Resume.
- **Main elements**:
  - **Next step** button:
    - Always visible throughout the brew flow
    - Enabled when:
      - current step has no timer, OR
      - timer reached 0 (`phase == .stepReadyToAdvance`)
    - Label adapts on last step (“Finish”)
  - **Pause/Resume** button:
    - Visible during timed steps (and optionally always visible but disabled for non-timed steps)
    - Toggle label based on `phase` (`Pause` when active, `Resume` when paused)
- **Handled events**:
  - Next tapped → `onNextStep()`
  - Pause/Resume tapped → `onPauseResume()`
- **Props**:
  - `phase: BrewSessionState.Phase`
  - `isLastStep: Bool`
  - `isNextEnabled: Bool`
  - `isPauseResumeEnabled: Bool`
  - Closures: `onNextStep`, `onPauseResume`

### BrewSessionSecondaryControls
- **Description**: Secondary actions with safeguards. MVP requires Restart with confirmation + press-and-hold.
- **Main elements**:
  - `HoldToConfirmButton` with label “Hold to Restart”
  - Optional short helper text (“Restart resets step 1 and timers.”)
- **Handled events**:
  - Hold succeeded → trigger restart confirmation dialog (optional) then `onRestartHoldConfirmed()`
- **Props**:
  - `isEnabled: Bool` (disabled if completed, or if restart is not allowed)
  - `onConfirmed: () -> Void`

### HoldToConfirmButton (reusable component)
- **Description**: A button that requires a continuous long-press for \(N\) seconds to confirm destructive actions (restart).
- **Main elements**:
  - Visible label + system image
  - Visual progress while holding (e.g., circular progress or fill animation)
  - Accessibility:
    - VoiceOver hint explaining hold requirement
    - Alternative path: if VoiceOver is running, allow a two-step confirmation dialog instead of press-and-hold (still meets the “safeguard” intent).
- **Handled events**:
  - Long press began/ended/cancelled
  - Completed hold → call `onConfirmed()`
- **Props**:
  - `title: String`
  - `systemImage: String`
  - `holdDuration: Duration` (e.g., `.seconds(1.0)` or `.seconds(1.5)`)
  - `role: ButtonRole?` (typically `.destructive`)
  - `onConfirmed: () -> Void`

## 5. Types

### Existing domain DTOs (already in code)
- `BrewInputs`
  - `recipeId: UUID`
  - `recipeName: String`
  - `method: BrewMethod`
  - `doseGrams: Double`
  - `targetYieldGrams: Double`
  - `waterTemperatureCelsius: Double`
  - `grindLabel: GrindLabel`
  - `lastEdited: BrewInputs.LastEditedField`
  - `ratio: Double` (computed)
- `ScaledStep: Identifiable`
  - `stepId: UUID`
  - `orderIndex: Int`
  - `instructionText: String`
  - `timerDurationSeconds: Double?`
  - `waterAmountGrams: Double?`
  - `isCumulativeWaterTarget: Bool`
- `BrewPlan`
  - `inputs: BrewInputs`
  - `scaledSteps: [ScaledStep]`
  - `totalWaterGrams: Double` (computed)
- `BrewSessionState`
  - `plan: BrewPlan`
  - `phase: BrewSessionState.Phase`
  - `currentStepIndex: Int`
  - `remainingTime: TimeInterval?`
  - `startedAt: Date?`
  - `isInputsLocked: Bool`
  - computed:
    - `currentStep: ScaledStep?`
    - `isLastStep: Bool`
    - `progress: Double`

### New UI model types (recommended for this view)

#### BrewSessionFlowViewModel (new)
- **Kind**: `@Observable @MainActor final class`
- **Purpose**: Single source of truth for UI state + session state transitions; owns and cancels the timer task; provides intent methods for the view.
- **Stored properties**:
  - `state: BrewSessionState`
  - `showExitConfirmation: Bool`
  - `showRestartConfirmation: Bool` (if using a 2-step restart confirm)
  - `errorBanner: BrewSessionFlowErrorBanner?` (optional non-blocking surface for rare failures)
  - `isSavingPostBrew: Bool` (if coordinating save from the host)
  - `timerTask: Task<Void, Never>?` (private)
  - `clock: any Clock<Duration>` (private, injectable; default `ContinuousClock()`)
- **Computed properties**:
  - `currentStep: ScaledStep?` (forward from state)
  - `stepCount: Int`
  - `isCompleted: Bool` (state.phase == .completed)
  - `isNextEnabled: Bool`
  - `isPauseResumeEnabled: Bool`
  - `timerDuration: TimeInterval?` (from current step)
  - `ui: BrewSessionFlowUIState` (pre-formatted strings + derived display booleans)
- **Public intent methods**:
  - `onAppear()`
  - `requestExit()`
  - `confirmExit(dismiss: () -> Void)`
  - `startStepIfNeeded()` (auto-start timer for timed steps when entering `.notStarted`)
  - `togglePauseResume()`
  - `nextStep()`
  - `restart()` (resets to step 0, clears timers, sets phase `.notStarted`)
  - `saveBrewOutcome(rating:tasteTag:note:context:) async throws` (or keep saving inside `PostBrewView` and only dismiss here)

#### BrewSessionFlowUIState (new)
- **Kind**: `struct`
- **Purpose**: View-ready values so SwiftUI code stays declarative (no formatting logic in `View` bodies).
- **Fields**:
  - `stepTitle: String` (e.g., “Step 2 of 6”)
  - `instructionText: String`
  - `waterLine: String?` (e.g., “150 g total” or “45 g pour”)
  - `countdownText: String?` (formatted mm:ss)
  - `isTimerVisible: Bool`
  - `isReadyToAdvance: Bool`
  - `primaryNextLabel: String` (“Next step” / “Finish”)
  - `primaryPauseResumeLabel: String` (“Pause” / “Resume”)

#### BrewSessionFlowErrorBanner (new, optional)
- **Kind**: `enum`
- **Purpose**: Non-modal surfacing for unexpected failures without derailing the brew (e.g., save failure can be shown in post-brew).
- **Cases**:
  - `.cannotStartTimer`
  - `.saveFailed(message: String)`

## 6. State Management
- **State ownership**:
  - `BrewSessionFlowView` owns `@State private var viewModel: BrewSessionFlowViewModel` initialized from `presentation.plan`.
  - The session state machine lives in `viewModel.state` (`BrewSessionState`) and drives all rendering.
- **Timer management (no GCD/Timer APIs)**:
  - Use a `Task` loop driven by a `Clock` (default `ContinuousClock`) to update `remainingTime` periodically while in `.active`.
  - Store a deadline/remaining reference in the view model (not the view) and recompute remaining on each tick.
  - When remaining reaches 0:
    - set `state.phase = .stepReadyToAdvance`
    - set `state.remainingTime = 0`
    - stop/cancel the ticking task
- **Scene phase behavior (recommended)**:
  - On background/inactive, automatically pause a running timer (set `.paused`) and stop ticking.
  - On returning active, do not auto-resume (require user to tap Resume), consistent with “no lock-screen/background guarantees.”

## 7. API Integration
This view is **offline-first** and does not call a network endpoint. Integration points are local domain/persistence operations:

- **Inputs**: `BrewPlan` provided via `BrewSessionPresentation` (created upstream by `BrewSessionUseCase.createPlan(from:)`).
  - Request type: `BrewInputs`
  - Response type: `BrewPlan`
- **Brew execution**: purely local state transitions (no repository calls).
  - Primary operations required by UI plan/PRD:
    - `start` (auto-start step timer when step has duration)
    - `pause`
    - `resume`
    - `nextStep`
    - `restart`
  - Implementation note: current codebase does not yet expose these operations from `BrewSessionUseCase`; implement them in `BrewSessionFlowViewModel` (UI layer) or extract to a small domain helper (preferred) that mutates/returns `BrewSessionState`.
- **Save brew log (after completion)**:
  - Persistence API: `BrewLogRepository(context: ModelContext)` → `insert(log)` → `save()`
  - Request type (recommended): `CreateBrewLogRequest` (Domain DTO) validated before creating a `BrewLog`
  - Stored entity type: `BrewLog` (SwiftData model)
  - Response type: `Void` (with error handling surfaced to the user)

## 8. User Interactions
- **View current step**:
  - Shows instruction text and optional water target.
  - For timed steps, shows countdown and pause/resume controls.
- **Next step (large)**:
  - Untimed step: advances immediately.
  - Timed step:
    - Disabled until countdown reaches 0 (then enabled and clearly marked “Ready”).
    - On final step: “Finish” completes the session and transitions to `PostBrewView`.
- **Pause / Resume (large)**:
  - Pause stops the countdown and switches button label to Resume.
  - Resume continues from remaining time; does not unlock any inputs.
- **Restart (guarded)**:
  - User must press-and-hold “Hold to Restart”.
  - After hold, optionally show a confirmation dialog “Restart brew?” with destructive action.
  - Restart resets:
    - `currentStepIndex = 0`
    - `phase = .notStarted`
    - `remainingTime = nil`
    - cancels any running timer task
- **Exit attempt (guarded)**:
  - “Exit” in toolbar triggers confirmation prompt.
  - “Exit” dismisses modal and loses progress (explicitly stated).
  - “Cancel/Stay” returns to brewing.

## 9. Conditions and Validation
Conditions validated at the UI/component level (with expected UI effects):

- **Plan validity**:
  - Condition: `presentation.plan.scaledSteps` is non-empty.
  - Enforcement:
    - Coordinator already guards this; view should still handle defensively by showing a blocking error state and a single “Close” action.
- **Timer duration**:
  - Condition: `currentStep.timerDurationSeconds == nil` → no timer UI, Next enabled.
  - Condition: `currentStep.timerDurationSeconds != nil && duration > 0` → timer visible, auto-start when entering step.
  - Condition: `duration <= 0` → treat as untimed step (ready immediately), log warning via `OSLog`.
- **Next button enablement**:
  - Untimed: enabled.
  - Timed + active/paused: disabled (until `remainingTime == 0` / `.stepReadyToAdvance`).
- **Inputs locked**:
  - Confirmed by design: this view never renders editable inputs; state should keep `isInputsLocked = true`.
- **Accessibility**:
  - Touch targets meet 44×44 minimum; control size `.large` for primary buttons.
  - Dynamic Type supported: avoid fixed font sizes; use semantic fonts (`.title`, `.largeTitle`, `.headline`) and `monospacedDigit()` for time.

## 10. Error Handling
- **Unexpected empty plan / missing current step**:
  - Show a `ContentUnavailableView` with “Close” button to dismiss.
  - Log via `OSLog` for diagnosis.
- **Timer task issues** (should be rare):
  - If the timer cannot start, mark step as ready-to-advance (fail-safe) and show a subtle banner.
- **Saving brew log fails** (post-brew):
  - Keep the user on `PostBrewView`, show an error message with “Try Again” and “Discard”.
  - Do not dismiss automatically on failure.
- **App goes to background**:
  - Pause timers automatically; show clear paused state on return; do not promise background accuracy.

## 11. Implementation Steps
1. **Create `.ai/BrewSessionFlowView-view-implementation-plan.md`** (this document) as the single reference for the brew flow screen behavior and component structure.
2. **Refactor the existing `BrewSessionFlowView` implementation** to match PRD/UI-plan:
   - Ensure Next + Pause/Resume are the primary controls (large, always present as appropriate).
   - Add Restart with confirmation + press-and-hold safeguard.
   - Keep exit confirmation and `.interactiveDismissDisabled(true)`.
3. **Extract the view model**:
   - Move `BrewSessionViewModel` out of `BrewSessionFlowView.swift` into `UI/Screens/BrewSessionFlowViewModel.swift` (or `UI/Screens/BrewSession/` feature folder) to keep the view file focused.
   - Store `BrewSessionState` as the single session source of truth.
4. **Implement a concurrency-safe timer loop** in the view model:
   - Use a `Task` with `Task.sleep(for:)` and a `Clock` to update `remainingTime`.
   - Cancel the task on pause, next step, restart, exit, and completion.
5. **Implement state transitions** as explicit intent methods:
   - `startStepIfNeeded`, `togglePauseResume`, `nextStep`, `restart`.
   - Auto-start timer on timed steps; do not require a separate “Start timer” UI in MVP.
6. **Build reusable UI components**:
   - `BrewNowStepCard`, `BrewTimerPanel`, `BrewSessionPrimaryControls`, `BrewSessionSecondaryControls`, `HoldToConfirmButton`.
7. **Add scene phase handling** (optional but recommended):
   - Pause timers when app becomes inactive/background.
8. **Ensure accessibility + kitchen-proof layout**:
   - Use semantic fonts, large controls, clear spacing, and VoiceOver labels/hints (especially for hold-to-restart).
9. **Integrate post-brew handoff**:
   - On final step: set `.completed` and render `PostBrewView`.
   - Wire save/discard to coordinator dismissal, and surface save errors without auto-dismissing.
10. **Add unit tests (recommended)**:
   - Test `BrewSessionFlowViewModel` state transitions (timed/untimed steps, pause/resume, ready-to-advance gating, restart).
   - Use an injectable clock to make timer behavior deterministic.
