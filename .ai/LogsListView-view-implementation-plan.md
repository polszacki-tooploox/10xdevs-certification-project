## View Implementation Plan: LogsListView

## 1. Overview
`LogsListView` is the root screen for the **Logs** tab. It displays a **chronological history of brews** (most recent first), lets the user **open a log detail screen**, and supports **deleting a log with confirmation** (PRD US-021, US-022, US-023). The view is **offline-first** (SwiftData-backed) and does **not require authentication**; if CloudKit sync is enabled, deletions should propagate automatically.

Key UX goals:
- Fast scanability in a kitchen context: large rows, minimal clutter.
- Stable list identity: always use snapshot fields (not live recipe properties) such as `recipeNameAtBrew`.
- Safe destructive actions: confirm before delete.

## 2. View Routing
- **Tab root**: `AppRootView` → `LogsTabRootView` hosts a `NavigationStack(path: $coordinator.logsPath)` and presents `LogsListView()` as root.
- **Navigation destination**: `LogsRoute.logDetail(id: UUID)` is registered in `AppRootView` via `.navigationDestination(for: LogsRoute.self)`.
- **Row navigation**:
  - Tapping a row pushes `LogsRoute.logDetail(id: log.id)` onto `coordinator.logsPath`.
  - Destination view should be `LogDetailNavigationView(logId:)` which fetches the log and renders `LogDetailView` (currently TODO in `AppRootView`).

## 3. Component Structure
High-level SwiftUI hierarchy:

```
LogsListView
└─ LogsListScreen
   ├─ LoadingStateView (optional)
   ├─ ErrorStateView (optional, retryable)
   └─ List
      ├─ ContentUnavailableView (empty)
      └─ ForEach(logs) → BrewLogRow
         └─ NavigationLink(value: LogsRoute.logDetail(id:))
             └─ BrewLogRowContent
```

Supporting presentation components (recommended):
- `BrewLogRow`: one row layout for a `BrewLogSummaryDTO`.
- `BrewLogRatingView`: star-based rating display (VoiceOver friendly).
- `TasteTagPill` (optional): compact taste tag indicator when present.
- `DeleteLogConfirmationDialog` (pattern): state-driven confirmation dialog.

## 4. Component Details

### LogsListView
- **Purpose**: Entry point for the Logs tab list. Wires dependencies (SwiftData `ModelContext`, coordinator) into a view model and owns its lifecycle.
- **Main elements**:
  - `LogsListScreen(state:onEvent:)` (pure rendering) OR direct bindings to view-model fields.
  - `confirmationDialog` (or `.alert`) for delete confirmation.
  - Optional `.refreshable { await viewModel.reload(...) }`.
- **Handled events**:
  - Initial load: `.task { await viewModel.load(context: modelContext) }`
  - Retry: re-run load after a failure.
  - Row tap: navigate to detail by pushing `LogsRoute.logDetail(id:)`.
  - Swipe delete request: set pending delete state (do not delete immediately).
  - Confirm delete: call delete use case, then update list.
- **Props (component interface)**:
  - For testability, allow injecting factories (optional, defaulted):
    - `makeRepository: (ModelContext) -> BrewLogRepository`
    - `makeUseCase: (BrewLogRepository) -> BrewLogUseCase` (recommended if you introduce a use case layer for logs)

### LogsListScreen
- **Purpose**: Pure renderer; receives DTO list + UI state and emits user events.
- **Main elements**:
  - `List` containing:
    - Empty: `ContentUnavailableView("No Brew Logs", ...)`
    - Otherwise: `ForEach(logs) { log in BrewLogRow(...) }`
  - Inline error presentation (banner/section) with “Retry”.
  - Optional pull-to-refresh.
- **Handled events**:
  - `onTapLog(id: UUID)`
  - `onRequestDelete(id: UUID)`
  - `onRetry()`
- **Props (component interface)**:
  - `logs: [BrewLogSummaryDTO]`
  - `isLoading: Bool`
  - `errorMessage: String?`
  - `onTapLog: (UUID) -> Void`
  - `onRequestDelete: (UUID) -> Void`
  - `onRetry: () -> Void`

### BrewLogRow (row wrapper)
- **Purpose**: Row container that provides navigation and swipe actions.
- **Main elements**:
  - `NavigationLink(value: LogsRoute.logDetail(id: log.id)) { BrewLogRowContent(log: log) }`
  - `.swipeActions(edge: .trailing)` with `Button(role: .destructive)` labeled “Delete”.
- **Handled events**:
  - Swipe “Delete” triggers `onRequestDelete`.
- **Validation handled**:
  - None (list-only). Defensive UI: treat missing/empty `recipeNameAtBrew` as “(Unknown recipe)” if encountered.
