# Use Case Refactoring Plan

## Overview

This document outlines the plan to refactor the BrewGuide codebase to ensure:
1. All business logic resides in use case classes
2. Use cases interact with repositories through protocols
3. Tests are updated to validate business logic in use cases

## Key Principles

### Repository Responsibility (Data Access Only)
```
✅ Repositories SHOULD:
- Execute CRUD operations (Create, Read, Update, Delete)
- Run queries with predicates and sorting
- Manage persistence context (save, transactions)

❌ Repositories should NOT:
- Validate business rules
- Make business decisions
- Perform calculations
- Enforce access control
```

### Use Case Responsibility (Business Logic)
```
✅ Use Cases SHOULD:
- Validate inputs against business rules
- Orchestrate repository operations
- Make business decisions (what can be edited, deleted, etc.)
- Transform data between layers
- Calculate derived values
```

### Summary of Logic Migration

| Logic | FROM | TO |
|-------|------|-----|
| Recipe validation rules | `RecipeRepository.validate()` | `RecipeValidator` |
| Brew log validation rules | `BrewLogRepository.validate()` | `BrewLogValidator` |
| Step ordering normalization | `RecipeRepository.replaceSteps()` | `RecipeUseCase` |
| Duplicate naming convention | `RecipeRepository.duplicate()` | `RecipeUseCase` |
| Starter protection (delete) | `RecipeRepository.deleteCustomRecipe()` | `RecipeUseCase` |
| Recipe grouping/sorting | `RecipeListViewModel` | `RecipeListUseCase` |
| Average rating calculation | `BrewLogRepository` | `BrewLogUseCase` |

## Current State Analysis

### Existing Architecture

```
Views → ViewModels → UseCases/Services → Repositories → SwiftData
```

### Business Logic Leakage in Repositories

#### RecipeRepository Issues

| Method | Issue | Severity |
|--------|-------|----------|
| `validate(_:)` | All validation rules are business logic | ❌ Critical |
| `replaceSteps(for:with:)` | Step ordering normalization is a business rule | ⚠️ Medium |
| `duplicate(_:)` | `isStarter`, `origin`, naming convention are business rules | ⚠️ Medium |
| `deleteCustomRecipe(_:)` | Starter protection is a business rule | ⚠️ Medium |
| `fetchRecipes(for:)` | "Starters first" sorting is presentation logic | ⚠️ Low |

#### BrewLogRepository Issues

| Method | Issue | Severity |
|--------|-------|----------|
| `validate(_:)` | All validation rules are business logic | ❌ Critical |
| `calculateAverageRating()` | Statistical calculation is business logic | ⚠️ Medium |

### Repository Responsibility Principle

**Repositories should only:**
- Execute CRUD operations (Create, Read, Update, Delete)
- Run queries with predicates/sorting
- Manage persistence context (save, transactions)

**Repositories should NOT:**
- Validate business rules
- Make business decisions (naming, default values)
- Perform calculations
- Enforce access control rules

### Existing Use Cases (Well-Structured)

| Use Case | Protocol | Repository Used | Responsibilities |
|----------|----------|-----------------|------------------|
| `RecipeUseCase` | `RecipeUseCaseProtocol` | `RecipeRepositoryProtocol` | Fetch detail, update custom recipe |
| `BrewSessionUseCase` | None | `RecipeRepositoryProtocol` | Create brew plan, create inputs |
| `BrewLogUseCase` | None | `BrewLogRepositoryProtocol` | Delete log, fetch summaries |
| `AuthUseCase` | `AuthUseCaseProtocol` | `AuthSessionStoreProtocol` | Auth operations |
| `SyncUseCase` | `SyncUseCaseProtocol` | Multiple stores | Sync operations |

### ViewModels with Business Logic (Need Refactoring)

| ViewModel | Direct Repository Use | Business Logic |
|-----------|----------------------|----------------|
| `RecipeListViewModel` | `RecipeRepository` | Load recipes, group by origin, validate, delete |
| `RecipeDetailViewModel` | `RecipeRepository` | Load recipe, validate, duplicate, delete |
| `ConfirmInputsViewModel` | `RecipeRepository` (created in `onAppear`) | Load recipe, validate brewability |

### Repository Protocol Gaps

`RecipeRepositoryProtocol` is incomplete:

```swift
// Current protocol
protocol RecipeRepositoryProtocol {
    func fetchRecipe(byId id: UUID) throws -> Recipe?
    func save() throws
    func validate(_ recipe: Recipe) -> [RecipeValidationError]
    func replaceSteps(for recipe: Recipe, with stepDTOs: [RecipeStepDTO]) throws
}
```

