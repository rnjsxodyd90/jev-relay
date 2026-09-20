import XCTest

final class OfflineScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // Exercise real views only. This suite uses fake local-only strings, cleans them from Keychain, and never consents, translates, records, or contacts a provider.
        app.launch()
        XCTAssertTrue(app.staticTexts["Your English-to-Dutch conversation helper"].waitForExistence(timeout: 15), "The offline app shell did not appear.")
        removeAllProviderKeys(assertCleanup: true)
        tapTab(named: "Translate")
    }

    override func tearDownWithError() throws {
        if app != nil, app.state != .notRunning {
            if app.state != .runningForeground { app.activate() }
            if app.state == .runningForeground { removeAllProviderKeys(assertCleanup: false) }
        }
        app?.terminate()
        app = nil
    }

    func testGenuineOfflineScreenshots() {
        captureWorkbench()
        capturePhrasebook()
        captureSettings()
    }

    func testProviderKeyLifecycleAndSecureBuffersRemainLocal() {
        tapTab(named: "Settings")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        returnSettingsToTop()

        let field = app.secureTextFields["TypeSafe / Jev API key"].firstMatch
        let saveButton = app.buttons.matching(identifier: "jev-key-save").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled)

        let firstFakeKey = "ui-fake-jev-key-one"
        field.tap()
        field.typeText(firstFakeKey)
        XCTAssertTrue(saveButton.isEnabled)
        dismissKeyboardIfPresent()
        saveButton.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "jev-key-remove").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled, "Saving must immediately clear the secure-entry buffer.")
        XCTAssertFalse(app.navigationBars["Transmission notice"].exists, "Saving a key must not request consent or contact a provider.")

        let replacementFakeKey = "ui-fake-jev-key-two"
        field.tap()
        field.typeText(replacementFakeKey)
        XCTAssertTrue(saveButton.isEnabled)
        dismissKeyboardIfPresent()
        saveButton.tap()
        XCTAssertFalse(saveButton.isEnabled, "Replacing must immediately clear the secure-entry buffer.")
        XCTAssertTrue(app.buttons.matching(identifier: "jev-key-remove").firstMatch.exists)

        field.tap()
        field.typeText("unsaved-fake-key")
        XCTAssertTrue(saveButton.isEnabled)
        tapTab(named: "Phrases")
        tapTab(named: "Settings")
        returnSettingsToTop()
        XCTAssertFalse(app.buttons.matching(identifier: "jev-key-save").firstMatch.isEnabled, "Leaving Settings must clear unsaved plaintext.")

        let activeField = app.secureTextFields["TypeSafe / Jev API key"].firstMatch
        activeField.tap()
        activeField.typeText("background-fake-key")
        XCTAssertTrue(app.buttons.matching(identifier: "jev-key-save").firstMatch.isEnabled)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        returnSettingsToTop()
        XCTAssertFalse(app.buttons.matching(identifier: "jev-key-save").firstMatch.isEnabled, "Backgrounding must clear unsaved plaintext.")

        removeAllProviderKeys(assertCleanup: true)
        XCTAssertFalse(app.buttons.matching(identifier: "jev-key-remove").firstMatch.exists)
        XCTAssertFalse(app.navigationBars["Transmission notice"].exists)
    }

    private func captureWorkbench() {
        XCTAssertTrue(app.staticTexts["Type or speak English, review the Dutch, then choose to play it."].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "providerSetupCard").firstMatch.exists, "The offline fixture must honestly show the own-key prerequisite.")
        XCTAssertTrue(app.buttons["Open Settings"].exists)
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
        // The expanded content must remain in the same rail column, directly below its trigger.
        XCTAssertLessThanOrEqual(abs(details.frame.minX - transparentDetail.frame.minX), 24, "How it works and its detail must share one card column.")
        XCTAssertGreaterThan(transparentDetail.frame.minY, details.frame.maxY, "How it works detail must appear below its trigger.")
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
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "byokNoCreditsNotice").firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Not configured")).count, 2, "Offline screenshots must not use owner or demo provider keys.")
        let jevField = app.secureTextFields["TypeSafe / Jev API key"].firstMatch
        XCTAssertTrue(jevField.exists)
        XCTAssertNotEqual(jevField.value as? String, "", "The secure field should show its placeholder, never a stored key.")
        attachScreenshot(named: "03-byok-settings-offline")

        let privacy = app.descendants(matching: .any).matching(identifier: "privacyPolicyLink").firstMatch
        for _ in 0..<8 where !privacy.exists || !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.exists && privacy.isHittable, "The privacy row was not visible and reachable in Settings.")
        let notice = app.descendants(matching: .any).matching(identifier: "privacySafetyNotice").firstMatch
        for _ in 0..<4 where !notice.exists || !notice.isHittable { app.swipeUp() }
        XCTAssertTrue(notice.exists && notice.isHittable, "The privacy and safety notice was not visible.")
        attachScreenshot(named: "06-privacy-preferences-offline")
    }

    private func removeAllProviderKeys(assertCleanup: Bool) {
        tapTab(named: "Settings")
        guard app.navigationBars["Settings"].waitForExistence(timeout: 10) else {
            if assertCleanup { XCTFail("Settings was unavailable for provider-key cleanup.") }
            return
        }
        returnSettingsToTop()
        for provider in ["jev", "nebius"] {
            let removeButton = app.buttons.matching(identifier: "\(provider)-key-remove").firstMatch
            guard removeButton.exists else { continue }
            makeVisibleFromEitherDirection(removeButton)
            guard removeButton.isHittable else {
                if assertCleanup { XCTFail("The \(provider) key could not be reached for cleanup.") }
                continue
            }
            removeButton.tap()
            let confirm = app.buttons["Remove key"].firstMatch
            guard confirm.waitForExistence(timeout: 5) else {
                if assertCleanup { XCTFail("The \(provider) removal confirmation did not appear.") }
                continue
            }
            confirm.tap()
            _ = removeButton.waitForNonExistence(timeout: 5)
        }
        if assertCleanup {
            XCTAssertFalse(app.buttons.matching(identifier: "jev-key-remove").firstMatch.exists)
            XCTAssertFalse(app.buttons.matching(identifier: "nebius-key-remove").firstMatch.exists)
        }
    }

    private func returnSettingsToTop() {
        dismissKeyboardIfPresent()
        for _ in 0..<10 { app.swipeDown() }
    }

    private func makeVisibleFromEitherDirection(_ element: XCUIElement) {
        for _ in 0..<8 where !isVisibleAboveBottomNavigation(element) { app.swipeDown() }
        for _ in 0..<8 where !isVisibleAboveBottomNavigation(element) { app.swipeUp() }
    }

    private func dismissKeyboardIfPresent() {
        guard app.keyboards.firstMatch.exists else { return }
        let returnKey = app.keyboards.buttons["return"].firstMatch
        if returnKey.exists { returnKey.tap() }
        else { app.swipeDown() }
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