- **Props**:
  - `log: BrewLogSummaryDTO`
  - `onRequestDelete: (UUID) -> Void`

### BrewLogRowContent
- **Purpose**: Visual content of a log row (kitchen-proof and Dynamic Type friendly).
- **Main elements**:
  - **Title**: `Text(log.recipeNameAtBrew)` (headline).
  - **Subtitle line**: timestamp formatted with `.dateTime.month().day().hour().minute()` (or locale-appropriate default).
  - **Trailing rating**: `BrewLogRatingView(rating: log.rating)` (stars, not emoji strings).
  - **Optional taste tag**: show a small pill/badge when `log.tasteTag != nil`.
- **Handled events**: none.
- **Props**:
  - `log: BrewLogSummaryDTO`

### BrewLogRatingView
- **Purpose**: Render rating 1–5 in a scalable, accessible way.
- **Main elements**:
  - `HStack` with 5 `Image(systemName:)` stars (filled for `<= rating`).
  - Uses `.foregroundStyle(.yellow)` for filled and `.secondary` for empty.
- **Props**:
  - `rating: Int`
- **Validation**:
  - Clamp defensively to 0...5 for rendering only (business validation is elsewhere).

### DeleteLogConfirmationDialog (presentation pattern)
- **Purpose**: Ensure delete requires explicit confirmation (PRD US-023).
- **Main elements**:
  - `confirmationDialog("Delete this brew log?", isPresented: ...) { Delete/Cancel } message: { "This action cannot be undone." }`
  - Alternatively `.alert` if you want a simpler style.
- **Handled events**:
  - Confirm → `viewModel.confirmDelete(context:)`
  - Cancel → clear pending delete state
- **Props**:
  - `pendingDeleteLog: BrewLogSummaryDTO?` (or `PendingDeleteLog` helper)

## 5. Types

### Existing DTOs (reuse)
`BrewLogSummaryDTO` (`Domain/DTOs/BrewLogDTOs.swift`):
- `id: UUID`
- `timestamp: Date`
- `method: BrewMethod`
- `recipeNameAtBrew: String`
- `rating: Int`
- `tasteTag: TasteTag?`
- `recipeId: UUID?`

`BrewLogDetailDTO` (`Domain/DTOs/BrewLogDTOs.swift`) is used by detail, not required for list rendering.

### Existing mapping helpers (reuse)
`BrewLog.toSummaryDTO() -> BrewLogSummaryDTO` (`Domain/DTOs/MappingExtensions.swift`).

### New ViewModel (recommended)
`@MainActor @Observable final class LogsListViewModel`
- **Purpose**: Owns loading, error state, and delete confirmation flow using repositories/use-cases. Keeps SwiftUI view mostly declarative and testable.
- **Fields**:
  - `logs: [BrewLogSummaryDTO] = []`
  - `isLoading: Bool = false`
  - `errorMessage: String? = nil`
  - `pendingDelete: BrewLogSummaryDTO? = nil`
  - `isDeleting: Bool = false` (optional; prevents double-confirm)
- **Dependencies**:
  - `makeRepository: (ModelContext) -> BrewLogRepository`
  - `useCaseFactory: (BrewLogRepository) -> BrewLogUseCase` (recommended)
- **Methods**:
  - `func load(context: ModelContext) async`
  - `func reload(context: ModelContext) async` (optional alias)
  - `func requestDelete(id: UUID)`
  - `func cancelDelete()`
  - `func confirmDelete(context: ModelContext) async`

### New Use Case (recommended if not already present)
`@MainActor final class BrewLogUseCase`
- **Purpose**: Encapsulate log mutations (delete, save) so the UI does not manipulate `ModelContext` directly.
- **API**:
  - `func deleteLog(id: UUID) throws`
- **Implementation detail**:
  - Uses `BrewLogRepository.fetchLog(byId:)` then deletes via repository/base repository and saves the context.
  - Treat “log not found” as a non-fatal success for the list UI (reload and continue).

### New helper types (optional)
`enum LogsListErrorState: Equatable`
- `case loadFailed(message: String)`
- `case deleteFailed(message: String)`

`enum LogsListEvent`
- `.appeared`
- `.tapLog(UUID)`
- `.requestDelete(UUID)`
- `.confirmDelete`
- `.cancelDelete`
- `.retry`

## 6. State Management
Use Observation (`@Observable`) and keep the view model as the single source of truth:
- `LogsListView` owns the view model with `@State private var viewModel = LogsListViewModel(...)`.
- Load logs on first appearance using `.task`.
- Store delete confirmation state in the view model (`pendingDelete`) so the dialog is purely state-driven.
- Consider `.refreshable` for manual reload; this should call the same `load` logic (idempotent).

