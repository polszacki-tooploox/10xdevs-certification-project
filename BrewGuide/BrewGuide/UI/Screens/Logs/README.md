# Logs Feature Implementation

This directory contains the implementation of the Logs tab, which displays a chronological history of completed brews and allows users to view details and delete entries.

## Feature Overview

The Logs feature provides:
- **Chronological list** of brew logs (most recent first)
- **Swipe-to-delete** with confirmation dialog
- **Navigation** to detailed log view
- **Pull-to-refresh** capability
- **Error handling** with retry
- **Empty state** for new users
- **Offline-first** persistence via SwiftData

## Architecture

### Domain-First MVVM Pattern

```
┌─────────────────────────────────────────────────────┐
│                   UI Layer                          │
│  ┌───────────────┐        ┌──────────────────────┐ │
│  │ LogsListView  │───────▶│ LogsListViewModel    │ │
│  │ (Rendering)   │        │ (State Management)   │ │
│  └───────────────┘        └──────────────────────┘ │
└─────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────┐
│                 Domain Layer                        │
│  ┌──────────────────────────────────────────────┐  │
│  │ BrewLogUseCase                               │  │
│  │ (Business Logic: fetch, delete)              │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────┐
│              Persistence Layer                      │
│  ┌──────────────────────────────────────────────┐  │
│  │ BrewLogRepository                            │  │
│  │ (SwiftData abstraction)                      │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## File Structure

```
BrewGuide/
├── Domain/
│   ├── BrewLogUseCase.swift          # Business logic for logs
│   └── DTOs/
│       ├── BrewLogDTOs.swift         # BrewLogSummaryDTO, BrewLogDetailDTO
│       └── MappingExtensions.swift    # BrewLog.toSummaryDTO()
│
├── UI/
│   ├── Screens/
│   │   ├── LogsListView.swift        # Main list view + components
│   │   ├── LogDetailView.swift       # Detail view (separate file)
│   │   └── Logs/
│   │       └── LogsListViewModel.swift  # View model
│   │
│   └── Components/
│       ├── BrewLogRatingView.swift   # Accessible star rating display
│       └── TasteTagPill.swift         # Taste tag indicator
│
└── Persistence/
    ├── Models/
    │   └── BrewLog.swift             # SwiftData entity
    └── Repositories/
        └── BrewLogRepository.swift   # Data access layer
