# Brew Timer System - Technical Reference

## Timer Architecture Overview

### Two-Timer System

The brew session now uses a coordinated two-timer approach:

1. **Brew Clock (Elapsed Time)** - Total time since first pour
2. **Step Countdown** - Per-step countdown for timed steps

---

## Timer Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                     Brew Session Start                       │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │  First Pour Step Begins  │
                    │  (bloom/pour/wait)       │
                    └──────────┬───────────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  Set startedAt = Date()  │
                    │  Start Timer Loop        │
                    └──────────┬───────────────┘
                               │
                               ▼
       ┌───────────────────────────────────────────────┐
       │         Timer Loop (100ms ticks)              │
       │                                                │
       │  ┌─────────────────────────────────────┐     │
       │  │  Update Step Countdown               │     │
       │  │  (if phase == .active && has timer)  │     │
       │  └─────────────────────────────────────┘     │
       │                    │                           │
       │                    ▼                           │
       │  ┌─────────────────────────────────────┐     │
       │  │  Step Timer Reaches 0?               │     │
       │  │  → Set phase = .stepReadyToAdvance   │     │
       │  │  → Keep loop running                 │     │
       │  └─────────────────────────────────────┘     │
       │                    │                           │
       │                    ▼                           │
       │  ┌─────────────────────────────────────┐     │
       │  │  Elapsed Time Updates Automatically  │     │
       │  │  (computed from Date.now - startedAt)│     │
       │  └─────────────────────────────────────┘     │
       └───────────────────┬───────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  User Taps Next Step   │
              └────────────┬───────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  Cancel Timer Task      │
              │  Move to Next Step      │
              │  Restart Timer Loop     │
              └────────────┬───────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  Continue Until Last   │
              │  Step Completes        │
              └────────────────────────┘
```

---

## Key Implementation Details

### Timer Loop

```swift
private func startTimerLoop() {
    timerTask = Task { @MainActor [weak self] in
        while !Task.isCancelled {
            try await clock.sleep(for: .milliseconds(100))
            
            // Update step countdown (if active and has timer)
            if self.state.phase == .active, self.state.remainingTime != nil {
                await self.tick()
                
                // Check if reached zero
                if let remaining = self.state.remainingTime, remaining <= 0 {
                    await self.timerReachedZero()
                    // Continue loop to update elapsed time
                }
            }
            
            // Elapsed time auto-updates via @Observable
            // UI reads computed property elapsedTime
        }
    }
}
```

### Elapsed Time (Brew Clock)

```swift
// In BrewSessionState (DTO)
var elapsedTime: TimeInterval? {
    guard let startedAt else { return nil }
    return Date.now.timeIntervalSince(startedAt)
}

// In BrewSessionFlowViewModel
var ui: BrewSessionFlowUIState {
    var elapsedText: String?
    if let elapsed = state.elapsedTime {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        elapsedText = String(format: "%d:%02d", minutes, seconds)
    }
    // ...
}
```

### When Timer Loop Starts

| Step Type | Timer Loop Behavior |
|-----------|---------------------|
| `preparation` | No timer loop (ready immediately) |
| `bloom` | Starts after user confirms pour complete |
| `pour` | Starts immediately (tracks elapsed time) |
| `wait` | Starts immediately (countdown timer) |
| `agitate` | No timer loop (ready immediately) |

---

## Background Behavior

### Before (with pause)
- App background → Auto-pause timer
- User returns → Must tap Resume

### After (no pause)
- App background → Timer continues
- User returns → Elapsed time is accurate (computed from `startedAt`)
- Step countdown continues accurately (not iOS-backgrounding dependent)

**Note**: iOS may suspend the timer task in background, but elapsed time remains accurate because it's computed from `Date.now - startedAt` on each UI update.

---

## State Machine

### Phases

```swift
enum Phase: String, Codable {
    case notStarted                 // Before step timer begins
    case awaitingPourConfirmation   // Bloom step: waiting for pour
    case active                     // Timer running
    case paused                     // DEPRECATED (kept for compatibility)
    case stepReadyToAdvance         // Countdown reached 0, ready for next
    case completed                  // Final step done
}
```

### Phase Transitions

```
notStarted → awaitingPourConfirmation (bloom steps)
            ↓
