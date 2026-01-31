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
