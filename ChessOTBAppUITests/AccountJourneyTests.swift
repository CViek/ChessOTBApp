import Foundation
import XCTest

@MainActor
final class AccountJourneyTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDown() {
        if let run = testRun, run.failureCount > 0 {
            let app = XCUIApplication()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Account journey failure"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Account journey accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }

    private let password = "Local-account-test-58!"
    private var baseURL = ""
    private var publishableKey = ""

    func testRealAccountsProfilePersistenceIsolationAndRecovery() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else {
            throw XCTSkip("Run tools/backend/start-local.sh to enable local account integration tests.")
        }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321", publishableKey.hasPrefix("sb_publishable_") else {
            XCTFail("Account journey tests must target disposable local Supabase only.")
            return
        }
        let firstEmail = "ui-first-" + UUID().uuidString.lowercased() + "@example.com"
        let secondEmail = "ui-second-" + UUID().uuidString.lowercased() + "@example.com"
        let app = XCUIApplication()
        app.launch()
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        tap(app.buttons["account.create"], in: app)
        fill(app.textFields["account.email"], with: firstEmail, in: app)
        fill(app.secureTextFields["account.password"], with: password, in: app)
        tap(app.buttons["account.submit"], in: app)
        XCTAssertTrue(app.textFields["account.code"].waitForExistence(timeout: 15))
        let confirmation = try await emailCode(for: firstEmail, subject: "Confirm")
        fill(app.textFields["account.code"], with: confirmation, in: app)
        tap(app.buttons["account.submit"], in: app)
        XCTAssertTrue(app.textFields["profile.name"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["profile.save"].isEnabled)
        fill(app.textFields["profile.name"], with: "First player", in: app)
        tap(app.buttons["profile.save"], in: app)
        assertProfile("First player", in: app)
        tap(app.buttons["profile.edit"], in: app)
        fill(app.textFields["profile.name"], with: "First player updated", in: app)
        tap(app.buttons["profile.save"], in: app)
        assertProfile("First player updated", in: app)
        tap(app.switches["profile.darkAppearance"], in: app)
        let appearance = app.switches["profile.darkAppearance"].value as? String
        app.terminate()
        app.launch()
        assertProfile("First player updated", in: app)
        XCTAssertEqual(app.switches["profile.darkAppearance"].value as? String, appearance)
        capture("Saved profile after relaunch", app: app)
        signOut(app)

        try await createConfirmedAccount(email: secondEmail)
        signIn(app, email: secondEmail, password: password)
        XCTAssertTrue(app.textFields["profile.name"].waitForExistence(timeout: 15))
        fill(app.textFields["profile.name"], with: "Second player", in: app)
        tap(app.buttons["profile.save"], in: app)
        assertProfile("Second player", in: app)
        XCTAssertFalse(app.staticTexts["First player updated"].exists)
        signOut(app)
        signIn(app, email: firstEmail, password: password)
        assertProfile("First player updated", in: app)
        signOut(app)

        fill(app.textFields["account.email"], with: firstEmail, in: app)
        tap(app.buttons["account.forgot"], in: app)
        tap(app.buttons["account.submit"], in: app)
        XCTAssertTrue(app.textFields["account.code"].waitForExistence(timeout: 15))
        let recovery = try await emailCode(for: firstEmail, subject: "Reset")
        fill(app.textFields["account.code"], with: recovery, in: app)
        fill(app.secureTextFields["account.password"], with: "Changed-local-test-79!", in: app)
        tap(app.buttons["account.submit"], in: app)
        assertProfile("First player updated", in: app)
        signOut(app)
        signIn(app, email: firstEmail, password: password)
        XCTAssertTrue(app.staticTexts["account.error"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["profile.displayName"].exists)
        fill(app.secureTextFields["account.password"], with: "Changed-local-test-79!", in: app)
        tap(app.buttons["account.submit"], in: app)
        assertProfile("First player updated", in: app)
        signOut(app)
    }

    private func signIn(_ app: XCUIApplication, email: String, password: String) {
        fill(app.textFields["account.email"], with: email, in: app)
        fill(app.secureTextFields["account.password"], with: password, in: app)
        tap(app.buttons["account.submit"], in: app)
    }

    private func signOut(_ app: XCUIApplication) {
        tap(app.buttons["account.signOut"], in: app)
        let buttons = app.buttons.matching(identifier: "Sign out")
        XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 5))
        buttons.element(boundBy: buttons.count - 1).tap()
        XCTAssertTrue(app.textFields["account.email"].waitForExistence(timeout: 15))
    }

    private func assertProfile(_ name: String, in app: XCUIApplication) {
        let label = app.staticTexts["profile.displayName"]
        XCTAssertTrue(label.waitForExistence(timeout: 15))
        XCTAssertEqual(label.label, name)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        if app.keyboards.firstMatch.exists,
           element.frame.maxY >= app.keyboards.firstMatch.frame.minY - 50 {
            app.scrollViews.firstMatch.swipeUp()
        }
        for _ in 0..<5 {
            if element.isHittable { break }
            app.swipeUp()
        }
        element.tap()
    }

    private func fill(_ element: XCUIElement, with value: String, in app: XCUIApplication) {
        tap(element, in: app)
        if element.elementType == .secureTextField,
           app.buttons["GenerateStrongPasswordButton"].waitForExistence(timeout: 1) {
            app.buttons["xmark"].tap()
            element.tap()
        }
        if let current = element.value as? String, current != element.placeholderValue, !current.isEmpty {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: element.elementType == .secureTextField ? 128 : current.count))
        }
        element.typeText(value)
    }

    private func createConfirmedAccount(email: String) async throws {
        _ = try await post("/auth/v1/signup", body: ["email": email, "password": password])
        let code = try await emailCode(for: email, subject: "Confirm")
        _ = try await post("/auth/v1/verify", body: ["email": email, "token": code, "type": "signup"])
    }

    private func post(_ path: String, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        XCTAssertTrue((200..<300).contains(status), "Test fixture request failed")
        return data
    }

    private func emailCode(for email: String, subject: String) async throws -> String {
        for _ in 0..<100 {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:54324/api/v1/messages")!)
            let inbox = try JSONDecoder().decode(MailInbox.self, from: data)
            if let message = inbox.messages.first(where: { $0.Subject.contains(subject) && $0.To.contains(where: { $0.Address == email }) }) {
                let (detail, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:54324/api/v1/message/" + message.ID)!)
                let body = try JSONDecoder().decode(MailBody.self, from: detail)
                let expression = try NSRegularExpression(pattern: "\\b([0-9]{6})\\b")
                let text = (body.Text ?? "") + (body.HTML ?? "")
                if let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: 1), in: text) {
                    return String(text[range])
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("No local verification email arrived")
        throw URLError(.timedOut)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    nonisolated private struct MailInbox: Decodable { let messages: [MailMessage] }
    nonisolated private struct MailMessage: Decodable {
        let ID: String
        let Subject: String
        let To: [Recipient]
        struct Recipient: Decodable { let Address: String }
    }
    nonisolated private struct MailBody: Decodable { let Text: String?; let HTML: String? }
}
