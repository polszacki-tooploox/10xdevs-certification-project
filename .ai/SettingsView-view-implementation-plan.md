# View Implementation Plan — `SettingsView` (+ `DataDeletionRequestView`)

## 1. Overview
`SettingsView` is the root screen of the **Settings** tab. Its purpose is to:
- Keep the app fully usable **local-only** while offering **optional** Sign in with Apple + CloudKit sync.
- Communicate **auth state**, **sync enabled state**, and **last sync attempt** (timestamp + outcome).
- Provide a single place to **manually retry sync** (no global retry UI elsewhere).
- Provide a **privacy path** to request deletion of **synced (cloud) data** via `DataDeletionRequestView`.

This plan implements PRD stories:
- **US-028** (Sign in with Apple to enable sync)
- **US-029** (Handle sign-in cancellation/failure)
- **US-030** (Sign out; local data remains)
- **US-031** (Sync when online; non-blocking)
- **US-032** (Sync failures are non-blocking; retry from settings)
- **US-035** (Request deletion of synced data)

## 2. View Routing
`SettingsView` is accessible via the Settings tab root.

- **Tab root**: `AppRootView` → `SettingsTabRootView` hosts `NavigationStack(path: $coordinator.settingsPath)` and presents `SettingsView()` as root.
- **Navigation destination**: `SettingsRoute.dataDeletionRequest` is registered in `SettingsTabRootView` (already in place).
- **Push navigation**:
  - Tapping “Request deletion of synced data” pushes `SettingsRoute.dataDeletionRequest` onto `coordinator.settingsPath`.

## 3. Component Structure
High-level hierarchy:

```
SettingsView
└─ SettingsScreen
   ├─ List
   │  ├─ Section("Sync (optional)")
   │  │  ├─ SignInRow (signed out)
   │  │  ├─ SignOutRow (signed in)
   │  │  ├─ SyncEnabledToggleRow
   │  │  ├─ SyncStatusRow (status + last attempt + inline failure message)
   │  │  └─ RetrySyncRow (only manual retry entry point)
   │  └─ Section("Privacy")
   │     └─ DataDeletionEntryRow (NavigationLink)
   └─ (optional) Alert / Banner for auth + sync errors

DataDeletionRequestView
└─ DataDeletionRequestScreen
   ├─ ExplanationSection (what is deleted / what remains)
   ├─ RequirementsSection (signed-in requirement + timing limitations)
   ├─ ConfirmationSection (guarded confirmation)
   └─ PrimaryActionSection (Request deletion) + inline success/failure
```

## 4. Component Details

### `SettingsView`
- **Purpose**: Settings tab entry point, owns view model lifecycle, wires dependencies, and renders `SettingsScreen`.
- **Main elements**:
  - `@State private var viewModel = SettingsViewModel(...)`
  - `SettingsScreen(state:onEvent:)`
  - `.task { await viewModel.onAppear() }` to refresh auth/sync status
  - `.alert` or inline banner bound to `viewModel.ui.alert` for non-blocking errors (sign-in failures, sync failures)
- **Handled events**:
  - Appear → refresh auth state and sync status
  - Sign in tapped
  - Sign out tapped
  - Sync toggle changed
  - Retry sync tapped
  - Navigate to deletion request
- **Props (component interface)**:
  - Typically none (root screen).
  - For testability, optionally allow injecting dependency factories:
    - `authUseCase: AuthUseCaseProtocol = AuthUseCase(...)`
    - `syncUseCase: SyncUseCaseProtocol = SyncUseCase(...)`
    - `syncSettingsStore: SyncSettingsStoreProtocol = SyncSettingsStore.shared`
    - `syncStatusStore: SyncStatusStoreProtocol = SyncStatusStore.shared`
    - `authSessionStore: AuthSessionStoreProtocol = AuthSessionStore.shared`

