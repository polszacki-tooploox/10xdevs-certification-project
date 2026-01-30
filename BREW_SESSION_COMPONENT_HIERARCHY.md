# BrewSessionFlowView Component Hierarchy

## Visual Component Structure

```
AppRootView
│
└─── .fullScreenCover(item: $coordinator.activeBrewSession)
     │
     └─── BrewSessionFlowView (main view)
          │
          ├─── NavigationStack
          │    │
          │    ├─── Toolbar
          │    │    └─── Exit Button (with confirmation)
          │    │
          │    └─── Content (conditional)
          │         │
          │         ├─── When brewing (state.phase != .completed)
          │         │    └─── BrewSessionContent
          │         │         │
          │         │         ├─── BrewSessionProgressView
          │         │         │    ├─── Linear Progress Bar
          │         │         │    └─── "Step X of Y" Label
          │         │         │
          │         │         ├─── ScrollView
          │         │         │    └─── VStack
          │         │         │         │
          │         │         │         ├─── BrewNowStepCard
          │         │         │         │    ├─── Instruction Text (.title2)
          │         │         │         │    └─── Water Row (optional)
          │         │         │         │         ├─── Drop Icon
          │         │         │         │         ├─── Amount (e.g., "50 g")
          │         │         │         │         └─── Label ("pour" / "total")
          │         │         │         │
          │         │         │         ├─── BrewTimerPanel (if timed step)
          │         │         │         │    ├─── Countdown Display (72pt, monospaced)
          │         │         │         │    ├─── "Ready" Indicator (when time == 0)
          │         │         │         │    └─── Progress Bar
          │         │         │         │
          │         │         │         ├─── BrewSessionPrimaryControls
          │         │         │         │    ├─── Next Step Button
          │         │         │         │    │    ├─── Label: "Next Step" / "Finish"
          │         │         │         │    │    ├─── Size: .large
          │         │         │         │    │    └─── Style: .borderedProminent
          │         │         │         │    │
          │         │         │         │    └─── Pause/Resume Button
          │         │         │         │         ├─── Label: "Pause" / "Resume"
          │         │         │         │         ├─── Size: .large
          │         │         │         │         └─── Style: .bordered
          │         │         │         │
          │         │         │         └─── BrewSessionSecondaryControls
          │         │         │              ├─── HoldToConfirmButton
          │         │         │              │    ├─── Label: "Hold to Restart"
          │         │         │              │    ├─── Hold Duration: 1.5s
          │         │         │              │    ├─── Visual Progress Indicator
          │         │         │              │    └─── VoiceOver Alternative (confirmation dialog)
          │         │         │              │
          │         │         │              └─── Helper Text
          │         │         │
          │         │         └─── Scene Phase Monitor
          │         │              └─── Auto-pauses on background
          │         │
          │         └─── When completed (state.phase == .completed)
          │              └─── PostBrewView
          │                   ├─── Success Icon
          │                   ├─── Brew Summary
          │                   ├─── Rating (1-5 stars)
          │                   ├─── Taste Tags (optional)
          │                   ├─── Notes Field (optional)
          │                   └─── Actions
          │                        ├─── Save Button
          │                        └─── Discard Button
          │
          └─── Modifiers
               ├─── .interactiveDismissDisabled(true)
               ├─── .onAppear { viewModel.onAppear() }
               └─── .onChange(of: scenePhase) { ... }
```

## Component Responsibilities

### BrewSessionFlowView (Main Container)
**Responsibility**: Coordinate modal presentation, navigation, and lifecycle
- Present exit confirmation
- Monitor scene phase changes
- Route between brewing and post-brew views
- Manage view model lifecycle

### BrewSessionContent (Brewing Layout)
**Responsibility**: Compose all brewing UI components
- Progress indicator
- Current step display
- Timer panel (conditional)
- Control buttons
- Maintain scroll view for accessibility

### BrewSessionProgressView (Progress Indicator)
**Responsibility**: Show brew progress
- Linear progress bar (0.0 to 1.0)
- Step counter text
- Dynamic Type support

### BrewNowStepCard (Instruction Display)
**Responsibility**: Display current brew instruction
- Large, readable instruction text
- Optional water amount with icon
- Visual distinction (card with background)

### BrewTimerPanel (Countdown Timer)
**Responsibility**: Show timer state
- Large countdown display
- "Ready" indicator at 0
- Progress bar (elapsed time)
- Color coding (red at <5s, green when ready)

### BrewSessionPrimaryControls (Main Actions)
**Responsibility**: Primary user actions
- Next step button (always visible)
- Pause/Resume button (for timed steps)
- Large touch targets
- Enabled/disabled states

### BrewSessionSecondaryControls (Safeguarded Actions)
**Responsibility**: Destructive actions with safeguards
- Restart with hold-to-confirm
- Helper text explaining behavior

