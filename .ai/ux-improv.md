# Brew Session UX Improvements - Implementation Plan

## Executive Summary

Based on analysis of the current codebase and brewing domain expertise, this plan addresses two targeted improvements:

1. **Persistent Brew Clock**: Display total elapsed time throughout the session for better pacing
2. **Remove Reset Button**: Simplify the UI by removing the MVP-unnecessary restart functionality

---

## Current State Analysis

The existing implementation has:

| Component | Status |
|-----------|--------|
| `BrewSessionState.startedAt` | ✅ Exists - tracks when brew started |
| `BrewSessionState.elapsedTime` | ✅ Computed property exists |
| `BrewSessionFlowUIState.elapsedText` | ✅ Formatted string computed |
| **Elapsed time display in UI** | ❌ **Not rendered anywhere** |
| `BrewSessionSecondaryControls` | Has "Hold to Restart" button |
| `BrewSessionFlowViewModel.restart()` | Restart logic exists |

**Key Finding**: The elapsed time infrastructure already exists but is not displayed. The `elapsedText` is computed in the ViewModel but never rendered in the view.

---

## Improvement 1: Persistent Brew Clock

### Barista Perspective

A visible total brew time is essential because:
- V60 recipes use milestone targets ("pour to 150g **by 1:30**")
- Total brew time affects extraction (2:30-3:30 is typical for V60)
- Users need pacing feedback: "Am I on track or falling behind?"
- It answers the question: "How long has my coffee been brewing?"

### Implementation Steps

#### Step 1.1: Create `BrewClockDisplay` Component

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionComponents.swift`

Add a new component for the persistent brew clock using `TimelineView` for automatic updates:

```swift
/// Always-visible elapsed time display using TimelineView for auto-updates
struct BrewClockDisplay: View {
    let startedAt: Date?
    
    var body: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                let minutes = Int(elapsed) / 60
                let seconds = Int(elapsed) % 60
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(.capsule)
            }
        }
    }
}
```

This approach uses SwiftUI's `TimelineView` to handle updates automatically - no manual timer management needed.

#### Step 1.2: Update `BrewSessionContent` to Display Clock

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionComponents.swift`

Update `BrewSessionContent` to include the brew clock:

```swift
struct BrewSessionContent: View {
    let state: BrewSessionState
    let uiState: BrewSessionFlowUIState
    let onNextStep: () -> Void
    let onPauseResume: () -> Void
    // REMOVED: let onRestartHoldConfirmed: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            BrewSessionProgressView(
                currentStepIndex: state.currentStepIndex,
                stepCount: state.plan.scaledSteps.count,
                progress: state.progress
            )
            
            // NEW: Persistent brew clock (always visible after brew starts)
            BrewClockDisplay(startedAt: state.startedAt)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Current step card
                    if let step = state.currentStep {
                        BrewNowStepCard(
                            step: step,
                            formattedWater: uiState.waterLine
                        )
                    }
                    
                    // Timer panel (if timed step)
                    if uiState.isTimerVisible, let remaining = state.remainingTime {
                        BrewTimerPanel(
                            remaining: remaining,
                            duration: state.currentStep?.timerDurationSeconds ?? 0,
                            phase: state.phase
                        )
                    }
                    
                    // Primary controls
                    BrewSessionPrimaryControls(
                        phase: state.phase,
                        isLastStep: state.isLastStep,
                        isNextEnabled: state.phase == .stepReadyToAdvance || 
                                      state.currentStep?.timerDurationSeconds == nil,
                        isPauseResumeEnabled: state.phase == .active || state.phase == .paused,
                        onNextStep: onNextStep,
                        onPauseResume: onPauseResume
                    )
                    
                    // REMOVED: BrewSessionSecondaryControls
                }
                .padding()
            }
        }
    }
}
```

#### Step 1.3: Brew Clock Start Behavior

The current `startedAt` logic is already appropriate:
- Bloom: `startedAt` set on `confirmBloomPourComplete()`
- Pour: `startedAt` set when pour step starts
- Wait: `startedAt` set when wait countdown begins