### `SettingsScreen`
- **Purpose**: Pure SwiftUI renderer for the settings list; emits user intent via events/callbacks.
- **Main elements**:
  - `List` with:
    - Sync section:
      - `SignInRow` OR `SignOutRow`
      - `SyncEnabledToggleRow`
      - `SyncStatusRow`
      - `RetrySyncRow`
    - Privacy section:
      - `DataDeletionEntryRow`
- **Handled events**:
  - `onEvent(.signInTapped)`
  - `onEvent(.signOutTapped)`
  - `onEvent(.syncToggleChanged(Bool))`
  - `onEvent(.retrySyncTapped)`
  - `onEvent(.dataDeletionTapped)` (optional; navigation can also be driven by `NavigationLink` without explicit event)
- **Props**:
  - `state: SettingsViewState`
  - `onEvent: (SettingsEvent) -> Void`

### `SignInRow`
- **Purpose**: Offer Sign in with Apple when signed out; explain that sync requires sign-in.
- **Main elements**:
  - Button label: “Sign in with Apple” (use `SignInWithAppleButton` in implementation)
  - Secondary text: “You can use the app without signing in. Sign in to enable sync.”
- **Handled events**:
  - Tap → `SettingsEvent.signInTapped`
- **Validation**:
  - Disabled while `state.isPerformingAuth == true`
- **Props**:
  - `isEnabled: Bool`
  - `onTap: () -> Void`

### `SignOutRow`
- **Purpose**: Allow signed-in user to sign out; make consequences explicit (local remains, sync disabled).
- **Main elements**:
  - Button “Sign out”
  - Inline helper text (secondary): “Local data stays on this device. Sync will be turned off.”
- **Handled events**:
  - Tap → `SettingsEvent.signOutTapped`
- **Validation**:
  - Disabled while `state.isPerformingAuth || state.isSyncInProgress`
- **Props**:
  - `onTap: () -> Void`
  - `isEnabled: Bool`

### `SyncEnabledToggleRow`
- **Purpose**: Toggle persisted sync setting; only meaningful when signed in.
- **Main elements**:
  - `Toggle("Sync enabled", isOn: ...)`
  - When signed out:
    - Toggle is disabled
    - Additional caption: “Sign in to enable sync.”
- **Handled events**:
  - Change → `SettingsEvent.syncToggleChanged(isOn)`
- **Validation / rules**:
  - If signed out, do not allow enabling; show explanation (banner/alert) instead of changing stored value.
  - If enabling while signed in, call `SyncUseCase.enableSync()` and update persisted store on success.
  - If disabling, call `SyncUseCase.disableSync()` then persist `syncEnabled = false`.
- **Props**:
  - `isSignedIn: Bool`
  - `syncEnabled: Bool`
  - `isBusy: Bool`
  - `onChange: (Bool) -> Void`

### `SyncStatusRow`
- **Purpose**: Communicate current sync mode and last attempt result; show inline non-blocking failure state.
- **Main elements**:
  - Status line (always):
    - If signed out OR sync disabled: “Local only”
    - If signed in AND sync enabled: “Sync enabled”
  - Last attempt line (if available): “Last attempt: {date} — {resultLabel}”
  - Inline failure message (only if last attempt is failure): short, user-friendly text + “Retry sync” affordance is provided separately by `RetrySyncRow`.
- **Handled events**:
  - None (pure display).
- **Validation**:
  - Handle missing date/result gracefully by hiding the “Last attempt” row.
- **Props**:
  - `status: SyncStatusDisplay`

### `RetrySyncRow`
- **Purpose**: The **only** place to manually retry sync (per UI plan).
- **Main elements**:
  - Button “Retry sync”
  - Disabled state + caption when:
    - signed out (“Sign in to retry sync.”)
    - sync disabled (“Enable sync to retry.”)
    - sync currently in progress
- **Handled events**:
  - Tap → `SettingsEvent.retrySyncTapped`
- **Props**:
  - `isEnabled: Bool`
  - `isInProgress: Bool`
  - `onTap: () -> Void`