Missing methods used by ViewModels:
- `fetchRecipes(for: BrewMethod) throws -> [Recipe]`
- `fetchStarterRecipe(for: BrewMethod) throws -> Recipe?`
- `duplicate(_ recipe: Recipe) throws -> Recipe`
- `deleteCustomRecipe(_ recipe: Recipe) throws`

---

## Refactoring Plan

### Phase 0: Extract Validation to Domain Layer

**Goal:** Move all validation logic from repositories to dedicated validators in the Domain layer.

#### New File: `Domain/RecipeValidator.swift`

```swift
/// Pure validation logic for recipes - no dependencies on persistence
struct RecipeValidator {
    
    /// Validate a recipe entity against business rules
    static func validate(_ recipe: Recipe) -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        // Name validation
        if recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        // Dose/yield validation
        if recipe.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        if recipe.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        
        // Steps validation
        guard let steps = recipe.steps, !steps.isEmpty else {
            errors.append(.noSteps)
            return errors
        }
        
        // Timer validation
        for step in steps {
            if let duration = step.timerDurationSeconds, duration < 0 {
                errors.append(.negativeTimer(stepIndex: step.orderIndex))
            }
        }
        
        // Water total validation (±1g tolerance)
        let waterSteps = steps.compactMap { $0.waterAmountGrams }
        if !waterSteps.isEmpty {
            let totalWater = waterSteps.max() ?? 0
            let difference = abs(totalWater - recipe.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: recipe.defaultTargetYield, actual: totalWater))
            }
        }
        
        return errors
    }
    
    /// Validate an update request DTO
    static func validate(_ request: UpdateRecipeRequest) -> [RecipeValidationError] {
        var errors: [RecipeValidationError] = []
        
        if request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        if request.defaultDose <= 0 {
            errors.append(.invalidDose)
        }
        if request.defaultTargetYield <= 0 {
            errors.append(.invalidYield)
        }
        if request.steps.isEmpty {
            errors.append(.noSteps)
        }
        
        // Validate steps
        for (index, step) in request.steps.enumerated() {
            if let duration = step.durationSeconds, duration < 0 {
                errors.append(.negativeTimer(stepIndex: index))
            }
        }
        
        // Water total check
        let waterAmounts = request.steps.compactMap { $0.waterAmountGrams }
        if !waterAmounts.isEmpty {
            let totalWater = waterAmounts.max() ?? 0
            let difference = abs(totalWater - request.defaultTargetYield)
            if difference > 1.0 {
                errors.append(.waterTotalMismatch(expected: request.defaultTargetYield, actual: totalWater))
            }
        }
        
        return errors
    }
}
```

#### New File: `Domain/BrewLogValidator.swift`

```swift
/// Pure validation logic for brew logs
struct BrewLogValidator {
    
    static func validate(_ log: BrewLog) -> [BrewLogValidationError] {
        var errors: [BrewLogValidationError] = []
        
        // Rating must be 1-5
        if log.rating < 1 || log.rating > 5 {
            errors.append(.invalidRating(log.rating))
        }
        
        // Recipe name cannot be empty
        if log.recipeNameAtBrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRecipeName)
        }
        
        // Dose and yield must be positive
        if log.doseGrams <= 0 {
            errors.append(.invalidDose)
        }
        if log.targetYieldGrams <= 0 {
            errors.append(.invalidYield)
        }
        
        // Note length limit
        if let note = log.note, note.count > 280 {
            errors.append(.noteTooLong(count: note.count))
        }
        
        return errors
    }
}
```

#### Simplified RecipeRepository

Remove `validate()` method from repository:

```swift
@MainActor
protocol RecipeRepositoryProtocol {
    // Pure CRUD - no validation
    func fetchRecipe(byId id: UUID) throws -> Recipe?
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe]
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe?
    func insert(_ recipe: Recipe)
    func delete(_ recipe: Recipe)
    func save() throws
    
    // Step operations - no normalization
    func deleteSteps(for recipe: Recipe)
    func insertSteps(_ steps: [RecipeStep])
}
```

#### Simplified BrewLogRepository

Remove `validate()` and `calculateAverageRating()` from repository:

```swift
@MainActor
protocol BrewLogRepositoryProtocol {
    func fetchAllLogs() throws -> [BrewLog]
    func fetchLog(byId id: UUID) throws -> BrewLog?
    func delete(_ log: BrewLog)
    func save() throws
}
```

#### Update Use Cases to Use Validators

```swift
// RecipeUseCase uses RecipeValidator instead of repository.validate()
func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO {
    guard let recipe = try repository.fetchRecipe(byId: id) else {
        throw RecipeUseCaseError.recipeNotFound
    }
    
    // Use domain validator instead of repository
    let validationErrors = RecipeValidator.validate(recipe)
    return recipe.toDetailDTO(isValid: validationErrors.isEmpty)
}

func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors> {
    // Validate request using domain validator
    let requestErrors = RecipeValidator.validate(request)
    guard requestErrors.isEmpty else {
        return .failure(RecipeValidationErrors(errors: requestErrors))
    }
    // ... rest of update logic
}
```

