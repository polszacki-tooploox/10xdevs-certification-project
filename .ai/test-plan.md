# Test Plan - BrewGuide iOS Application

## 1. Introduction and Testing Objectives

### 1.1 Document Purpose
This document defines the comprehensive testing strategy for the BrewGuide iOS application - a coffee brewing assistant that guides users through V60 pour-over recipes with timer-based workflows, recipe scaling, and brew logging capabilities.

### 1.2 Testing Objectives
- **Functional Correctness**: Verify that all features work according to PRD specifications
- **Reliability**: Ensure the app performs consistently across various usage scenarios
- **Data Integrity**: Validate that SwiftData persistence and CloudKit sync maintain data consistency
- **User Experience**: Confirm that the kitchen-proof UI meets accessibility and usability standards
- **Performance**: Ensure responsive timer execution and smooth UI transitions
- **Security**: Validate Sign in with Apple authentication flow and data privacy controls

### 1.3 Quality Goals
| Metric | Target |
|--------|--------|
| Unit Test Coverage (Domain Layer) | ≥ 80% |
| Unit Test Coverage (ViewModels) | ≥ 70% |
| Critical Path Test Coverage | 100% |
| UI Test Coverage (Core Flows) | ≥ 60% |
| Zero P0/P1 bugs in release candidates | Required |

---

## 2. Test Scope

### 2.1 In Scope

#### Core Features
- **Recipe Management**
  - Starter recipe display (read-only)
  - Recipe duplication
  - Custom recipe editing with validation
  - Recipe deletion (custom only)
  - Recipe list filtering and selection

- **Guided Brewing Flow**
  - Confirm inputs screen with parameter editing
  - Recipe scaling (dose/yield) with "last edited wins" logic
  - Timer execution (countdown, pause, resume)
  - Step-by-step navigation
  - Bloom pour confirmation workflow
  - Pacing indicator for pour steps
  - Restart with confirmation safeguard

- **Brew Logging**
  - Post-brew rating (1-5)
  - Quick taste tags
  - Optional notes
  - Log list display (chronological)
  - Log detail view
  - Log deletion with confirmation

- **Authentication & Sync**
  - Sign in with Apple integration
  - Sign out flow
  - CloudKit sync enable/disable
  - Manual sync retry
  - Data deletion request

- **Settings & Preferences**
  - Last selected recipe persistence
  - Sync status display
  - Account management

#### Technical Areas
- SwiftData model persistence
- DTO mapping layer
- Repository pattern implementation
- ViewModel state management
- Navigation coordination
- Background/foreground transitions

### 2.2 Out of Scope
- AeroPress and Espresso brew modes (future)
- Grinder-specific calibration
- AI/ML recommendations
- Analytics instrumentation
- Lock screen timer widgets
- Third-party integrations (smart scales, thermometers)
- Localization testing (single language MVP)

### 2.3 Testing Exclusions
- Visual design review (separate UX process)
- App Store submission compliance
- Marketing material accuracy

---

## 3. Test Types and Strategy

### 3.1 Unit Tests

#### 3.1.1 Domain Layer Tests
**Target**: All use cases, services, and business rules

| Component | Priority | Focus Areas |
|-----------|----------|-------------|
| `ScalingService` | Critical | Dose/yield scaling, rounding rules, V60 water targets, warning generation |
| `RecipeUseCase` | Critical | CRUD operations, validation rules, starter recipe protection |
| `BrewSessionUseCase` | Critical | Plan creation, step scaling, method validation |
| `BrewLogUseCase` | High | Log CRUD, summary ordering |
| `AuthUseCase` | High | Session management, error handling |
| `SyncUseCase` | Medium | Enable/disable logic, status tracking |

**Testing Pattern**:
```swift
@MainActor
struct ScalingServiceTests {
    @Test("Dose edit triggers yield recalculation with recipe ratio")
    func testDoseEditRecalculatesYield() { ... }
    
    @Test("Yield rounds to nearest 1g")
    func testYieldRounding() { ... }
    
    @Test("V60 bloom water equals 3x dose rounded")
    func testBloomWaterCalculation() { ... }
}
```

#### 3.1.2 ViewModel Tests
**Target**: All ViewModels with business logic

