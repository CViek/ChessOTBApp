import Foundation
import Testing
@testable import ChessOTBApp

struct ProfileServiceTests {
    @Test func saveSendsNoCallerSuppliedOwnerAndReturnsPublicProjection() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/save_own_profile")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            return (200, Data(#"[{"id":"99999999-9999-9999-9999-999999999999","display_name":"New name"}]"#.utf8))
        }
        let profile = try await ProfileService(client: client, auth: AuthDouble()).saveDisplayName("New name")
        #expect(profile.id == AccountFixtures.profileID)
        #expect(profile.displayName == "New name")
        let fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as! [String: Any]
        #expect(Set(fields.keys) == ["id", "displayName"])
    }
}