#### Refactor `replaceSteps` - Move Normalization to Use Case

**Current (in repository - BAD):**
```swift
func replaceSteps(for recipe: Recipe, with stepDTOs: [RecipeStepDTO]) throws {
    // ❌ Business logic: sorting and normalizing orderIndex
    let normalizedSteps = stepDTOs
        .sorted(by: { $0.orderIndex < $1.orderIndex })
        .enumerated()
        .map { index, dto in
            RecipeStepDTO(orderIndex: index, ...) // Normalizing!
        }
    // ... persistence
}
```

**New approach - Repository just persists:**
```swift
// Repository - pure persistence
func replaceSteps(for recipe: Recipe, with steps: [RecipeStep]) {
    if let existingSteps = recipe.steps {
        for step in existingSteps {
            context.delete(step)
        }
    }
    for step in steps {
        context.insert(step)
    }
    recipe.steps = steps
}
```

**Use Case handles normalization:**
```swift
// RecipeUseCase - business logic
func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors> {
    // ... validation ...
    
    // Normalize step ordering (business rule)
    let normalizedSteps = normalizeStepOrdering(request.steps)
    
    // Create step entities
    let stepEntities = normalizedSteps.map { dto in
        RecipeStep(from: dto, recipe: recipe)
    }
    
    // Repository just persists
    repository.replaceSteps(for: recipe, with: stepEntities)
    try repository.save()
    return .success(())
}

private func normalizeStepOrdering(_ steps: [RecipeStepDTO]) -> [RecipeStepDTO] {
    steps
        .sorted(by: { $0.orderIndex < $1.orderIndex })
        .enumerated()
        .map { index, dto in
            RecipeStepDTO(orderIndex: index, ...)
        }
}
```

#### Refactor `duplicate` - Move Business Rules to Use Case

**Current (in repository - BAD):**
```swift
func duplicate(_ source: Recipe) throws -> Recipe {
    let newRecipe = Recipe(
        isStarter: false,        // ❌ Business rule
        origin: .custom,         // ❌ Business rule
        name: "\(source.name) Copy", // ❌ Business rule
        // ...
    )
    // ...
}
```

**New approach - Repository just copies:**
```swift
// Repository - generic insert
func insert(_ recipe: Recipe)
func insertSteps(_ steps: [RecipeStep])
```

**Use Case handles business rules:**
```swift
// RecipeUseCase
func duplicateRecipe(id: UUID) throws -> UUID {
    guard let source = try repository.fetchRecipe(byId: id) else {
        throw RecipeUseCaseError.recipeNotFound
    }
    
    // Business rules applied here
    let newRecipe = Recipe(
        isStarter: false,
        origin: .custom,
        method: source.method,
        name: generateCopyName(source.name),
        defaultDose: source.defaultDose,
        // ... copy other properties
    )
    
    repository.insert(newRecipe)
    
    // Clone steps
    let clonedSteps = (source.steps ?? []).map { step in
        RecipeStep(
            orderIndex: step.orderIndex,
            instructionText: step.instructionText,
            // ... copy properties
            recipe: newRecipe
        )
    }
    repository.insertSteps(clonedSteps)
    newRecipe.steps = clonedSteps
    
    try repository.save()
    return newRecipe.id
}

private func generateCopyName(_ originalName: String) -> String {
    "\(originalName) Copy"
}
```

#### Refactor `deleteCustomRecipe` - Move Protection to Use Case

**Current (in repository - BAD):**
```swift
func deleteCustomRecipe(_ recipe: Recipe) throws {
    guard !recipe.isStarter else {
        throw RecipeRepositoryError.cannotDeleteStarterRecipe // ❌ Business rule
    }
    delete(recipe)
}
```

**New approach - Repository just deletes:**
```swift
// Repository - pure deletion
func delete(_ recipe: Recipe) {
    context.delete(recipe)
}
```

**Use Case enforces business rules:**
```swift
// RecipeUseCase
func deleteRecipe(id: UUID) throws {
    guard let recipe = try repository.fetchRecipe(byId: id) else {
        return // Idempotent
    }
    
    // Business rule check here
    guard !recipe.isStarter else {
        throw RecipeUseCaseError.cannotDeleteStarter
    }
    
    repository.delete(recipe)
    try repository.save()
}
```

---

### Phase 1: Simplify Repository Protocol

**Goal:** Make `RecipeRepositoryProtocol` pure CRUD without business logic.

**File:** `BrewGuide/Persistence/Repositories/RecipeRepository.swift`

