# Brew Steps Domain Analysis & Improvement Plan

## Executive Summary

After reviewing the codebase as both a barista and iOS developer, I've identified several issues where the current implementation diverges from accurate pour-over brewing domain concepts. The core problem is that **the model conflates different types of brewing actions and timing semantics into a single generic step structure**.

---

## Part 1: Domain Analysis — What's Wrong from a Barista Perspective

### Issue 1: Generic Steps Lose Brewing Semantics

The current `RecipeStep` treats all brewing actions as equivalent text instructions with optional timers and water amounts. However, V60 brewing has fundamentally different step types that behave differently:

| Step Type | Action | Timer Behavior | Water Behavior |
|-----------|--------|----------------|----------------|
| **Preparation** | Setup (rinse filter, add grounds) | Manual advance | None |
| **Bloom** | Pre-infusion pour, then wait | Wait X seconds | Fixed ratio to dose |
| **Pour** | Active water addition | Complete BY target time | Target cumulative amount |
| **Wait/Drawdown** | Passive drainage | Duration estimate | None |
| **Agitation** | Swirl/stir | Brief | None |

The current model cannot distinguish between "wait for 45 seconds" (bloom) and "reach 150g by 1:30" (pour milestone).

### Issue 2: Timer Semantics Are Inconsistent

Looking at the starter recipes:

```swift
// Step 3: Bloom
instructionText: "Bloom: pour 45g, start timer"
timerDurationSeconds: 45  // ✓ This is a WAIT duration after pouring

// Step 4: Pour
instructionText: "Pour to 150g by 1:30"  
timerDurationSeconds: 90  // ✗ This is NOT a duration—it's a TARGET milestone time
```

The `timerDurationSeconds` field means two different things:
- **Bloom**: "After pouring, wait this many seconds" (duration)
- **Pour**: "Complete this pour before this elapsed time from brew start" (milestone)

This conflation makes the timer display misleading during pours.

### Issue 3: Missing Total Elapsed Time

V60 recipes are fundamentally milestone-based: "pour to 150g **by 1:30**" means 1 minute 30 seconds from brew start. The current implementation only shows step countdowns, not total elapsed time since brewing began.

A barista using this app cannot answer: "Am I on pace? Is my total brew time 2:15 or 3:45?"

### Issue 4: Instruction Text Duplicates Structured Data

The instruction `"Bloom: pour 45g, start timer"` encodes:
- Step type: bloom
- Water amount: 45g
- Action: pour + wait

This same information exists in `waterAmountGrams: 45`. When scaling changes water to 60g, the instruction text becomes stale—it still says "45g" unless manually regenerated.

### Issue 5: Scaling Logic Is Incomplete

Current scaling in `ScalingService`:
- Water amounts: Scaled ✓
- Timer durations: **Not scaled** ✗
- Instruction text: **Not scaled** ✗

For a 20g → 30g dose increase (1.5× scale):
- Water targets scale correctly (250g → 375g)
- But pour windows don't scale—larger volumes need more time
- Instruction text still references original values

### Issue 6: Bloom Ratio Is Hardcoded

The `ScalingService` hardcodes bloom = 3× dose. But:
- Light roasts often use 2–2.5× (faster extraction)
- Dark roasts may use 3–4× (longer pre-infusion)
- Some techniques (e.g., Hoffmann) use different ratios

The bloom ratio should be a recipe-level parameter, not a service constant.

### Issue 7: No Pour Pacing Guidance

