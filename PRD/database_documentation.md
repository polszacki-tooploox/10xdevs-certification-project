# BrewGuide SwiftData Database Documentation

## Overview

The BrewGuide database is built on **SwiftData** with **CloudKit private database** support for optional sync across devices. The database follows a local-first, offline-capable design with minimal entities focused on recipes and brew logs.

## Architecture Decisions

### CloudKit Compatibility (Day 1)
- All model properties have **default values or are optional** to satisfy CloudKit requirements
- Relationships are marked as **optional** for CloudKit compatibility
- Uses **string-backed enums** for forward compatibility and stable CloudKit storage
- Container identifier: `iCloud.com.brewguide.BrewGuide` (update to match actual bundle ID)

### Snapshot Strategy for Brew Logs
- `BrewLog` stores **brew-time parameters** (recipe name, dose, yield, temperature, grind) as snapshots
- Optional reference to `Recipe` for navigation, but historical integrity relies on snapshot data
- Logs remain accurate even if the recipe is later edited or deleted

### Computed Values (Not Persisted)
- **Ratio** (yield / dose) is computed on-the-fly, not stored
- **Scaled recipe quantities** are computed dynamically based on user input

### Validation Outside Database
- No database-layer validation or constraints
- Business rules enforced in Domain layer and repositories
- Models accept any valid data types; validation happens before persistence

## Database Schema

### Core Entities

#### 1. Recipe
Represents a structured brew recipe with method-specific defaults.

**Attributes:**
- `id: UUID` — stable identifier
- `isStarter: Bool` — true for built-in starter recipes
- `origin: RecipeOrigin` — `.starterTemplate`, `.custom`, or `.conflictedCopy`
- `method: BrewMethod` — brew method (`.v60` only in MVP)
- `name: String` — recipe name
- `defaultDose: Double` — default coffee dose in grams
- `defaultTargetYield: Double` — default target yield in grams
- `defaultWaterTemperature: Double` — default water temperature in Celsius
- `defaultGrindLabel: GrindLabel` — grind size label (`.fine`, `.medium`, `.coarse`)
- `grindTactileDescriptor: String?` — tactile grind description (e.g., "sand; slightly finer than sea salt")
- `createdAt: Date` — creation timestamp
- `modifiedAt: Date` — last modification timestamp

**Relationships:**
- `steps: [RecipeStep]?` — ordered sequence of recipe steps (1-to-many, cascade delete)

**Business Rules (enforced outside DB):**
- Starter recipes (`isStarter == true`) cannot be edited in-place or deleted
- Custom recipes can be edited and deleted
- Recipe validation: all step timers non-negative, water additions sum to target yield (±1g tolerance)

#### 2. RecipeStep
A single step in a brew recipe with instructions, timing, and water guidance.

**Attributes:**
- `stepId: UUID` — stable step identifier
- `orderIndex: Int` — position in step sequence (0-based)
- `instructionText: String` — human-readable instruction
- `timerDurationSeconds: Double?` — duration for timed steps (nil if not timed)
- `waterAmountGrams: Double?` — target water amount (nil if not applicable)
- `isCumulativeWaterTarget: Bool` — true if water amount is cumulative (e.g., "pour to 150g")

**Relationships:**
- `recipe: Recipe?` — parent recipe (owned; deleted when recipe is deleted)

**Step Ordering:**
- Steps are ordered by `orderIndex` (ascending)
- Steps should be fetched and sorted by `orderIndex` for display

#### 3. BrewLog
Lightweight log entry capturing the outcome of a completed brew (snapshot strategy).

**Attributes:**
- `id: UUID` — stable identifier
- `timestamp: Date` — brew completion timestamp
- `method: BrewMethod` — brew method used
- `recipeNameAtBrew: String` — snapshot of recipe name at brew time
- `doseGrams: Double` — snapshot of dose used
- `targetYieldGrams: Double` — snapshot of target yield
- `waterTemperatureCelsius: Double` — snapshot of water temperature
- `grindLabel: GrindLabel` — snapshot of grind label used
- `rating: Int` — user rating (1-5, required)
- `tasteTag: TasteTag?` — optional quick taste feedback
- `note: String?` — optional free-text note

**Relationships:**
- `recipe: Recipe?` — optional reference for navigation (may be nil if recipe deleted)

**Query Pattern:**
- Fetch logs in **descending order by `timestamp`** for chronological list view

## Supporting Types (Enums)

### BrewMethod
```swift
enum BrewMethod: String, Codable {
    case v60 = "v60"
}
```

### RecipeOrigin
```swift
enum RecipeOrigin: String, Codable {
    case starterTemplate = "starter_template"
    case custom = "custom"
    case conflictedCopy = "conflicted_copy"
}
```

### GrindLabel
```swift
enum GrindLabel: String, Codable {
    case fine = "fine"
    case medium = "medium"
    case coarse = "coarse"
}
```

### TasteTag
```swift
enum TasteTag: String, Codable {
    case tooBitter = "too_bitter"
    case tooSour = "too_sour"
    case tooWeak = "too_weak"
    case tooStrong = "too_strong"
}
```

**Static Adjustment Hints (per PRD 3.8.4):**
- `tooBitter` → "Try slightly coarser or cooler"
- `tooSour` → "Try slightly finer or hotter"
- `tooWeak` → "Try higher dose or finer"
- `tooStrong` → "Try lower dose or coarser"