No SwiftUI “custom hook” is needed; the equivalent is:
- A view model with methods + event handling
- Small presentation subviews for composition.

## 7. API Integration
This view is offline-first and uses the internal repository/use-case APIs.

### List (read)
- **Call**: `BrewLogRepository.fetchAllLogs()`
- **Expected response type (per UI plan)**: `[BrewLogSummaryDTO]`
- **Note about current codebase**:
  - `BrewLogRepository.fetchAllLogs()` currently returns `[BrewLog]`. To align with the UI plan and keep UI DTO-driven, either:
    - Change it to return `[BrewLogSummaryDTO]` (preferred for this screen), or
    - Add `fetchAllLogSummaries()` and keep the existing entity-returning method for other use cases.
- **Mapping**:
  - If repository returns entities: `logs.map { $0.toSummaryDTO() }`
- **Sorting**:
  - Repository already sorts by `timestamp` descending; verify most-recent-first at the repository level to keep UI simple.

### Delete (write)
- **Call**: `BrewLogUseCase.deleteLog(id: UUID) throws`
- **Response**: `Void` on success.
- **Post-delete behavior**:
  - Remove from `logs` optimistically OR reload list from repository (recommended for correctness with SwiftData/CloudKit).

## 8. User Interactions
- **View logs list (US-021)**:
  - On open, show logs in reverse chronological order.
  - If empty, show `ContentUnavailableView` describing that brew history will appear here.
- **Open log detail (US-022)**:
  - Tap a row → navigate to `LogsRoute.logDetail(id:)`.
- **Delete a log entry (US-023)**:
  - Swipe left on a row to reveal “Delete”.
  - Tap “Delete” → show confirmation dialog.
  - Confirm → delete via use case, then update list.
  - Cancel → no changes.

## 9. Conditions and Validation
Conditions verified at the UI/component level:
- **Ordering**: list must be most-recent-first (verify repository sort).
- **Row display**:
  - Always display snapshot `recipeNameAtBrew` (never fetch live recipe name for the list).
  - Always display `timestamp`.
  - Always display `rating`; render defensively if out of range.
  - Display taste tag pill only when `tasteTag != nil`.
- **Delete constraints**:
  - Deletion must require explicit confirmation (no immediate `.onDelete` without confirmation).
  - UI should prevent repeated confirm taps while deletion is in progress (`isDeleting`).

## 10. Error Handling
Potential failure scenarios and recommended handling:
- **Load fails** (SwiftData fetch throws / context issues):
  - Keep screen usable, show an inline error message and a “Retry” button.
  - Optionally log the underlying error with `OSLog`.
- **Delete fails** (save failure / repository error):
  - Show an alert/banner “Couldn’t delete log. Please try again.”
  - Keep the log visible (don’t silently remove it).
- **Log missing on delete** (deleted by sync/other device):
  - Treat as success: clear pending delete and reload list.
- **Navigation to detail for missing log**:
  - `LogDetailNavigationView` should handle missing log by showing `ContentUnavailableView("Log not found")` with a “Back” action.

## 11. Implementation Steps
1. **Introduce a DTO-driven logs list view model**
   - Add `LogsListViewModel` in `BrewGuide/BrewGuide/UI/Screens/Logs/LogsListViewModel.swift` (feature-first grouping recommended).
   - Implement `load(context:)` using `BrewLogRepository`.
2. **Align repository API with UI-plan**
   - Update `BrewLogRepository.fetchAllLogs()` to return `[BrewLogSummaryDTO]` OR add a new method returning summaries.
   - Keep sorting at the repository level.
3. **Add `BrewLogUseCase` (if missing)**
   - Implement `deleteLog(id:)` using `BrewLogRepository`.
4. **Refactor `LogsListView` to use the view model**
   - Replace direct `@Query` usage with `viewModel.logs`.
   - Add loading/error/empty states.
5. **Implement confirmed swipe-to-delete**
   - Use `.swipeActions` to request delete (sets `pendingDelete`).
   - Present `confirmationDialog` bound to `pendingDelete != nil`.
   - On confirm, call `await viewModel.confirmDelete(context:)`.
6. **Improve row rendering**
   - Replace emoji-based rating with `BrewLogRatingView` for accessibility and visual consistency.
   - Add optional taste tag pill.
7. **Verify navigation integration**
   - Ensure row navigation uses `NavigationLink(value:)` with `LogsRoute.logDetail(id:)` (already established).
   - Implement `LogDetailNavigationView` TODO to fetch the log by ID and present `LogDetailView`, with a missing-log fallback UI.
8. **Accessibility pass**
   - Provide clear accessibility labels for rating (“Rating: 4 out of 5”), taste tag, and delete action.
   - Ensure row tap targets remain large and readable with Dynamic Type.