**New Protocol (clean):**
```swift
@MainActor
protocol RecipeRepositoryProtocol {
    // Fetch operations
    func fetchRecipe(byId id: UUID) throws -> Recipe?
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe]
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe?
    
    // CRUD operations
    func insert(_ recipe: Recipe)
    func delete(_ recipe: Recipe)
    func save() throws
    
    // Step operations (pure persistence, no normalization)
    func replaceSteps(for recipe: Recipe, with steps: [RecipeStep])
    func insertSteps(_ steps: [RecipeStep])
}
```

**Removed from protocol:**
- `validate()` → Moved to `RecipeValidator`
- `duplicate()` → Logic moved to `RecipeUseCase`
- `deleteCustomRecipe()` → Replaced by simple `delete()`, protection in use case

**Update FakeRecipeRepository** to implement simplified protocol.

---

### Phase 2: Create RecipeListUseCase

**Goal:** Extract business logic from `RecipeListViewModel` into a dedicated use case.

**New File:** `BrewGuide/Domain/RecipeListUseCase.swift`

**Protocol:**
```swift
protocol RecipeListUseCaseProtocol: Sendable {
    @MainActor func fetchGroupedRecipes(for method: BrewMethod) throws -> RecipeListSections
    @MainActor func deleteRecipe(id: UUID) throws
    @MainActor func canDeleteRecipe(_ recipe: RecipeSummaryDTO) -> Bool
}
```

**Implementation:**
```swift
@MainActor
final class RecipeListUseCase: RecipeListUseCaseProtocol {
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol) {
        self.repository = repository
    }
    
    func fetchGroupedRecipes(for method: BrewMethod) throws -> RecipeListSections {
        let recipes = try repository.fetchRecipes(for: method)
        
        let dtos = recipes.map { recipe -> RecipeSummaryDTO in
            let validationErrors = repository.validate(recipe)
            return recipe.toSummaryDTO(isValid: validationErrors.isEmpty)
        }
        
        let starterRecipes = dtos
            .filter { $0.isStarter || $0.origin == .starterTemplate }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        let customRecipes = dtos
            .filter { !$0.isStarter && $0.origin != .starterTemplate }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        return RecipeListSections(starter: starterRecipes, custom: customRecipes)
    }
    
    func deleteRecipe(id: UUID) throws {
        guard let recipe = try repository.fetchRecipe(byId: id) else {
            return // Treat as success (idempotent)
        }
        
        try repository.deleteCustomRecipe(recipe)
        try repository.save()
    }
    
    func canDeleteRecipe(_ recipe: RecipeSummaryDTO) -> Bool {
        !recipe.isStarter && recipe.origin != .starterTemplate
    }
}
```

**Business Logic Moved:**
- Recipe grouping by origin (starter vs custom)
- Sorting logic
- Validation status mapping
- Delete eligibility check
- Idempotent delete behavior

---

### Phase 3: Extend RecipeUseCase

**Goal:** Add missing recipe operations to existing use case.

**File:** `BrewGuide/Domain/RecipeUseCase.swift`

**Extended Protocol:**
```swift
protocol RecipeUseCaseProtocol: Sendable {
    // Existing
    @MainActor func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO
    @MainActor func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors>
    
    // New additions
    @MainActor func duplicateRecipe(id: UUID) throws -> UUID
    @MainActor func deleteRecipe(id: UUID) throws
    @MainActor func canEdit(recipe: RecipeSummaryDTO) -> Bool
    @MainActor func canDelete(recipe: RecipeSummaryDTO) -> Bool
}
```

**New Methods:**
```swift
func duplicateRecipe(id: UUID) throws -> UUID {
    guard let recipe = try repository.fetchRecipe(byId: id) else {
        throw RecipeUseCaseError.recipeNotFound
    }
    
    let newRecipe = try repository.duplicate(recipe)
    try repository.save()
    
    return newRecipe.id
}

func deleteRecipe(id: UUID) throws {
    guard let recipe = try repository.fetchRecipe(byId: id) else {
        return // Idempotent: treat as success
    }
    
    try repository.deleteCustomRecipe(recipe)
    try repository.save()
}

func canEdit(recipe: RecipeSummaryDTO) -> Bool {
    !recipe.isStarter && recipe.origin != .starterTemplate
}

func canDelete(recipe: RecipeSummaryDTO) -> Bool {
    !recipe.isStarter && recipe.origin != .starterTemplate
}
```

---

### Phase 4: Add BrewSessionUseCaseProtocol

**Goal:** Add protocol for testability.

**File:** `BrewGuide/Domain/BrewSessionUseCase.swift`