| ViewModel | Priority | Focus Areas |
|-----------|----------|-------------|
| `BrewSessionFlowViewModel` | Critical | State machine transitions, timer tick, pause/resume, step advancement |
| `ConfirmInputsViewModel` | Critical | Input updates, scaling integration, validation, start brew flow |
| `RecipeEditViewModel` | Critical | Draft management, validation, step reordering, save/cancel |
| `RecipeListViewModel` | High | Fetch, filtering, deletion |
| `LogsListViewModel` | High | Fetch, delete confirmation, reload |
| `SettingsViewModel` | High | Auth state, sync toggle, error handling |
| `RecipeDetailViewModel` | Medium | Recipe fetch, duplicate action |

**Testing Pattern**:
```swift
@MainActor
struct BrewSessionFlowViewModelTests {
    @Test("Phase transitions from notStarted to active on bloom confirmation")
    func testBloomConfirmationStartsTimer() async { ... }
    
    @Test("Pause cancels timer task and sets phase to paused")
    func testPauseStopsTimer() { ... }
    
    @Test("Timer reaching zero sets phase to stepReadyToAdvance")
    func testTimerCompletion() { ... }
}
```

#### 3.1.3 DTO and Mapping Tests
**Target**: Entity-to-DTO conversions

| Mapping | Priority | Focus Areas |
|---------|----------|-------------|
| `Recipe → RecipeSummaryDTO` | High | All fields mapped, computed ratio |
| `Recipe → RecipeDetailDTO` | High | Steps included and sorted |
| `BrewLog → BrewLogSummaryDTO` | High | All fields mapped |
| `UpdateRecipeRequest.validate()` | Critical | All validation rules |
| `CreateRecipeRequest.validate()` | Critical | All validation rules |

### 3.2 Integration Tests

#### 3.2.1 Repository + SwiftData Tests
**Target**: Persistence layer with in-memory ModelContext

| Test Area | Priority | Focus Areas |
|-----------|----------|-------------|
| `RecipeRepository` | Critical | CRUD operations, starter recipe fetch, validation query |
| `BrewLogRepository` | High | Insert, fetch sorted, delete |
| `DatabaseSeeder` | Medium | Starter recipe creation, idempotent seeding |

**Testing Pattern**:
```swift
@MainActor
struct RecipeRepositoryTests {
    private func makeTestContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Recipe.self, RecipeStep.self, BrewLog.self, configurations: config)
        return ModelContext(container)
    }
    
    @Test("Fetching starter recipe returns exactly one V60 recipe")
    func testFetchStarterRecipe() async throws { ... }
}
```

#### 3.2.2 UseCase + Repository Integration
**Target**: Domain layer integration points

| Test Area | Priority | Focus Areas |
|-----------|----------|-------------|
| `BrewSessionUseCase + RecipeRepository` | Critical | Plan creation from persisted recipe |
| `RecipeUseCase + RecipeRepository` | High | Update flow with validation |
| `BrewLogUseCase + BrewLogRepository` | High | Full log lifecycle |

### 3.3 UI Tests

#### 3.3.1 Critical Path Tests
**Target**: End-to-end user journeys

| Flow | Priority | Scenario |
|------|----------|----------|
| Complete Brew Flow | Critical | Launch → Confirm inputs → Start brew → Navigate all steps → Save log |
| Recipe Edit Flow | Critical | Select recipe → Duplicate → Edit → Validate → Save |
| Auth Flow | High | Sign in → Enable sync → Sign out |
| Log Management Flow | High | Complete brew → View log list → Open detail → Delete |

**UI Test Framework**: XCUITest

```swift
final class BrewFlowUITests: XCTestCase {
    func testCompleteBrewFlowSavesLog() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Confirm inputs and start
        app.buttons["Start Brew"].tap()
        
        // Navigate through steps
        while app.buttons["Next Step"].exists {
            app.buttons["Next Step"].tap()
        }
        
        // Finish and save
        app.buttons["Finish"].tap()
        app.buttons["Save"].tap()
        
        // Verify log created
        app.tabBars.buttons["Logs"].tap()
        XCTAssertTrue(app.cells.firstMatch.exists)
    }
}
```

#### 3.3.2 Accessibility Tests
**Target**: VoiceOver and Dynamic Type support

| Area | Priority | Criteria |
|------|----------|----------|
| Primary brew controls | Critical | 44x44pt minimum, VoiceOver labels |
| Timer display | Critical | VoiceOver announces time changes |
| Step navigation | High | Clear button labels |
| Form inputs | High | Accessible labels and hints |

### 3.4 Performance Tests

