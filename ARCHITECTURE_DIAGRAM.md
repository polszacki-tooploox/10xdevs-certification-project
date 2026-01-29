# AppRootView Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              BrewGuideApp (Entry)                               │
│                                      ↓                                          │
│                              AppRootView (Root)                                 │
│                                      │                                          │
│                         ┌────────────┼────────────┐                            │
│                         │            │            │                             │
│              ┌──────────▼─────┐  ┌──▼─────────┐  ┌───▼────────┐              │
│              │  Recipes Tab   │  │ Logs Tab   │  │ Settings   │               │
│              │                │  │            │  │    Tab     │               │
│              │ NavigationStack│  │Navigation  │  │Navigation  │               │
│              │                │  │   Stack    │  │   Stack    │               │
│              └────────┬───────┘  └──────┬─────┘  └─────┬──────┘              │
│                       │                 │              │                        │
│              ┌────────▼──────────┐  ┌──▼─────────┐  ┌─▼────────────┐         │
│              │ ConfirmInputsView │  │LogsListView│  │ SettingsView │          │
│              │  (Tab Root)       │  │(Tab Root)  │  │  (Tab Root)  │          │
│              └────────┬──────────┘  └──────┬─────┘  └──────┬───────┘         │
│                       │                    │               │                   │
│             ┌─────────┼─────────┐          │               │                   │
│             │         │         │          │               │                   │
│   ┌─────────▼──┐  ┌──▼────┐  ┌─▼──────┐  │    ┌──────────▼──────┐           │
│   │RecipeList  │  │Recipe │  │Recipe  │  │    │DataDeletionRequest│          │
│   │    View    │  │Detail │  │ Edit   │  │    │      View         │           │
│   └────────────┘  └───────┘  └────────┘  │    └───────────────────┘          │
│                                           │                                     │
│                                    ┌──────▼─────┐                              │
│                                    │LogDetailView│                             │
│                                    └────────────┘                              │
└────────────────────────────────────────────────────────────────────────────────┘

                                        ║
                         ═══════════════╝══════════════
                         ║  fullScreenCover(item:)    ║
                         ║  Centralized Presentation  ║
                         ╚═════════════╦══════════════╝
                                       ║
                    ┌──────────────────▼──────────────────┐
                    │    BrewSessionFlowView (Modal)       │
                    │                                      │
                    │  ┌─────────────────────────────┐    │
                    │  │  Step Progression UI        │    │
                    │  │  - Timer Display            │    │
                    │  │  - Step Cards               │    │
                    │  │  - Progress Bar             │    │
                    │  │  - Control Buttons          │    │
                    │  └─────────────┬───────────────┘    │
                    │                │                     │
                    │                │ (on completion)     │
                    │                ▼                     │
                    │  ┌─────────────────────────────┐    │
                    │  │    PostBrewView             │    │
                    │  │    - Rating (1-5 stars)     │    │
                    │  │    - Taste Tags             │    │
                    │  │    - Notes                  │    │
                    │  │    - Save / Discard         │    │
                    │  └─────────────────────────────┘    │
                    └─────────────────────────────────────┘


═════════════════════════════════════════════════════════════════════════════════
                           STATE MANAGEMENT LAYER
═════════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│                        AppRootCoordinator (@Observable)                      │
│                                                                              │
│  selectedTab: AppTab                          ┌─────────────────────────┐   │
│  recipesPath: NavigationPath                  │ Injected via            │   │
│  logsPath: NavigationPath                     │ .environment(coordinator)│  │
│  settingsPath: NavigationPath                 │                         │   │
│  activeBrewSession: BrewSessionPresentation?  │ Available to all child  │   │
│                                               │ views                   │   │
│  + presentBrewSession(plan:)                  └─────────────────────────┘   │
│  + dismissBrewSession()                                                      │
│  + resetToRoot(tab:)                                                         │
└─────────────────────────────────────────────────────────────────────────────┘


═════════════════════════════════════════════════════════════════════════════════
                            DOMAIN / BUSINESS LOGIC
═════════════════════════════════════════════════════════════════════════════════

┌──────────────────────┐         ┌──────────────────────┐
│ BrewSessionUseCase   │         │  PreferencesStore    │
│                      │         │                      │
│ + createPlan(inputs) │         │ + lastSelectedRecipeId│
│ + createInputs(recipe)│        │ + resetAll()         │
└──────────┬───────────┘         └──────────────────────┘
           │
           ▼
┌──────────────────────┐         ┌──────────────────────┐
│  RecipeRepository    │         │  BrewLogRepository   │
│                      │         │                      │
│ + fetchRecipe(id)    │         │ + saveLog(log)       │
│ + fetchAll()         │         │ + deleteLog(id)      │
└──────────────────────┘         └──────────────────────┘
           │                              │
           └──────────┬───────────────────┘
                      ▼
           ┌──────────────────────┐
           │     SwiftData        │
           │   ModelContext       │
           └──────────────────────┘


═════════════════════════════════════════════════════════════════════════════════
                                DATA FLOW EXAMPLE
═════════════════════════════════════════════════════════════════════════════════

1. USER STARTS BREW:
   ConfirmInputsView → "Start Brewing" button tapped
   ├─ ConfirmInputsViewModel.startBrew()
   │  ├─ BrewSessionUseCase.createPlan(inputs)
   │  │  ├─ RecipeRepository.fetchRecipe(id)
   │  │  │  └─ SwiftData fetch
   │  │  └─ Returns BrewPlan (scaled steps)
   │  └─ AppRootCoordinator.presentBrewSession(plan)
   │     └─ Sets activeBrewSession
   └─ AppRootView observes change → presents BrewSessionFlowView

2. USER COMPLETES BREW:
   BrewSessionFlowView → "Finish" on last step
   ├─ Shows PostBrewView
   └─ User rates and saves
      ├─ BrewSessionViewModel.saveBrew(rating, tag, notes)
      │  ├─ Creates BrewLog
      │  └─ BrewLogRepository.saveLog()
      │     └─ SwiftData insert
      └─ Coordinator.dismissBrewSession()
         └─ Returns to ConfirmInputsView

3. USER SWITCHES TABS:
   AppRootView → TabView selection changes
   ├─ Coordinator.selectedTab = .logs
   └─ NavigationStack preserves state
      ├─ recipesPath unchanged (scroll position preserved)
      ├─ logsPath loaded with previous state
      └─ Tab content re-rendered


═════════════════════════════════════════════════════════════════════════════════
                            KEY ARCHITECTURAL DECISIONS
═════════════════════════════════════════════════════════════════════════════════

✅ INDEPENDENT TAB NAVIGATION
   - Each tab has its own NavigationPath
   - State preserved when switching tabs
   - No shared navigation state

✅ CENTRALIZED BREW MODAL
   - Presented from AppRootView (not from tab)
   - Covers entire app (prevents background interaction)
   - Single source of truth (activeBrewSession)

✅ COORDINATOR PATTERN
   - AppRootCoordinator owns all app-level navigation
   - Children send intents via coordinator
   - No direct navigation from child views

✅ DOMAIN-FIRST MVVM
   - Views are dumb (render only)
   - View models orchestrate logic
   - Use cases contain business rules
   - Repositories abstract persistence

✅ TYPE-SAFE NAVIGATION
   - Route enums for each tab (RecipesRoute, LogsRoute, etc.)
   - navigationDestination(for:) with specific types
   - Compile-time safety for navigation

✅ UNIDIRECTIONAL DATA FLOW
   - User action → View Model → Use Case → Repository → SwiftData
   - State changes flow back through @Observable
   - SwiftUI automatically re-renders
```