**Add Protocol:**
```swift
protocol BrewSessionUseCaseProtocol: Sendable {
    @MainActor func createPlan(from inputs: BrewInputs) async throws -> BrewPlan
    @MainActor func createInputs(from recipe: Recipe) -> BrewInputs
    @MainActor func loadRecipeForBrewing(id: UUID?, fallbackMethod: BrewMethod) throws -> Recipe
}
```

**Add New Method:**
```swift
func loadRecipeForBrewing(id: UUID?, fallbackMethod: BrewMethod) throws -> Recipe {
    // Try specified ID
    if let id, let recipe = try recipeRepository.fetchRecipe(byId: id) {
        return recipe
    }
    
    // Fallback to starter
    if let starter = try recipeRepository.fetchStarterRecipe(for: fallbackMethod) {
        return starter
    }
    
    throw BrewSessionError.recipeNotFound
}
```

---

### Phase 5: Refactor ViewModels

#### 5.1 RecipeListViewModel

**Changes:**
- Replace `RecipeRepository` with `RecipeListUseCaseProtocol`
- Move grouping and deletion logic to use case
- Keep only UI state management

```swift
@Observable
@MainActor
final class RecipeListViewModel {
    // State (unchanged)
    private(set) var method: BrewMethod
    private(set) var sections: RecipeListSections
    private(set) var isLoading: Bool
    private(set) var errorState: RecipeListErrorState?
    private(set) var pendingDelete: RecipeSummaryDTO?
    private(set) var isDeleting: Bool
    
    // Dependencies (changed)
    private let preferences: PreferencesStore
    private let useCase: RecipeListUseCaseProtocol
    
    init(
        method: BrewMethod = .v60,
        preferences: PreferencesStore = .shared,
        useCase: RecipeListUseCaseProtocol
    ) {
        // ...
    }
    
    func load() async {
        isLoading = true
        errorState = nil
        
        do {
            sections = try useCase.fetchGroupedRecipes(for: method)
        } catch {
            errorState = .loadFailed(message: "Could not load recipes.")
        }
        
        isLoading = false
    }
    
    func requestDelete(_ recipe: RecipeSummaryDTO) {
        guard useCase.canDeleteRecipe(recipe) else { return }
        pendingDelete = recipe
    }
    
    func confirmDelete() async {
        guard let recipe = pendingDelete else { return }
        
        isDeleting = true
        
        do {
            try useCase.deleteRecipe(id: recipe.id)
            pendingDelete = nil
            await load()
        } catch {
            errorState = .deleteFailed(message: "Could not delete recipe.")
            pendingDelete = nil
        }
        
        isDeleting = false
    }
}
```

#### 5.2 RecipeDetailViewModel

**Changes:**
- Replace `RecipeRepository` with `RecipeUseCaseProtocol`
- Move duplication and deletion logic to use case

```swift
@MainActor
@Observable
final class RecipeDetailViewModel {
    // Dependencies (changed)
    private let useCase: RecipeUseCaseProtocol
    private let preferences: PreferencesStore
    
    init(
        recipeId: UUID,
        useCase: RecipeUseCaseProtocol,
        preferences: PreferencesStore = .shared
    ) {
        // ...
    }
    
    func load() async {
        state.isLoading = true
        
        do {
            let detail = try useCase.fetchRecipeDetail(id: recipeId)
            state.detail = detail
        } catch RecipeUseCaseError.recipeNotFound {
            state.error = RecipeDetailErrorState(message: "Recipe not found.", isRetryable: false)
        } catch {
            state.error = RecipeDetailErrorState(message: "Failed to load recipe.", isRetryable: true)
        }
        
        state.isLoading = false
    }
    
    var canEdit: Bool {
        guard let detail = state.detail else { return false }
        return useCase.canEdit(recipe: detail.recipe)
    }
    
    func duplicateRecipe() async -> UUID? {
        do {
            return try useCase.duplicateRecipe(id: recipeId)
        } catch {
            actionError = RecipeDetailActionError(message: "Failed to duplicate recipe.")
            return nil
        }
    }
    
    func confirmDelete() async -> Bool {
        do {
            try useCase.deleteRecipe(id: recipeId)
            return true
        } catch {
            actionError = RecipeDetailActionError(message: "Failed to delete recipe.")
            return false
        }
    }
}
```

#### 5.3 ConfirmInputsViewModel

**Changes:**
- Accept dependencies via initializer instead of creating in `onAppear`
- Use `BrewSessionUseCaseProtocol` for all recipe operations