### HoldToConfirmButton (Reusable Safeguard)
**Responsibility**: Prevent accidental destructive actions
- Require 1.5s continuous press
- Visual progress feedback
- VoiceOver alternative
- Accessibility support

## Data Flow

```
User Action → BrewSessionFlowView → BrewSessionFlowViewModel → BrewSessionState
                                                                       ↓
                                                    BrewSessionFlowUIState (computed)
                                                                       ↓
                                        BrewSessionContent ← BrewSession[Component]
```

### State Updates

```swift
// User taps Next Step
BrewSessionPrimaryControls.onNextStep()
    ↓
BrewSessionFlowViewModel.nextStep()
    ↓
state.currentStepIndex += 1
state.phase = .notStarted
    ↓
startStepIfNeeded() // auto-start timer
    ↓
UI updates automatically (@Observable)
```

### Timer Flow

```swift
// Timer tick cycle
startTimerLoop()
    ↓
Task {
    while !cancelled {
        sleep(100ms)
        tick() // decrement remainingTime
        if remainingTime <= 0:
            timerReachedZero()
            break
    }
}
    ↓
state.phase = .stepReadyToAdvance
state.remainingTime = 0
    ↓
UI shows "Ready" + enables Next button
```

## View Model Architecture

```
BrewSessionFlowViewModel (@Observable @MainActor)
│
├─── State Management
│    ├─── state: BrewSessionState (source of truth)
│    ├─── showExitConfirmation: Bool
│    ├─── showRestartConfirmation: Bool
│    ├─── errorBanner: BrewSessionFlowErrorBanner?
│    └─── isSavingPostBrew: Bool
│
├─── Timer Management
│    ├─── timerTask: Task<Void, Never>?
│    └─── clock: any Clock<Duration> (injectable)
│
├─── Computed Properties
│    ├─── currentStep: ScaledStep?
│    ├─── stepCount: Int
│    ├─── isCompleted: Bool
│    ├─── isNextEnabled: Bool
│    ├─── isPauseResumeEnabled: Bool
│    └─── ui: BrewSessionFlowUIState (pre-formatted)
│
└─── Public Intent Methods
     ├─── onAppear()
     ├─── requestExit()
     ├─── confirmExit(dismiss:)
     ├─── startStepIfNeeded()
     ├─── togglePauseResume()
     ├─── nextStep()
     ├─── restart()
     ├─── handleScenePhaseChange(isActive:)
     └─── saveBrewOutcome(rating:tasteTag:note:context:)
```

## File Organization

```
BrewGuide/BrewGuide/
│
├─── UI/
│    │
│    ├─── Screens/
│    │    │
│    │    ├─── BrewSessionFlowView.swift (120 lines)
│    │    │    └─── Main view + coordinator integration
│    │    │
│    │    └─── BrewSession/
│    │         │
│    │         ├─── BrewSessionFlowViewModel.swift (350+ lines)
│    │         │    ├─── @Observable view model
│    │         │    ├─── Timer management (Task + Clock)
│    │         │    ├─── State transitions
│    │         │    └─── Error handling
│    │         │
│    │         └─── BrewSessionComponents.swift (280+ lines)
│    │              ├─── BrewSessionProgressView
│    │              ├─── BrewNowStepCard
│    │              ├─── BrewTimerPanel
│    │              ├─── BrewSessionPrimaryControls
│    │              ├─── BrewSessionSecondaryControls
│    │              └─── BrewSessionContent
│    │
│    └─── Components/
│         │
│         └─── HoldToConfirmButton.swift (150+ lines)
│              ├─── Press-and-hold interaction
│              ├─── Visual progress feedback
│              └─── VoiceOver alternative
│
├─── Domain/
│    └─── DTOs/
│         └─── BrewSessionDTOs.swift
│              ├─── BrewInputs
│              ├─── ScaledStep
│              ├─── BrewPlan
│              └─── BrewSessionState
│
└─── Persistence/
     └─── Repositories/
          └─── BrewLogRepository.swift
               └─── Save brew outcome
```

## Integration Points

### Entry Point
```swift
// ConfirmInputsViewModel
let plan = try await brewSessionUseCase.createPlan(from: inputs)
coordinator.presentBrewSession(plan: plan)
```

### Presentation
```swift
// AppRootView
.fullScreenCover(item: $coordinator.activeBrewSession) { presentation in
    BrewSessionFlowView(presentation: presentation)
}
```

### Dismissal
```swift
// After save or discard
coordinator.dismissBrewSession()
// Sets activeBrewSession = nil
```

---

This component hierarchy ensures:
- ✅ Clear separation of concerns
- ✅ Reusable components
- ✅ Testable architecture
- ✅ Maintainable code structure
- ✅ Declarative SwiftUI patterns