### `DataDeletionEntryRow`
- **Purpose**: Entry point to request deletion of **synced** (CloudKit) data.
- **Main elements**:
  - `NavigationLink(value: SettingsRoute.dataDeletionRequest)` with label “Request deletion of synced data”
  - Secondary explanation: “This affects cloud-synced data; local-only usage remains available.”
- **Handled events**:
  - Navigation push.
- **Props**:
  - None.

---

### `DataDeletionRequestView`
- **Purpose**: Explain what deletion means, require explicit confirmation, and invoke `SyncUseCase.requestDataDeletion()` (US-035).
- **Main elements**:
  - Owns `@State private var viewModel = DataDeletionRequestViewModel(...)`
  - `DataDeletionRequestScreen(state:onEvent:)`
  - Inline success/failure presentation (avoid frightening language; be precise and transparent).
- **Handled events**:
  - Appear → refresh sign-in + sync state
  - Confirm input changed
  - Request deletion tapped
  - Done/back after success
- **Props**:
  - None (reached via navigation stack).

### `DataDeletionRequestScreen`
- **Purpose**: Pure rendering + event emission.
- **Main elements**:
  - **Explanation section**:
    - “This requests deletion of your synced BrewGuide data from iCloud.”
    - “Data deleted: custom recipes, brew logs, basic preferences (e.g. last selected recipe).”
    - “What remains: the app can still be used locally; local data on this device is not automatically deleted.”
  - **Limitations section**:
    - Requires sign-in
    - May take time / depends on connectivity
  - **Confirmation section** (guarded):
    - Choose one guarded approach:
      - **Text confirmation** (e.g. type `DELETE`) OR
      - **Checkbox + confirm alert** (preferred for kitchen-proof, less typing)
    - This plan recommends **checkbox + confirm alert** to reduce typing.
  - **Primary action**:
    - Button “Request deletion”
    - Disabled unless: signed in, not busy, confirmation complete
  - **Result area**:
    - Inline success state (“Request sent. Sync has been turned off to prevent re-upload.”)
    - Inline failure state with retry guidance
- **Handled events**:
  - `onEvent(.confirmChanged(Bool))` (or `.confirmationTextChanged(String)`)
  - `onEvent(.requestDeletionTapped)`
- **Props**:
  - `state: DataDeletionRequestViewState`
  - `onEvent: (DataDeletionRequestEvent) -> Void`

## 5. Types

### View state models (UI-only)
`struct SettingsViewState: Equatable`
- `isSignedIn: Bool`
- `syncEnabled: Bool`
- `syncStatus: SyncStatusDisplay`
- `isPerformingAuth: Bool`
- `isSyncInProgress: Bool`
- `inlineMessage: InlineMessage?` (optional: non-blocking message banner)

`struct SyncStatusDisplay: Equatable`
- `mode: SyncModeDisplay` (`.localOnly` | `.syncEnabled`)
- `lastAttempt: SyncAttemptDisplay?`
- `lastFailureMessage: String?` (only when last attempt failed; short user-friendly)

`enum SyncModeDisplay: Equatable`
- `case localOnly`
- `case syncEnabled`

`struct SyncAttemptDisplay: Equatable`
- `timestamp: Date`
- `result: SyncAttemptResultDisplay`

`enum SyncAttemptResultDisplay: Equatable`
- `case success`
- `case failure`

`struct InlineMessage: Equatable`
- `kind: InlineMessageKind` (`.info` | `.warning` | `.error`)
- `text: String`

`enum InlineMessageKind: Equatable`
- `case info, warning, error`

`struct DataDeletionRequestViewState: Equatable`
- `isSignedIn: Bool`
- `syncEnabled: Bool`
- `confirmation: DataDeletionConfirmationState`
- `isSubmitting: Bool`
- `result: DataDeletionRequestResult?` (nil/ success/ failure)

`enum DataDeletionConfirmationState: Equatable`
- `case notConfirmed`
- `case confirmed`