```swift
@Observable
@MainActor
final class ConfirmInputsViewModel {
    // Dependencies (changed - injected via init)
    private let preferences: PreferencesStore
    private let scalingService: ScalingService
    private let brewSessionUseCase: BrewSessionUseCaseProtocol
    
    init(
        preferences: PreferencesStore = .shared,
        scalingService: ScalingService = ScalingService(),
        brewSessionUseCase: BrewSessionUseCaseProtocol
    ) {
        self.preferences = preferences
        self.scalingService = scalingService
        self.brewSessionUseCase = brewSessionUseCase
    }
    
    func onAppear(recipeId: UUID?) async {
        let targetRecipeId = recipeId ?? preferences.lastSelectedRecipeId
        await loadRecipe(recipeId: targetRecipeId)
    }
    
    private func loadRecipe(recipeId: UUID?) async {
        do {
            let recipe = try brewSessionUseCase.loadRecipeForBrewing(
                id: recipeId,
                fallbackMethod: .v60
            )
            
            // Create snapshot and inputs from recipe
            // ...
        } catch {
            ui.errorMessage = "No recipes available."
        }
    }
}
```

---

### Phase 6: Update Tests

#### 6.1 New Test File: RecipeListUseCaseTests.swift

```swift
@Suite("RecipeListUseCase Tests")
@MainActor
struct RecipeListUseCaseTests {
    
    @Test("Fetch grouped recipes separates starter and custom")
    func testFetchGroupedRecipes() throws {
        let repository = FakeRecipeRepository()
        repository.addRecipe(RecipeFixtures.makeStarterV60Recipe())
        repository.addRecipe(RecipeFixtures.makeValidV60Recipe())
        
        let useCase = RecipeListUseCase(repository: repository)
        let sections = try useCase.fetchGroupedRecipes(for: .v60)
        
        #expect(sections.starter.count == 1)
        #expect(sections.custom.count == 1)
    }
    
    @Test("Delete custom recipe succeeds")
    func testDeleteCustomRecipe() throws {
        let repository = FakeRecipeRepository()
        let recipe = RecipeFixtures.makeValidV60Recipe()
        repository.addRecipe(recipe)
        
        let useCase = RecipeListUseCase(repository: repository)
        try useCase.deleteRecipe(id: recipe.id)
        
        #expect(repository.saveCalls == 1)
    }
    
    @Test("Delete non-existent recipe succeeds (idempotent)")
    func testDeleteNonExistentRecipeSucceeds() throws {
        let repository = FakeRecipeRepository()
        let useCase = RecipeListUseCase(repository: repository)
        
        // Should not throw
        try useCase.deleteRecipe(id: UUID())
    }
    
    @Test("Cannot delete starter recipe")
    func testCannotDeleteStarterRecipe() {
        let useCase = RecipeListUseCase(repository: FakeRecipeRepository())
        let starter = RecipeSummaryDTO(
            id: UUID(),
            name: "Starter",
            method: .v60,
            isStarter: true,
            origin: .starterTemplate,
            isValid: true
        )
        
        #expect(useCase.canDeleteRecipe(starter) == false)
    }
}
```

#### 6.2 Extend RecipeUseCaseTests.swift

Add tests for new methods:

```swift
// MARK: - Duplicate Recipe Tests

@Test("Duplicate recipe creates new recipe and returns ID")
func testDuplicateRecipeSucceeds() throws {
    let repository = FakeRecipeRepository()
    let recipe = RecipeFixtures.makeValidV60Recipe()
    repository.addRecipe(recipe)
    
    let useCase = RecipeUseCase(repository: repository)
    let newId = try useCase.duplicateRecipe(id: recipe.id)
    
    #expect(newId != recipe.id)
    #expect(repository.saveCalls == 1)
}

@Test("Duplicate non-existent recipe throws error")
func testDuplicateNonExistentRecipeThrows() {
    let repository = FakeRecipeRepository()
    let useCase = RecipeUseCase(repository: repository)
    
    #expect(throws: RecipeUseCaseError.recipeNotFound) {
        try useCase.duplicateRecipe(id: UUID())
    }
}

// MARK: - Delete Recipe Tests

@Test("Delete recipe succeeds")
func testDeleteRecipeSucceeds() throws {
    let repository = FakeRecipeRepository()
    let recipe = RecipeFixtures.makeValidV60Recipe()
    repository.addRecipe(recipe)
    
    let useCase = RecipeUseCase(repository: repository)
    try useCase.deleteRecipe(id: recipe.id)
    
    #expect(repository.saveCalls == 1)
}

@Test("Delete non-existent recipe succeeds (idempotent)")
func testDeleteNonExistentRecipeSucceeds() throws {
    let repository = FakeRecipeRepository()
    let useCase = RecipeUseCase(repository: repository)
    
    // Should not throw
    try useCase.deleteRecipe(id: UUID())
}
```

#### 6.3 Add BrewSessionUseCaseTests.swift Updates

Add tests for new `loadRecipeForBrewing` method.

#### 6.4 Update Existing ViewModel Tests

Update `RecipeEditViewModelTests.swift` and `LogsListViewModelTests.swift` to use use cases through protocols.

