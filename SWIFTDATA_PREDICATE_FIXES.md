# SwiftData Predicate Fixes

## Issue
SwiftData predicates do not support captured enum values or accessing `.rawValue` within predicates. This causes runtime crashes with errors like:

```
Fatal error: Failed to validate \Recipe.method.rawValue because rawValue is not a member of BrewMethod
```

or

```
Unsupported Predicate: Captured/constant values of type 'BrewMethod' are not supported
```

## Root Cause
SwiftData's `#Predicate` macro has limitations:
1. Cannot capture enum values as variables
2. Cannot access `.rawValue` on enum properties within predicates
3. Literal enum values (like `.v60`) work fine when not captured

## Solutions Applied

### 1. DatabaseSeeder.swift
**Problem**: Trying to compare enum with captured variable
```swift
// ❌ BEFORE - Crashes
let v60RawValue = BrewMethod.v60.rawValue
predicate: #Predicate<Recipe> { recipe in
    recipe.method.rawValue == v60RawValue  // CRASH
}
```

**Solution**: Use literal enum value
```swift
// ✅ AFTER - Works
predicate: #Predicate<Recipe> { recipe in
    recipe.method == .v60  // Literal enum works
}
```

### 2. RecipeRepository.swift

#### fetchRecipes(for:)
**Problem**: Cannot use captured `method` parameter in predicate
```swift
// ❌ BEFORE - Crashes
func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
    let methodRawValue = method.rawValue
    let descriptor = FetchDescriptor<Recipe>(
        predicate: #Predicate { $0.method.rawValue == methodRawValue }  // CRASH
    )
}
```

**Solution**: Fetch all, filter in Swift
```swift
// ✅ AFTER - Works
func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
    let descriptor = FetchDescriptor<Recipe>()
    let allRecipes = try fetch(descriptor: descriptor)
    return allRecipes
        .filter { $0.method == method }  // Filter in Swift, not predicate
        .sorted { ... }
}
```

#### fetchStarterRecipe(for:)
**Solution**: Predicate for `isStarter`, then filter by method in Swift
```swift
// ✅ Works
func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe? {
    let descriptor = FetchDescriptor<Recipe>(
        predicate: #Predicate { recipe in
            recipe.isStarter == true  // Predicate only for Bool
        }
    )
    let starters = try fetch(descriptor: descriptor)
    return starters.first { $0.method == method }  // Filter enum in Swift
}
```

### 3. BrewLogRepository.swift

#### fetchLogs(for:)
**Solution**: Similar approach - fetch all, filter in Swift
```swift
// ✅ Works
func fetchLogs(for method: BrewMethod) throws -> [BrewLog] {
    let descriptor = FetchDescriptor<BrewLog>(
        sortBy: [SortDescriptor(\BrewLog.timestamp, order: .reverse)]
    )
    let allLogs = try fetch(descriptor: descriptor)
    return allLogs.filter { $0.method == method }  // Filter in Swift
}
```

## Best Practices

### What Works in SwiftData Predicates ✅
- Literal enum values: `$0.method == .v60`
- Boolean comparisons: `$0.isStarter == true`
- UUID comparisons: `$0.id == uuid`
- String comparisons: `$0.name == "Test"`
- Numeric comparisons: `$0.rating > 3`
- Optional checks: `$0.recipe?.id == recipeId`

### What Doesn't Work ❌
- Captured enum variables: `let m = method; $0.method == m`
- Accessing `.rawValue`: `$0.method.rawValue == "v60"`
- Complex enum operations within predicates

### Workarounds
1. **Use literal enum values** when possible
2. **Fetch broader set + filter in Swift** when you need to use captured enum parameters
3. **Predicate for other conditions, Swift filter for enums**

## Performance Considerations
- Fetching all records and filtering in Swift is acceptable for small datasets (< 1000 records)
- For larger datasets, consider:
  - Using literal enum values where possible
  - Restructuring queries to avoid enum filtering
  - Using String-based filtering if necessary (store rawValue separately)

## Files Modified
1. `BrewGuide/Persistence/DatabaseSeeder.swift` - Fixed starter recipe seeding
2. `BrewGuide/Persistence/Repositories/RecipeRepository.swift` - Fixed recipe fetching
3. `BrewGuide/Persistence/Repositories/BrewLogRepository.swift` - Fixed log fetching
4. `BrewGuide/Persistence/PERSISTENCE_README.md` - Added documentation

## Verification
- ✅ No linter errors
- ✅ Predicates use only supported types
- ✅ Enum filtering done in Swift code, not predicates
- ✅ Documentation updated with best practices
