# Brew Steps Domain Improvement - Implementation Plan

## Overview

This document provides a detailed implementation plan to update the existing BrewGuide codebase based on the domain analysis in `brew_improvement.md`. The plan addresses the semantic conflation of step types, timer semantics, and missing brew clock functionality.

---

## Current State Summary

### Persistence Layer (`RecipeStep.swift`)
```swift
@Model
final class RecipeStep {
    var stepId: UUID = UUID()
    var orderIndex: Int = 0
    var instructionText: String = ""
    var timerDurationSeconds: Double?       // Conflated: means both "wait duration" AND "milestone time"
    var waterAmountGrams: Double?
    var isCumulativeWaterTarget: Bool = true
    var recipe: Recipe?
}
```

### Domain Layer (`BrewSessionDTOs.swift`)
- `ScaledStep`: Mirrors `RecipeStep` structure with scaled water amounts
- `BrewSessionState`: Tracks `remainingTime` (per-step countdown) but never uses `startedAt` for elapsed time

### Scaling (`ScalingService.swift`)
- Hardcoded bloom ratio: `3.0 × dose`
- Water targets computed but timer durations not scaled
- Instruction text not regenerated after scaling

### ViewModel (`BrewSessionFlowViewModel.swift`)
- All steps treated identically: timer countdown → ready to advance
- No differentiation between preparation, bloom, pour, wait, or agitate steps
- `startedAt` is set but never used for UI display

---

## Implementation Phases

### Phase 1: Introduce Step Types (Foundation)

**Goal**: Make step semantics explicit and machine-readable.

#### 1.1 Create `StepKind` Enum

**File**: `BrewGuide/BrewGuide/Persistence/Models/StepKind.swift` (new)

```swift
import Foundation

/// Semantic type of a brew step, determining timer and UI behavior.
enum StepKind: String, Codable, CaseIterable {
    /// Manual setup step (rinse filter, add grounds). No timer, manual advance.
    case preparation
    
    /// Pre-infusion pour then wait. Timer = wait duration AFTER pour complete.
    case bloom
    
    /// Active water addition. User pours to target weight BY milestone time.
    case pour
    
    /// Passive wait (e.g., drawdown). Timer = countdown duration.
    case wait
    
    /// Brief action like swirl or stir. Optional short timer, manual advance.
    case agitate
}
```

#### 1.2 Add `stepKind` to `RecipeStep` Model

**File**: `BrewGuide/BrewGuide/Persistence/Models/RecipeStep.swift`

**Changes**:
```swift
@Model
final class RecipeStep {
    // ... existing properties ...
    
    /// Semantic type of this step (determines timer behavior)
    /// Default to `.pour` for backward compatibility with existing recipes
    var stepKind: StepKind = .pour
    
    // ... rest of class ...
}
```

**Migration Note**: CloudKit requires default values. Using `.pour` as default ensures existing custom recipes continue to work.

#### 1.3 Update `ScaledStep` DTO

**File**: `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift`

```swift
struct ScaledStep: Codable, Identifiable, Hashable {
    let stepId: UUID
    let orderIndex: Int
    let instructionText: String
    let stepKind: StepKind                    // NEW
    let timerDurationSeconds: Double?         // Will be renamed in Phase 2
    let waterAmountGrams: Double?
    let isCumulativeWaterTarget: Bool
    
    var id: UUID { stepId }
}
```

#### 1.4 Update `MappingExtensions.swift`

Add `stepKind` to the `RecipeStep` → `ScaledStep` mapping.

#### 1.5 Migrate Starter Recipes

**File**: `BrewGuide/BrewGuide/Persistence/DatabaseSeeder.swift`

Update all starter recipe steps with appropriate `stepKind`:

| Current Instruction Pattern | Step Kind |
|-----------------------------|-----------|
| "Rinse filter…" | `.preparation` |
| "Add coffee…" | `.preparation` |
| "Bloom: pour…" | `.bloom` |
| "Pour to Xg…" | `.pour` |
| "Wait for drawdown…" | `.wait` |

