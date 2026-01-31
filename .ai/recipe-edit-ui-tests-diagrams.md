# Recipe Edit UI Test Flow Diagrams

## Test 1: testRecipeEditValidateSaveFlow (Happy Path)

```
┌─────────────────────────────────────────────────────────────────┐
│                     HAPPY PATH TEST FLOW                        │
└─────────────────────────────────────────────────────────────────┘

   START
     │
     ├─→ Launch App
     │
     ├─→ Navigate to Recipes Tab
     │      └─ Tap "Recipes" tab button
     │
     ├─→ Find/Create Custom Recipe
     │      ├─ If "My Recipes" exists:
     │      │    └─→ Tap existing custom recipe
     │      │    └─→ Tap "Edit" button
     │      │
     │      └─ If no custom recipes:
     │           └─→ Tap starter recipe
     │           └─→ Tap "Duplicate" button
     │
     ├─→ Verify Edit View Loaded
     │      └─ Assert: "Edit Recipe" title visible
     │
     ├─→ Modify Recipe Fields
     │      ├─→ Name: Append " - Modified [timestamp]"
     │      ├─→ Dose: Change to "18.5"
     │      └─→ Yield: Change to "308"
     │
     ├─→ Verify Validation State
     │      ├─ Check for validation banner
     │      └─ Assert: Save button exists
     │
     ├─→ Save Recipe
     │      ├─ If save button enabled:
     │      │    └─→ Tap "Save"
     │      │    └─→ Wait for edit view to dismiss
     │      │    └─→ Assert: Back at detail/list view
     │      │    └─→ Assert: Modified name visible
     │      │
     │      └─ If save button disabled:
     │           └─→ Assert: Validation errors shown
     │
     └─→ END (PASS)
```

## Test 2: testRecipeEditValidationErrors (Error Handling)

```
┌─────────────────────────────────────────────────────────────────┐
│                  VALIDATION ERROR TEST FLOW                     │
└─────────────────────────────────────────────────────────────────┘

   START
     │
     ├─→ Launch App
     │
     ├─→ Navigate to Recipes Tab
     │
     ├─→ Find Recipe
     │      └─→ Tap first recipe
     │
     ├─→ Enter Edit Mode
     │      ├─ Tap "Edit" button (if exists)
     │      └─ OR Tap "Duplicate" button
     │
     ├─→ Verify Edit View Loaded
     │
     ├─→ Create Validation Error
     │      └─→ Clear name field (make it empty)
     │          ├─ Tap name field
     │          ├─ Triple-tap to select all
     │          └─ Press delete key
     │
     ├─→ Trigger Validation
     │      └─→ Tap "Recipe Defaults" label
     │
     ├─→ Verify Error State
     │      ├─→ Assert: Error message visible
     │      │      └─ Contains "issue" OR "Required"
     │      │
     │      └─→ Assert: Save button disabled
     │
     ├─→ Attempt to Save (Should Fail)
     │      └─→ Tap "Save" button
     │
     ├─→ Verify Save Blocked
     │      └─→ Assert: Still in edit view
     │          └─ "Edit Recipe" title still visible
     │
     └─→ END (PASS)
```

## Test 3: testRecipeEditCancelWithUnsavedChanges (Cancel Flow)

```
┌─────────────────────────────────────────────────────────────────┐
│                   CANCEL WITH CHANGES FLOW                      │
└─────────────────────────────────────────────────────────────────┘

   START
     │
     ├─→ Launch App
     │
     ├─→ Navigate to Recipes Tab
     │
     ├─→ Find Recipe
     │      └─→ Tap first recipe
     │
     ├─→ Enter Edit Mode
     │      ├─ Tap "Edit" button (if exists)
     │      └─ OR Tap "Duplicate" button
     │
     ├─→ Verify Edit View Loaded
     │
     ├─→ Make Changes (Mark as Dirty)
     │      └─→ Modify name field
     │          └─ Append " Test Change"
     │
     ├─→ Cancel Edit
     │      └─→ Tap "Cancel" button
     │
     ├─→ Verify Discard Dialog
     │      ├─→ Assert: Dialog appears
     │      │      └─ Title: "Discard changes?"
     │      │
     │      └─→ Options visible:
     │          ├─ "Discard Changes" (destructive)
     │          └─ "Keep Editing" (cancel)
     │
     ├─→ Confirm Discard
     │      └─→ Tap "Discard Changes"
     │
     ├─→ Verify Navigation
     │      ├─→ Assert: Edit view dismissed
     │      │      └─ "Edit Recipe" title not visible
     │      │
     │      └─→ Assert: Back at previous view
     │          └─ Navigation bar visible
     │
     └─→ END (PASS)
```

## State Diagram: Recipe Edit View States