#### 3.4.1 Timer Accuracy Tests
**Target**: Brew timer precision

| Test | Criteria |
|------|----------|
| Timer tick accuracy | ≤ 50ms drift over 5 minutes |
| Pause/resume latency | < 100ms response |
| Background recovery | Timer pauses correctly on background |

**Testing with Injectable Clock**:
```swift
@MainActor
struct TimerAccuracyTests {
    @Test("Timer ticks are consistent over 60 seconds")
    func testTimerAccuracy() async throws {
        let clock = TestClock()
        let viewModel = BrewSessionFlowViewModel(plan: makeTestPlan(), clock: clock)
        
        // Simulate 60 seconds of ticks
        for _ in 0..<600 {
            await clock.advance(by: .milliseconds(100))
        }
        
        // Verify expected remaining time
        #expect(viewModel.state.remainingTime == expectedTime)
    }
}
```

#### 3.4.2 Data Load Performance
**Target**: SwiftData query performance

| Metric | Target |
|--------|--------|
| Recipe list load | < 100ms for 50 recipes |
| Log list load | < 200ms for 500 logs |
| Recipe detail load | < 50ms |

### 3.5 Security Tests

| Area | Test Focus |
|------|------------|
| Sign in with Apple | Credential handling, session persistence |
| Session token storage | Keychain usage verification |
| Data deletion | Cloud data removal confirmation |
| CloudKit permissions | Private database only |

---

## 4. Test Scenarios for Key Functionality

### 4.1 Recipe Scaling Scenarios

| ID | Scenario | Input | Expected Output |
|----|----------|-------|-----------------|
| SC-001 | Dose change triggers yield recalc | Dose: 15g → 20g (ratio 1:16.67) | Yield: 333g |
| SC-002 | Yield change triggers dose recalc | Yield: 250g → 300g | Dose: 18g |
| SC-003 | Dose rounds to 0.1g | Computed: 17.456g | Display: 17.5g |
| SC-004 | Yield rounds to 1g | Computed: 287.3g | Display: 287g |
| SC-005 | Bloom water = 3x dose | Dose: 15g | Bloom: 45g |
| SC-006 | Pour split 50/50 | Yield 250g, Bloom 45g | Pours: 103g, 102g (cumulative: 148g, 250g) |
| SC-007 | Warning on low ratio | Ratio < 1:14 | Display warning |
| SC-008 | Warning on high ratio | Ratio > 1:18 | Display warning |
| SC-009 | Warning on low temp | Temp < 90°C | Display warning |
| SC-010 | Warning on high temp | Temp > 96°C | Display warning |

### 4.2 Brew Session State Machine Scenarios

| ID | Phase | Event | Next Phase | Side Effects |
|----|-------|-------|------------|--------------|
| BS-001 | notStarted | onAppear (prep step) | stepReadyToAdvance | - |
| BS-002 | notStarted | onAppear (bloom step) | awaitingPourConfirmation | - |
| BS-003 | awaitingPourConfirmation | confirmBloomPour | active | Timer starts, startedAt set |
| BS-004 | active | togglePauseResume | paused | Timer cancelled |
| BS-005 | paused | togglePauseResume | active | Timer resumed |
| BS-006 | active | timer reaches 0 | stepReadyToAdvance | Timer cancelled |
| BS-007 | stepReadyToAdvance | nextStep (not last) | notStarted | currentStepIndex++ |
| BS-008 | stepReadyToAdvance | nextStep (last step) | completed | - |
| BS-009 | active | app backgrounds | paused | Timer cancelled |
| BS-010 | any (except completed) | requestExit | - | showExitConfirmation = true |

### 4.3 Recipe Validation Scenarios

| ID | Scenario | Input State | Expected Errors |
|----|----------|-------------|-----------------|
| RV-001 | Empty name | name = "" | .emptyName |
| RV-002 | Zero dose | defaultDose = 0 | .invalidDose |
| RV-003 | Negative timer | step.timerDuration = -5 | .negativeTimer(stepIndex: N) |
| RV-004 | Water mismatch | yield = 250, max water = 200 | .waterTotalMismatch(250, 200) |
| RV-005 | No steps | steps = [] | .noSteps |
| RV-006 | Edit starter | recipe.isStarter = true | .starterCannotBeModified |
| RV-007 | Valid recipe | All fields valid | [] (empty errors) |
| RV-008 | Water ±1g tolerance | yield = 250, max water = 251 | [] (within tolerance) |

