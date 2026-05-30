import XCTest

final class VoiceNotesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here.
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITest")
        app.launch()

        // Check if the empty state or home screen loads
        let helloText = app.staticTexts["What would you\nlike to hear today?"]
        XCTAssertTrue(helloText.waitForExistence(timeout: 5), "The home screen should display the welcome text")
    }

    func testCreateNewNoteAndEdit() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITest")
        app.launch()
        
        // Tap the FAB to create a new note
        let createButton = app.buttons["Create Note FAB"]
        if createButton.exists {
            createButton.tap()
        } else {
            // Fallback for empty state
            let emptyStateCreateButton = app.buttons["Create Note"]
            if emptyStateCreateButton.exists {
                emptyStateCreateButton.tap()
            } else {
                XCTFail("Could not find a button to create a new note.")
            }
        }
        
        // Ensure the editor appears
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 2), "Text editor should appear.")
        
        // Type some text
        textEditor.tap()
        textEditor.typeText("This is a UI test note.")
        
        // Go back
        // Save note
        let saveButton = app.buttons["Save Note"]
        if saveButton.exists {
            saveButton.tap()
        }
        
        // The note should be on the home screen
        let noteCard = app.staticTexts["This is a UI test note."]
        XCTAssertTrue(noteCard.waitForExistence(timeout: 2), "The newly created note should appear on the home screen.")
    }
    
    func testProfileTabAndAboutModal() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITest")
        app.launch()
        
        // Switch to Profile Tab
        let profileTab = app.buttons["Profile Tab"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 2), "Profile tab button should exist.")
        profileTab.tap()
        
        // Check if the Profile header exists
        let profileHeader = app.staticTexts["Profile"]
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 2), "Profile header should be visible.")
        
        // Tap About VoiceNotes
        let aboutButton = app.buttons["About VoiceNotes"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 2), "About button should exist.")
        aboutButton.tap()
        
        // Check if the About Modal opened
        let companyInfo = app.staticTexts["Company Information"]
        XCTAssertTrue(companyInfo.waitForExistence(timeout: 2), "Company Information section should be visible in the About modal.")
        
        // Close the modal
        let closeButton = app.buttons["Close"] // Ensure there's an accessibility identifier or text match
        if closeButton.exists {
            closeButton.tap()
        }
    }
}
