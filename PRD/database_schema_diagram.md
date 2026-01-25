# BrewGuide Database Schema Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SwiftData Models                             │
│                    (CloudKit Private Database)                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────┐
│          Recipe                 │
├─────────────────────────────────┤
│ • id: UUID                      │
│ • isStarter: Bool               │
│ • origin: RecipeOrigin          │◄──── .starterTemplate
│ • method: BrewMethod            │      .custom
│ • name: String                  │      .conflictedCopy
│ • defaultDose: Double           │
│ • defaultTargetYield: Double    │
│ • defaultWaterTemperature: °C   │
│ • defaultGrindLabel: GrindLabel │◄──── .fine, .medium, .coarse
│ • grindTactileDescriptor: String│
│ • createdAt: Date               │
│ • modifiedAt: Date              │
└────────────┬────────────────────┘
             │
             │ steps (1-to-many)
             │ cascade delete
             ▼
┌─────────────────────────────────┐
│        RecipeStep               │
├─────────────────────────────────┤
│ • stepId: UUID                  │
│ • orderIndex: Int               │
│ • instructionText: String       │
│ • timerDurationSeconds: Double? │
│ • waterAmountGrams: Double?     │
│ • isCumulativeWaterTarget: Bool │
│ • recipe: Recipe? (parent)      │
└─────────────────────────────────┘


┌─────────────────────────────────┐
│          BrewLog                │
├─────────────────────────────────┤
│ SNAPSHOT STRATEGY:              │
│ • id: UUID                      │
│ • timestamp: Date               │
│ • method: BrewMethod            │
│                                 │
│ BREW-TIME PARAMETERS:           │
│ • recipeNameAtBrew: String      │◄──── Snapshot (not live)
│ • doseGrams: Double             │
│ • targetYieldGrams: Double      │
│ • waterTemperatureCelsius: °C   │
│ • grindLabel: GrindLabel        │
│                                 │
│ USER FEEDBACK:                  │
│ • rating: Int (1-5)             │
│ • tasteTag: TasteTag?           │◄──── .tooBitter, .tooSour,
│ • note: String? (≤280 chars)    │      .tooWeak, .tooStrong
│                                 │
│ NAVIGATION ONLY:                │
│ • recipe: Recipe? (optional)    │◄──── For "brew again"
└─────────────────────────────────┘


═══════════════════════════════════════════════════════════════
                         KEY RELATIONSHIPS
═══════════════════════════════════════════════════════════════

Recipe ──┬──► RecipeStep (owned, cascade delete)
         │
         │
         │     (optional reference)
         └──○──○ BrewLog (snapshot + optional link)


═══════════════════════════════════════════════════════════════
                      STARTER RECIPE (SEEDED)
═══════════════════════════════════════════════════════════════

Recipe: "V60 Starter"
├─ isStarter: true
├─ origin: .starterTemplate
├─ method: .v60
├─ defaultDose: 15.0g
├─ defaultTargetYield: 250.0g (ratio 1:16.7)
├─ defaultWaterTemperature: 94°C
├─ defaultGrindLabel: .medium
├─ grindTactileDescriptor: "sand; slightly finer than sea salt"
└─ steps:
   ├─ [0] "Rinse filter and preheat"
   ├─ [1] "Add coffee, level bed"
   ├─ [2] "Bloom: pour 45g, start timer" (45s, 45g water)
   ├─ [3] "Pour to 150g by 1:30" (90s, 150g cumulative)
   ├─ [4] "Pour to 250g by 2:15" (135s, 250g cumulative)
   └─ [5] "Wait for drawdown, target finish 3:00–3:30" (180s)


═══════════════════════════════════════════════════════════════
                         QUERY PATTERNS
═══════════════════════════════════════════════════════════════

Recipe Queries:
  • fetchRecipes(for: .v60)
    └─ Sorted: starters first, then alphabetical
  • fetchStarterRecipe(for: .v60)
  • fetchRecipe(byId: UUID)

BrewLog Queries:
  • fetchAllLogs()
    └─ Sorted: timestamp descending (most recent first)
  • fetchRecentLogs(limit: 10)
  • fetchLogs(forRecipeId: UUID)
  • calculateAverageRating()


