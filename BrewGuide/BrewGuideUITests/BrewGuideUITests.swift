//
//  BrewGuideUITests.swift
//  BrewGuideUITests
//
//  Created by Przemysław Olszacki on 24/01/2026.
//

import XCTest

extension XCUIElement {
    /**
     Removes any current text in the field before typing in the new value
     - Parameter text: the text to enter into the field
     */
    func clearAndEnterText(text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }

        self.tap()

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)

        self.typeText(deleteString)
        self.typeText(text)
    }
}

final class BrewGuideUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Recipe Edit Flow Tests
    
    /// Tests the complete Edit -> Validate -> Save end-to-end flow for custom recipes
    /// Flow: Recipe List -> Recipe Detail -> Edit -> Modify Fields -> Validate -> Save
    @MainActor
    func testRecipeEditValidateSaveFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully load
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        // STEP 1: Navigate to Recipes tab
        let recipesTab = app.tabBars.buttons["Recipes"]
        XCTAssertTrue(recipesTab.waitForExistence(timeout: 3), "Recipes tab should exist")
        recipesTab.tap()
        
        // Wait for recipe list to load
        sleep(2) // Give time for list to populate
        
        // STEP 2: Find and tap a custom recipe (not starter)
        // Look for "My Recipes" section header
        let myRecipesHeader = app.staticTexts["My Recipes"]
        
        // If no custom recipes exist, create one by duplicating a starter recipe
        if !myRecipesHeader.exists {
            // Tap the first starter recipe in the list
            let firstRecipeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'RecipeRow_'")).firstMatch
            XCTAssertTrue(firstRecipeButton.waitForExistence(timeout: 3), "First recipe should exist")
            firstRecipeButton.tap()
            
            // Wait for detail view to load
            sleep(1)
            
            // Tap the Duplicate button
            let duplicateButton = app.buttons["Duplicate"]
            XCTAssertTrue(duplicateButton.waitForExistence(timeout: 3), "Duplicate button should exist")
            duplicateButton.tap()
            
            // Wait for edit view to appear after duplication
            let editTitle = app.navigationBars["Edit Recipe"]
            XCTAssertTrue(editTitle.waitForExistence(timeout: 5), "Edit view should appear after duplication")
        } else {
            // Tap an existing custom recipe (look for one under "My Recipes" section)
            // Find all recipe rows after the "My Recipes" header
            let customRecipeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'RecipeRow_'"))
                .element(boundBy: 1) // Try second recipe (first might be starter)
            
            if customRecipeButton.waitForExistence(timeout: 3) {
                customRecipeButton.tap()
            } else {
                // Fallback: tap first recipe and duplicate it
                let firstRecipeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'RecipeRow_'")).firstMatch
                XCTAssertTrue(firstRecipeButton.waitForExistence(timeout: 3))
                firstRecipeButton.tap()
                
                sleep(1)
                
                let duplicateButton = app.buttons["Duplicate"]
                XCTAssertTrue(duplicateButton.waitForExistence(timeout: 3))
                duplicateButton.tap()
                
                let editTitle = app.navigationBars["Edit Recipe"]
                XCTAssertTrue(editTitle.waitForExistence(timeout: 5))
            }
            
            // If we tapped a custom recipe, now tap Edit
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()
            }
        }
        
        // STEP 3: Verify Edit View loaded
        let editTitle = app.navigationBars["Edit Recipe"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5), "Edit Recipe view should load")
        
        // STEP 4: Modify recipe fields to trigger validation
        
        // Modify the name field
        let nameField = app.textFields["RecipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Name field should exist")
        nameField.tap()
        nameField.typeText(" - Modified \(Date().timeIntervalSince1970)")
        
        // Dismiss keyboard
        app.buttons["Return"].tap()
        
        // Scroll to dose field and modify it
        let doseField = app.textFields["DefaultDoseField"]
        if doseField.waitForExistence(timeout: 2) {
            doseField.tap()
            // Select all and replace
            doseField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
            doseField.typeText("18.5")
        }
        
        // Scroll to yield field
        let yieldField = app.textFields["TargetYieldField"]
        if yieldField.waitForExistence(timeout: 2) {
            yieldField.tap()
            yieldField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
            yieldField.typeText("308")
        }
        
        // Tap somewhere else to dismiss keyboard and trigger validation
        app.staticTexts["Recipe Defaults"].tap()
        
        // STEP 5: Verify validation state
        // Give validation time to compute
        sleep(1)
        
        // Check for validation issues
        let validationBanner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'issue'")).firstMatch
        
        // If there's a water mismatch or other validation issue, we may need to fix it
        // For now, we'll proceed with the test
        
        // STEP 6: Verify Save button exists
        let saveButton = app.buttons["RecipeEditSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        
        // STEP 7: Attempt to save (if button is enabled)
        // Note: XCUIElement.isEnabled is available in iOS 13+
        if saveButton.isEnabled {
            saveButton.tap()
            
            // STEP 8: Verify navigation back to detail view after successful save
            // The edit view should dismiss and we should be back at the detail view
            let editTitleAfterSave = app.navigationBars["Edit Recipe"]
            
            // Wait for edit view to disappear (with timeout)
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: editTitleAfterSave
            )
            
            let result = XCTWaiter.wait(for: [expectation], timeout: 5)
            XCTAssertEqual(result, .completed, "Edit view should dismiss after save")
            
            // Verify we're back at a view (detail or list)
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3), "Should be back at a navigation view")
        } else {
            // If save is disabled, verify validation errors are shown
            XCTAssertTrue(validationBanner.exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Required' OR label CONTAINS 'error'")).firstMatch.exists,
                         "Validation errors should be shown when save is disabled")
        }
    }
    
    /// Tests validation error handling when trying to save an invalid recipe
    @MainActor
    func testRecipeEditValidationErrors() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Recipes tab
        let recipesTab = app.tabBars.buttons["Recipes"]
        XCTAssertTrue(recipesTab.waitForExistence(timeout: 3))
        recipesTab.tap()
        
        sleep(2) // Wait for list to load
        
        // Find and tap a recipe
        let firstRecipe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'RecipeRow_'")).firstMatch
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 3))
        firstRecipe.tap()
        
        sleep(1)
        
        // Tap Edit or Duplicate
        let editButton = app.buttons["Edit"]
        let duplicateButton = app.buttons["Duplicate"]
        
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
        } else if duplicateButton.waitForExistence(timeout: 2) {
            duplicateButton.tap()
        }
        
        // Wait for edit view
        let editTitle = app.navigationBars["Edit Recipe"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5))
        
        // Clear the name field to trigger validation error
        let nameField = app.textFields["RecipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Name field should exist")
        nameField.clearAndEnterText(text: "")

        // Select all text and delete
        nameField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        app.keys["delete"].tap()
        
        // Tap elsewhere to trigger validation
        app.staticTexts["Recipe Defaults"].tap()
        
        sleep(1) // Allow validation to run
        
        // Verify validation error appears
        let errorIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'issue' OR label CONTAINS 'Required'")).firstMatch
        XCTAssertTrue(errorIndicator.waitForExistence(timeout: 3), "Validation error should be displayed")
        
        // Verify Save button is disabled
        let saveButton = app.buttons["RecipeEditSaveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when validation fails")
        
        // Try to tap save - it should not dismiss the view
        saveButton.tap()
        
        sleep(1)
        
        // Verify we're still in edit view (save was prevented)
        XCTAssertTrue(app.navigationBars["Edit Recipe"].exists, "Should remain in edit view when validation fails")
    }
    
    /// Tests the cancel/discard flow when there are unsaved changes
    @MainActor
    func testRecipeEditCancelWithUnsavedChanges() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Recipes tab
        let recipesTab = app.tabBars.buttons["Recipes"]
        XCTAssertTrue(recipesTab.waitForExistence(timeout: 3))
        recipesTab.tap()
        
        sleep(2)
        
        // Find and tap a recipe
        let firstRecipe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'RecipeRow_'")).firstMatch
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 3))
        firstRecipe.tap()
        
        sleep(1)
        
        // Navigate to edit
        let editButton = app.buttons["Edit"]
        let duplicateButton = app.buttons["Duplicate"]
        
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
        } else if duplicateButton.waitForExistence(timeout: 2) {
            duplicateButton.tap()
        }
        
        // Wait for edit view
        let editTitle = app.navigationBars["Edit Recipe"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5))
        
        // Make a change
        let nameField = app.textFields["RecipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(" Test Change")
        
        // Tap Cancel
        let cancelButton = app.buttons["RecipeEditCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.tap()
        
        sleep(1)
        
        // Verify discard confirmation dialog appears
        let discardButton = app.buttons["Discard Changes"].firstMatch
            XCTAssertTrue(discardButton.exists, "Discard button should exist")
        discardButton.tap()
        
        sleep(1)
        
        // Verify we're back at the detail view
        XCTAssertFalse(app.navigationBars["Edit Recipe"].exists, "Should have left edit view")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3), "Should be back at detail view")
    }
}
