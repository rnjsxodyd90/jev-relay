import XCTest

final class OfflineScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // Exercise real views only. This suite never consents, translates, records, or deletes a cloud identity.
        app.launch()
        XCTAssertTrue(app.staticTexts["Your English-to-Dutch conversation helper"].waitForExistence(timeout: 15), "The offline app shell did not appear.")
    }

    override func tearDownWithError() throws { app?.terminate(); app = nil }

    func testGenuineOfflineScreenshots() {
        captureWorkbench()
        capturePhrasebook()
        captureSettings()
    }

    private func captureWorkbench() {
        XCTAssertTrue(app.staticTexts["Type or speak English, review the Dutch, then choose to play it."].exists)
        let editor = app.textViews["sourceEditor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["translateButton"].isEnabled, "An empty turn must not be sent.")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "transmissionNotice").firstMatch.exists)
        attachScreenshot(named: "00-empty-editor-offline")

        let example = "Which train goes to Amsterdam?"
        app.buttons["tryExampleButton"].tap()
        XCTAssertEqual(editor.value as? String, example, "Try an example must only fill editable English text.")
        XCTAssertFalse(app.descendants(matching: .any)["resultPanel"].exists, "Examples must not fabricate inference results.")
        XCTAssertFalse(app.descendants(matching: .any)["interpretProgress"].exists, "Examples must not start translation.")
        attachScreenshot(named: "01-interpret-offline")

        editor.tap()
        let done = app.buttons["dismissKeyboardButton"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "An explicit keyboard-dismiss control must be available.")
        done.tap()
        XCTAssertEqual(editor.value as? String, example, "Dismissing the keyboard must preserve the editable source.")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Done must dismiss the keyboard.")

        // Tap the native disclosure row, rather than its identified container, because the container's bounds grow on expansion.
        let optional = app.buttons["Optional context and tone"].firstMatch
        XCTAssertTrue(optional.waitForExistence(timeout: 5), "Optional controls must be clearly available.")
        optional.tap()
        // A vertically expanding SwiftUI TextField may be exposed as either a text field or text view.
        // Its identifier is stable across those native accessibility representations.
        let context = app.descendants(matching: .any).matching(identifier: "contextEditor").firstMatch
        guard requireExpandedElement(context, named: "context-editor", message: "Expanding optional controls must reveal editable context.") else { return }
        scrollToVisible(context, swipingUp: true)
        XCTAssertTrue(isVisibleAboveBottomNavigation(context), "The revealed context control must be reachable.")
        // Context can push the native row above the viewport. Return to that row before collapsing it.
        scrollToVisible(optional, swipingUp: false)
        XCTAssertTrue(isVisibleAboveBottomNavigation(optional), "The optional-controls row must remain reachable.")
        optional.tap()

        let details = app.buttons["How it works"].firstMatch
        scrollToVisible(details, swipingUp: true)
        XCTAssertTrue(isVisibleAboveBottomNavigation(details), "How it works must be reachable.")
        details.tap()
        let transparentDetail = app.staticTexts["Transparent detail"].firstMatch
        guard requireExpandedElement(transparentDetail, named: "transparent-detail", message: "Expanding How it works must reveal the transparent detail.") else { return }
        scrollToVisible(transparentDetail, swipingUp: true)
        XCTAssertTrue(isVisibleAboveBottomNavigation(transparentDetail), "Expanded decision detail must be reachable.")
        attachScreenshot(named: "04-decisions-scroll-offline")

        let safety = app.descendants(matching: .any).matching(identifier: "workbenchSafetyNotice").firstMatch
        for _ in 0..<8 where !isVisibleAboveBottomNavigation(safety) { app.swipeUp() }
        XCTAssertTrue(isVisibleAboveBottomNavigation(safety), "Lower safety content must remain reachable.")
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

    private func captureSettings() {
        tapTab(named: "Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let privacy = app.descendants(matching: .any).matching(identifier: "privacyPolicyLink").firstMatch
        for _ in 0..<8 where !privacy.exists || !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.exists && privacy.isHittable, "The privacy row was not visible and reachable in Settings.")
        let notice = app.descendants(matching: .any).matching(identifier: "privacySafetyNotice").firstMatch
        for _ in 0..<4 where !notice.exists || !notice.isHittable { app.swipeUp() }
        XCTAssertTrue(notice.exists && notice.isHittable, "The privacy and safety notice was not visible.")
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
        if bar.exists && bar.frame.minY > app.frame.midY { return element.frame.maxY <= bar.frame.minY }
        return true
    }

    private func scrollToVisible(_ element: XCUIElement, swipingUp: Bool, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !isVisibleAboveBottomNavigation(element) {
            if swipingUp { app.swipeUp() } else { app.swipeDown() }
        }
    }

    private func scrollToAndCapture(_ element: XCUIElement, named name: String) {
        scrollToVisible(element, swipingUp: true)
        attachScreenshot(named: name)
        XCTAssertTrue(isVisibleAboveBottomNavigation(element), "Lower content must remain reachable above the floating tab bar.")
    }

    // QA-only diagnostics: retained only when expansion does not reveal its real child control.
    @discardableResult
    private func requireExpandedElement(_ element: XCUIElement, named name: String, message: String) -> Bool {
        guard !element.waitForExistence(timeout: 5) else { return true }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "QA expansion failure - \(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "QA expansion accessibility hierarchy - \(name)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail(message)
        return false
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