### 4.4 Authentication Scenarios

| ID | Scenario | Trigger | Expected Result |
|----|----------|---------|-----------------|
| AU-001 | Successful sign-in | Apple ID auth success | Session stored, isSignedIn = true |
| AU-002 | Cancelled sign-in | User taps cancel | No error shown, remain signed out |
| AU-003 | Failed sign-in | Auth error | Error message displayed, retry option |
| AU-004 | Sign out | User taps sign out | Session cleared, sync disabled |
| AU-005 | Session check on launch | App launch | Restore isSignedIn from Keychain |

### 4.5 Sync Scenarios

| ID | Scenario | Preconditions | Expected Result |
|----|----------|---------------|-----------------|
| SY-001 | Enable sync | Signed in | CloudKit account check, sync enabled |
| SY-002 | Enable sync (no iCloud) | Signed in, no iCloud | Error: "iCloud account not found" |
| SY-003 | Manual sync | Signed in, sync enabled | syncNow() called, status updated |
| SY-004 | Sync while offline | No network | Error: "Network unavailable", retry later |
| SY-005 | Disable sync | Sync enabled | Sync flag cleared, local data preserved |
| SY-006 | Data deletion | Signed in | Cloud records marked for deletion |

### 4.6 Brew Log Scenarios

| ID | Scenario | Input | Expected Result |
|----|----------|-------|-----------------|
| BL-001 | Save log with rating only | rating = 4 | Log created with timestamp, method, recipe params |
| BL-002 | Save log with taste tag | rating = 3, tag = .tooSour | Log includes tag |
| BL-003 | Save log with note | rating = 5, note = "Great!" | Log includes note (≤280 chars) |
| BL-004 | Delete log | Tap delete, confirm | Log removed from list |
| BL-005 | Cancel delete | Tap delete, cancel | Log remains, pendingDelete = nil |
| BL-006 | Logs ordered by date | 3 logs, different dates | Most recent first |

---

## 5. Test Environment

### 5.1 Development Environment
| Component | Specification |
|-----------|---------------|
| IDE | Xcode 16.0+ (latest stable) |
| macOS | macOS Sequoia 15.0+ |
| Swift | 6.2 |
| iOS SDK | 26.0 |

### 5.2 Test Devices / Simulators
| Device | iOS Version | Purpose |
|--------|-------------|---------|
| iPhone 16 Pro Simulator | iOS 26.0 | Primary development |
| iPhone 15 Simulator | iOS 26.0 | Screen size variation |
| iPhone SE (3rd gen) Simulator | iOS 26.0 | Compact size testing |
| iPad Pro 11" Simulator | iOS 26.0 | iPad compatibility (if applicable) |
| Physical iPhone | iOS 26.0 | Performance and Sign in with Apple testing |

### 5.3 Test Data Requirements
| Data Set | Description | Usage |
|----------|-------------|-------|
| Starter Recipe | V60 recipe with 6 steps | Default state testing |
| Custom Recipes (5) | Various configurations | List and edit testing |
| Brew Logs (50) | Mixed ratings and dates | Log list performance |
| Invalid Recipe | Missing required fields | Validation testing |

### 5.4 External Dependencies
| Dependency | Test Strategy |
|------------|---------------|
| CloudKit | Mock for unit tests, real for integration |
| Sign in with Apple | Real flow on device, mock for unit tests |
| Keychain | In-memory stub for unit tests |

---

## 6. Testing Tools

### 6.1 Test Frameworks
| Tool | Purpose |
|------|---------|
| Swift Testing (`Testing`) | Unit and integration tests |
| XCTest / XCUITest | UI automation tests |
| SwiftData (in-memory) | Persistence layer mocking |

### 6.2 Test Utilities
| Utility | Purpose |
|---------|---------|
| `ModelConfiguration(isStoredInMemoryOnly: true)` | In-memory database for tests |
| `TestClock` (custom) | Injectable clock for timer tests |
| Fake/Stub protocols | Dependency injection for use cases |

### 6.3 CI/CD Integration
| Platform | Configuration |
|----------|---------------|
| Xcode Cloud / GitHub Actions | Automated test runs on PR |
| Test parallelization | Enabled for unit tests |
| Code coverage reporting | Xcode coverage or Codecov |