`enum DataDeletionRequestResult: Equatable`
- `case success(message: String)`
- `case failure(message: String)`

### View models (Observation)
`@MainActor @Observable final class SettingsViewModel`
- **Purpose**: Orchestrate auth + sync status, manage toggle semantics, and keep UI declarative.
- **Stored fields** (internal mutable state):
  - `var ui: SettingsViewState`
  - `private let authUseCase: AuthUseCaseProtocol`
  - `private let syncUseCase: SyncUseCaseProtocol`
  - `private let syncSettingsStore: SyncSettingsStoreProtocol`
  - `private let authSessionStore: AuthSessionStoreProtocol`
  - `private let syncStatusStore: SyncStatusStoreProtocol`
  - `private let logger = Logger(subsystem: "com.brewguide", category: "Settings")`
- **Key methods**:
  - `func onAppear() async`
  - `func signIn() async`
  - `func signOut() async`
  - `func setSyncEnabled(_ enabled: Bool) async`
  - `func retrySync() async`
  - `private func refreshFromStores()`
  - `private func mapSyncStatusToDisplay(...) -> SyncStatusDisplay`

`@MainActor @Observable final class DataDeletionRequestViewModel`
- **Purpose**: Gate deletion request behind sign-in + explicit confirmation and call `SyncUseCase.requestDataDeletion()`.
- **Stored fields**:
  - `var ui: DataDeletionRequestViewState`
  - Dependencies: `syncUseCase`, `syncSettingsStore`, `authSessionStore`, `syncStatusStore`, `logger`
- **Key methods**:
  - `func onAppear() async`
  - `func setConfirmed(_ confirmed: Bool)`
  - `func requestDeletion() async`

### Domain / application types (required for Settings integration)
These types are referenced by PRD and the existing `.ai/api-plan.md`. If they are not already implemented, they must be added (or adapted) to match these shapes.

`protocol AuthUseCaseProtocol`
- `func signInWithApple() async -> Result<AuthSession, AuthError>`
- `func signOut() async`

`struct AuthSession: Equatable, Sendable`
- `isSignedIn: Bool` (or infer from stored identifier)
  - Implementation detail: do **not** expose user identifiers to UI; UI only needs a boolean.

`enum AuthError: LocalizedError, Equatable`
- `case cancelled`
- `case notAvailable`
- `case failed(message: String)` (wrap underlying ASAuthorization errors safely)

`protocol SyncUseCaseProtocol`
- `func enableSync() async -> Result<Void, SyncError>`
- `func disableSync() async`
- `func syncNow() async -> Result<Void, SyncError>` (explicit retry; should also update last attempt)
- `func requestDataDeletion() async -> Result<Void, SyncError>`

`enum SyncError: LocalizedError, Equatable`
- `case notSignedIn`
- `case networkUnavailable`
- `case cloudKitError(message: String)`
- `case unknown(message: String)`

`protocol SyncSettingsStoreProtocol`
- `func isSyncEnabled() -> Bool`
- `func setSyncEnabled(_ enabled: Bool)`

`protocol AuthSessionStoreProtocol`
- `func isSignedIn() -> Bool` (preferred)
  - Alternate: `func appleUserId() -> String?` but UI must not display it.

`protocol SyncStatusStoreProtocol`
- `func lastAttempt() -> SyncAttempt?`
- `func setLastAttempt(_ attempt: SyncAttempt)`

`struct SyncAttempt: Equatable, Sendable`
- `timestamp: Date`
- `result: SyncAttemptResult`

`enum SyncAttemptResult: Equatable, Sendable`
- `case success`
- `case failure(message: String)` (store user-safe summary; keep raw errors only in logs)

## 6. State Management
- Use **Observation** with `@Observable` view models as the single source of truth for each screen.
- `SettingsView` owns `SettingsViewModel` via `@State`, ensuring the instance is stable across redraws.
- `SettingsViewModel` reads/writes persisted values through stores:
  - `SyncSettingsStore` (persisted `syncEnabled`)
  - `AuthSessionStore` (signed-in state)
  - `SyncStatusStore` (last attempt timestamp/outcome)
