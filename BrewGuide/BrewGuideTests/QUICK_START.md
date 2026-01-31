# Domain Unit Tests - Quick Start Guide

## Running the Tests

### Via Xcode
1. **Run All Tests:** `Cmd + U`
2. **Run Single Suite:** Click ▶ next to `@Suite` annotation
3. **Run Single Test:** Click ▶ next to `@Test` annotation

### Via Command Line
```bash
# Navigate to project directory
cd "/Users/polszacki/Documents/10xDevs/10xDevs project/BrewGuide"

# Run all tests
xcodebuild test -scheme BrewGuide -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific suite
xcodebuild test -scheme BrewGuide -only-testing:BrewGuideTests/ScalingServiceTests

# Run specific test
xcodebuild test -scheme BrewGuide \
  -only-testing:BrewGuideTests/ScalingServiceTests/testDoseEditTriggersYieldRecalculation
```

## Verification Checklist

### ✅ Initial Setup
- [ ] All 17 files added to Xcode project
- [ ] Files organized in correct folder structure
- [ ] Build succeeds (`Cmd + B`)
- [ ] Test target builds (`Cmd + Shift + U`)

### ✅ Test Execution
- [ ] All 132 tests pass (0 failures)
- [ ] No compiler warnings in test files
- [ ] Tests complete in < 10 seconds
- [ ] No flaky tests (run 3+ times, all pass)

### ✅ Coverage Verification
1. In Xcode: `Product → Test` (Cmd + U)
2. Open Report Navigator (Cmd + 9)
3. Select latest test run
4. Click "Coverage" tab
5. Verify Domain layer coverage ≥ 80%

Expected Coverage by File:
- `ScalingService.swift`: ~95%
- `RecipeUseCase.swift`: ~90%
- `BrewSessionUseCase.swift`: ~90%
- `BrewLogUseCase.swift`: ~90%
- `AuthUseCase.swift`: ~75% (session management only)
- `SyncUseCase.swift`: ~60% (business logic, CloudKit requires integration)
- DTOs (validation methods): ~100%

## Test Summary by Suite

| Suite | Tests | Focus |
|-------|-------|-------|
| ScalingServiceTests | 19 | Dose/yield scaling, rounding, V60 targets, warnings |
| RecipeUseCaseTests | 20 | CRUD, validation, starter protection |
| BrewSessionUseCaseTests | 14 | Plan creation, scaling, error handling |
| BrewLogUseCaseTests | 16 | Log CRUD, ordering, DTO mapping |
| AuthUseCaseTests | 10 | Session management, sign out, restoration |
| SyncUseCaseTests | 15 | Sync enable/disable, status tracking |
| DTOValidationTests | 38 | Request validation rules |
| **TOTAL** | **132** | |

## Common Issues & Solutions

### Issue: Tests not found
**Solution:** 
- Verify files are added to BrewGuideTests target (not BrewGuide target)
- Check File Inspector (Cmd + Option + 1) → Target Membership

### Issue: Import errors
**Solution:**
- Ensure `@testable import BrewGuide` at top of each test file
- Verify BrewGuide scheme includes test target

### Issue: MainActor errors
**Solution:**
- Verify `@MainActor` attribute on test suites that need it:
  - RecipeUseCaseTests
  - BrewSessionUseCaseTests
  - BrewLogUseCaseTests
  - AuthUseCaseTests
  - SyncUseCaseTests

### Issue: Fake repositories not working
**Solution:**
- Check that fakes properly initialize ModelContext
- Verify test fixtures create valid entities

### Issue: Async test timeouts
**Solution:**
- Ensure `await` is used with async test functions
- Check that async use cases complete properly

## Test Patterns Reference

### Basic Test Structure
```swift
@Test("Description matching Test Plan scenario")
func testMethodName() {
    // Arrange: Setup test data
    let repository = FakeRecipeRepository()
    let useCase = RecipeUseCase(repository: repository)
    
    // Act: Execute system under test
    let result = try useCase.someMethod()
    
    // Assert: Verify outcomes
    #expect(result == expectedValue)
}
```

### Async Test
```swift
@Test("Async operation completes successfully")
func testAsyncMethod() async throws {
    // Arrange
    let useCase = makeUseCase()
    
    // Act
    let result = try await useCase.asyncMethod()
    
    // Assert
    #expect(result.isSuccess)
}
```

### Error Testing
```swift
@Test("Invalid input throws expected error")
func testErrorHandling() {
    // Arrange
    let useCase = makeUseCase()
    
    // Act & Assert
    #expect(throws: ExpectedError.self) {
        try useCase.methodThatThrows()
    }
}
```

### Parameterized Testing
```swift
@Test("All valid ratings 1-5 pass validation")
func testValidRatings() {
    for rating in 1...5 {
        let request = makeRequest(rating: rating)
        let errors = request.validate()
        #expect(errors.isEmpty)
    }
}
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run Domain Tests
  run: |
    xcodebuild test \
      -scheme BrewGuide \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      -only-testing:BrewGuideTests/Domain
```

### Coverage Report
```yaml
- name: Generate Coverage Report
  run: |
    xcodebuild test \
      -scheme BrewGuide \
      -enableCodeCoverage YES \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Performance Benchmarks

Expected execution times (approximate):
- ScalingServiceTests: < 1s
- RecipeUseCaseTests: < 2s
- BrewSessionUseCaseTests: < 1s
- BrewLogUseCaseTests: < 1s
- AuthUseCaseTests: < 1s
- SyncUseCaseTests: < 1s
- DTOValidationTests: < 2s

**Total:** < 10 seconds for all Domain tests

## Test Maintenance

### When Adding New Domain Logic
1. Write test first (TDD approach)
2. Use existing fixtures/fakes
3. Add new fixture methods if needed
4. Follow naming conventions
5. Map test to Test Plan scenario (if applicable)

### When Modifying Domain Logic
1. Update affected tests
2. Add tests for new behavior
3. Ensure all tests pass
4. Update documentation if needed

### When Refactoring Tests
1. Keep test names descriptive
2. Maintain AAA pattern
3. Don't break existing coverage
4. Update fixtures if needed

## Additional Resources

- **Test Plan:** `.ai/test-plan.md`
- **Domain Code:** `BrewGuide/Domain/`
- **Test Summary:** `BrewGuideTests/DOMAIN_TESTS_SUMMARY.md`
- **File Locations:** `BrewGuideTests/FILE_LOCATIONS.md`
- **Swift Testing Docs:** [developer.apple.com/testing](https://developer.apple.com/documentation/testing)

## Support

For issues or questions:
1. Check this guide first
2. Review test summary document
3. Inspect test file comments
4. Run individual tests to isolate issues

---

**Quick Command Reference:**
```bash
# Build tests
xcodebuild build-for-testing -scheme BrewGuide

# Run tests
xcodebuild test -scheme BrewGuide

# Clean and test
xcodebuild clean test -scheme BrewGuide

# Test with coverage
xcodebuild test -scheme BrewGuide -enableCodeCoverage YES
```
