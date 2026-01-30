# Settings Architecture Diagram

## Component Relationships

```
┌─────────────────────────────────────────────────────────────────────┐
│                           USER INTERFACE                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────────┐         ┌──────────────────────────────┐  │
│  │   SettingsView       │         │ DataDeletionRequestView      │  │
│  │  (View Model Owner)  │         │    (View Model Owner)        │  │
│  └──────────┬───────────┘         └───────────┬──────────────────┘  │
│             │                                   │                     │
│             │ owns                              │ owns                │
│             │                                   │                     │
│  ┌──────────▼───────────┐         ┌───────────▼──────────────────┐  │
│  │  SettingsViewModel   │         │ DataDeletionRequestViewModel │  │
│  │    (@Observable)     │         │       (@Observable)          │  │
│  └──────────┬───────────┘         └───────────┬──────────────────┘  │
│             │                                   │                     │
│             │ updates                           │ updates             │
│             │                                   │                     │
│  ┌──────────▼───────────┐         ┌───────────▼──────────────────┐  │
│  │   SettingsScreen     │         │  DataDeletionRequestScreen   │  │
│  │  (Pure Renderer)     │         │      (Pure Renderer)         │  │
│  └──────────────────────┘         └──────────────────────────────┘  │
│                                                                       │
│  Components:                                                          │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  • SignInRow            • SyncEnabledToggleRow              │    │
│  │  • SignOutRow           • SyncStatusRow                     │    │
│  │  • RetrySyncRow         • DataDeletionEntryRow              │    │
│  │  • InlineMessageBanner                                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                │ calls
                                │
┌───────────────────────────────▼───────────────────────────────────────┐
│                         DOMAIN LAYER                                   │
├───────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────┐   ┌──────────────────────────────┐ │
│  │       AuthUseCase            │   │       SyncUseCase            │ │
│  │  ┌────────────────────────┐  │   │  ┌────────────────────────┐ │ │
│  │  │ signInWithApple()      │  │   │  │ enableSync()           │ │ │
│  │  │ signOut()              │  │   │  │ disableSync()          │ │ │
│  │  │ currentSession()       │  │   │  │ syncNow()              │ │ │
│  │  └────────────────────────┘  │   │  │ requestDataDeletion()  │ │ │
│  │           │                   │   │  └────────────────────────┘ │ │
│  │           │ uses              │   │           │                  │ │
│  │           ▼                   │   │           ▼                  │ │
│  │  ASAuthorizationController    │   │    CKContainer.default()    │ │
│  │  (Sign in with Apple)         │   │       (CloudKit)            │ │
│  └───────────┬───────────────────┘   └───────────┬──────────────────┘ │
│              │                                     │                    │
│              │ reads/writes                        │ reads/writes       │
│              │                                     │                    │
└──────────────┼─────────────────────────────────────┼────────────────────┘
               │                                     │
               │                                     │
┌──────────────▼─────────────────────────────────────▼────────────────────┐
│                        PERSISTENCE LAYER                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐│
│  │  AuthSessionStore   │  │  SyncSettingsStore   │  │ SyncStatusStore ││
│  │  ─────────────────  │  │  ───────────────────  │  │ ──────────────  ││
│  │  • isSignedIn()     │  │  • isSyncEnabled()   │  │ • lastAttempt() ││
│  │  • userId()         │  │  • setSyncEnabled()  │  │ • setLast...()  ││
│  │  • setSession()     │  │                      │  │ • clear...()    ││
│  │  • clearSession()   │  │                      │  │                 ││
│  └──────────┬──────────┘  └──────────┬───────────┘  └────────┬────────┘│
│             │                        │                        │         │
│             └────────────────────────┴────────────────────────┘         │
│                                      │                                  │
│                                      ▼                                  │
│                              UserDefaults                               │
│                    ┌──────────────────────────────┐                     │
│                    │  Keys:                        │                     │
│                    │  • appleUserId                │                     │
│                    │  • syncEnabled                │                     │
│                    │  • lastSyncAttemptTimestamp   │                     │
│                    │  • lastSyncAttemptResult      │                     │
│                    │  • lastSyncAttemptMessage     │                     │
│                    └──────────────────────────────┘                     │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Examples

### Sign In Flow

```
User taps "Sign in with Apple"
    ↓
SettingsScreen emits .signInTapped event
    ↓
SettingsView handles event → Task { viewModel.signIn() }
    ↓
SettingsViewModel.signIn() calls AuthUseCase.signInWithApple()
    ↓
AuthUseCase presents ASAuthorizationController
    ↓
User completes auth in system sheet
    ↓
AuthUseCase receives credential → stores userId in AuthSessionStore
    ↓
Returns .success(AuthSession) to SettingsViewModel
    ↓
SettingsViewModel calls refreshFromStores()
    ↓
Reads isSignedIn from AuthSessionStore → updates ui.isSignedIn
    ↓
SwiftUI observes state change → UI updates
    ↓
SettingsScreen shows SignOutRow, enables SyncEnabledToggleRow
```

### Enable Sync Flow

```
User toggles "Sync enabled" ON
    ↓
SyncEnabledToggleRow emits .syncToggleChanged(true) event
    ↓
SettingsView handles event → Task { viewModel.setSyncEnabled(true) }
    ↓
SettingsViewModel.setSyncEnabled(true) validates isSignedIn
    ↓
Calls SyncUseCase.enableSync()
    ↓
SyncUseCase checks CKContainer.default().accountStatus()
    ↓
If available → SyncSettingsStore.setSyncEnabled(true)
    ↓
Creates success SyncAttempt → SyncStatusStore.setLastAttempt()
    ↓
Returns .success to SettingsViewModel
    ↓
