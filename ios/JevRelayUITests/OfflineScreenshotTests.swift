import XCTest

final class OfflineScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // Exercise the real app views, without a replay or alternate app mode.
        // Never consent, Interpret, Record, or delete a cloud identity in this suite.
        app.launch()
        XCTAssertTrue(app.staticTexts["What would you like to say?"].waitForExistence(timeout: 15), "The offline app shell did not appear.")
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testGenuineOfflineScreenshots() {
        captureWorkbench()
        capturePhrasebook()
        capturePrivacyPreferences()
    }

    private func captureWorkbench() {
        let heading = app.staticTexts["What would you like to say?"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        let editor = app.textViews["sourceEditor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["interpretButton"].isEnabled, "An empty turn must not be sent.")
        attachScreenshot(named: "00-empty-editor-offline")
        let example = "Which train goes to Amsterdam?"
        editor.tap()
        editor.typeText(example)
        let done = app.buttons["dismissKeyboardButton"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "An explicit keyboard-dismiss control must be available.")
        done.tap()
        XCTAssertEqual(editor.value as? String, example, "Dismissing the keyboard must preserve the editable source.")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Done must dismiss the keyboard.")
        XCTAssertFalse(app.descendants(matching: .any)["resultPanel"].exists, "Offline screenshots must not present a fabricated inference result.")
        XCTAssertFalse(app.descendants(matching: .any)["interpretProgress"].exists, "Editing text must not start interpretation.")
        attachScreenshot(named: "01-interpret-offline")

        let notice = app.descendants(matching: .any).matching(identifier: "workbenchSafetyNotice").firstMatch
        scrollToAndCapture(notice, named: "04-decisions-scroll-offline")
    }

    private func capturePhrasebook() {
        tapTab(named: "Phrases")
        XCTAssertTrue(app.navigationBars["Offline phrases"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Could you repeat that?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kunt u dat herhalen?"].exists)
        attachScreenshot(named: "02-phrasebook-offline")
        let savedStatus = app.descendants(matching: .any).matching(identifier: "savedPhraseStatus").firstMatch
        scrollToAndCapture(savedStatus, named: "05-phrasebook-end-offline")
    }

    private func capturePrivacyPreferences() {
        tapTab(named: "Preferences")
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 10))

        // SwiftUI Link may expose a button rather than XCUIElementTypeLink.
        // Use a stable identifier without assuming its accessibility element type.
        let privacy = app.descendants(matching: .any).matching(identifier: "privacyPolicyLink").firstMatch
        for _ in 0..<8 where !privacy.exists || !privacy.isHittable { app.swipeUp() }
        if !privacy.exists || !privacy.isHittable {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Privacy accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(privacy.exists && privacy.isHittable, "The privacy row was not visible and reachable in Preferences.")
        let notice = app.descendants(matching: .any).matching(identifier: "privacySafetyNotice").firstMatch
        for _ in 0..<4 where !notice.exists || !notice.isHittable { app.swipeUp() }
        XCTAssertTrue(notice.exists && notice.isHittable, "The privacy and safety notice was not visible.")
        XCTAssertTrue(privacy.exists && privacy.isHittable, "The screenshot must also include the accessible privacy row.")
        attachScreenshot(named: "03-privacy-preferences-offline")
    }

    private func tapTab(named name: String) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.exists { tabBarButton.tap(); return }
        let fallbackButton = app.buttons[name].firstMatch
        XCTAssertTrue(fallbackButton.waitForExistence(timeout: 5), "The \(name) tab was not available on this device layout.")
        fallbackButton.tap()
    }

    private func isVisibleAboveBottomNavigation(_ element: XCUIElement) -> Bool {
        guard element.exists && element.isHittable else { return false }
        let bar = app.tabBars.firstMatch
        // iPad may place its tab controls at the top instead.
        if bar.exists && bar.frame.minY > app.frame.midY {
            return element.frame.maxY <= bar.frame.minY
        }
        return true
    }

    private func scrollToAndCapture(_ element: XCUIElement, named name: String) {
        for _ in 0..<8 where !isVisibleAboveBottomNavigation(element) { app.swipeUp() }
        attachScreenshot(named: name)
        XCTAssertTrue(isVisibleAboveBottomNavigation(element), "Lower content must remain reachable above the floating tab bar.")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
