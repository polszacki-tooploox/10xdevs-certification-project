# Domain Unit Tests - File Locations

## Complete File Structure

```
BrewGuide/BrewGuideTests/
├── DOMAIN_TESTS_SUMMARY.md          # This summary document
├── FILE_LOCATIONS.md                # This file
│
├── Fakes/                           # Test Doubles (Mocks/Stubs/Fakes)
│   ├── FakeRecipeRepository.swift
│   ├── FakeBrewLogRepository.swift
│   ├── FakeAuthSessionStore.swift
│   ├── FakeSyncSettingsStore.swift
│   └── FakeSyncStatusStore.swift
│
├── Fixtures/                        # Test Data Builders
│   ├── RecipeFixtures.swift
│   ├── BrewLogFixtures.swift
│   └── DTOFixtures.swift
│
└── Domain/                          # Domain Layer Test Suites
    ├── ScalingServiceTests.swift
    ├── RecipeUseCaseTests.swift
    ├── BrewSessionUseCaseTests.swift
    ├── BrewLogUseCaseTests.swift
    ├── AuthUseCaseTests.swift
    ├── SyncUseCaseTests.swift
    └── DTOValidationTests.swift
```

## File Paths (Absolute)

### Test Infrastructure
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fakes/FakeRecipeRepository.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fakes/FakeBrewLogRepository.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fakes/FakeAuthSessionStore.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fakes/FakeSyncSettingsStore.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fakes/FakeSyncStatusStore.swift`

### Test Fixtures
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fixtures/RecipeFixtures.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fixtures/BrewLogFixtures.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Fixtures/DTOFixtures.swift`

### Test Suites
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/ScalingServiceTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/RecipeUseCaseTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/BrewSessionUseCaseTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/BrewLogUseCaseTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/AuthUseCaseTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/SyncUseCaseTests.swift`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/Domain/DTOValidationTests.swift`

### Documentation
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/DOMAIN_TESTS_SUMMARY.md`
- `/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide/BrewGuideTests/FILE_LOCATIONS.md`

## Xcode Project Integration

### Adding Files to Xcode
1. In Xcode, right-click on `BrewGuideTests` folder
2. Select "Add Files to BrewGuide..."
3. Navigate to the test files directory
4. Select all new files (hold Cmd to multi-select)
5. Ensure "Copy items if needed" is **unchecked** (files are already in place)
6. Ensure "BrewGuideTests" target is checked
7. Click "Add"

### Folder Structure in Xcode
Organize as:
```
BrewGuideTests/
├── Fakes/
├── Fixtures/
├── Domain/
└── Documentation/
```

## Quick Stats
- **Total Files Created:** 17
- **Fakes:** 5 files
- **Fixtures:** 3 files
- **Test Suites:** 7 files
- **Documentation:** 2 files
- **Total Test Cases:** 132 tests
- **Lines of Code:** ~3,500+ lines

## Next Steps
1. Add all files to Xcode project (follow instructions above)
2. Build the test target: `Cmd + Shift + U`
3. Run all tests: `Cmd + U`
4. Verify all 132 tests pass
5. Check code coverage in Xcode Report Navigator

## Notes
- All files use Swift Testing framework (not XCTest)
- All test files use `@testable import BrewGuide`
- MainActor isolation used where appropriate
- No external dependencies required