---

### Phase 7: Update FakeRecipeRepository

**File:** `BrewGuideTests/Fakes/FakeRecipeRepository.swift`

Add implementations for new protocol methods:

```swift
final class FakeRecipeRepository: RecipeRepositoryProtocol {
    // Existing...
    
    // New method tracking
    var fetchRecipesCalls: [(method: BrewMethod)] = []
    var fetchStarterRecipeCalls: [(method: BrewMethod)] = []
    var duplicateCalls: [(recipe: Recipe)] = []
    var deleteCustomRecipeCalls: [(recipe: Recipe)] = []
    
    func fetchRecipes(for method: BrewMethod) throws -> [Recipe] {
        fetchRecipesCalls.append((method: method))
        return recipes.filter { $0.method == method }
    }
    
    func fetchStarterRecipe(for method: BrewMethod) throws -> Recipe? {
        fetchStarterRecipeCalls.append((method: method))
        return recipes.first { $0.isStarter && $0.method == method }
    }
    
    func duplicate(_ recipe: Recipe) throws -> Recipe {
        duplicateCalls.append((recipe: recipe))
        let newRecipe = Recipe(
            isStarter: false,
            origin: .custom,
            method: recipe.method,
            name: "\(recipe.name) Copy",
            defaultDose: recipe.defaultDose,
            defaultTargetYield: recipe.defaultTargetYield,
            defaultWaterTemperature: recipe.defaultWaterTemperature,
            defaultGrindLabel: recipe.defaultGrindLabel,
            grindTactileDescriptor: recipe.grindTactileDescriptor
        )
        recipes.append(newRecipe)
        return newRecipe
    }
    
    func deleteCustomRecipe(_ recipe: Recipe) throws {
        deleteCustomRecipeCalls.append((recipe: recipe))
        guard !recipe.isStarter else {
            throw RecipeRepositoryError.cannotDeleteStarterRecipe
        }
        recipes.removeAll { $0.id == recipe.id }
    }
}
```

---

## Implementation Order

### Step 1: Extract Validators (Phase 0)
1. Create `Domain/RecipeValidator.swift` with validation logic from repository
2. Create `Domain/BrewLogValidator.swift` with validation logic from repository
3. Create `RecipeValidatorTests.swift` and `BrewLogValidatorTests.swift`
4. Update use cases to use validators instead of `repository.validate()`
5. Remove `validate()` from repository protocols
6. Run tests to verify

### Step 2: Simplify Repository Protocol (Phase 1)
1. Remove business logic methods from `RecipeRepositoryProtocol`
2. Replace `duplicate()` with simple `insert()`
3. Replace `deleteCustomRecipe()` with simple `delete()`
4. Simplify `replaceSteps()` to not normalize
5. Update `FakeRecipeRepository` to match simplified protocol
6. Verify existing tests still pass

### Step 3: Create RecipeListUseCase (Phase 2)
1. Create `RecipeListUseCase.swift` with protocol
2. Move grouping and sorting logic from ViewModel
3. Create `RecipeListUseCaseTests.swift`
4. Run tests to verify business logic

### Step 4: Extend RecipeUseCase (Phase 3)
1. Add `duplicateRecipe()` with business rules (naming, origin)
2. Add `deleteRecipe()` with starter protection
3. Add step normalization to update method
4. Add `canEdit`, `canDelete` methods
5. Add tests in `RecipeUseCaseTests.swift`
6. Run tests

### Step 5: Add BrewSessionUseCaseProtocol (Phase 4)
1. Create protocol for `BrewSessionUseCase`
2. Add `loadRecipeForBrewing` method
3. Add tests
4. Create `FakeBrewSessionUseCase` for testing

### Step 6: Refactor RecipeListViewModel (Phase 5.1)
1. Update to use `RecipeListUseCaseProtocol`
2. Update view to inject use case
3. Update any existing ViewModel tests

### Step 7: Refactor RecipeDetailViewModel (Phase 5.2)
1. Update to use `RecipeUseCaseProtocol`
2. Update view to inject use case
3. Verify functionality

### Step 8: Refactor ConfirmInputsViewModel (Phase 5.3)
1. Update to accept dependencies via initializer
2. Use `BrewSessionUseCaseProtocol`
3. Update view to create and inject dependencies

### Step 9: Final Cleanup
1. Run all tests
2. Remove unused repository methods
3. Manual testing of all flows
4. Fix any regressions

---

## Files to Create

