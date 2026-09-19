import XCTest

final class OfflineScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += ["-UITEST_OFFLINE", "1", "-UIViewAnimationsEnabled", "NO"]
        app.launchEnvironment["UITEST_OFFLINE"] = "1"
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
        XCTAssertTrue(app.descendants(matching: .any)["sourceEditor"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["resultPanel"].exists, "Offline screenshots must not present a fabricated inference result.")
        attachScreenshot(named: "01-interpret-offline")
    }

    private func capturePhrasebook() {
        tapTab(named: "Phrases")
        XCTAssertTrue(app.navigationBars["Offline phrases"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Could you repeat that?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kunt u dat herhalen?"].exists)
        attachScreenshot(named: "02-phrasebook-offline")
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

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