The clock starts when the first meaningful brewing action begins - no changes needed.

---

## Improvement 2: Remove Reset Button

### Rationale

For MVP, the reset button adds:
- UI complexity (hold-to-confirm pattern)
- Cognitive load ("What does restart do?")
- Rarely used functionality (users can exit and start fresh)

The "Exit" button in the toolbar already provides an escape path.

### Implementation Steps

#### Step 2.1: Remove `BrewSessionSecondaryControls`

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionComponents.swift`

Delete or comment out the entire `BrewSessionSecondaryControls` struct:

```swift
// MARK: - Brew Session Secondary Controls (REMOVED FOR MVP)
// This section intentionally removed - users can exit and restart if needed
```

#### Step 2.2: Update `BrewSessionContent` Signature

Remove the `onRestartHoldConfirmed` parameter (shown in Step 1.2 above).

#### Step 2.3: Update `BrewSessionFlowView`

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSessionFlowView.swift`

Remove the restart callback from `BrewSessionContent` instantiation:

```swift
private var brewingView: some View {
    BrewSessionContent(
        state: viewModel.state,
        uiState: viewModel.ui,
        onNextStep: {
            viewModel.nextStep()
        },
        onPauseResume: {
            viewModel.togglePauseResume()
        }
        // REMOVED: onRestartHoldConfirmed
    )
}
```

#### Step 2.4: Clean Up ViewModel (Optional)

**File**: `BrewGuide/BrewGuide/UI/Screens/BrewSession/BrewSessionFlowViewModel.swift`

The `restart()` method and `showRestartConfirmation` property can be kept for potential future use or removed:

```swift
// MARK: - Restart (Disabled for MVP)
// Keeping implementation for potential future use

// Remove showRestartConfirmation property
// var showRestartConfirmation = false  // REMOVED
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `BrewSessionComponents.swift` | Add `BrewClockDisplay`, remove `BrewSessionSecondaryControls`, update `BrewSessionContent` |
| `BrewSessionFlowView.swift` | Remove `onRestartHoldConfirmed` callback |
| `BrewSessionFlowViewModel.swift` | (Optional) Remove `showRestartConfirmation`, keep `restart()` for future |

## New Components

| Component | Purpose |
|-----------|---------|
| `BrewClockDisplay` | TimelineView-based elapsed time display, always visible after brew starts |

---

## Testing Checklist

| Test Case | Expected Result |
|-----------|-----------------|
| Start brew session | Clock not visible until first timed step begins |
| Bloom step → pour complete | Clock starts, displays elapsed time |
| Navigate through steps | Clock remains visible and updating |
| Pause timer | Clock continues (total elapsed time, not step time) |
| Complete brew | Clock shows final brew time |
| No reset button visible | Simplified UI without secondary controls |
| Exit button still works | Users can exit and dismiss session |

---

## Visual Design Notes

**Brew Clock Placement**: Above the step card, below the progress indicator
- Pill/capsule shape with semi-transparent background
- Clock icon + MM:SS format
- Subtle but always visible

**Removed Elements**:
- "Hold to Restart" button
- "Restart resets to step 1 and clears timers" helper text

---

## Implementation Order

1. **Step 1**: Add `BrewClockDisplay` component with `TimelineView`
2. **Step 2**: Update `BrewSessionContent` to show clock and remove secondary controls
3. **Step 3**: Update `BrewSessionFlowView` to remove restart callback
4. **Step 4**: Test complete flow
5. **Step 5**: (Optional) Clean up unused ViewModel properties

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| TimelineView performance | Low | Updates only every 1 second, minimal overhead |
| Users miss restart | Low | Exit + restart is adequate for MVP |
| Clock not starting | Medium | Ensure `startedAt` is set on first action step |

---

## Summary

This plan provides a focused, minimal implementation that improves the brewing UX:

1. **Brew clock** leverages existing infrastructure (`startedAt`, `elapsedTime`) that was computed but never displayed
2. **Removing reset button** simplifies the interface for MVP users

Both changes are low-risk and can be implemented quickly with minimal code changes.
