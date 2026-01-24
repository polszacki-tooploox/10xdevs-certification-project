<conversation_summary>
<decisions>
1. Target user: beginner-to-intermediate home brewer focused on repeatability/consistency.
2. Primary context: phone on kitchen counter, wet hands, one-handed, low attention; user has a grinder, a 0.1g scale, and a kettle with temperature readout.
3. MVP brew modes: V60, AeroPress, Espresso.
4. Guided brewing UX: lock all parameter editing once a brew starts; large separated primary actions (“Next step”, “Pause”); confirm/press-and-hold for “Restart”.
5. Units: standardize on grams for dose, pours, and yield across the app.
6. Grind guidance: simple method-specific labels (fine/medium/coarse) with 2–3 tactile descriptors (e.g., flour/sand/sea salt); provide a minimal post-brew adjustment hint (e.g., “Too sour? Go slightly finer”) without personalization.
7. Recipe library scope: exactly 1 starter recipe per method for MVP.
8. Recipe model and editing: structured, step-based recipes with timers and quantitative steps; editing is guardrailed with validation; users “duplicate and edit” rather than overwriting the original starter recipe; offer auto-fix for invalid edits.
9. Scaling behavior: explicit per-method scaling rules with validated ranges and warnings; clamp out-of-range values; offer a one-tap reset to defaults.
10. Espresso guidance in MVP: generic flow (dose, target yield, target time window, start/stop prompts) without machine-specific profiling.
11. Timer behavior: support pause/resume/restart only; no background/lock-screen handling in MVP; interruptions/resume behavior not addressed.
12. Brew log: post-brew “Save” is the default action; collect a 1–5 rating with optional quick tag (“too bitter/sour/weak/strong”) and optional note.
13. Analytics: no analytics instrumentation in MVP.
14. Platform: iOS-only for MVP.
15. Accounts/sync: include Sign in with Apple; synchronize essential data only (user ID, custom recipes, brew logs, basic preferences) to an online service.
16. Success criteria usage: the numeric targets (60% completion, 40% saved with rating/note, ≥3.5/5 after week one) are kept as planning goals; measurement is not implemented in MVP.
</decisions>

<matched_recommendations>
1. Focus on a single primary persona to keep the MVP opinionated and avoid conflicting UX needs (chosen: beginner-to-intermediate seeking repeatability).
2. Optimize for low-attention, wet-hands counter use with large primary actions and constrained interaction during brewing (implemented via locked edits + clear controls + restart confirmation).
3. Use method-specific grind guidance that is relative and descriptive (fine/medium/coarse + tactile references) rather than precise grinder calibration (adopted).
4. Implement per-method scaling constraints with guardrails (validated ranges, warnings, clamping, and reset to defaults) (adopted).
5. Use a structured, step-based recipe model and prefer “duplicate & edit” rather than overwriting starter recipes; validate edits and offer auto-fix (adopted).
6. Use a streamlined first-run funnel: Method → Starter Recipe (default preselected) → Confirm inputs → Brew (adopted).
7. Make saving the brew a default post-brew step with lightweight feedback capture (rating + optional tags/note) to increase logging rates (adopted, with quick taste tag).
8. Prefer Sign in with Apple for iOS and sync only essential entities to minimize account-management scope (adopted).
9. Standardize measurements on grams to align with scale-based brewing and reduce unit confusion (adopted).
10. Keep espresso MVP guidance generic (ratio/yield/time window + start/stop prompts) to avoid machine-specific complexity (adopted).
</matched_recommendations>

<prd_planning_summary>
a) Main functional requirements (MVP)
- Platforms & accounts
  - iOS-only application.
  - Authentication via Sign in with Apple.
  - Cloud synchronization for essential data: user profile identifier, custom/edited recipes (as duplicates), brew logs, and basic preferences.
- Core product goal
  - Improve home-brew consistency by guiding users through a recipe with clear parameters and timed steps, and enabling lightweight reflection to support incremental adjustment.
- Brew mode selection
  - Supported methods: V60, AeroPress, Espresso.
- Recipe library
  - One starter recipe per method.
  - Starter recipes are editable via “duplicate & edit”; originals remain intact.
- Guided brewing flow
  - Flow: Method → Starter Recipe (default preselected) → Confirm inputs → Brew.
  - Inputs include: coffee dose (g), target yield (g), coarse grind guidance, water temperature.
  - Step-by-step instruction sequence with timers and quantitative step details (e.g., bloom + pours, steep + plunge, espresso start/stop with time window).
  - Controls: Start, Pause, Resume, Restart (restart guarded by confirmation/press-and-hold), Next Step.
  - Parameter editing is locked once brew starts.
  - No background/lock-screen handling; interruptions are not addressed in MVP.
- Scaling
  - Automatic scaling when dose or yield changes, within method constraints.
  - Guardrails: validated ranges and warnings, clamping out-of-range values, and a one-tap reset to defaults.
- Brew log
  - Post-brew save is the default action.
  - Save includes: method, recipe used, key parameters, timestamp, 1–5 rating, optional quick taste tag (too bitter/sour/weak/strong), optional short note.

b) Key user stories and usage paths
- First-time user, guided brew
  - As a beginner-to-intermediate brewer, I select a method, accept the default starter recipe, confirm dose/yield/temp/grind guidance, and follow timed steps with minimal interaction to complete a brew.
- Adjusting brew parameters with scaling
  - As a user, I change dose or target yield before starting, and the app scales the recipe steps/quantities within safe bounds and warns/clamps if outside recommended ranges.
- Logging and reflection
  - As a user, after finishing, I quickly save the brew with a one-tap rating and optional taste tag (and note) so I can remember outcomes and guide my next adjustment.
- Recipe customization
  - As a user, I duplicate a starter recipe and make small edits (ratio/temp/timers/pour weights) with validation and auto-fix to keep the recipe usable.

c) Success criteria and ways to measure them
- Defined success criteria (as planning targets, not MVP-instrumented)
  - ≥60% of users who start a brew flow complete it.
  - ≥40% of completed brews are saved with a rating or note.
  - ≥3.5/5 average rating across logged brews after the first week.
- Measurement approach (MVP decision)
  - No analytics in MVP; targets are retained as guiding goals for planning and future instrumentation rather than measured metrics.

d) Design constraints and implications
- “Kitchen-proof” UX: low attention, wet hands, one-handed usage requires large controls, minimal typing, and locking edits during brew.
- Units and inputs: grams-only aligns with the expected scale usage and reduces ambiguity.
- Scope control: one recipe per method keeps content and QA manageable; guardrailed editing and scaling constrain complexity while enabling customization.
- Interruption handling is explicitly out of MVP: no background timer guarantees and no lock-screen experience.
</prd_planning_summary>

<unresolved_issues>
- Backend/sync specifics: data storage choice, offline-first behavior, conflict resolution strategy, and security/privacy requirements for synced brew logs and recipes.
- Exact per-method constraints and scaling rules: recommended ranges for dose/yield/ratio, temperature bounds, and any step-level scaling logic per method.
- Starter recipe definitions: the concrete parameters and step sequences for the single V60/AeroPress/Espresso recipes (ratios, timings, step counts, and pour structure).
- Espresso “time window” defaults: target time range and how it’s communicated without implying machine calibration.
- Interruption consequences: since background handling is ignored, specify the expected user-visible behavior if the app is minimized or the screen locks mid-brew (even if it is “not supported,” UX copy/state should be defined).
</unresolved_issues>
</conversation_summary>