```

## Component Responsibilities

### LogsListView (Container)
- **Responsibility**: Own view model lifecycle, wire dependencies
- **State**: `@State private var viewModel`
- **Dependencies**: `@Environment(\.modelContext)`
- **Presentation**: Confirmation dialog for delete
- **Lifecycle**: `.task` for initial load, `.refreshable` for reload

### LogsListViewModel (State Management)
- **Responsibility**: Manage loading, error, and delete states
- **State Properties**:
  - `logs: [BrewLogSummaryDTO]` - Current list
  - `isLoading: Bool` - Loading indicator
  - `errorMessage: String?` - Error display
  - `pendingDelete: BrewLogSummaryDTO?` - Delete confirmation
  - `isDeleting: Bool` - Prevent double-tap
- **Methods**:
  - `load(context:)` - Fetch logs
  - `requestDelete(id:)` - Initiate delete
  - `confirmDelete(context:)` - Execute delete
  - `cancelDelete()` - Cancel delete

### LogsListScreen (Pure Renderer)
- **Responsibility**: Render UI based on props
- **Props**: `logs`, `isLoading`, `errorMessage`, event handlers
- **Rendering**: List with empty/error/loading states
- **Events**: Emits user actions via callbacks

### BrewLogRow (Row Container)
- **Responsibility**: Navigation and swipe actions
- **Features**:
  - `NavigationLink` with `LogsRoute.logDetail(id:)`
  - `.swipeActions` with destructive delete
- **Props**: `log`, `onRequestDelete`

### BrewLogRowContent (Visual Layout)
- **Responsibility**: Display log summary
- **Layout**:
  - Recipe name (headline)
  - Timestamp (formatted)
  - Taste tag pill (optional)
  - Rating stars (right-aligned)
- **Props**: `log`

### BrewLogUseCase (Business Logic)
- **Responsibility**: Coordinate log operations
- **Methods**:
  - `deleteLog(id:)` - Delete log by ID
  - `fetchAllLogSummaries()` - Get DTOs sorted by timestamp
- **Dependencies**: `BrewLogRepository`

## Data Flow

### Load Flow
```
1. LogsListView appears
2. .task triggers viewModel.load(context:)
3. ViewModel calls useCase.fetchAllLogSummaries()
4. UseCase calls repository.fetchAllLogs()
5. Repository queries SwiftData
6. Entities mapped to DTOs
7. ViewModel updates logs array
8. View re-renders with data
```

### Delete Flow
```
1. User swipes left on row
2. User taps "Delete"
3. ViewModel.requestDelete(id:) sets pendingDelete
4. Confirmation dialog appears
5. User confirms
6. ViewModel.confirmDelete(context:) called
7. UseCase.deleteLog(id:) executes
8. Repository deletes entity and saves
9. ViewModel removes from logs array
10. View re-renders without deleted log
```

## Key Design Decisions

### 1. DTO-Driven UI
**Decision**: Use `BrewLogSummaryDTO` instead of live `BrewLog` entities

**Rationale**:
- Avoids unnecessary SwiftData subscriptions in list
- Uses snapshot fields (recipeNameAtBrew) for historical accuracy
- Simplifies state management (value types)
- Better testability (no model context needed)

### 2. Two-Step Delete
**Decision**: Swipe shows action, tap shows confirmation

**Rationale**:
- Prevents accidental data loss
- Follows iOS destructive action patterns
- PRD requirement (US-023)
- User can cancel before committing

### 3. Use Case Layer
**Decision**: Introduce `BrewLogUseCase` between UI and repository

**Rationale**:
- Encapsulates business logic (e.g., "missing log is OK")
- Keeps view model focused on UI state
- Testable without SwiftData context
- Consistent with project architecture

### 4. Pure Renderer Pattern
**Decision**: Separate `LogsListScreen` from `LogsListView`

**Rationale**:
- Testable rendering logic
- Clear separation: state vs. presentation
- Easier preview configurations
- Follows React/Flutter patterns

### 5. Accessibility-First Rating
**Decision**: Star icons with accessibility labels, not emoji

**Rationale**:
- VoiceOver reads properly ("Rating: 4 out of 5")
- Scalable with Dynamic Type
- Consistent visual language
- Professional appearance

## Testing Strategy

### Unit Tests (BrewGuideTests/)
- `LogsListViewModelTests.swift` - State management logic
- `BrewLogUseCaseTests.swift` - Business rules

### Test Coverage
- ✅ Load success/empty/error
- ✅ Delete request/confirm/cancel
- ✅ Reload functionality
- ✅ Invalid ID handling
- ✅ Ordering verification

### Manual Testing
See `LOGS_LIST_IMPLEMENTATION_VERIFICATION.md` for detailed scenarios.

## Error Handling

### Load Failures
- **Display**: Inline error banner
- **Message**: "Failed to load brew logs. Please try again."
- **Action**: Retry button re-runs load
- **Logging**: OSLog with error details

### Delete Failures
- **Display**: Error message in view model
- **Message**: "Couldn't delete log. Please try again."
- **State**: Log remains visible, can retry
- **Logging**: OSLog with error details

### Missing Logs (Navigation)
- **Display**: ContentUnavailableView
- **Message**: "Log Not Found"
- **Cause**: Log deleted by sync/other device
- **Action**: Back button returns to list

## Performance Considerations

### Memory
- DTOs instead of entities (no live subscriptions)
- View model released when view dismissed
- No retain cycles (escaping closures handled correctly)

### Rendering
- Stable list identity (UUID-based)
- Minimal re-renders (state-driven only)
- Efficient ForEach with Identifiable

### Database
- Single fetch for entire list
- Sorting at repository level
- No N+1 queries
- Mapping done once at load

## Accessibility

### VoiceOver Support
- Rating: "Rating: N out of 5"
- Swipe actions: "Delete" with destructive role
- Empty state: Descriptive labels
- Navigation: Proper hints

### Dynamic Type
- All text scales with system settings
- No forced font sizes
- Layout adapts to larger text

### Touch Targets
- Full-row navigation (44pt minimum)
- Swipe action buttons (standard iOS size)

## Future Enhancements (Not in Scope)

These features are not implemented but could be added:
- Advanced filtering (by method, rating, date range)
- Search functionality
- Batch delete operations
- Export/share logs
- Statistics/analytics
- Sorting options
- Log editing

## Integration with Other Features

### Recipe Navigation
- `LogDetailView` can navigate to recipe if present
- Uses `coordinator.recipesPath.append(RecipesRoute.recipeDetail(id:))`
- Switches to Recipes tab automatically

### CloudKit Sync
- Deletions propagate automatically when enabled
- No explicit sync UI needed
- Repository layer handles sync reconciliation

### Brew Session
- New logs created by `PostBrewView` after brew completion
- Appear automatically in list (or after pull-to-refresh)

## Troubleshooting

### Logs not appearing after brew
- **Cause**: List needs reload
- **Solution**: Pull to refresh

### Delete confirmation not showing
- **Check**: `pendingDelete` is set in view model
- **Check**: `.confirmationDialog` binding is correct

### Rating shows emoji instead of stars
- **Cause**: Using old implementation
- **Solution**: Ensure `BrewLogRatingView` is used

### Navigation to detail fails
- **Check**: `LogDetailNavigationView` is implemented in `AppRootView`
- **Check**: Route is registered in navigation destination

## Related Documentation

- `LOGS_LIST_IMPLEMENTATION_SUMMARY.md` - Detailed implementation summary
- `LOGS_LIST_IMPLEMENTATION_VERIFICATION.md` - Verification checklist
- `.ai/LogsListView-view-implementation-plan.md` - Original plan
- `VIEWS_IMPLEMENTATION_CHECKLIST.md` - Project-wide view status

## Contact / Maintenance

**Last Updated**: January 30, 2026  
**Implemented By**: AI Implementation Agent  
**Architecture**: Domain-First MVVM  
**Status**: ✅ Complete and verified
