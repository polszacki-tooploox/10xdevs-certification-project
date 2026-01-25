# SwiftData + CloudKit (MVP) — Database Planning Summary

<conversation_summary>
<decisions>
1. **No persistent `UserAccount` SwiftData model** for MVP.
2. **SwiftData will store “recipes + logs only.”** Preferences like Apple user identifier and `syncEnabled` are not part of SwiftData.
3. **CloudKit compatibility is required from day 1** (SwiftData + CloudKit private database).
4. Use a **single `Recipe` model** with `isStarter: Bool` and `origin: RecipeOrigin` (e.g., `.starterTemplate`, `.custom`, `.conflictedCopy`); enforce starter immutability/deletability in repository/business rules (not in DB).
5. Model **`Recipe` 1-to-many `RecipeStep`** with `orderIndex: Int` and stable `stepId: UUID`; steps are owned by recipe and deleted with it.
6. `BrewLog` will store a **snapshot** of brew-time parameters (recipe name at brew, dose/yield/temp/grind used; step summary optional) and may optionally reference a `Recipe` for navigation.
7. **Scaling/derived values are computed on the fly** (not persisted as derived fields).
8. Use **`Double`** for numeric fields; **no validation in the database layer** (validation/rules handled outside persistence).
9. Use **Swift enums with `String` raw values** for stable storage (e.g., method, grind label, taste tag, origin).
10. **Indexing/query planning is minimal**: primary fetch needs are `BrewLog.timestamp` (descending) and `Recipe.method`; last selected recipe will not be stored in the database.
11. **Sync conflicts are ignored for now** (no conflicted-copy handling implemented in MVP).
12. **No deletion request record** will be added for MVP.
</decisions>

<matched_recommendations>
1. **Keep SwiftData for recipes + logs only** and store preferences outside the model (fits your “SwiftData as recipes + logs only” decision).
2. **Design models as CloudKit-compatible now** (defaults for properties, optional relationships) since CloudKit is required from day 1.
3. **Single `Recipe` entity with `isStarter` + `origin`** to simplify lists and logic; enforce starter protection via repository/business rules.
4. **`Recipe` → `RecipeStep` composition** with stable step identity (`stepId`) and explicit ordering (`orderIndex`); cascade delete steps with recipe.
5. **`BrewLog` snapshot strategy** (store brew-time parameters) plus optional recipe reference for navigation to preserve historical accuracy after recipe edits.
6. **Compute scaling/derived values in Domain/UI** (not stored), aligned with “compute on the fly.”
7. **Use string-backed enums** for CloudKit-friendly persistence and forward compatibility.
8. **Keep query patterns simple** around `BrewLog.timestamp` and `Recipe.method` to support MVP screens.
</matched_recommendations>

<database_planning_summary>
**a. Main requirements for the database**
- Persist only **Recipes** (starter + custom) and **Brew Logs**.
- Must be **SwiftData with CloudKit (private DB) from day 1**.
- Support: recipe duplication/editing (custom only), step-based recipes, guided brew logging, and historical log integrity via snapshots.
- Preferences/auth state (Apple user identifier, sync enabled, last-selected recipe) are **not stored in SwiftData**.

**b. Key entities and their relationships**
- **`Recipe`**
  - Attributes: `isStarter: Bool`, `origin: RecipeOrigin` (String raw value), `method` (e.g., `.v60`), name, default dose/yield/temp, grind guidance fields (per PRD), validity state (if tracked outside DB it can be computed; if persisted then a Bool).
  - Relationship: **1-to-many** with `RecipeStep`.
- **`RecipeStep`**
  - Attributes: `stepId: UUID`, `orderIndex: Int`, plus step-specific fields (instruction text, optional timer metadata, optional water amount guidance) as needed by PRD.
  - Owned by recipe; deleted when recipe is deleted.
- **`BrewLog`**
  - Attributes (snapshot): timestamp, method, `recipeNameAtBrew`, dose, target yield, temperature, grind label, rating (1–5), optional taste tag, optional note.
  - Relationship: optional link to `Recipe` for navigation (historical integrity relies on snapshot, not the relationship).

**c. Important security and scalability concerns**
- **Security / isolation**: CloudKit private database provides **per-user isolation**; no separate `UserAccount` entity is persisted.
- **Data integrity**: You chose **no DB-layer validation**; therefore, correctness depends on Domain/repository rules (e.g., rounding, step sum tolerance, required rating on save).
- **Scalability**: MVP query needs are simple (logs by timestamp, recipes by method). Brew logs can grow large; list rendering should rely on snapshot fields stored on `BrewLog` to avoid heavy joins.

**d. Unresolved issues / clarification needed**
- See list below.
</database_planning_summary>

<unresolved_issues>
1. **Where are `appleUserId` and `syncEnabled` stored exactly** (e.g., `UserDefaults`, Keychain for identifier, or another local store), and are they ever synced?
2. **Stable IDs for `Recipe` and `BrewLog`**: you specified `stepId`, but not whether recipes/logs have explicit `id: UUID` fields (recommended if logs optionally reference recipes and for future sync stability).
3. **Deletion semantics**: When a `Recipe` is deleted, should existing `BrewLog` links be nulled while keeping logs (likely), and should deletion cascade ever remove logs (probably not)?
4. **Step modeling details**: confirm step “kinds” and which step fields are optional vs always present (instruction-only vs timed vs water-addition vs timer guidance).
5. **Conflict behavior explicitly deferred**: since CloudKit is on day 1 but conflicts are ignored, define what “ignored” means (last-writer-wins? duplicates? user-visible issues?) so data loss risks are understood.
6. **Validation/guardrails location**: since DB validation is off, specify the minimum Domain validations required for MVP (e.g., rating required, note max length, non-negative timers) to prevent persisting unusable data.
</unresolved_issues>
</conversation_summary>