### 6.4 Recommended Test Double Structure
```
BrewGuideTests/
├── Fakes/
│   ├── FakeRecipeRepository.swift
│   ├── FakeBrewLogRepository.swift
│   ├── FakeAuthSessionStore.swift
│   ├── FakeSyncSettingsStore.swift
│   └── FakeClock.swift
├── Fixtures/
│   ├── RecipeFixtures.swift
│   ├── BrewLogFixtures.swift
│   └── DTOFixtures.swift
├── Domain/
│   ├── ScalingServiceTests.swift
│   ├── RecipeUseCaseTests.swift
│   ├── BrewSessionUseCaseTests.swift
│   └── BrewLogUseCaseTests.swift
├── ViewModels/
│   ├── BrewSessionFlowViewModelTests.swift
│   ├── ConfirmInputsViewModelTests.swift
│   ├── RecipeEditViewModelTests.swift
│   └── SettingsViewModelTests.swift
└── Integration/
    ├── RecipeRepositoryIntegrationTests.swift
    └── BrewLogRepositoryIntegrationTests.swift
```

---

## 7. Test Schedule

### 7.1 Continuous Testing
| Activity | Frequency | Owner |
|----------|-----------|-------|
| Unit test execution | Every commit / PR | CI/CD |
| Integration test execution | Every PR merge | CI/CD |
| Code coverage check | Every PR | CI/CD |

### 7.2 Milestone Testing
| Phase | Activities |
|-------|------------|
| Feature Complete | Full regression suite, performance baseline |
| Release Candidate | UI tests, manual exploratory testing, accessibility audit |
| Pre-Release | Device testing, Sign in with Apple flow, CloudKit sync |

### 7.3 Test Prioritization
| Priority | Criteria | Examples |
|----------|----------|----------|
| P0 - Critical | Core brewing flow, data loss prevention | Timer accuracy, log save, recipe validation |
| P1 - High | Key user journeys, auth/sync | Recipe edit, sign in, sync enable |
| P2 - Medium | Secondary features | Settings UI, log detail view |
| P3 - Low | Edge cases, cosmetic | Empty states, unusual inputs |

---

## 8. Test Acceptance Criteria

### 8.1 Unit Test Pass Criteria
- All tests pass (0 failures)
- Coverage targets met per component
- No flaky tests (100% deterministic)
- Execution time < 60 seconds total

### 8.2 Integration Test Pass Criteria
- All persistence operations verified
- Repository-UseCase integration working
- In-memory tests deterministic

### 8.3 UI Test Pass Criteria
- Critical paths execute without failures
- Navigation flows complete successfully
- Accessibility audit passes (VoiceOver, Dynamic Type)

### 8.4 Release Criteria
| Criteria | Requirement |
|----------|-------------|
| P0 bugs | 0 open |
| P1 bugs | 0 open |
| P2 bugs | ≤ 3 open (with workarounds) |
| Test coverage | Domain ≥ 80%, ViewModels ≥ 70% |
| Performance | Timer drift < 50ms/5min |

---

## 9. Roles and Responsibilities

### 9.1 Development Team
| Role | Responsibilities |
|------|------------------|
| iOS Developer | Write unit tests, fix test failures, maintain test infrastructure |
| QA Engineer | Design test scenarios, write UI tests, regression testing |
| Tech Lead | Review test coverage, approve test strategy changes |

### 9.2 Test Review Process
1. Developer writes unit tests alongside feature code
2. PR includes test additions/modifications
3. Code review includes test quality assessment
4. CI/CD validates all tests pass before merge

### 9.3 Test Maintenance
| Activity | Owner | Frequency |
|----------|-------|-----------|
| Flaky test investigation | Developer | As detected |
| Test refactoring | Developer | Sprint allocation |
| Coverage report review | Tech Lead | Weekly |
| Test documentation updates | QA Engineer | Per milestone |

---

## 10. Bug Reporting Procedures

### 10.1 Bug Report Template
```markdown
## Summary
[Brief description of the issue]

## Environment
- Device: [iPhone model or Simulator]
- iOS Version: [26.0]
- App Version: [Build number]
- Test Type: [Unit/Integration/UI/Manual]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Result
[What should happen]

## Actual Result
[What actually happened]

## Test Code (if applicable)
```swift
// Failing test code
```

## Screenshots/Logs
[Attach relevant screenshots or log output]

## Severity
- [ ] P0 - Critical (blocking, data loss)
- [ ] P1 - High (major feature broken)
- [ ] P2 - Medium (feature impaired)
- [ ] P3 - Low (minor issue)
```

