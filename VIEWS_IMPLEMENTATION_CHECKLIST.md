# BrewGuide — Views Implementation Checklist

Source of truth: `.ai/ui-plan.md` + `.ai/prd.md`, compared against the current SwiftUI code in `BrewGuide/BrewGuide/UI/`.

**Status legend**
- **Implemented**: Exists as a real screen in the current app shell.
- **Placeholder**: Exists but is explicitly marked TODO / demo-only / missing required MVP behavior.
- **Missing**: Not present in codebase as a view/screen yet.

Last updated: 2026-01-30

---

## App Shell

| View | PRD/UI plan | Status | Current location | Notes |
|---|---:|---|---|---|
| `AppRootView` | Yes | **Implemented** | `BrewGuide/BrewGuide/UI/AppShell/AppRootView.swift` | 3-tab shell + per-tab `NavigationStack` + brew full-screen modal host. |
| `AppRootCoordinator` (supporting type) | Yes (architecture) | **Implemented** | `BrewGuide/BrewGuide/UI/AppShell/AppRootCoordinator.swift` | Navigation + modal state owner (not a screen). |

---

## Recipes Tab (Brew entry + recipe library)

| View | PRD/UI plan | Status | Current location | Notes |
|---|---:|---|---|---|
| `ConfirmInputsView` | Yes | **Implemented** | `BrewGuide/BrewGuide/UI/Screens/ConfirmInputsView.swift` | Recipes tab root in `AppRootView`. |
| `RecipeListView` | Yes | **Implemented** (partial) | `BrewGuide/BrewGuide/UI/Screens/RecipeListView.swift` | "Add Recipe" button is a TODO; UI plan emphasizes duplicate-from-starter path. |
| `RecipeDetailView` | Yes | **Placeholder** | `BrewGuide/BrewGuide/UI/Screens/ContentView.swift` | Marked "Placeholder Detail Views"; currently used via `AppRootView` destination wrapper. Needs full planned behavior (badges, "Use this recipe", duplicate/edit/delete rules, steps UX). |
| `RecipeEditView` (custom-only editor) | Yes | **Placeholder** | `BrewGuide/BrewGuide/UI/AppShell/AppRootView.swift` (private `RecipeEditView`) | Just renders TODO text; should become a real `UI/Screens/RecipeEditView.swift` with validation UX. |
| `RecipeCreateView` (optional) | Optional | **Missing** | — | PRD doesn't require create-from-scratch for MVP (duplication is the MVP path), but `RecipeListView` currently exposes "Add Recipe". Decide whether to remove/disable or implement. |

---

## Brew Flow (Full-screen modal)

| View | PRD/UI plan | Status | Current location | Notes |
|---|---:|---|---|---|
| `BrewSessionFlowView` | Yes | **Implemented** | `BrewGuide/BrewGuide/UI/Screens/BrewSessionFlowView.swift` | Full-screen modal from `AppRootView`. |
| `PostBrewView` | Yes | **Implemented** | `BrewGuide/BrewGuide/UI/Screens/PostBrewView.swift` | Post-brew rating/taste tag/note + save/discard. |

---

## Logs Tab

| View | PRD/UI plan | Status | Current location | Notes |
|---|---:|---|---|---|
| `LogsListView` | Yes | **Implemented** (enhanced) | `BrewGuide/BrewGuide/UI/Screens/LogsListView.swift` | Logs tab root with full MVVM architecture, DTO-driven rendering, swipe-to-delete with confirmation, error handling, and pull-to-refresh. Uses `LogsListViewModel` and `BrewLogUseCase`. Includes accessible rating display and taste tag pills. See `LOGS_LIST_IMPLEMENTATION_SUMMARY.md` for details. |
| `LogDetailView` | Yes | **Implemented** | `BrewGuide/BrewGuide/UI/Screens/LogDetailView.swift` | Displays full log details with delete confirmation and optional recipe navigation. Conforms to PRD US-022 and US-023. |

---

## Settings Tab

| View | PRD/UI plan | Status | Current location | Notes |
|---|---:|---|---|---|
| `SettingsView` | Yes | **Implemented** (partial) | `BrewGuide/BrewGuide/UI/Screens/SettingsView.swift` | Sign-in + sync are explicit TODOs; "Sync Status" button implies an unplanned extra screen. UI plan expects sync status + retry in Settings itself. |
| `DataDeletionRequestView` | Yes | **Implemented** (scope mismatch) | `BrewGuide/BrewGuide/UI/Screens/DataDeletionRequestView.swift` | UI plan/PRD describe *synced data deletion request*; current implementation appears to delete local app data (recipes/logs/preferences). Screen exists, but behavior may need to change once sync exists. |

---

## Shared UI Components Mentioned in `ui-plan.md` (recommended extraction)

These are described as "conceptual, not implementation commitments". Some have been implemented as reusable components:

**Implemented:**
- `BrewLogRatingView` - Accessible star rating display (1-5 stars)
- `TasteTagPill` - Compact taste tag indicator pill

**Not yet implemented:**
- `PrimaryActionButton`
- `InlineErrorText` / `FieldErrorState`
- `ValidationSummaryBanner`
- `RangeWarningBanner` / `WarningList`
- `NumericInputRow`
- `GrindLabelSelector`
- `RecipeBadgeSet` (Starter / Invalid / Conflicted Copy)
- `PressAndHoldConfirmButton`
- `ExitConfirmationDialog`
- `StepCard`
- `CountdownTimerView`
- `LogSummaryRow`
- `SyncStatusRow`

---

## Legacy / Dev-only Screens

| View | Status | Current location | Notes |
|---|---|---|---|
| `ContentView` | **Dev-only** | `BrewGuide/BrewGuide/UI/Screens/ContentView.swift` | Not used by `BrewGuideApp` (which launches `AppRootView`). Currently houses placeholder `RecipeDetailView` and `BrewLogDetailView` that are also used by navigation destinations. Once proper `RecipeDetailView`/`LogDetailView` are implemented in dedicated files, this can likely be removed or repurposed. |

