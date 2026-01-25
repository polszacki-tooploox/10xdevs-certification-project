# BrewGuide Persistence Layer

This directory contains the complete SwiftData + CloudKit persistence implementation for BrewGuide.

## Directory Structure

```
Persistence/
├── Models/                      # SwiftData entity models and supporting enums
│   ├── BrewLog.swift           # Brew log entry (snapshot strategy)
│   ├── Recipe.swift            # Structured brew recipe
│   ├── RecipeStep.swift        # Individual recipe step
│   ├── BrewMethod.swift        # Enum: brew methods (.v60)
│   ├── RecipeOrigin.swift      # Enum: recipe origin types
│   ├── GrindLabel.swift        # Enum: grind size labels
│   └── TasteTag.swift          # Enum: taste feedback tags
├── Repositories/               # Data access layer abstractions
│   ├── Repository.swift        # Base repository protocol and implementation
│   ├── RecipeRepository.swift  # Recipe-specific operations
│   └── BrewLogRepository.swift # Brew log-specific operations
├── PersistenceController.swift # ModelContainer configuration and setup
└── DatabaseSeeder.swift        # First-launch data seeding
```

## Quick Start

### 1. Accessing the Database

The app uses a singleton `PersistenceController` for production:

```swift
@MainActor
let controller = PersistenceController.shared
let context = controller.mainContext
```

For previews and testing, use an in-memory instance:

```swift
@MainActor
let previewController = PersistenceController.preview // Pre-seeded with sample data
let testController = PersistenceController(inMemory: true) // Empty
```

### 2. Using Repositories

Repositories provide type-safe, validated access to entities:

```swift
@MainActor
let recipeRepo = RecipeRepository(context: context)
let logRepo = BrewLogRepository(context: context)
```

### 3. Common Operations

#### Fetch Recipes

```swift
// Get all V60 recipes (starters first, then custom alphabetically)
let recipes = try recipeRepo.fetchRecipes(for: .v60)

// Get just the V60 starter recipe
let starter = try recipeRepo.fetchStarterRecipe(for: .v60)

// Get a specific recipe by ID
let recipe = try recipeRepo.fetchRecipe(byId: someUUID)
```

#### Duplicate a Recipe

```swift
// Duplicate the starter to create a custom recipe
let customRecipe = try recipeRepo.duplicate(starter)
customRecipe.name = "My Custom V60"
try recipeRepo.save()
```

#### Validate and Save a Recipe

```swift
// Validate before saving
let errors = recipeRepo.validate(customRecipe)
guard errors.isEmpty else {
    // Show validation errors to user
    return
}

// Save changes
try recipeRepo.save()
```

#### Delete a Custom Recipe

```swift
// Starter recipes cannot be deleted; this throws an error
try recipeRepo.deleteCustomRecipe(customRecipe)
try recipeRepo.save()
```

#### Create a Brew Log

```swift
// Create log with snapshot of brew parameters
let log = BrewLog(
    method: .v60,
    recipeNameAtBrew: recipe.name,
    doseGrams: 15.0,
    targetYieldGrams: 250.0,
    waterTemperatureCelsius: 94.0,
    grindLabel: .medium,
    rating: 4,
    tasteTag: nil,
    note: "Great balance",
    recipe: recipe // Optional reference for navigation
)

// Validate before saving
let errors = logRepo.validate(log)
guard errors.isEmpty else {
    // Show validation errors
    return
}

logRepo.insert(log)
try logRepo.save()
```

#### Fetch Brew Logs

```swift
// Get all logs (most recent first)
let allLogs = try logRepo.fetchAllLogs()

// Get recent logs only
let recentLogs = try logRepo.fetchRecentLogs(limit: 10)

// Get logs for a specific recipe
let recipeLogs = try logRepo.fetchLogs(forRecipeId: recipe.id)

// Calculate average rating
let avgRating = try logRepo.calculateAverageRating()
```

## Key Design Patterns

### 1. Snapshot Strategy (BrewLog)

Brew logs store **snapshots** of all brew parameters at brew time:
- `recipeNameAtBrew` (not a live reference to recipe name)
- `doseGrams`, `targetYieldGrams`, `waterTemperatureCelsius`, `grindLabel`

This ensures historical accuracy even if the recipe is edited or deleted later.

The optional `recipe` relationship is for **navigation only** (e.g., "brew this recipe again").

### 2. Repository Pattern

