# Quick Start: Adding New Files to Xcode Project

## Files Created (Need to be Added)

All files have been created in the correct directories but are not yet part of the Xcode project compilation.

### Method 1: Add via Xcode (Recommended)

1. **Open the project**
   ```bash
   open BrewGuide/BrewGuide.xcodeproj
   ```

2. **Add AppShell folder**
   - In Project Navigator, right-click on `UI` folder
   - Select "Add Files to BrewGuide..."
   - Navigate to `BrewGuide/BrewGuide/UI/AppShell`
   - Select the `AppShell` folder
   - ✅ Check "Create groups"
   - ✅ Check "BrewGuide" target
   - Click "Add"

3. **Add new Screen files**
   - Right-click on `UI/Screens` in Project Navigator
   - "Add Files to BrewGuide..."
   - Select these files:
     - `RecipeListView.swift`
     - `PostBrewView.swift`
     - `DataDeletionRequestView.swift`
   - ✅ Check "Create groups"
   - ✅ Check "BrewGuide" target
   - Click "Add"

4. **Add Domain files**
   - Right-click on `Domain` folder
   - "Add Files to BrewGuide..."
   - Select these files:
     - `BrewSessionUseCase.swift`
     - `PreferencesStore.swift`
   - ✅ Check "Create groups"
   - ✅ Check "BrewGuide" target
   - Click "Add"

5. **Build the project**
   ```
   Product → Build (⌘B)
   ```

### Method 2: Add Individual Files

If you prefer to add files one by one:

1. Right-click the appropriate folder in Project Navigator
2. Choose "Add Files to BrewGuide..."
3. Select a single file
4. Ensure "Create groups" and "BrewGuide" target are checked
5. Click "Add"
6. Repeat for each file

### Files List

**UI/AppShell/** (5 files)
```
- AppTab.swift
- NavigationRoutes.swift
- BrewSessionPresentation.swift
- AppRootCoordinator.swift
- AppRootView.swift
```

**UI/Screens/** (3 new files)
```
- RecipeListView.swift
- PostBrewView.swift
- DataDeletionRequestView.swift
```

**Domain/** (2 files)
```
- BrewSessionUseCase.swift
- PreferencesStore.swift
```

### Already Updated (No Action Needed)
```
✓ App/BrewGuideApp.swift
✓ UI/Screens/ConfirmInputsView.swift
✓ UI/Screens/BrewSessionFlowView.swift
✓ UI/Screens/LogsListView.swift
✓ UI/Screens/SettingsView.swift
```

## Verification Steps

After adding files:

1. **Clean Build Folder**
   ```
   Product → Clean Build Folder (⌘⇧K)
   ```

2. **Build**
   ```
   Product → Build (⌘B)
   ```

3. **Check for Errors**
   - If you see "Cannot find type in scope" errors, the files weren't added to the target
   - Right-click the file → Show File Inspector → ensure "BrewGuide" is checked under Target Membership

4. **Run**
   ```
   Product → Run (⌘R)
   ```

## Expected Result

The app should:
1. ✅ Launch to AppRootView with three tabs
2. ✅ Show Recipes tab by default (ConfirmInputsView)
3. ✅ Display a recipe with editable brew parameters
4. ✅ Allow "Start Brewing" to open full-screen brew flow
5. ✅ Navigate to recipe list via toolbar button
6. ✅ Switch to Logs tab (show recent brews)
7. ✅ Switch to Settings tab

## Troubleshooting

### Build Error: "Cannot find type 'AppRootView'"
**Solution**: `AppRootView.swift` not added to target
- Find file in Project Navigator
- File Inspector (⌥⌘1)
- Check "BrewGuide" under Target Membership

### Build Error: "Cannot find type 'AppRootCoordinator'"
**Solution**: `AppRootCoordinator.swift` not added to target
- Follow same steps as above

### Build Error: Missing imports
**Solution**: Files in wrong location
- Verify files are in correct folders:
  - `UI/AppShell/` for coordinator and types
  - `UI/Screens/` for views
  - `Domain/` for use cases

### Runtime Error: Crash on launch
**Solution**: Check console for specifics
- Likely a SwiftData query issue
- Ensure recipes exist (DatabaseSeeder should run on first launch)

## Testing the Implementation

### Smoke Test
1. Launch app
2. Verify Recipes tab is selected
3. Check if a recipe is loaded
4. Tap "Recipes" toolbar button → see recipe list
5. Tap "Start Brewing" → see brew flow modal
6. Tap "Exit" → confirm and return to recipes
7. Switch to Logs tab → see recent brews (if any)
8. Switch to Settings tab → see sections
9. Navigate to "Request Data Deletion"

### Full Flow Test
1. Launch app
2. Adjust brew parameters (dose/yield)
3. Verify ratio updates
4. Tap "Start Brewing"
5. Wait for timer or tap "Skip"
6. Advance through all steps
7. Rate the brew (tap stars)
8. Select a taste tag
9. Add notes
10. Tap "Save Brew"
11. Return to main screen
12. Switch to Logs tab → verify new log appears

## Next Development Steps

See `IMPLEMENTATION_SUMMARY.md` for:
- Detailed architecture documentation
- Future enhancement opportunities
- Testing recommendations
- Integration points