═══════════════════════════════════════════════════════════════
                      BUSINESS RULES
═══════════════════════════════════════════════════════════════

Recipe:
  ✓ Starter recipes cannot be edited in-place
  ✓ Starter recipes cannot be deleted
  ✓ Custom recipes created via duplication
  ✓ All timers must be ≥ 0
  ✓ Water additions must sum to yield (±1g tolerance)
  ✓ Name cannot be empty

BrewLog:
  ✓ Rating must be 1-5 (required)
  ✓ Note max 280 characters
  ✓ Dose and yield must be > 0
  ✓ Recipe name snapshot required

RecipeStep:
  ✓ Ordered by orderIndex (0-based)
  ✓ Deleted when parent recipe deleted
  ✓ Stable stepId for identity


═══════════════════════════════════════════════════════════════
                    CLOUDKIT COMPATIBILITY
═══════════════════════════════════════════════════════════════

All models follow CloudKit best practices:
  ✓ Default values for all properties (or optional)
  ✓ Optional relationships
  ✓ String-backed enums (stable raw values)
  ✓ Private database per-user isolation
  ✓ Sync enabled only after Sign in with Apple

Container: iCloud.com.brewguide.BrewGuide
           └─ UPDATE TO MATCH YOUR BUNDLE ID


═══════════════════════════════════════════════════════════════
                     REPOSITORY LAYER
═══════════════════════════════════════════════════════════════

RecipeRepository
  • fetchRecipes(for:)
  • fetchStarterRecipe(for:)
  • duplicate(_:) → custom recipe with cloned steps
  • deleteCustomRecipe(_:) → validates not starter
  • validate(_:) → business rule checks

BrewLogRepository
  • fetchAllLogs() → chronological
  • fetchRecentLogs(limit:)
  • fetchLogs(forRecipeId:)
  • calculateAverageRating()
  • validate(_:) → rating, note length, etc.


═══════════════════════════════════════════════════════════════
                       USAGE EXAMPLE
═══════════════════════════════════════════════════════════════

// 1. Fetch starter recipe
let starter = try recipeRepo.fetchStarterRecipe(for: .v60)!

// 2. Duplicate to create custom recipe
let custom = try recipeRepo.duplicate(starter)
custom.name = "My V60"
custom.defaultDose = 18.0
custom.defaultTargetYield = 300.0

// 3. Validate and save
let errors = recipeRepo.validate(custom)
guard errors.isEmpty else { /* show errors */ }
try recipeRepo.save()

// 4. Brew with custom recipe
// ... (brew flow in Domain layer) ...

// 5. Log the brew
let log = BrewLog(
    recipeNameAtBrew: custom.name,
    doseGrams: 18.0,
    targetYieldGrams: 300.0,
    waterTemperatureCelsius: 94.0,
    grindLabel: .medium,
    rating: 4,
    tasteTag: nil,
    note: "Great balance!",
    recipe: custom
)
try logRepo.insert(log)
try logRepo.save()

// 6. View brew history
let allLogs = try logRepo.fetchAllLogs()
// Most recent first, preserves historical accuracy


═══════════════════════════════════════════════════════════════
                    COMPUTED VALUES
═══════════════════════════════════════════════════════════════

NOT STORED IN DATABASE (computed on-the-fly):
  • Recipe.defaultRatio (yield / dose)
  • BrewLog.ratio (yield / dose)
  • Scaled recipe quantities (Domain layer)
  • Step water amounts for different doses (Domain layer)


═══════════════════════════════════════════════════════════════
                    FUTURE ENHANCEMENTS
═══════════════════════════════════════════════════════════════

Conflict Resolution (deferred in MVP):
  • Detect conflicts during sync
  • Create duplicate with origin: .conflictedCopy
  • Logs are append-only (allow duplicates)

Additional Features:
  • Search/filter recipes by name
  • Filter logs by rating, taste tag, date range
  • Aggregate statistics per recipe
  • Pagination for large log lists


═══════════════════════════════════════════════════════════════
```