**Example**:
```swift
RecipeStep(
    orderIndex: 0,
    instructionText: "Rinse filter and preheat",
    stepKind: .preparation,           // NEW
    timerDurationSeconds: nil,
    waterAmountGrams: nil,
    isCumulativeWaterTarget: true,
    recipe: recipe
)
```

---

### Phase 2: Separate Duration from Milestone Time

**Goal**: Distinguish "wait X seconds" from "complete BY X elapsed time".

#### 2.1 Add New Properties to `RecipeStep`

**File**: `BrewGuide/BrewGuide/Persistence/Models/RecipeStep.swift`

```swift
@Model
final class RecipeStep {
    // ... existing properties ...
    
    /// Duration to wait (for bloom/wait steps). Renamed from timerDurationSeconds.
    var durationSeconds: Double?
    
    /// Target milestone in total brew elapsed time (for pour steps).
    /// E.g., 90 means "complete this pour by 1:30 from brew start"
    var targetElapsedSeconds: Double?
    
    // DEPRECATED but kept for backward compatibility
    // Will be used if durationSeconds AND targetElapsedSeconds are both nil
    var timerDurationSeconds: Double?
    
    // ... rest of class ...
}
```

#### 2.2 Update `ScaledStep` DTO

**File**: `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift`

```swift
struct ScaledStep: Codable, Identifiable, Hashable {
    let stepId: UUID
    let orderIndex: Int
    let instructionText: String
    let stepKind: StepKind
    
    /// Wait duration for bloom/wait steps (seconds)
    let durationSeconds: Double?
    
    /// Target milestone time from brew start for pour steps (seconds)
    let targetElapsedSeconds: Double?
    
    let waterAmountGrams: Double?
    let isCumulativeWaterTarget: Bool
    
    var id: UUID { stepId }
    
    /// Computed: legacy compatibility
    var timerDurationSeconds: Double? {
        durationSeconds ?? targetElapsedSeconds
    }
}
```

#### 2.3 Migrate Starter Recipe Data

**File**: `BrewGuide/BrewGuide/Persistence/DatabaseSeeder.swift`

Update step definitions:

```swift
// Bloom step - uses durationSeconds (wait 45 seconds AFTER pouring)
RecipeStep(
    orderIndex: 2,
    instructionText: "Bloom: pour 45g, start timer",
    stepKind: .bloom,
    durationSeconds: 45,              // Wait duration after pour
    targetElapsedSeconds: nil,
    waterAmountGrams: 45,
    isCumulativeWaterTarget: true,
    recipe: recipe
)

// Pour step - uses targetElapsedSeconds (complete BY 1:30 from start)
RecipeStep(
    orderIndex: 3,
    instructionText: "Pour to 150g by 1:30",
    stepKind: .pour,
    durationSeconds: nil,
    targetElapsedSeconds: 90,         // Milestone: 1:30 from brew start
    waterAmountGrams: 150,
    isCumulativeWaterTarget: true,
    recipe: recipe
)

// Wait step - uses durationSeconds (countdown 180 seconds)
RecipeStep(
    orderIndex: 5,
    instructionText: "Wait for drawdown, target finish 3:00–3:30",
    stepKind: .wait,
    durationSeconds: 180,             // Countdown duration
    targetElapsedSeconds: nil,
    waterAmountGrams: nil,
    isCumulativeWaterTarget: true,
    recipe: recipe
)
```

---

### Phase 3: Add Total Elapsed Time to Session State

**Goal**: Track and display brew clock alongside step timers.

#### 3.1 Add Computed Property to `BrewSessionState`

**File**: `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift`

