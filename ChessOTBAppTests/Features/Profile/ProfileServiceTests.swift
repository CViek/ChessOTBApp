import Foundation
import Testing
@testable import ChessOTBApp

struct ProfileServiceTests {
    @Test func savingMultipleRatingsSendsCompleteListAndDecodesAllEntries() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/save_profile_ratings")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try HTTPStub.body(request)
            let fields = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(fields["p_display_name"] as? String == "Alex")
            let ratings = try #require(fields["p_ratings"] as? [[String: Any]])
            #expect(ratings.count == 2)
            #expect(ratings[0]["kind"] as? String == "chess_com_rapid")
            #expect(ratings[0]["value"] as? Int == 1500)
            #expect(ratings[1]["kind"] as? String == "lichess_blitz")
            #expect(ratings[1]["value"] as? Int == 1700)
            return (200, Data(#"[{"id":"99999999-9999-9999-9999-999999999999","display_name":"Alex","ratings":[{"kind":"chess_com_rapid","value":1500},{"kind":"lichess_blitz","value":1700}]}]"#.utf8))
        }
        let profile = try await ProfileService(client: client, auth: AuthDouble()).saveProfile(displayName: " Alex ", ratings: [
            RatingEntry(kind: .chessComRapid, value: 1500), RatingEntry(kind: .lichessBlitz, value: 1700)
        ])
        #expect(profile.ratings == [RatingEntry(kind: .chessComRapid, value: 1500), RatingEntry(kind: .lichessBlitz, value: 1700)])
    }

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