During an active pour, a barista needs to know:
- Current target: "Pour to 150g"
- Current scale reading: (from user's observation)
- Suggested pour rate: "~2.5g/sec"
- Time remaining: "15 seconds left in pour window"

The current model cannot compute pour rate because it doesn't know when the pour *started*—only when the step's timer ends.

---

## Part 2: Architectural Issues

### Issue 8: Steps Are Not Strongly Typed

The `RecipeStep` is essentially a bag of optional properties:

```swift
@Model
final class RecipeStep {
    var instructionText: String = ""
    var timerDurationSeconds: Double?
    var waterAmountGrams: Double?
    var isCumulativeWaterTarget: Bool = true
}
```

There's no indication whether this step is a bloom, pour, or wait. The domain knowledge exists only in freeform `instructionText`, which is not machine-readable.

### Issue 9: State Machine Lacks Brew Clock

`BrewSessionState` tracks:
- `currentStepIndex`
- `remainingTime` (per-step countdown)
- `startedAt` (when brew started)

But `startedAt` is never used to display total elapsed time. The UI only shows step countdown, not `Date.now - startedAt`.

### Issue 10: No Step Behavior Differentiation

All steps behave identically in `BrewSessionFlowViewModel`:
1. If step has timer → start countdown
2. When timer reaches 0 → show "ready to advance"
3. User taps next → advance

But brewing steps should behave differently:
- **Preparation**: Manual advance only (no timer)
- **Bloom**: Auto-start timer after pour, wait for countdown
- **Pour**: Show elapsed time and target, user confirms when reached
- **Drawdown**: Show estimated time, user advances when drained

---

## Part 3: Improvement Plan

### Phase 1: Introduce Step Types (Domain Model Enhancement)

**Goal**: Make step semantics explicit and machine-readable.

**Changes**:

1. Add `StepKind` enum to domain:

```swift
enum StepKind: String, Codable {
    case preparation  // Manual advance, no timer/water
    case bloom        // Pour + wait duration
    case pour         // Active pour to target by milestone time
    case wait         // Passive countdown
    case agitate      // Brief action (swirl/stir)
}
```

2. Add `stepKind` property to `RecipeStep` model

3. Migrate existing steps:
   - "Rinse filter…" → `.preparation`
   - "Add coffee…" → `.preparation`
   - "Bloom: pour…" → `.bloom`
   - "Pour to Xg…" → `.pour`
   - "Wait for drawdown…" → `.wait`

### Phase 2: Separate Duration from Milestone Time

**Goal**: Distinguish "wait X seconds" from "complete by X elapsed time".

**Changes**:

1. Replace single `timerDurationSeconds` with:

```swift
// For bloom/wait steps: how long to wait
var durationSeconds: Double?

// For pour steps: target milestone in total brew elapsed time
var targetElapsedSeconds: Double?
```

2. Update step data:
   - Bloom: `durationSeconds: 45`, `targetElapsedSeconds: nil`
   - Pour: `durationSeconds: nil`, `targetElapsedSeconds: 90` (1:30 from start)

### Phase 3: Add Total Elapsed Time to Session State

**Goal**: Track and display brew clock alongside step timers.

**Changes**:

1. Add computed property to `BrewSessionState`:

```swift
var elapsedTime: TimeInterval? {
    guard let startedAt else { return nil }
    return Date.now.timeIntervalSince(startedAt)
}
```

2. Update UI to show dual timers:
   - **Brew clock**: Total time since first timed step began
   - **Step timer**: Countdown for current step (if applicable)

3. For pour steps, show:
   - "Target: by 1:30" (milestone)
   - "Elapsed: 1:15" (brew clock)
   - Visual indicator (on pace / behind / ahead)

### Phase 4: Generate Instructions from Structured Data

**Goal**: Eliminate instruction text drift during scaling.

**Changes**:

1. Add instruction template system:

```swift
enum InstructionTemplate {
    case preparation(action: String)
    case bloom(waterGrams: Double)
    case pourTo(targetGrams: Double, byTime: TimeInterval)
    case waitForDrawdown(estimatedMinutes: ClosedRange<Double>)
}
```

2. Generate `instructionText` from template + scaled values
3. Store template enum (or raw instruction) in `RecipeStep`
4. Regenerate display text during plan creation

### Phase 5: Make Bloom Ratio Configurable

**Goal**: Allow recipes to specify their bloom ratio.

**Changes**:

1. Add `bloomRatio` property to `Recipe`:

```swift
var bloomRatio: Double = 3.0  // Default 3× dose
```

2. Update `ScalingService` to use recipe's bloom ratio instead of hardcoded `3.0`

3. Update starter recipes with appropriate ratios:
   - Balanced: 3.0×
   - Bright & Light: 3.3× (more bloom water)
   - Bold & Strong: 3.0×

### Phase 6: Differentiate Step Behaviors in ViewModel

**Goal**: Each step type has appropriate timer/advance behavior.

**Changes**:

1. **Preparation steps**:
   - No timer
   - Manual "Next" only
   - Optional haptic on tap

2. **Bloom steps**:
   - "Pour now" prompt
   - Timer starts when user confirms pour complete
   - Countdown shows wait remaining

3. **Pour steps**:
   - Show brew elapsed time vs target milestone
   - Visual pacing indicator
   - Manual "Done" when user reaches target water
   - Optional: compute suggested pour rate

4. **Wait steps**:
   - Auto-start countdown
   - Show both elapsed and remaining
   - Auto-advance option (or manual)

### Phase 7: Add Pour Pacing (Optional Enhancement)

**Goal**: Help users pour at the right rate.

**Changes**:

1. Compute pour window:

```swift
let pourStartElapsed = previousStepTargetElapsed ?? 0
let pourEndElapsed = currentStep.targetElapsedSeconds
let pourDuration = pourEndElapsed - pourStartElapsed
let waterToAdd = currentTarget - previousTarget
let suggestedRate = waterToAdd / pourDuration  // g/sec
```

2. Display in UI:
   - "Add 105g in 45 seconds"
   - "Suggested rate: ~2.3 g/sec"

---

## Migration Strategy

### Database Migration Considerations

Since CloudKit sync may be active:

1. **New properties must be optional or have defaults** (CloudKit requirement)
2. Add `stepKind` with default `.pour` (most common)
3. Add `targetElapsedSeconds` as optional
4. Keep `timerDurationSeconds` for backward compatibility, rename to `durationSeconds`
5. Migrate starter recipes in `DatabaseSeeder`

### Backward Compatibility

1. Existing custom recipes continue to work (interpreted as `.pour` steps)
2. New recipes can use enhanced step types
3. Consider migration prompt for users with custom recipes

---

## Summary of Proposed Model Changes

| Current | Proposed | Purpose |
|---------|----------|---------|
| `instructionText: String` | Keep + add template system | Display text, generated from template |
| `timerDurationSeconds: Double?` | Rename to `durationSeconds: Double?` | Wait time for bloom/wait steps |
| — | `targetElapsedSeconds: Double?` | Milestone time for pour steps |
| — | `stepKind: StepKind` | Semantic step type |
| — | `Recipe.bloomRatio: Double` | Configurable bloom water ratio |
| `BrewSessionState.remainingTime` | Keep | Per-step countdown |
| — | `BrewSessionState.elapsedTime` (computed) | Total brew clock |

---

## Recommended Implementation Order

1. **Phase 1 & 2**: Step types + timing separation (foundational)
2. **Phase 3**: Total elapsed time (high UX value)
3. **Phase 5**: Bloom ratio configuration (recipe flexibility)
4. **Phase 4**: Instruction templates (maintenance improvement)
5. **Phase 6**: Step behavior differentiation (polish)
6. **Phase 7**: Pour pacing (optional enhancement)