- All async operations run in `Task` context and update UI state on the main actor (view models are `@MainActor`).

No custom SwiftUI “hook” abstraction is required; the equivalent is:
- `SettingsViewModel` + `DataDeletionRequestViewModel`
- small, testable pure view components (`SettingsScreen`, row subviews)

## 7. API Integration
This app uses an **internal application API** (repositories + use-cases), not HTTP.

### Auth
- **Call**: `AuthUseCase.signInWithApple() -> Result<AuthSession, AuthError>`
  - On `.success`: mark signed-in (via `AuthSessionStore`), refresh UI, and allow enabling sync.
  - On `.failure(.cancelled)`: show no error banner (optional) or a subtle “Sign-in cancelled” info.
  - On other failures: show a non-blocking error banner with a retry.
- **Call**: `AuthUseCase.signOut()`
  - After sign-out:
    - Ensure `SyncSettingsStore.syncEnabled = false`
    - Ensure UI shows “Local only”

### Sync enabled toggle
- **Enable**:
  - Verify signed-in (`AuthSessionStore.isSignedIn == true`)
  - Call `SyncUseCase.enableSync() -> Result<Void, SyncError>`
  - On success: `SyncSettingsStore.setSyncEnabled(true)` and optionally trigger an initial `syncNow()`
  - Update `SyncStatusStore` with a success/failure attempt
- **Disable**:
  - Call `SyncUseCase.disableSync()` (stop/disable CloudKit integration)
  - `SyncSettingsStore.setSyncEnabled(false)`

### Retry sync
- **Call**: `SyncUseCase.syncNow() -> Result<Void, SyncError>`
  - Only allowed when signed in + sync enabled
  - Always update `SyncStatusStore` with a new `SyncAttempt` (timestamp + result)

### Data deletion request
- **Call**: `SyncUseCase.requestDataDeletion() -> Result<Void, SyncError>`
  - Preconditions:
    - signed in (required)
  - Postconditions:
    - On success: set a success state in view model.
    - To prevent re-upload, immediately disable sync locally:
      - `await SyncUseCase.disableSync()`
      - `SyncSettingsStore.setSyncEnabled(false)`
    - Update `SyncStatusStore` to reflect a “success” attempt for deletion request OR store a separate deletion status (preferred if you want separation).

## 8. User Interactions
`SettingsView`:
- **Sign in**:
  - Tap “Sign in with Apple” → starts auth flow
  - Outcome:
    - Success → “Signed in” UI, sync toggle becomes enabled
    - Cancel → remains signed out; app continues local-only
    - Failure → inline error with retry
- **Sign out**:
  - Tap “Sign out” → signs out and disables sync
  - Outcome: “Local only” status, sync toggle off/disabled
- **Toggle sync**:
  - When signed out:
    - Toggle appears disabled, and UI explains sign-in requirement
  - When signed in:
    - Toggle on → enable sync; show progress and last attempt update
    - Toggle off → disable sync; status shows local-only
- **Retry sync**:
  - Tap “Retry sync” → calls `syncNow()`
  - Outcome: last attempt timestamp updated + success/failure shown inline
- **Request deletion entry**:
  - Tap → navigates to `DataDeletionRequestView`

`DataDeletionRequestView`:
- **Read explanation** (non-interactive)
- **Confirm intent**:
  - Checkbox (or typed confirmation) to unlock the primary action
- **Request deletion**:
  - Tap “Request deletion” → async request; show progress
  - Outcome:
    - Success → show success message; sync is turned off
    - Failure → show failure message; allow retry

## 9. Conditions and Validation
`SettingsView`:
- **Sync requires sign-in**:
  - Condition: `AuthSessionStore.isSignedIn() == true`
  - UI behavior:
    - When false: disable toggle and retry button; show explanatory caption
    - Prevent any attempt to call `enableSync()`/`syncNow()` while signed out