## Persistence Configuration

### PersistenceController
- **Singleton** instance (`PersistenceController.shared`) for production
- **In-memory** constructor for testing/previews (`PersistenceController(inMemory: true)`)
- Provides `mainContext` (main actor) and `newBackgroundContext()` for async operations

### Model Container Setup
```swift
ModelContainer(
    for: schema,
    configurations: [
        ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.brewguide.BrewGuide")
        )
    ]
)
```

### First Launch Seeding
- `DatabaseSeeder.seedStarterRecipesIfNeeded(in:)` creates V60 starter recipe on first launch
- Called from `BrewGuideApp.init()`
- Idempotent: checks for existing starter before seeding

## Common Query Patterns

### Fetch All Recipes by Method
```swift
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.method == .v60 },
    sortBy: [SortDescriptor(\.isStarter, order: .reverse), SortDescriptor(\.name)]
)
let recipes = try context.fetch(descriptor)
```

### Fetch Brew Logs (Chronological)
```swift
let descriptor = FetchDescriptor<BrewLog>(
    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
)
let logs = try context.fetch(descriptor)
```

### Fetch Starter Recipe
```swift
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.isStarter == true && $0.method == .v60 }
)
let starter = try context.fetch(descriptor).first
```

### Fetch Recipe with Steps (Ordered)
```swift
// Recipe relationship automatically loads steps
let recipe = // ... fetched recipe
let orderedSteps = recipe.steps?.sorted(by: { $0.orderIndex < $1.orderIndex }) ?? []
```

## Data Lifecycle

### Recipe Duplication Flow
1. Fetch source recipe (typically starter)
2. Create new `Recipe` with `origin: .custom`, new `id`, copy all defaults
3. Clone all `RecipeStep` objects with new `stepId` values, same `orderIndex`
4. Assign cloned steps to new recipe
5. Insert recipe and steps into context, save

### Brew Completion Flow
1. User completes brew with adjusted parameters (dose, yield, temperature, grind)
2. Create `BrewLog` with:
   - Snapshot of all brew-time parameters
   - Reference to `recipe` (optional, for navigation)
   - Required `rating` (1-5)
   - Optional `tasteTag` and `note`
3. Insert into context, save

### Recipe Deletion
- Cascade delete removes all associated `RecipeStep` objects
- `BrewLog` references to deleted recipe become `nil` (logs are preserved)
- Starter recipes cannot be deleted (enforced in business layer)

## CloudKit Sync Behavior

### Sync Scope (MVP)
- **Recipes** (custom only; starters are seeded locally on each device)
- **Brew logs**
- **NOT synced**: user preferences (last selected recipe, sync enabled flag, Apple user ID)

### Conflict Resolution (Deferred in MVP)
- Conflicts are "ignored" in MVP (behavior undefined)
- PRD specifies eventual behavior: create conflicted copy with `origin: .conflictedCopy`
- Logs are append-only; duplicates allowed

### Offline Support
- All operations work offline
- Changes queue locally and sync when connectivity returns
- No blocking on sync operations

## Security & Privacy

### Isolation
- CloudKit private database provides **per-user isolation**
- No cross-user data access
- No separate `UserAccount` entity persisted

### Data Deletion
- User can request data deletion via settings (implementation outside database layer)
- Deleting local data: clear all custom recipes and logs via context
- Deleting synced data: CloudKit deletion request (details outside MVP scope)

## Unresolved Items (Per Planning Doc)

1. **User preferences storage** (`appleUserId`, `syncEnabled`, `lastSelectedRecipeId`) — likely `UserDefaults` or Keychain, not SwiftData
2. **Conflict resolution implementation** — deferred; "ignored" behavior needs definition
3. **Step field optionality** — current model allows flexibility; validation in Domain layer
4. **Note max length** — not enforced in DB; validation at input/save time (suggest 280 characters per PRD)

## Migration Strategy (Future)

- SwiftData handles schema migrations automatically for compatible changes
- Breaking changes require explicit migration plans
- Version schema before production release for safe migrations

## Testing Strategy

### Unit Testing
- Use `PersistenceController(inMemory: true)` for isolated tests
- Test repositories and business rules separately from DB layer
- Validate scaling, rounding, and validation logic in Domain tests

### Preview Support
- `PersistenceController.preview` provides seeded in-memory container
- Sample data includes starter recipe, custom recipe, and 3 brew logs
- Use `.modelContainer(PersistenceController.preview.container)` in SwiftUI previews

## Performance Considerations

### Indexing (MVP)
- Primary queries: `BrewLog.timestamp` (descending), `Recipe.method`
- SwiftData automatically indexes properties used in predicates
- No explicit compound indexes needed for MVP scale

### Scalability
- Brew logs can grow large over time
- List views should use snapshot fields (no joins needed)
- Consider pagination for log list if performance degrades (future)

## References

- PRD: `.ai/prd.md`
- Tech Stack: `.ai/tech-stack.md`
- Planning Summary: `PRD/database_planning_summary.md`
- SwiftData Docs: [Context7 SwiftData](https://context7.com/docs)
- CloudKit Integration: [Apple Developer - SwiftData with CloudKit](https://developer.apple.com/documentation/swiftdata/adding-cloudkit-capabilities)
