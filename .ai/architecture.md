## Goals
- **Ship fastest** on newest iOS only.
- **Offline-first**: brewing + logging always work without network.
- **Sync is optional**: only after Sign in with Apple; opportunistic background sync when online.
- **Kitchen-proof UX**: large primary actions, minimal typing, guarded destructive actions.
- **Accessibility**: Dynamic Type + VoiceOver supported on core brew flow screens.

## Architectural style
- **Domain-first MVVM**
  - **Domain layer**: pure rules and state transitions (no SwiftUI, no persistence).
  - **UI layer**: SwiftUI screens + view models using Observation.
  - **Persistence layer**: SwiftData + repositories.
  - **Sync layer**: CloudKit sync service (runs only when signed in and enabled).

## Key design decisions
- **Brew flow as a state machine** (single source of truth for step progression + timer state).
- **Business rules never live inside SwiftUI views** (views render state; view models orchestrate).
- **Local-first data access** via repositories; sync reconciles in background.

## Suggested project structure
- `BrewGuideApp/`
  - `App/` (entry point, dependency wiring)
  - `Domain/` (rules, state machine, shared types)
  - `UI/`
    - `Screens/`
    - `Components/`
    - `Accessibility/`
  - `Persistence/` (SwiftData models + repositories)
  - `Sync/` (CloudKit + auth-gated sync logic)
  - `Support/` (formatters, extensions, logging)

## Runtime behaviors (high level)
- **App launch**: open recipe selection/confirm flow (last-selected recipe preselected).
- **Before brew start**: user can edit inputs; scaling/guardrails apply.
- **After brew start**: inputs lock; user progresses via Next/Pause/Resume; Restart is guarded.
- **Post-brew**: user saves or discards; logs are viewable and deletable.
- **Settings**: sign in/out, sync toggle, delete synced data entry point.