Repositories abstract SwiftData operations and enforce business rules:
- **Validation** before persistence
- **Type-safe queries** with common fetch patterns
- **Business logic** (e.g., can't delete starter recipes, duplicate creates custom recipes)

Domain and UI layers interact with repositories, not directly with ModelContext.

### 3. CloudKit Compatibility

All models follow CloudKit best practices:
- Default values or optional properties
- Optional relationships
- String-backed enums for stable storage

CloudKit sync is **optional** and enabled only after user signs in with Apple.

### 4. Local-First Design

- App works fully offline
- Changes queue and sync when connectivity returns
- No blocking on sync operations

## Validation Rules

### Recipe Validation (enforced in `RecipeRepository.validate(_:)`)

- Name must not be empty
- Dose > 0
- Target yield > 0
- At least one step
- All timer durations ≥ 0
- Sum of water additions ≈ target yield (±1g tolerance)

### Brew Log Validation (enforced in `BrewLogRepository.validate(_:)`)

- Rating must be 1–5
- Recipe name snapshot must not be empty
- Dose > 0
- Target yield > 0
- Note ≤ 280 characters (if present)

## First-Launch Seeding

The V60 starter recipe is seeded automatically on first launch:

```swift
DatabaseSeeder.seedStarterRecipesIfNeeded(in: context)
```

Called from `BrewGuideApp.init()`. Idempotent: checks for existing starter before seeding.

Starter recipe details (from PRD 3.5):
- **Dose:** 15g
- **Yield:** 250g (ratio 1:16.7)
- **Temperature:** 94°C
- **Grind:** medium ("sand; slightly finer than sea salt")
- **Steps:** 6 steps (rinse, add coffee, bloom 45s, pour to 150g by 1:30, pour to 250g by 2:15, drawdown to 3:00–3:30)

## SwiftUI Integration

### App-Level Setup

```swift
@main
struct BrewGuideApp: App {
    @MainActor
    private let persistenceController = PersistenceController.shared

    init() {
        Task { @MainActor in
            DatabaseSeeder.seedStarterRecipesIfNeeded(
                in: persistenceController.mainContext
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistenceController.container)
    }
}
```

### View-Level Queries

Use `@Query` for reactive data:

```swift
struct RecipeListView: View {
    @Query(
        filter: #Predicate<Recipe> { $0.method == .v60 },
        sort: [
            SortDescriptor(\Recipe.isStarter, order: .reverse),
            SortDescriptor(\Recipe.name)
        ]
    )
    private var recipes: [Recipe]
    
    var body: some View {
        List(recipes) { recipe in
            Text(recipe.name)
        }
    }
}
```

### Preview Support

```swift
#Preview {
    RecipeListView()
        .modelContainer(PersistenceController.preview.container)
}
```

## Testing

### Unit Tests (with In-Memory Container)

```swift
@Test @MainActor
func testRecipeDuplication() async throws {
    let controller = PersistenceController(inMemory: true)
    let context = controller.mainContext
    let repo = RecipeRepository(context: context)
    
    // Seed starter
    DatabaseSeeder.seedStarterRecipesIfNeeded(in: context)
    
    // Fetch and duplicate
    let starter = try repo.fetchStarterRecipe(for: .v60)!
    let custom = try repo.duplicate(starter)
    
    #expect(custom.origin == .custom)
    #expect(custom.isStarter == false)
    #expect(custom.defaultDose == starter.defaultDose)
}
```

## CloudKit Configuration

**Important:** Update the CloudKit container identifier in `PersistenceController.swift`:

```swift
cloudKitDatabase: .private("iCloud.com.brewguide.BrewGuide")
```

Replace `com.brewguide.BrewGuide` with your actual bundle identifier.

Also ensure:
1. CloudKit capability is enabled in Xcode project
2. iCloud container is configured in Signing & Capabilities
3. Container identifier matches across Xcode and code

## Performance Notes

- Brew logs can grow large; consider pagination for lists if needed
- Snapshot strategy avoids joins; log list views are fast
- SwiftData automatically indexes predicate fields
- No explicit compound indexes needed for MVP scale

## Future Considerations

### Conflict Resolution

Currently deferred ("ignored" in MVP). Future implementation should:
- Detect conflicts during sync
- Create a `conflictedCopy` recipe with `origin: .conflictedCopy`
- Logs are append-only (duplicates allowed)

### Migration Strategy

- SwiftData handles compatible schema changes automatically
- Breaking changes require explicit migration plan
- Version schema in production for safe migrations

### Additional Queries

As features expand, add repository methods for:
- Search/filter recipes by name
- Filter logs by rating, taste tag, or date range
- Aggregate statistics (avg rating per recipe, brew frequency)

## References

- **Full Documentation:** `PRD/database_documentation.md`
- **PRD:** `.ai/prd.md`
- **Planning Summary:** `PRD/database_planning_summary.md`
- **SwiftData Docs:** [Context7](https://context7.com/docs)