```swift
struct BrewSessionState: Codable, Hashable {
    let plan: BrewPlan
    var phase: Phase
    var currentStepIndex: Int
    var remainingTime: TimeInterval?
    var startedAt: Date?
    let isInputsLocked: Bool
    
    // ... existing properties ...
    
    /// Total elapsed time since brew started (first timed step began).
    /// Returns nil if brew hasn't started yet.
    var elapsedTime: TimeInterval? {
        guard let startedAt else { return nil }
        return Date.now.timeIntervalSince(startedAt)
    }
}
```

#### 3.2 Update `BrewSessionFlowUIState`

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`

```swift
struct BrewSessionFlowUIState {
    let stepTitle: String
    let instructionText: String
    let waterLine: String?
    
    // Timer display
    let countdownText: String?           // Per-step countdown (MM:SS)
    let elapsedText: String?             // Total brew time (MM:SS) - NEW
    
    let isTimerVisible: Bool
    let isReadyToAdvance: Bool
    let primaryNextLabel: String
    let primaryPauseResumeLabel: String
    
    // Pacing indicator for pour steps - NEW
    let pacingIndicator: PacingIndicator?
}

enum PacingIndicator {
    case onPace
    case ahead
    case behind
}
```

#### 3.3 Update ViewModel to Track Elapsed Time

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`

Add to `ui` computed property:

```swift
var ui: BrewSessionFlowUIState {
    // ... existing code ...
    
    // Format elapsed time
    var elapsedText: String?
    if let elapsed = state.elapsedTime {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        elapsedText = String(format: "%d:%02d", minutes, seconds)
    }
    
    // Compute pacing indicator for pour steps
    var pacingIndicator: PacingIndicator?
    if let step = currentStep,
       step.stepKind == .pour,
       let targetElapsed = step.targetElapsedSeconds,
       let elapsed = state.elapsedTime {
        let timeRemaining = targetElapsed - elapsed
        if timeRemaining < -10 {
            pacingIndicator = .behind
        } else if timeRemaining > 30 {
            pacingIndicator = .ahead
        } else {
            pacingIndicator = .onPace
        }
    }
    
    return BrewSessionFlowUIState(
        // ... existing properties ...
        elapsedText: elapsedText,
        pacingIndicator: pacingIndicator
    )
}
```

#### 3.4 Persist `startedAt` Across Steps

Currently `startedAt` is reset per step. Change to persist from first timed step:

```swift
func startStepIfNeeded() {
    guard state.phase == .notStarted else { return }
    guard let step = currentStep else { return }
    
    // ... existing timer check ...
    
    // Only set startedAt on FIRST timed step (brew clock start)
    if state.startedAt == nil {
        state.startedAt = Date()
    }
    
    // ... rest of method ...
}
```

#### 3.5 Update UI Components

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionComponents.swift`

Add dual timer display:
- **Primary**: Brew clock (elapsed since start)
- **Secondary**: Step timer (countdown or milestone)

```swift
struct BrewTimerPanel: View {
    let elapsedText: String?
    let countdownText: String?
    let pacingIndicator: PacingIndicator?
    