| File | Purpose |
|------|---------|
| `Domain/RecipeValidator.swift` | Pure validation logic extracted from repository |
| `Domain/BrewLogValidator.swift` | Pure validation logic extracted from repository |
| `Domain/RecipeListUseCase.swift` | New use case for recipe list operations |
| `BrewGuideTests/Domain/RecipeValidatorTests.swift` | Tests for recipe validation rules |
| `BrewGuideTests/Domain/BrewLogValidatorTests.swift` | Tests for brew log validation rules |
| `BrewGuideTests/Domain/RecipeListUseCaseTests.swift` | Tests for new use case |
| `BrewGuideTests/Fakes/FakeBrewSessionUseCase.swift` | Fake for brew session use case |

## Files to Modify

| File | Changes |
|------|---------|
| `Persistence/Repositories/RecipeRepository.swift` | Simplify protocol, remove `validate()`, `duplicate()`, `deleteCustomRecipe()` |
| `Persistence/Repositories/BrewLogRepository.swift` | Remove `validate()`, `calculateAverageRating()` |
| `Domain/RecipeUseCase.swift` | Add duplicate/delete methods, use `RecipeValidator` |
| `Domain/BrewLogUseCase.swift` | Use `BrewLogValidator`, add average rating calculation |
| `Domain/BrewSessionUseCase.swift` | Add protocol, add loading method |
| `UI/Screens/Recipes/RecipeListViewModel.swift` | Use RecipeListUseCaseProtocol |
| `UI/Screens/Recipes/RecipeDetail/RecipeDetailViewModel.swift` | Use RecipeUseCaseProtocol |
| `UI/Screens/ConfirmInputs/ConfirmInputsViewModel.swift` | Inject dependencies via init |
| `BrewGuideTests/Fakes/FakeRecipeRepository.swift` | Implement simplified protocol |
| `BrewGuideTests/Domain/RecipeUseCaseTests.swift` | Add duplicate/delete tests, update validation tests |
| `BrewGuideTests/Domain/BrewSessionUseCaseTests.swift` | Add loading tests |

---

## Expected Outcomes

### Before Refactoring

```
RecipeListViewModel → RecipeRepository (direct)
RecipeDetailViewModel → RecipeRepository (direct)
ConfirmInputsViewModel → RecipeRepository (created internally)
                       → BrewSessionUseCase
```

### After Refactoring

```
RecipeListViewModel → RecipeListUseCaseProtocol → RecipeRepositoryProtocol
RecipeDetailViewModel → RecipeUseCaseProtocol → RecipeRepositoryProtocol
ConfirmInputsViewModel → BrewSessionUseCaseProtocol → RecipeRepositoryProtocol
RecipeEditViewModel → RecipeUseCaseProtocol → RecipeRepositoryProtocol (unchanged)
LogsListViewModel → BrewLogUseCaseProtocol → BrewLogRepositoryProtocol (unchanged pattern)
```

### Benefits

1. **Testability**: All business logic testable through use case protocols with fakes
2. **Single Responsibility**: ViewModels handle UI state only; use cases handle business rules
3. **Dependency Inversion**: ViewModels depend on abstractions (protocols), not implementations
4. **Consistency**: All ViewModels follow the same pattern (inject use case protocol)
5. **Maintainability**: Business rule changes isolated to use case layer

---

## Test Coverage Summary

| Component | Test File | Test Count |
|-----------|-----------|------------|
| `RecipeValidator` | `RecipeValidatorTests.swift` | ~15 tests (new) |
| `BrewLogValidator` | `BrewLogValidatorTests.swift` | ~8 tests (new) |
| `RecipeListUseCase` | `RecipeListUseCaseTests.swift` | ~10 tests (new) |
| `RecipeUseCase` | `RecipeUseCaseTests.swift` | ~25 tests (5 new) |
| `BrewSessionUseCase` | `BrewSessionUseCaseTests.swift` | ~18 tests (4 new) |
| `BrewLogUseCase` | `BrewLogUseCaseTests.swift` | 16 tests (unchanged) |
| `AuthUseCase` | `AuthUseCaseTests.swift` | 10 tests (unchanged) |
| `SyncUseCase` | `SyncUseCaseTests.swift` | 15 tests (unchanged) |

**Total Domain Tests:** ~165+ (up from 132)

### Validator Test Coverage

`RecipeValidatorTests.swift`:
- Empty name validation
- Whitespace-only name validation
- Zero/negative dose validation
- Zero/negative yield validation
- No steps validation
- Negative timer validation
- Water total mismatch validation
- Water within tolerance validation

`BrewLogValidatorTests.swift`:
- Invalid rating (0, 6, negative)
- Empty recipe name validation
- Invalid dose/yield validation
- Note too long validation (>280 chars)

---

## Risk Mitigation

1. **Incremental approach**: Each step can be tested independently
2. **Protocol-based changes**: Existing code continues to work until ViewModel refactoring
3. **Fake repositories**: Test isolation prevents cascading failures
4. **Manual verification**: Test key user flows after each phase