- **Retry sync only when meaningful**:
  - Condition: `isSignedIn && syncEnabled && !isSyncInProgress`
  - UI behavior: disable button otherwise with short explanation
- **Do not display Apple identifiers**:
  - UI must only show `Signed in` / `Signed out`, never user IDs/emails.

`DataDeletionRequestView`:
- **Require sign-in for cloud deletion**:
  - Condition: `isSignedIn == true`
  - UI behavior:
    - If signed out: disable primary action; show “Sign in to request deletion of synced data.”
- **Require explicit confirmation**:
  - Condition: `confirmation == .confirmed`
  - UI behavior: disable “Request deletion” until confirmed.

## 10. Error Handling
Common error scenarios and recommended handling:
- **User cancels Sign in with Apple**:
  - Treat as non-error; optional subtle banner: “Sign-in cancelled.”
- **Sign-in fails (ASAuthorization / system issues)**:
  - Show non-blocking error message with a retry button.
  - Log technical details via `OSLog` (do not surface raw system codes).
- **Enable sync fails** (no network, CloudKit error):
  - Keep app usable, keep `syncEnabled` off if enable failed.
  - Show inline status failure and offer “Retry sync” after enable succeeds (or retry enable explicitly).
- **Retry sync fails**:
  - Update last attempt to failure with user-safe message.
  - Keep “Retry sync” available.
- **Request deletion fails**:
  - Show failure state with retry; do not delete local data as a side-effect of a failed cloud deletion request.
- **Race conditions / double-taps**:
  - Guard with `isPerformingAuth` and `isSyncInProgress` to prevent concurrent operations.

## 11. Implementation Steps
1. **Align Settings UI with requirements**
   - Replace placeholder `SettingsView` content with the “Sync (optional)” + “Privacy” sections described in `.ai/ui-plan.md`.
2. **Introduce view models**
   - Add `SettingsViewModel` and `DataDeletionRequestViewModel` as `@MainActor @Observable`.
   - Implement `SettingsViewState` and `DataDeletionRequestViewState`.
3. **Add/confirm persistence stores**
   - Ensure `SyncSettingsStore` persists `syncEnabled: Bool`.
   - Ensure `AuthSessionStore` can answer `isSignedIn`.
   - Add `SyncStatusStore` to persist last sync attempt: timestamp + success/failure (user-safe).
4. **Implement Auth + Sync use-case APIs**
   - Add `AuthUseCase` with Sign in with Apple using `AuthenticationServices`.
   - Add `SyncUseCase` surface (`enableSync`, `disableSync`, `syncNow`, `requestDataDeletion`) that integrates with CloudKit/SwiftData sync layer.
   - Ensure all methods are `async` and update `SyncStatusStore` appropriately.
5. **Wire `SettingsView` to the view model**
   - On appear, load `isSignedIn`, `syncEnabled`, and `lastAttempt`.
   - Render the correct rows (sign in vs sign out; toggle enabled/disabled; retry availability).
6. **Implement `DataDeletionRequestView` to match PRD**
   - Update copy to clarify “synced (cloud) data deletion request” and that local-only usage remains possible.
   - Require sign-in; disable action when signed out.
   - Use guarded confirmation (checkbox + confirm alert recommended).
   - On success: disable sync locally and show next steps.
7. **Accessibility pass**
   - Ensure all rows have clear labels, Dynamic Type works, and touch targets meet 44×44pt.
   - Avoid jargon and avoid exposing identifiers.
8. **Testing strategy (unit)**
   - Add unit tests for:
     - `SettingsViewModel` state transitions (signed out → sign in success/failure; toggle enable/disable; retry updates last attempt)
     - `DataDeletionRequestViewModel` gating and result handling.
   - Use fake `AuthUseCaseProtocol` and `SyncUseCaseProtocol` to keep tests deterministic.

