import XCTest

@MainActor
final class FoundationLaunchTests: XCTestCase {
    func testLaunchShowsFoundationWithoutUnimplementedActions() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["foundation.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["account.submit"].exists)
        XCTAssertEqual(app.tabBars.count, 0)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Account entry"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["foundation.title"].waitForExistence(timeout: 10))
        let largeText = XCTAttachment(screenshot: app.screenshot())
        largeText.name = "Account entry accessibility text"
        largeText.lifetime = .keepAlways
        add(largeText)
    }
}
