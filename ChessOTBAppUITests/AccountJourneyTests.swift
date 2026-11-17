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
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
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
        try await seedAreaForAccount(email: firstEmail, app: app)
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
        try await seedAreaForAccount(email: secondEmail, app: app)
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

    func testAreaDenialManualDiscoveryProfileFiltersAndPersistence() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let otherEmail = "ui-neighbor-" + UUID().uuidString.lowercased() + "@example.com"
        let otherToken = try await createConfirmedAccount(email: otherEmail)
        let otherName = "Neighbor " + String(UUID().uuidString.prefix(6))
        let otherData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": otherName], token: otherToken)
        let otherID = try XCTUnwrap((JSONSerialization.jsonObject(with: otherData) as? [[String: Any]])?.first?["id"] as? String)
        _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: otherToken)
        let email = "ui-discovery-" + UUID().uuidString.lowercased() + "@example.com"
        try await createConfirmedAccount(email: email)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: email, password: password)
        fill(app.textFields["profile.name"], with: "Area explorer", in: app)
        tap(app.buttons["profile.save"], in: app)
        tap(app.buttons["area.currentLocation"], in: app)
        let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Don't Allow", "Don’t Allow")).firstMatch
        if deny.waitForExistence(timeout: 5) { deny.tap() }
        XCTAssertTrue(app.staticTexts["account.error"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["account.error"].label.contains("Location access is off"))
        fill(app.textFields["area.query"], with: "New York, NY", in: app)
        tap(app.buttons["area.search"], in: app)
        let candidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "area.candidate.")).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: 30))
        capture("Resolved manual area choices", app: app)
        tap(candidate, in: app)
        tap(app.buttons["area.save"], in: app)
        let neighbor = app.buttons["discovery.player." + otherID.lowercased()]
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.player.")).firstMatch.waitForExistence(timeout: 20))
        for _ in 0..<100 {
            if neighbor.exists { break }
            app.swipeUp()
            let more = app.buttons["Load more players"]
            if more.exists, more.isHittable { more.tap() }
        }
        XCTAssertTrue(neighbor.exists)
        capture("Real nearby players", app: app)
        tap(neighbor, in: app)
        XCTAssertTrue(app.staticTexts["player.displayName"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["player.displayName"].label, otherName)
        capture("Public player profile", app: app)
        app.navigationBars.buttons.firstMatch.tap()
        tap(app.buttons["discovery.filters"], in: app)
        selectDistance(10, in: app)
        tap(app.buttons["discovery.applyRadius"], in: app)
        XCTAssertTrue(app.buttons["discovery.distanceChip"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["discovery.distanceChip"].label.contains("10"))
        tap(app.buttons["discovery.area"], in: app)
        fill(app.textFields["area.query"], with: "Juneau, AK", in: app)
        tap(app.buttons["area.search"], in: app)
        let remoteCandidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@", "area.candidate.", "Juneau")).firstMatch
        XCTAssertTrue(remoteCandidate.waitForExistence(timeout: 30)); tap(remoteCandidate, in: app)
        tap(app.buttons["area.save"], in: app)
        XCTAssertTrue(app.staticTexts["No players in this area yet"].waitForExistence(timeout: 15))
        capture("Empty discovery with recovery", app: app)
        tap(app.buttons["discovery.filters"], in: app)
        selectDistance(3, in: app)
        tap(app.buttons["discovery.applyRadius"], in: app)
        tap(app.buttons["discovery.widen"], in: app)
        let sixMiles = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "6")).firstMatch
        XCTAssertTrue(sixMiles.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["No players in this area yet"].exists)
        app.tabBars.buttons["Profile"].tap(); app.tabBars.buttons["Discover"].tap()
        let tenMiles = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "10")).firstMatch
        let replayedWidening = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "12")).firstMatch
        XCTAssertFalse(replayedWidening.waitForExistence(timeout: 2), "Returning to Discover must not replay widening")
        XCTAssertTrue(sixMiles.exists, "The selected 6-mile radius must remain unchanged")
        tap(app.buttons["discovery.area"], in: app)
        selectDistance(10, in: app)
        tap(app.buttons["area.save"], in: app)
        XCTAssertTrue(tenMiles.waitForExistence(timeout: 15), "A repeated saved area/radius must refresh the displayed search")
        assertProfile("Area explorer", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "New York")).firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["discovery.area"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["discovery.area"].label.contains("Juneau"))
        assertProfile("Area explorer", in: app)
        tap(app.buttons["profile.edit"], in: app)
        fill(app.textFields["profile.name"], with: "Area explorer revised", in: app)
        tap(app.buttons["profile.editArea"], in: app)
        fill(app.textFields["area.query"], with: "Boston, MA", in: app)
        tap(app.buttons["area.search"], in: app)
        let profileCandidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@", "area.candidate.", "Boston")).firstMatch
        XCTAssertTrue(profileCandidate.waitForExistence(timeout: 30)); tap(profileCandidate, in: app)
        tap(app.buttons["area.save"], in: app)
        XCTAssertEqual(app.textFields["profile.name"].value as? String, "Area explorer revised")
        tap(app.buttons["profile.save"], in: app)
        assertProfile("Area explorer revised", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Boston")).firstMatch.exists)
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["discovery.area"].label.contains("Juneau"))
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["discovery.area"].waitForExistence(timeout: 15))
        capture("Discovery accessibility text", app: app)
        assertProfile("Area explorer revised", in: app)
        signOut(app)
    }

    func testRepeatedSavedAreaRefreshesDistance() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let email = "ui-repeat-" + UUID().uuidString.lowercased() + "@example.com"
        let token = try await createConfirmedAccount(email: email)
        _ = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Repeated area check"], token: token)
        _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 10], token: token)
        _ = try await post("/rest/v1/rpc/save_search_area", body: ["p_name": "Honolulu, HI", "p_latitude": 21.31, "p_longitude": -157.86, "p_country_code": "US", "p_radius_miles": 10], token: token)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: email, password: password)
        tap(app.buttons["discovery.area"], in: app)
        tap(app.buttons["area.save"], in: app)
        tap(app.buttons["discovery.filters"], in: app)
        selectDistance(5, in: app)
        tap(app.buttons["discovery.applyRadius"], in: app)
        let five = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "5")).firstMatch
        XCTAssertTrue(five.waitForExistence(timeout: 15))
        tap(app.buttons["discovery.area"], in: app)
        selectDistance(10, in: app)
        tap(app.buttons["area.save"], in: app)
        let ten = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "10")).firstMatch
        XCTAssertTrue(ten.waitForExistence(timeout: 15), "Resaving earlier settings must refresh the visible search")
        app.tabBars.buttons["Profile"].tap(); signOut(app)
    }

    func testDynamicRadiusCustomValuesBoundsAndPersistence() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let email = "ui-radius-" + UUID().uuidString.lowercased() + "@example.com"
        let token = try await createConfirmedAccount(email: email)
        _ = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Custom distance check"], token: token)
        _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: token)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: email, password: password)
        tap(app.buttons["discovery.filters"], in: app)
        selectDistance(37, in: app)
        capture("Dynamic distance controls", app: app)
        tap(app.buttons["discovery.applyRadius"], in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "37")).firstMatch.waitForExistence(timeout: 15))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "37")).firstMatch.waitForExistence(timeout: 15))
        tap(app.buttons["discovery.filters"], in: app)
        selectDistance(101, in: app)
        XCTAssertFalse(app.buttons["discovery.applyRadius"].isEnabled)
        let slider = app.sliders["discovery.radius"]
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(app.textFields["discovery.radiusMiles"].value as? String, "1")
        slider.adjust(toNormalizedSliderPosition: 1)
        // XCTest documents slider positioning as best effort; exact values use the numeric field.
        let upperValue = try XCTUnwrap(Int(app.textFields["discovery.radiusMiles"].value as? String ?? ""))
        XCTAssertTrue((99...100).contains(upperValue))
        selectDistance(100, in: app)
        tap(app.buttons["discovery.applyRadius"], in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "discovery.distanceChip", "100")).firstMatch.waitForExistence(timeout: 15))
        let saved = try await post("/rest/v1/rpc/get_discovery_settings", body: [:], token: token)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: saved) as? [String: Any])?["radius"] as? Int, 100)
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tap(app.buttons["discovery.filters"], in: app)
        XCTAssertEqual(app.textFields["discovery.radiusMiles"].value as? String, "100")
        capture("Dynamic distance accessibility text", app: app)
        tap(app.buttons["Cancel"], in: app)
        app.tabBars.buttons["Profile"].tap(); signOut(app)
    }

    func testMessagingTwoAccountsDraftsProfilesUnreadAndRelaunch() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let firstEmail = "ui-chat-a-" + UUID().uuidString.lowercased() + "@example.com"
        let secondEmail = "ui-chat-b-" + UUID().uuidString.lowercased() + "@example.com"
        let firstToken = try await createConfirmedAccount(email: firstEmail)
        let secondToken = try await createConfirmedAccount(email: secondEmail)
        let firstData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Chat first player"], token: firstToken)
        let secondData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Chat second player"], token: secondToken)
        let firstID = try XCTUnwrap((JSONSerialization.jsonObject(with: firstData) as? [[String: Any]])?.first?["id"] as? String)
        let secondID = try XCTUnwrap((JSONSerialization.jsonObject(with: secondData) as? [[String: Any]])?.first?["id"] as? String)
        for token in [firstToken, secondToken] {
            _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: token)
        }
        let threadData = try await post("/rest/v1/rpc/open_conversation", body: ["p_peer_id": secondID], token: firstToken)
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: threadData, options: .fragmentsAllowed) as? String)
        _ = try await post("/rest/v1/rpc/send_message", body: ["p_conversation_id": thread, "p_client_id": UUID().uuidString, "p_body": "Hello from the second player"], token: secondToken)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: firstEmail, password: password)
        tap(app.tabBars.buttons["Inbox"], in: app)
        let row = app.buttons["inbox.thread." + thread.lowercased()]
        tap(row, in: app)
        XCTAssertTrue(app.staticTexts["Hello from the second player"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["chat.send"].isEnabled)
        fill(app.textFields["chat.draft"], with: "Reply from the first player", in: app)
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts["Reply from the first player"].waitForExistence(timeout: 15))
        fill(app.textFields["chat.draft"], with: "A draft to keep", in: app)
        app.buttons["chat.done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        tap(row, in: app)
        XCTAssertEqual(app.textFields["chat.draft"].value as? String, "A draft to keep")
        tap(app.buttons["chat.peerProfile"], in: app)
        XCTAssertEqual(app.staticTexts["player.displayName"].label, "Chat second player")
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        signIn(app, email: secondEmail, password: password)
        tap(app.tabBars.buttons["Inbox"], in: app); tap(row, in: app)
        XCTAssertTrue(app.staticTexts["Reply from the first player"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["A draft to keep"].exists)
        fill(app.textFields["chat.draft"], with: "A real second-account reply", in: app)
        app.buttons["chat.send"].tap()
        app.terminate(); app.launch()
        tap(app.tabBars.buttons["Inbox"], in: app); tap(row, in: app)
        XCTAssertTrue(app.staticTexts["A real second-account reply"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        signIn(app, email: firstEmail, password: password)
        tap(app.tabBars.buttons["Inbox"], in: app); tap(row, in: app)
        XCTAssertEqual(app.textFields["chat.draft"].value as? String, "A draft to keep")
        _ = try await post("/rest/v1/rpc/send_message", body: ["p_conversation_id": thread, "p_client_id": UUID().uuidString, "p_body": "Active-chat refresh reply"], token: secondToken)
        XCTAssertTrue(app.staticTexts["Active-chat refresh reply"].waitForExistence(timeout: 6))
        capture("Real two-account conversation", app: app)
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        XCTAssertNotEqual(firstID, secondID)
    }

    func testMeetingAddressPickerAndCompactChangePage() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let firstEmail = "ui-address-a-" + UUID().uuidString.lowercased() + "@example.com"
        let secondEmail = "ui-address-b-" + UUID().uuidString.lowercased() + "@example.com"
        let first = try await createConfirmedAccount(email: firstEmail)
        let second = try await createConfirmedAccount(email: secondEmail)
        let ownData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Address friend"], token: first)
        let peerData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Address recipient"], token: second)
        let own = try XCTUnwrap((JSONSerialization.jsonObject(with: ownData) as? [[String: Any]])?.first?["id"] as? String)
        let peer = try XCTUnwrap((JSONSerialization.jsonObject(with: peerData) as? [[String: Any]])?.first?["id"] as? String)
        for token in [first, second] {
            _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: token)
        }
        _ = try await post("/rest/v1/rpc/mutate_friendship", body: ["p_peer_id": peer, "p_action": "send", "p_request_id": UUID().uuidString, "p_expected_version": 0], token: first)
        _ = try await post("/rest/v1/rpc/mutate_friendship", body: ["p_peer_id": own, "p_action": "accept", "p_request_id": UUID().uuidString, "p_expected_version": 1], token: second)
        let threadData = try await post("/rest/v1/rpc/open_conversation", body: ["p_peer_id": peer], token: first)
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: threadData, options: .fragmentsAllowed) as? String)
        let oldPlace: [String: Any] = ["name": "Central Library", "address": "476 5th Ave, New York, NY 10018", "latitude": 40.7532, "longitude": -73.9822]
        let newPlace: [String: Any] = ["name": "Bryant Park", "address": "40 W 40th St, New York, NY 10018", "latitude": 40.7536, "longitude": -73.9832]
        let created = try await post("/rest/v1/rpc/create_meeting_with_place", body: ["p_conversation_id": thread, "p_request_id": UUID().uuidString, "p_starts_at": "2099-05-17T18:00:00Z", "p_time_zone": "America/New_York", "p_location": "Central Library", "p_place": oldPlace, "p_note": "Bring a board"], token: first)
        let meetingID = try XCTUnwrap((JSONSerialization.jsonObject(with: created) as? [String: Any])?["id"] as? String)
        _ = try await post("/rest/v1/rpc/respond_to_meeting", body: ["p_meeting_id": meetingID, "p_request_id": UUID().uuidString, "p_expected_version": 1, "p_decision": "confirmed"], token: second)
        _ = try await post("/rest/v1/rpc/propose_meeting_change_with_place", body: ["p_meeting_id": meetingID, "p_request_id": UUID().uuidString, "p_expected_version": 2, "p_starts_at": "2099-05-17T18:00:00Z", "p_time_zone": "America/New_York", "p_location": "Bryant Park", "p_place": newPlace, "p_note": "Bring a board"], token: first)
        let outgoingData = try await post("/rest/v1/rpc/create_meeting_with_place", body: ["p_conversation_id": thread, "p_request_id": UUID().uuidString, "p_starts_at": "2099-05-18T18:00:00Z", "p_time_zone": "America/New_York", "p_location": "Central Library", "p_place": oldPlace, "p_note": "Original invitation note"], token: second)
        let outgoingID = try XCTUnwrap((JSONSerialization.jsonObject(with: outgoingData) as? [String: Any])?["id"] as? String)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: secondEmail, password: password)
        tap(app.tabBars.buttons["Meetings"], in: app)
        tap(app.buttons["meetings.new"], in: app)
        tap(app.buttons["meeting.chooseFriend." + own.lowercased()], in: app)
        tap(app.buttons["meeting.location"], in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("476 5th Ave New York")
        let result = app.buttons["meeting.addressResult"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20)); result.tap()
        XCTAssertTrue(app.buttons["meeting.review"].isEnabled)
        capture("Selected exact meeting address", app: app)
        tap(app.buttons["Close"], in: app)
        tap(app.buttons["meeting.row." + meetingID.lowercased()], in: app)
        XCTAssertTrue(app.links["meeting.openMaps"].exists || app.buttons["meeting.openMaps"].exists)
        XCTAssertFalse(app.buttons["Refresh"].exists)
        XCTAssertFalse(app.staticTexts["Proposal history"].exists)
        tap(app.buttons["meeting.viewChange"], in: app)
        XCTAssertTrue(app.staticTexts["40 W 40th St, New York, NY 10018"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["476 5th Ave, New York, NY 10018"].exists)
        XCTAssertFalse(app.staticTexts["New date and time"].exists)
        XCTAssertTrue(app.buttons["meeting.acceptChange"].exists)
        XCTAssertTrue(app.buttons["meeting.declineChange"].exists)
        XCTAssertFalse(app.buttons["meeting.editChange"].exists)
        capture("Only proposed location change", app: app)
        tap(app.buttons["meeting.acceptChange"], in: app)
        XCTAssertTrue(app.staticTexts["No pending change"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["40 W 40th St, New York, NY 10018"].waitForExistence(timeout: 10))
        tap(app.buttons["meeting.cancel"], in: app)
        let cancellation = app.alerts["Cancel this meeting?"]
        XCTAssertTrue(cancellation.waitForExistence(timeout: 5))
        XCTAssertTrue(cancellation.buttons["Keep Meeting"].exists)
        capture("Centered meeting cancellation confirmation", app: app)
        cancellation.buttons["Keep Meeting"].tap()
        XCTAssertEqual(app.staticTexts["meeting.status"].label, "Confirmed")
        tap(app.buttons["meeting.cancel"], in: app)
        tap(app.alerts["Cancel this meeting?"].buttons["Cancel Meeting"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "meeting.status", "Cancelled")).firstMatch.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        tap(app.buttons["meeting.row." + outgoingID.lowercased()], in: app)
        tap(app.buttons["meeting.editInvitation"], in: app)
        let note = app.textViews["meeting.note"].exists ? app.textViews["meeting.note"] : app.textFields["meeting.note"]
        tap(note, in: app)
        note.typeText("Please bring a board. ")
        let editedNote = try XCTUnwrap(note.value as? String)
        XCTAssertTrue(editedNote.contains("Please bring a board."))
        XCTAssertNotEqual(editedNote, "Original invitation note")
        tap(app.buttons["meeting.review"], in: app)
        tap(app.buttons["meeting.send"], in: app)
        XCTAssertTrue(app.staticTexts[editedNote].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["meeting.status"].label, "Awaiting agreement")
        let editedData = try await post("/rest/v1/rpc/get_meeting", body: ["p_meeting_id": outgoingID], token: first)
        let edited = try XCTUnwrap(JSONSerialization.jsonObject(with: editedData) as? [String: Any])
        XCTAssertEqual(edited["version"] as? Int, 2)
        XCTAssertEqual(edited["status"] as? String, "pending")
        XCTAssertEqual((edited["revision"] as? [String: Any])?["note"] as? String, editedNote)
        capture("Editable sent invitation", app: app)
        tap(app.tabBars.buttons["Profile"], in: app); signOut(app)
    }

    func testMeetingProposalReviewAgreementChangesAndCancellation() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let firstEmail = "ui-meeting-a-" + UUID().uuidString.lowercased() + "@example.com"
        let secondEmail = "ui-meeting-b-" + UUID().uuidString.lowercased() + "@example.com"
        let first = try await createConfirmedAccount(email: firstEmail)
        let second = try await createConfirmedAccount(email: secondEmail)
        _ = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Meeting first"], token: first)
        let peerData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Meeting second"], token: second)
        let peer = try XCTUnwrap((JSONSerialization.jsonObject(with: peerData) as? [[String: Any]])?.first?["id"] as? String)
        for token in [first, second] {
            _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: token)
        }
        let threadData = try await post("/rest/v1/rpc/open_conversation", body: ["p_peer_id": peer], token: first)
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: threadData, options: .fragmentsAllowed) as? String)
        _ = try await post("/rest/v1/rpc/send_message", body: ["p_conversation_id": thread, "p_client_id": UUID().uuidString, "p_body": "Arrange a game"], token: second)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: firstEmail, password: password)
        tap(app.tabBars.buttons["Inbox"], in: app)
        tap(app.buttons["inbox.thread." + thread.lowercased()], in: app)
        tap(app.buttons["meeting.propose"], in: app)
        selectMeetingAddress("New York Public Library Stephen A Schwarzman", in: app)
        app.terminate(); app.launch()
        tap(app.tabBars.buttons["Inbox"], in: app)
        tap(app.buttons["inbox.thread." + thread.lowercased()], in: app)
        tap(app.buttons["meeting.propose"], in: app)
        XCTAssertTrue(app.buttons["meeting.review"].isEnabled)
        tap(app.buttons["meeting.review"], in: app)
        XCTAssertTrue(app.links["meeting.openMaps"].exists || app.buttons["meeting.openMaps"].exists)
        tap(app.buttons["meeting.edit"], in: app)
        XCTAssertTrue(app.buttons["meeting.review"].isEnabled)
        tap(app.buttons["meeting.review"], in: app)
        tap(app.buttons["meeting.send"], in: app)
        XCTAssertTrue(app.staticTexts["meeting.status"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["meeting.status"].label, "Awaiting agreement")
        XCTAssertFalse(app.buttons["meeting.accept"].exists)
        app.terminate(); app.launch()
        tap(app.tabBars.buttons["Meetings"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch, in: app)
        XCTAssertEqual(app.staticTexts["meeting.status"].label, "Awaiting agreement")
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        signIn(app, email: secondEmail, password: password)
        tap(app.tabBars.buttons["Meetings"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch, in: app)
        tap(app.buttons["meeting.accept"], in: app)
        let confirmed = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "meeting.status", "Confirmed")).firstMatch
        XCTAssertTrue(confirmed.waitForExistence(timeout: 15))
        tap(app.buttons["meeting.change"], in: app)
        fill(app.textViews["meeting.note"], with: "Library upstairs", in: app)
        tap(app.buttons["meeting.review"], in: app); tap(app.buttons["meeting.send"], in: app)
        tap(app.buttons["meeting.viewChange"], in: app)
        XCTAssertTrue(app.staticTexts["Library upstairs"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["New date and time"].exists)
        XCTAssertFalse(app.buttons["meeting.acceptChange"].exists)
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        signIn(app, email: firstEmail, password: password)
        tap(app.tabBars.buttons["Meetings"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch, in: app)
        tap(app.buttons["meeting.viewChange"], in: app)
        tap(app.buttons["meeting.declineChange"], in: app)
        XCTAssertTrue(app.staticTexts["No pending change"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(confirmed.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Library upstairs"].exists)
        tap(app.buttons["meeting.change"], in: app)
        fill(app.textViews["meeting.note"], with: "Library reading room", in: app)
        tap(app.buttons["meeting.review"], in: app); tap(app.buttons["meeting.send"], in: app)
        app.tabBars.buttons["Profile"].tap(); signOut(app)
        signIn(app, email: secondEmail, password: password)
        tap(app.tabBars.buttons["Meetings"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch, in: app)
        tap(app.buttons["meeting.viewChange"], in: app)
        tap(app.buttons["meeting.acceptChange"], in: app)
        XCTAssertTrue(app.staticTexts["No pending change"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(confirmed.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Library reading room"].exists)
        capture("Agreed replacement details", app: app)
        tap(app.buttons["meeting.cancel"], in: app)
        tap(app.alerts["Cancel this meeting?"].buttons["Cancel Meeting"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "meeting.status", "Cancelled")).firstMatch.waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        tap(app.buttons["History"], in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap(); signOut(app)
    }

    func testMeetingAccessibilityAtLargeTextInDarkAppearance() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CHESSOTB_LOCAL_TESTS"] == "YES" else { throw XCTSkip("Local backend required") }
        baseURL = environment["CHESSOTB_TEST_API_URL"] ?? ""
        publishableKey = environment["CHESSOTB_TEST_PUBLISHABLE_KEY"] ?? ""
        guard baseURL == "http://127.0.0.1:54321" else { XCTFail("Local backend only"); return }
        let firstEmail = "ui-access-a-" + UUID().uuidString.lowercased() + "@example.com"
        let secondEmail = "ui-access-b-" + UUID().uuidString.lowercased() + "@example.com"
        let first = try await createConfirmedAccount(email: firstEmail)
        let second = try await createConfirmedAccount(email: secondEmail)
        _ = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Accessible player"], token: first)
        let peerData = try await post("/rest/v1/rpc/save_own_profile", body: ["p_display_name": "Other player"], token: second)
        let peer = try XCTUnwrap((JSONSerialization.jsonObject(with: peerData) as? [[String: Any]])?.first?["id"] as? String)
        _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: first)
        let threadData = try await post("/rest/v1/rpc/open_conversation", body: ["p_peer_id": peer], token: first)
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: threadData, options: .fragmentsAllowed) as? String)
        _ = try await post("/rest/v1/rpc/create_meeting_with_place", body: ["p_conversation_id": thread, "p_request_id": UUID().uuidString, "p_starts_at": "2099-05-17T18:00:00Z", "p_time_zone": "America/New_York", "p_location": "Central Library", "p_place": ["name": "Central Library", "address": "476 5th Ave, New York, NY 10018", "latitude": 40.7532, "longitude": -73.9822], "p_note": "A quiet game. Bring a board if you have one."], token: first)
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout: 2) { app.tabBars.buttons["Profile"].tap() }
        if app.buttons["account.signOut"].waitForExistence(timeout: 2) { signOut(app) }
        signIn(app, email: firstEmail, password: password)
        tap(app.tabBars.buttons["Profile"], in: app)
        let dark = app.switches["profile.darkAppearance"]
        if dark.value as? String != "1" { tap(dark, in: app) }
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tap(app.tabBars.buttons["Meetings"], in: app)
        capture("Meeting list dark accessibility text", app: app)
        try auditVisibleMeetingContent(app)
        app.scrollViews.firstMatch.swipeUp()
        try auditVisibleMeetingContent(app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meeting.row.")).firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["meeting.status"].waitForExistence(timeout: 10))
        capture("Meeting details dark accessibility text", app: app)
        try auditVisibleMeetingContent(app)
        app.terminate(); app.launchArguments = []; app.launch()
        tap(app.tabBars.buttons["Profile"], in: app)
        if app.switches["profile.darkAppearance"].value as? String == "1" { tap(app.switches["profile.darkAppearance"], in: app) }
        signOut(app)
    }

    private func auditVisibleMeetingContent(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .sufficientElementDescription]) { issue in
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            let navigationBottom = app.navigationBars.firstMatch.frame.maxY
            let tabTop = app.tabBars.firstMatch.frame.minY
            let frame = element.frame
            // The contrast auditor captures an element's full frame even when a scroll edge
            // clips its offscreen lines. Audit fully visible text, then scroll and audit again.
            return frame.minY < navigationBottom || frame.maxY > tabTop
        }
    }

    private func selectMeetingAddress(_ query: String, in app: XCUIApplication) {
        tap(app.buttons["meeting.location"], in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(query)
        let result = app.buttons["meeting.addressResult"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20)); result.tap()
        XCTAssertTrue(app.buttons["meeting.review"].isEnabled)
    }

    private func selectDistance(_ miles: Int, in app: XCUIApplication) {
        fill(app.textFields["discovery.radiusMiles"], with: String(miles), in: app)
        let done = app.buttons["discovery.radiusDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }

    private func seedAreaForAccount(email: String, app: XCUIApplication) async throws {
        XCTAssertTrue(app.buttons["area.manual"].waitForExistence(timeout: 15))
        let data = try await post("/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
        let token = try XCTUnwrap((JSONSerialization.jsonObject(with: data) as? [String: Any])?["access_token"] as? String)
        _ = try await post("/rest/v1/rpc/save_own_profile_area", body: ["p_name": "New York, NY", "p_latitude": 40.71, "p_longitude": -74.01, "p_country_code": "US", "p_radius_miles": 5], token: token)
        app.terminate(); app.launch()
    }

    private func signIn(_ app: XCUIApplication, email: String, password: String) {
        fill(app.textFields["account.email"], with: email, in: app)
        fill(app.secureTextFields["account.password"], with: password, in: app)
        tap(app.buttons["account.submit"], in: app)
    }

    private func signOut(_ app: XCUIApplication) {
        tap(app.buttons["account.signOut"], in: app)
        let confirmation = app.alerts["Sign out of ChessOTB?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Sign out"].tap()
        XCTAssertTrue(app.textFields["account.email"].waitForExistence(timeout: 15))
    }

    private func assertProfile(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Profile"].tap()
        let label = app.staticTexts["profile.displayName"]
        XCTAssertTrue(label.waitForExistence(timeout: 15))
        XCTAssertEqual(label.label, name)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10))
        if element.identifier == "area.search", app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
            return
        }
        if app.keyboards.firstMatch.exists,
           element.frame.maxY >= app.keyboards.firstMatch.frame.minY - 50 {
            app.scrollViews.firstMatch.swipeUp()
        }
        for _ in 0..<5 {
            if element.isHittable { break }
            if element.frame.maxY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
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
            if element.identifier.hasPrefix("meeting.") {
                // Multiline meeting fields reopen with a caret at the start.
                element.typeKey("a", modifierFlags: .command)
                element.typeText(XCUIKeyboardKey.delete.rawValue)
            } else {
                element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: element.elementType == .secureTextField ? 128 : current.count))
            }
        }
        element.typeText(value)
        if element.elementType == .textField {
            XCTAssertEqual(element.value as? String, value, "The test must enter the intended text before submitting")
        }
    }

    @discardableResult private func createConfirmedAccount(email: String) async throws -> String {
        _ = try await post("/auth/v1/signup", body: ["email": email, "password": password])
        let code = try await emailCode(for: email, subject: "Confirm")
        let data = try await post("/auth/v1/verify", body: ["email": email, "token": code, "type": "signup"])
        return try XCTUnwrap((JSONSerialization.jsonObject(with: data) as? [String: Any])?["access_token"] as? String)
    }

    private func post(_ path: String, body: [String: Any], token: String? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
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
