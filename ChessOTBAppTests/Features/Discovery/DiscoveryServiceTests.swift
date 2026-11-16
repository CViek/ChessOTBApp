import Foundation
import Testing
@testable import ChessOTBApp

struct DiscoveryServiceTests {
    @Test func sendsOnlyApproximateAreaAndDecodesPrivateSettings() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/save_search_area")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_latitude"] as? Double == 40.71)
            #expect(body["p_longitude"] as? Double == -74.01)
            #expect(body["p_radius_miles"] as? Int == 5)
            #expect(body["p_owner_id"] == nil)
            return (200, Data(#"{"area":{"name":"New York, NY","latitude":40.71,"longitude":-74.01,"country_code":"US"},"radius":5}"#.utf8))
        }
        let service = DiscoveryService(client: client, auth: AuthDouble())
        let saved = try await service.saveSettings(area: DiscoveryFixtures.newYork, radius: .five)
        #expect(saved.area.latitude == 40.71)
        #expect(saved.radius == .five)
    }
    @Test func passesOpaquePaginationCursorAndDecodesPublicPlayers() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/search_players")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_cursor"] as? String == "opaque")
            return (200, Data(#"{"players":[{"id":"aaaaaaaa-1111-1111-1111-111111111111","display_name":"First player","area_name":"New York, NY","distance_miles":0}],"next_cursor":null}"#.utf8))
        }
        let page = try await DiscoveryService(client: client, auth: AuthDouble()).searchPlayers(settings: DiscoveryFixtures.settings, cursor: "opaque")
        #expect(page.players.first?.distanceMiles == 0)
        #expect(page.nextCursor == nil)
    }
}
