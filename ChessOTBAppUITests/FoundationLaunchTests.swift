import XCTest

@MainActor
final class FoundationLaunchTests: XCTestCase {
    func testLaunchShowsFoundationWithoutUnimplementedActions() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["foundation.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.count, 0)
        XCTAssertEqual(app.tabBars.count, 0)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Phase 1 foundation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["foundation.title"].waitForExistence(timeout: 10))
        let largeText = XCTAttachment(screenshot: app.screenshot())
        largeText.name = "Phase 1 accessibility text"
        largeText.lifetime = .keepAlways
        add(largeText)
    }
}