    var body: some View {
        VStack(spacing: 8) {
            // Brew clock (always visible after first timed step)
            if let elapsed = elapsedText {
                Text(elapsed)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                Text("Elapsed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Step countdown (visible for timed steps)
            if let countdown = countdownText {
                Text(countdown)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            // Pacing indicator
            if let pacing = pacingIndicator {
                PacingIndicatorView(indicator: pacing)
            }
        }
    }
}
```

---

### Phase 4: Make Bloom Ratio Configurable

**Goal**: Allow recipes to specify their bloom ratio instead of hardcoding 3×.

#### 4.1 Add `bloomRatio` to `Recipe`

**File**: `BrewGuide/BrewGuide/Persistence/Models/Recipe.swift`

```swift
@Model
final class Recipe {
    // ... existing properties ...
    
    /// Bloom water ratio as multiplier of dose (e.g., 3.0 = 3× dose)
    /// Default 3.0 for V60 standard bloom
    var bloomRatio: Double = 3.0
    
    // ... rest of class ...
}
```

#### 4.2 Update `ScalingService`

**File**: `BrewGuide/BrewGuide/Domain/Scaling/ScalingService.swift`

```swift
/// Computes V60-specific cumulative water targets.
/// - Bloom = bloomRatio × dose (configurable, default 3×)
/// - Remaining split 50/50 into two pours
private func computeV60WaterTargets(
    dose: Double,
    targetYield: Double,
    bloomRatio: Double = 3.0    // NEW parameter
) -> [Double] {
    let bloom = roundWater(bloomRatio * dose)
    // ... rest unchanged ...
}
```

#### 4.3 Update `ScaleInputsRequest`

**File**: `BrewGuide/BrewGuide/Domain/DTOs/ScalingDTOs.swift`

```swift
struct ScaleInputsRequest {
    let recipeDose: Double
    let recipeTargetYield: Double
    let recipeRatio: Double
    let recipeBloomRatio: Double        // NEW
    
    let userDose: Double
    let userTargetYield: Double
    let lastEdited: BrewInputs.LastEditedField
}
```

#### 4.4 Update Starter Recipes

**File**: `BrewGuide/BrewGuide/Persistence/DatabaseSeeder.swift`

```swift
// V60 Balanced - standard bloom
Recipe(
    // ... existing properties ...
    bloomRatio: 3.0
)

// V60 Bright & Light - slightly higher bloom for light roasts
Recipe(
    // ... existing properties ...
    bloomRatio: 3.3
)

// V60 Bold & Strong - standard bloom
Recipe(
    // ... existing properties ...
    bloomRatio: 3.0
)
```

---

### Phase 5: Generate Instructions from Structured Data (Template System)

**Goal**: Eliminate instruction text drift during scaling.

#### 5.1 Create `InstructionTemplate` Enum

**File**: `BrewGuide/BrewGuide/Domain/InstructionTemplate.swift` (new)

```swift
import Foundation

/// Template for generating step instructions with dynamic values.
enum InstructionTemplate: Codable, Hashable {
    case preparation(action: String)
    case bloom(waterGrams: Double)
    case pourTo(targetGrams: Double, byTimeSeconds: Double)
    case waitForDrawdown(estimatedMinSeconds: Double, estimatedMaxSeconds: Double)
    case agitate(action: String)
    case custom(text: String)
    
    /// Generates display text from template with current values.
    func generateText(scaledWaterGrams: Double? = nil) -> String {
        switch self {
        case .preparation(let action):
            return action
            
        case .bloom(let waterGrams):
            let water = scaledWaterGrams ?? waterGrams
            return "Bloom: pour \(Int(water))g, start timer"
            
        case .pourTo(let targetGrams, let byTimeSeconds):
            let water = scaledWaterGrams ?? targetGrams
            let minutes = Int(byTimeSeconds) / 60
            let seconds = Int(byTimeSeconds) % 60
            let timeString = seconds > 0 
                ? "\(minutes):\(String(format: "%02d", seconds))"
                : "\(minutes):00"
            return "Pour to \(Int(water))g by \(timeString)"
            
        case .waitForDrawdown(let minSeconds, let maxSeconds):
            let minTime = formatTime(minSeconds)
            let maxTime = formatTime(maxSeconds)
            return "Wait for drawdown, target finish \(minTime)–\(maxTime)"
            
        case .agitate(let action):
            return action
            
        case .custom(let text):
            return text
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return secs > 0 
            ? "\(minutes):\(String(format: "%02d", secs))"
            : "\(minutes):00"
    }
}
```

#### 5.2 Add Template to `RecipeStep`

**File**: `BrewGuide/BrewGuide/Persistence/Models/RecipeStep.swift`

```swift
@Model
final class RecipeStep {
    // ... existing properties ...
    
    /// Instruction template for dynamic text generation.
    /// If nil, uses instructionText directly.
    var instructionTemplateData: Data?
    
    /// Computed property to encode/decode template
    var instructionTemplate: InstructionTemplate? {
        get {
            guard let data = instructionTemplateData else { return nil }
            return try? JSONDecoder().decode(InstructionTemplate.self, from: data)
        }
        set {
            instructionTemplateData = try? JSONEncoder().encode(newValue)
        }
    }
}
```

#### 5.3 Update Instruction Generation in Scaling

When creating `ScaledStep`, regenerate instruction text from template:

```swift
// In BrewSessionUseCase or mapping extension
func createScaledStep(from step: RecipeStep, scaledWater: Double?) -> ScaledStep {
    let displayText: String
    if let template = step.instructionTemplate {
        displayText = template.generateText(scaledWaterGrams: scaledWater)
    } else {
        displayText = step.instructionText
    }
    
    return ScaledStep(
        stepId: step.stepId,
        orderIndex: step.orderIndex,
        instructionText: displayText,
        // ... rest of properties ...
    )
}
```

---

### Phase 6: Differentiate Step Behaviors in ViewModel

**Goal**: Each step type has appropriate timer/advance behavior.

#### 6.1 Refactor `startStepIfNeeded()`

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`

```swift
func startStepIfNeeded() {
    guard state.phase == .notStarted else { return }
    guard let step = currentStep else { return }
    
    switch step.stepKind {
    case .preparation:
        // No timer - ready to advance immediately
        state.phase = .stepReadyToAdvance
        logger.debug("Preparation step - ready immediately")
        
    case .bloom:
        // Show "Pour now" prompt, timer starts after user confirms pour
        state.phase = .awaitingPourConfirmation
        logger.debug("Bloom step - awaiting pour confirmation")
        
    case .pour:
        // Show elapsed time vs milestone, user confirms when target reached
        if state.startedAt == nil {
            state.startedAt = Date()
        }
        state.phase = .active
        startElapsedTimeTracking()
        logger.debug("Pour step - tracking elapsed time to milestone \(step.targetElapsedSeconds ?? 0)")
        
    case .wait:
        // Auto-start countdown
        if let duration = step.durationSeconds {
            state.remainingTime = duration
            if state.startedAt == nil {
                state.startedAt = Date()
            }
            state.phase = .active
            startTimerLoop()
            logger.debug("Wait step - starting countdown for \(duration)s")
        } else {
            state.phase = .stepReadyToAdvance
        }
        
    case .agitate:
        // Brief action - ready to advance immediately (optional haptic)
        state.phase = .stepReadyToAdvance
        // TODO: Add haptic feedback
        logger.debug("Agitate step - ready immediately")
    }
}
```

#### 6.2 Add New Phase for Bloom Pour Confirmation

**File**: `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift`

```swift
struct BrewSessionState: Codable, Hashable {
    // ... existing properties ...
    
    enum Phase: String, Codable {
        case notStarted
        case awaitingPourConfirmation   // NEW: Bloom step waiting for pour complete
        case active
        case paused
        case stepReadyToAdvance
        case completed
    }
}
```

#### 6.3 Add Bloom Pour Confirmation Handler

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`

```swift
/// Called when user confirms bloom pour is complete - starts bloom wait timer
func confirmBloomPourComplete() {
    guard state.phase == .awaitingPourConfirmation else { return }
    guard let step = currentStep, step.stepKind == .bloom else { return }
    
    // Start brew clock if not already started
    if state.startedAt == nil {
        state.startedAt = Date()
    }
    
    // Start bloom wait timer
    if let duration = step.durationSeconds {
        state.remainingTime = duration
        state.phase = .active
        startTimerLoop()
        logger.info("Bloom timer started: \(duration)s")
    } else {
        state.phase = .stepReadyToAdvance
    }
}
```

#### 6.4 Update UI for Phase-Specific Controls

Add conditional UI based on `stepKind` and `phase`:

```swift
// In BrewSessionFlowView or BrewSessionComponents
@ViewBuilder
var stepControls: some View {
    switch (currentStep?.stepKind, state.phase) {
    case (.bloom, .awaitingPourConfirmation):
        Button("Pour Complete") {
            viewModel.confirmBloomPourComplete()
        }
        .buttonStyle(.borderedProminent)
        
    case (.pour, .active):
        VStack {
            Text("Target: \(targetTimeText)")
            Text("Elapsed: \(elapsedText)")
            Button("Reached Target") {
                viewModel.nextStep()
            }
            .buttonStyle(.borderedProminent)
        }
        
    default:
        // Standard next/pause controls
        BrewSessionPrimaryControls(viewModel: viewModel)
    }
}
```

---

### Phase 7: Pour Pacing (Optional Enhancement)

**Goal**: Help users pour at the right rate.

#### 7.1 Compute Pour Pacing Data

**File**: `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift` (or new file)

```swift
struct PourPacingInfo {
    let waterToAdd: Double              // Grams to add in this pour
    let pourDurationSeconds: Double     // Available time for pour
    let suggestedRateGramsPerSecond: Double
    let remainingSeconds: Double        // Time left in pour window
    
    var formattedRate: String {
        String(format: "~%.1f g/sec", suggestedRateGramsPerSecond)
    }
    
    var formattedWaterToAdd: String {
        String(format: "Add %.0fg in %.0f seconds", waterToAdd, pourDurationSeconds)
    }
}
```

#### 7.2 Compute Pacing in ViewModel

```swift
/// Computes pour pacing info for current pour step
var pourPacingInfo: PourPacingInfo? {
    guard let step = currentStep,
          step.stepKind == .pour,
          let targetElapsed = step.targetElapsedSeconds,
          let targetWater = step.waterAmountGrams else {
        return nil
    }
    
    // Find previous step's water target
    let previousWater = previousWaterTarget ?? 0
    let waterToAdd = targetWater - previousWater
    
    // Find previous step's milestone time (pour start time)
    let previousMilestone = previousTargetElapsed ?? 0
    let pourDuration = targetElapsed - previousMilestone
    
    guard pourDuration > 0 else { return nil }
    
    let suggestedRate = waterToAdd / pourDuration
    
    let elapsed = state.elapsedTime ?? 0
    let remainingSeconds = max(0, targetElapsed - elapsed)
    
    return PourPacingInfo(
        waterToAdd: waterToAdd,
        pourDurationSeconds: pourDuration,
        suggestedRateGramsPerSecond: suggestedRate,
        remainingSeconds: remainingSeconds
    )
}
```

#### 7.3 Display Pacing UI

```swift
struct PourPacingView: View {
    let pacingInfo: PourPacingInfo
    
    var body: some View {
        VStack(spacing: 4) {
            Text(pacingInfo.formattedWaterToAdd)
                .font(.headline)
            
            Text(pacingInfo.formattedRate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(Int(pacingInfo.remainingSeconds))s remaining")
                .font(.caption)
                .foregroundStyle(pacingInfo.remainingSeconds < 10 ? .red : .secondary)
        }
    }
}
```

---

## Migration Strategy

### Database Migration Steps

1. **Add new properties with defaults** (CloudKit compatible)
   - `stepKind: StepKind = .pour`
   - `durationSeconds: Double? = nil`
   - `targetElapsedSeconds: Double? = nil`
   - `bloomRatio: Double = 3.0`

2. **Keep deprecated properties** for backward compatibility
   - `timerDurationSeconds` → computed from `durationSeconds ?? targetElapsedSeconds`

3. **Migrate starter recipes**
   - Delete and re-seed starter recipes with new properties
   - Use recipe `origin` to identify starter templates

4. **Handle custom recipes gracefully**
   - Default `stepKind: .pour` works for most steps
   - Consider prompting user to review/update custom recipes

### Recommended Migration Code

```swift
// In DatabaseSeeder or AppDelegate
static func migrateToEnhancedSteps(in context: ModelContext) {
    // 1. Delete existing starter recipes (identified by origin)
    let descriptor = FetchDescriptor<Recipe>(
        predicate: #Predicate<Recipe> { $0.isStarter == true }
    )
    
    if let starters = try? context.fetch(descriptor) {
        for recipe in starters {
            context.delete(recipe)
        }
    }
    
    // 2. Re-seed with enhanced step data
    seedStarterRecipesIfNeeded(in: context)
}
```

---

## Testing Strategy

### Unit Tests Required

| Test Area | Test Cases |
|-----------|------------|
| `StepKind` | Encoding/decoding, all cases covered |
| `ScalingService` | Bloom ratio parameterization, water target computation |
| `BrewSessionState` | `elapsedTime` computation, phase transitions |
| `BrewSessionFlowViewModel` | Step-specific behavior (preparation, bloom, pour, wait, agitate) |
| `InstructionTemplate` | Text generation with scaled values |
| `PourPacingInfo` | Rate computation, edge cases (zero duration) |

### Integration Tests

1. Complete brew flow with mixed step types
2. Scaling preserves step semantics
3. Timer behavior varies by step kind
4. Elapsed time persists across steps

---

## Implementation Order

| Phase | Effort | Priority | Dependencies |
|-------|--------|----------|--------------|
| Phase 1: Step Types | Medium | High | None |
| Phase 2: Timer Semantics | Medium | High | Phase 1 |
| Phase 3: Elapsed Time | Low | High | Phase 1 |
| Phase 5: Bloom Ratio | Low | Medium | None |
| Phase 4: Instruction Templates | Medium | Medium | Phase 1 |
| Phase 6: Step Behaviors | High | High | Phases 1-3 |
| Phase 7: Pour Pacing | Medium | Low | Phases 1-3 |

**Recommended sequence**: 1 → 2 → 3 → 5 → 6 → 4 → 7

---

## Files to Modify (Summary)

### New Files
- `BrewGuide/BrewGuide/Persistence/Models/StepKind.swift`
- `BrewGuide/BrewGuide/Domain/InstructionTemplate.swift`

### Modified Files (Persistence)
- `BrewGuide/BrewGuide/Persistence/Models/RecipeStep.swift`
- `BrewGuide/BrewGuide/Persistence/Models/Recipe.swift`
- `BrewGuide/BrewGuide/Persistence/DatabaseSeeder.swift`

### Modified Files (Domain)
- `BrewGuide/BrewGuide/Domain/DTOs/BrewSessionDTOs.swift`
- `BrewGuide/BrewGuide/Domain/DTOs/ScalingDTOs.swift`
- `BrewGuide/BrewGuide/Domain/DTOs/MappingExtensions.swift`
- `BrewGuide/BrewGuide/Domain/Scaling/ScalingService.swift`
- `BrewGuide/BrewGuide/Domain/BrewSessionUseCase.swift`

### Modified Files (UI)
- `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`
- `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowView.swift`
- `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionComponents.swift`

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| CloudKit sync conflicts | High | Use optional properties with defaults, lightweight migration |
| Existing custom recipes break | Medium | Default `stepKind: .pour`, keep legacy property |
| UI complexity increases | Medium | Incremental rollout, feature flags |
| Timer drift with elapsed tracking | Low | Use `Date.now.timeIntervalSince(startedAt)` (recalculated each render) |

---

## Success Criteria

1. ✅ Starter recipes display step-appropriate timers (countdown vs milestone)
2. ✅ Brew clock shows total elapsed time from first timed step
3. ✅ Bloom steps prompt for pour completion before timer starts
4. ✅ Pour steps show pacing indicator (on pace / behind / ahead)
5. ✅ Scaling updates instruction text automatically
6. ✅ Bloom ratio configurable per recipe
7. ✅ Existing custom recipes continue to work without modification