```
┌─────────────────────────────────────────────────────────────────┐
│                  RECIPE EDIT VIEW STATES                        │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────┐
                    │  LOADING │
                    └────┬─────┘
                         │
                         ↓
                    ┌──────────┐
                    │  LOADED  │◄─────────┐
                    │  (Clean) │          │
                    └────┬─────┘          │
                         │                │
            ┌────────────┼────────────┐   │
            │            │            │   │
            ↓            ↓            ↓   │
      ┌──────────┐ ┌──────────┐ ┌──────────┐
      │  DIRTY   │ │  DIRTY   │ │  DIRTY   │
      │  VALID   │ │ INVALID  │ │ SAVING   │
      └────┬─────┘ └────┬─────┘ └────┬─────┘
           │            │            │
           │            │            ├─(success)───►
           │            │            │
           ├─(save)─────┤            └─(error)─────►┌──────────┐
           │            │                            │  ERROR   │
           │            │                            │  STATE   │
           │            │                            └──────────┘
           │            │
           │            └─(fix errors)───┐
           │                             │
           └─────────(cancel w/ changes)─┴──►┌──────────────┐
                                             │   CONFIRM    │
                                             │   DISCARD    │
                                             └──────┬───────┘
                                                    │
                                        ┌───────────┼───────────┐
                                        │                       │
                                   (discard)            (keep editing)
                                        │                       │
                                        ↓                       ↓
                                   ┌─────────┐           ┌──────────┐
                                   │ DISMISS │           │ RETURN   │
                                   └─────────┘           └──────────┘
```

## Validation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     VALIDATION FLOW                             │
└─────────────────────────────────────────────────────────────────┘

   User Edits Field
         │
         ↓
   ┌────────────────────┐
   │  Field onChange    │
   │  Handler Called    │
   └─────────┬──────────┘
             │
             ↓
   ┌────────────────────┐
   │ ViewModel Updates  │
   │    Draft State     │
   └─────────┬──────────┘
             │
             ↓
   ┌────────────────────┐
   │   Validation       │
   │   Recomputed       │
   └─────────┬──────────┘
             │
   ┌─────────┴─────────┐
   │                   │
   ↓                   ↓
┌────────┐      ┌────────────┐
│ VALID  │      │  INVALID   │
└───┬────┘      └─────┬──────┘
    │                 │
    ↓                 ↓
┌────────────┐   ┌──────────────┐
│ Save       │   │ Validation   │
│ Enabled    │   │ Error Banner │
│            │   │   Visible    │
│ No Banner  │   │              │
└────────────┘   │ Save         │
                 │ Disabled     │
                 └──────────────┘
```

## UI Element Hierarchy

```
BrewGuide App
│
├─ Tab Bar
│  └─ Recipes Tab ──────────────────────────────┐
│                                                │
├─ Recipe List View                             │
│  ├─ Starter Section                           │
│  │  └─ RecipeRow_[name]                       │
│  │     └─ (Tap) → Recipe Detail View          │
│  │                                             │
│  └─ My Recipes Section                        │
│     └─ RecipeRow_[name]                       │
│        └─ (Tap) → Recipe Detail View          │
│                                                │
└─ Recipe Detail View ◄─────────────────────────┘
   ├─ Toolbar
   │  ├─ Duplicate Button (starter recipes)
   │  └─ Edit Button (custom recipes)
   │     │
   │     └─────────────────────┐
   │                           ↓
   └─ Recipe Edit View ◄───────┘
      ├─ Navigation Bar
      │  └─ Title: "Edit Recipe"
      │
      ├─ Validation Banner (conditional)
      │
      ├─ Recipe Defaults Section
      │  ├─ RecipeNameField
      │  ├─ DefaultDoseField
      │  ├─ TargetYieldField
      │  ├─ WaterTemperatureField
      │  └─ Grind Label Picker
      │
      ├─ Steps Section
      │  ├─ Add Step Button
      │  └─ Step Cards...
      │
      └─ Action Bar (bottom)
         ├─ RecipeEditCancelButton
         └─ RecipeEditSaveButton
            └─ Enabled: canSave && isDirty && !isSaving
```

## Accessibility Identifier Map

```
UI Element                    Accessibility ID
═══════════════════════════   ══════════════════════════════
Tab Bar Button               "Recipes"
Recipe Row                   "RecipeRow_[recipeName]"
Edit Button                  "Edit"
Duplicate Button             "Duplicate"

Edit View Elements:
  Recipe Name Field          "RecipeNameField"
  Dose Field                 "DefaultDoseField"
  Yield Field                "TargetYieldField"
  Temperature Field          "WaterTemperatureField"
  Cancel Button              "RecipeEditCancelButton"
  Save Button                "RecipeEditSaveButton"

Dialogs:
  Discard Dialog             "Discard changes?" (alert/sheet)
  Discard Button             "Discard Changes"
  Keep Editing Button        "Keep Editing"
```

## Test Execution Timeline

```
Time (seconds)    Test Activity
═════════════     ═══════════════════════════════════════════
0                 Launch app
1-2               Navigate to Recipes tab
3-4               Load recipe list
5                 Tap recipe row
6-7               Load recipe detail
8                 Tap Edit/Duplicate button
9-11              Edit view loads
12-15             Modify fields (name, dose, yield)
16-17             Dismiss keyboard, trigger validation
18-20             Tap Save button
21-25             Save processing
26-30             Navigate back, verify results

TOTAL: ~30-60 seconds per test
```

---

*These diagrams represent the actual implementation of the Recipe Edit UI tests*  
*Created: January 31, 2026*