awaitingPourConfirmation → active (user confirms pour)

notStarted → active (timed steps: pour, wait)

notStarted → stepReadyToAdvance (untimed: preparation, agitate)

active → stepReadyToAdvance (countdown reaches 0)

stepReadyToAdvance → notStarted (user taps Next)

stepReadyToAdvance → completed (last step, user taps Finish)
```

---

## UI Update Mechanism

### Observable Pattern

```swift
@Observable @MainActor
final class BrewSessionFlowViewModel {
    private(set) var state: BrewSessionState
    
    var ui: BrewSessionFlowUIState {
        // Accesses state.elapsedTime
        // SwiftUI re-renders when state changes
    }
}
```

### Update Triggers

1. **Timer loop tick** (every 100ms)
   - Updates `state.remainingTime` (triggers @Observable)
   - UI automatically reads latest `state.elapsedTime`

2. **UI accesses `elapsedTime`**
   - Computed from `Date.now - startedAt`
   - Always current, no staleness possible

---

## Performance Considerations

### Timer Precision
- **Tick Rate**: 100ms (10 Hz)
- **Display Update**: MM:SS format (second precision)
- **Overhead**: Minimal - simple arithmetic per tick

### Memory
- Single `Task` per session
- No retention cycles (`[weak self]` in timer loop)
- Task cancelled on exit/completion

### Battery Impact
- Timer runs only during active brew session
- Cancelled immediately on exit
- No background timers when app terminated

---

## Testing Strategy

### Unit Tests (Recommended)

```swift
@Test("Elapsed time updates continuously")
func testElapsedTimeUpdates() async throws {
    let testClock = TestClock()
    let viewModel = BrewSessionFlowViewModel(
        plan: testPlan,
        clock: testClock
    )
    
    viewModel.onAppear()
    
    // Advance clock
    await testClock.advance(by: .seconds(30))
    
    // Assert elapsed time
    #expect(viewModel.state.elapsedTime ≈ 30.0)
}

@Test("Timer loop continues after step countdown reaches zero")
func testTimerContinuesAfterStepComplete() async throws {
    // Test that timerTask is not cancelled when step reaches 0
    // Elapsed time should keep updating
}
```

---

## Comparison: Before vs After

| Feature | Before | After |
|---------|--------|-------|
| **Brew Clock** | Not visible | ✅ Visible from first pour |
| **Pause Button** | ✅ Present | ❌ Removed |
| **Restart Button** | ✅ Present (hold-to-confirm) | ❌ Removed |
| **Timer Loop** | Stops at step countdown zero | ✅ Continues for elapsed time |
| **Background** | Auto-pauses | ✅ Continues (computed time) |
| **UI Complexity** | 3 buttons (Next, Pause, Restart) | ✅ 1 button (Next/Finish) |

---

## Known Limitations

1. **iOS Background Restrictions**
   - Timer task may suspend in deep background
   - Elapsed time remains accurate (computed from `startedAt`)
   - Step countdown may drift if suspended >1s (acceptable for barista use)

2. **No Pause Recovery**
   - Users cannot pause brew mid-process
   - Must exit and restart from recipe if interrupted

3. **Phase Enum Compatibility**
   - `.paused` case still exists but unused
   - Kept for potential stored session data compatibility

---

## Future Enhancements

### Potential Additions
- [ ] Haptic feedback at step transitions
- [ ] Audio alert when step countdown reaches 0
- [ ] Visual brew clock animation (pulsing/breathing)
- [ ] Step milestone markers on brew clock
- [ ] Export brew timeline for analysis

### Not Planned
- ❌ Re-adding pause functionality
- ❌ Timer adjustment during brew
- ❌ Background notifications (out of scope for MVP)