SettingsViewModel refreshes state from stores
    ↓
Updates ui.syncEnabled, ui.syncStatus with last attempt
    ↓
Optionally calls retrySync() for initial sync
    ↓
SwiftUI observes changes → UI updates with "Sync enabled" status
```

### Data Deletion Flow

```
User navigates to DataDeletionRequestView
    ↓
DataDeletionRequestViewModel.onAppear() refreshes state
    ↓
User toggles "I understand and want to request deletion"
    ↓
DataDeletionRequestScreen emits .confirmChanged(true)
    ↓
DataDeletionRequestViewModel.setConfirmed(true)
    ↓
Updates ui.confirmation = .confirmed → button becomes enabled
    ↓
User taps "Request Deletion"
    ↓
DataDeletionRequestScreen emits .requestDeletionTapped
    ↓
DataDeletionRequestViewModel.requestDeletion() validates requirements
    ↓
Calls SyncUseCase.requestDataDeletion()
    ↓
SyncUseCase checks CloudKit availability
    ↓
(MVP: placeholder operation)
    ↓
Calls SyncUseCase.disableSync() to prevent re-upload
    ↓
Returns .success to DataDeletionRequestViewModel
    ↓
Updates ui.result = .success(message)
    ↓
Refreshes state → ui.syncEnabled now false
    ↓
SwiftUI observes changes → shows success message
```

## State Synchronization

### View Model State Sources

```
SettingsViewModel.ui.isSignedIn
    ← AuthSessionStore.isSignedIn()

SettingsViewModel.ui.syncEnabled
    ← SyncSettingsStore.isSyncEnabled()

SettingsViewModel.ui.syncStatus.mode
    ← Derived from (isSignedIn && syncEnabled)

SettingsViewModel.ui.syncStatus.lastAttempt
    ← SyncStatusStore.lastAttempt()
    → Mapped to SyncAttemptDisplay

SettingsViewModel.ui.syncStatus.lastFailureMessage
    ← SyncStatusStore.lastAttempt().result (if failure)
```

### Observation Pattern

```
@Observable class SettingsViewModel {
    var ui: SettingsViewState  ← SwiftUI observes this
}

When any property of 'ui' changes:
    1. SwiftUI observation system detects change
    2. Any View reading that property re-renders
    3. No explicit @Published or objectWillChange needed
```

## Dependency Injection

### For Testing

```swift
// Production
let viewModel = SettingsViewModel()  // Uses default dependencies

// Testing
let fakeAuthUseCase = FakeAuthUseCase()
let fakeSyncUseCase = FakeSyncUseCase()
let fakeAuthStore = FakeAuthSessionStore()
let fakeSyncStore = FakeSyncSettingsStore()
let fakeStatusStore = FakeSyncStatusStore()

let viewModel = SettingsViewModel(
    authUseCase: fakeAuthUseCase,
    syncUseCase: fakeSyncUseCase,
    syncSettingsStore: fakeSyncStore,
    authSessionStore: fakeAuthStore,
    syncStatusStore: fakeStatusStore
)

// All dependencies are protocols, making them mockable
```

## Error Handling Strategy

### Non-Blocking Errors

```
Error occurs in domain layer
    ↓
Use case returns .failure(error)
    ↓
View model receives failure
    ↓
Maps to user-friendly message
    ↓
Updates ui.inlineMessage = InlineMessage(kind: .error, text: ...)
    ↓
SwiftUI renders InlineMessageBanner
    ↓
User sees error WITHOUT blocking app usage
    ↓
User can retry or continue using app locally
```

### Validation Guards

```
Before operation:
    if !ui.isSignedIn {
        ui.inlineMessage = warning("Must sign in")
        return early
    }

During operation:
    guard !ui.isSyncInProgress else { return }
    ui.isSyncInProgress = true
    await performOperation()
    ui.isSyncInProgress = false

Button states:
    .disabled(!isEnabled || isBusy)
```

## Concurrency Model

### MainActor Isolation

```
All view models are @MainActor:
    → All state updates happen on main thread
    → SwiftUI access is thread-safe

All use cases are @MainActor:
    → Simple, predictable execution
    → No Sendable issues with callbacks

Async operations:
    func signIn() async {
        // Already on MainActor
        ui.isPerformingAuth = true
        let result = await authUseCase.signInWithApple()
        // Still on MainActor
        ui.isPerformingAuth = false
    }

Task creation in views:
    Button("Sign In") {
        Task {
            await viewModel.signIn()
        }
    }
```

## Key Architectural Decisions

### 1. MVVM with Observation
- **Why:** Modern Swift pattern, no need for ObservableObject
- **Benefit:** Simpler code, better performance
- **Trade-off:** Requires iOS 17+

### 2. Pure Rendering Components
- **Why:** Testability, reusability
- **Benefit:** Screen components are pure functions of state
- **Trade-off:** More files, but clearer separation

### 3. Event-Based Communication
- **Why:** Unidirectional data flow
- **Benefit:** Predictable state changes
- **Trade-off:** More boilerplate than direct bindings

### 4. Protocol-Based Dependencies
- **Why:** Testability
- **Benefit:** Easy to mock/fake in tests
- **Trade-off:** More upfront design

### 5. Local-First Design
- **Why:** Reliability, offline support
- **Benefit:** App always works
- **Trade-off:** Sync complexity deferred

### 6. Non-Blocking Errors
- **Why:** User experience
- **Benefit:** Failures don't halt workflow
- **Trade-off:** Users might ignore errors

This architecture provides:
- ✅ Clear separation of concerns
- ✅ Testable components
- ✅ Type-safe communication
- ✅ Modern Swift patterns
- ✅ Scalable structure
- ✅ Maintainable codebase