### 10.2 Bug Triage Process
1. Bug reported in issue tracker (GitHub Issues)
2. Severity assigned by reporter
3. Tech Lead validates severity within 24 hours
4. P0/P1 bugs assigned immediately
5. P2/P3 bugs prioritized in next sprint planning

### 10.3 Bug Resolution Workflow
```
New → Triaged → In Progress → Code Review → Verified → Closed
                    ↓
                 Blocked → [Dependency resolution]
```

### 10.4 Regression Test Requirements
- Every bug fix must include a regression test
- Test must fail before fix, pass after fix
- Test added to automated suite

---

## 11. Appendix

### A. Test Data Fixtures

#### A.1 Valid V60 Recipe Fixture
```swift
static let validV60Recipe = Recipe(
    id: UUID(),
    isStarter: false,
    origin: .custom,
    method: .v60,
    name: "Test V60 Recipe",
    defaultDose: 15.0,
    defaultTargetYield: 250.0,
    defaultWaterTemperature: 94.0,
    defaultGrindLabel: .medium,
    grindTactileDescriptor: "sand; slightly finer than sea salt",
    bloomRatio: 3.0,
    steps: [
        RecipeStep(orderIndex: 0, instructionText: "Bloom", stepKind: .bloom, durationSeconds: 45, waterAmountGrams: 45),
        RecipeStep(orderIndex: 1, instructionText: "Pour to 150g", stepKind: .pour, targetElapsedSeconds: 90, waterAmountGrams: 150),
        RecipeStep(orderIndex: 2, instructionText: "Pour to 250g", stepKind: .pour, targetElapsedSeconds: 135, waterAmountGrams: 250),
        RecipeStep(orderIndex: 3, instructionText: "Wait for drawdown", stepKind: .wait, durationSeconds: 60)
    ]
)
```

#### A.2 Invalid Recipe Fixtures
```swift
static let emptyNameRecipe = Recipe(name: "", /* ... */)
static let zeroDoseRecipe = Recipe(defaultDose: 0, /* ... */)
static let negativeTimerRecipe = Recipe(steps: [RecipeStep(durationSeconds: -10, /* ... */)])
static let waterMismatchRecipe = Recipe(defaultTargetYield: 250, steps: [RecipeStep(waterAmountGrams: 200, /* ... */)])
```

### B. Mock/Fake Implementations

#### B.1 FakeAuthSessionStore
```swift
@MainActor
final class FakeAuthSessionStore: AuthSessionStoreProtocol {
    private var _userId: String?
    
    func userId() -> String? { _userId }
    func isSignedIn() -> Bool { _userId != nil }
    func setSession(userId: String) { _userId = userId }
    func clearSession() { _userId = nil }
}
```

#### B.2 FakeClock (for Timer Testing)
```swift
actor TestClock: Clock {
    typealias Duration = Swift.Duration
    typealias Instant = Swift.ContinuousClock.Instant
    
    private var currentTime: Instant = .now
    private var continuations: [CheckedContinuation<Void, any Error>] = []
    
    var now: Instant { currentTime }
    var minimumResolution: Duration { .milliseconds(1) }
    
    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }
    
    func advance(by duration: Duration) {
        currentTime = currentTime.advanced(by: duration)
        let pending = continuations
        continuations = []
        for continuation in pending {
            continuation.resume()
        }
    }
}
```

### C. Code Coverage Targets by Module

| Module | Target | Rationale |
|--------|--------|-----------|
| Domain/Scaling | 95% | Critical business logic |
| Domain/UseCases | 85% | Core orchestration |
| Domain/DTOs | 90% | Validation logic |
| Persistence/Repositories | 80% | Data integrity |
| UI/ViewModels | 75% | State management |
| UI/Views | 20% | UI tests preferred |

### D. Test Naming Conventions

```swift
// Pattern: test[MethodOrBehavior]_[Scenario]_[ExpectedResult]
// Or using Swift Testing display names:

@Test("Empty name produces .emptyName error")
func testEmptyNameValidation() { ... }

@Test("Dose edit triggers yield recalculation maintaining recipe ratio")
func testDoseEditRecalculatesYield() { ... }

@Test("Timer reaching zero transitions phase to stepReadyToAdvance")
func testTimerCompletionTransition() { ... }
```

---

*Document Version: 1.0*  
*Last Updated: January 2026*  
*Author: QA Engineering Team*
