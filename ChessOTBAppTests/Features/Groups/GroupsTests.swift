import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct GroupsTests {
    @Test func queryUsesAreaAndRadiusWithoutPlayerRating() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/search_groups")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_radius_miles"] as? Int == 5)
            #expect(body["p_latitude"] as? Double == 40.71)
            #expect(body["p_rating_kind"] == nil)
            #expect(body["p_cursor"] as? String == "cursor")
            return (200, Data(#"{"groups":[],"next_cursor":null}"#.utf8))
        }
        let settings = DiscoverySettings(area: DiscoveryFixtures.newYork, radius: .five, rating: RatingCriteria(kind: .chessComRapid, minimum: 1200, maximum: 1600))
        let page = try await GroupService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID).search(settings: settings, cursor: "cursor")
        #expect(page.groups.isEmpty)
    }
    @Test func detailKeepsDistinctContactAndIntroductionIdentities() async throws {
        let groupID = UUID(), contactID = UUID(), introducedID = UUID()
        let client = try HTTPStub.client { request in
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect((body["p_id"] as? String)?.lowercased() == groupID.uuidString.lowercased())
            return (200, Data("{\"id\":\"\(groupID)\",\"name\":\"Group\",\"area_name\":\"Area\",\"description\":\"Description\",\"contact\":{\"id\":\"\(contactID)\",\"display_name\":\"Contact\"},\"introduction\":{\"text\":\"Approved\",\"player\":{\"id\":\"\(introducedID)\",\"display_name\":\"Player\"}}}".utf8))
        }
        let service = GroupService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let model = GroupDetailViewModel(service: service)
        await model.load(id: groupID)
        #expect(model.listing?.contact?.conversationRoute.peerID == contactID)
        #expect(model.listing?.introduction?.player.id == introducedID)
    }
    @Test func emptyMissingAndFailureStatesAreHonest() async throws {
        let client = try HTTPStub.client { request in
            if request.url?.path == "/rest/v1/rpc/search_groups" { return (200, Data(#"{"groups":[],"next_cursor":null}"#.utf8)) }
            return (200, Data("null".utf8))
        }
        let service = GroupService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let model = GroupsViewModel(service: service)
        await model.search(settings: DiscoveryFixtures.settings)
        #expect(model.groups.isEmpty && !model.isLoading && model.errorMessage == nil)
        let detail = GroupDetailViewModel(service: service)
        await detail.load(id: UUID())
        #expect(detail.hasLoaded && detail.listing == nil && detail.errorMessage == nil)
        let auth = AuthDouble(); try await auth.signOut()
        let unauthorized = GroupDetailViewModel(service: GroupService(client: client, auth: auth, accountID: AccountFixtures.userID))
        await unauthorized.load(id: UUID())
        #expect(unauthorized.needsSignIn)
    }
    @Test func groupSettingsLoadDoesNotDependOnPlayerSearch() async {
        let service = DiscoveryDouble()
        service.failure = .unavailable
        let model = DiscoveryViewModel(service: service)
        await model.refresh(searchPlayers: false)
        #expect(model.settings == DiscoveryFixtures.settings)
        #expect(model.errorMessage == nil && model.players.isEmpty && !model.isLoading)
    }
    @Test func unavailableContactIsNotReplacedWithASamplePlayer() async throws {
        let client = try HTTPStub.client { _ in
            (200, Data(#"{"id":"90000000-0000-0000-0000-000000000001","name":"Group","area_name":"Area","description":"Description","contact":null,"introduction":null}"#.utf8))
        }
        let detail = try await GroupService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID).detail(id: UUID())
        #expect(detail != nil && detail?.contact == nil && detail?.introduction == nil)
    }
    @Test func accountMismatchCannotFetch() async throws {
        let client = try HTTPStub.client { _ in Issue.record("Mismatched account must never reach transport"); return (200, Data("null".utf8)) }
        await #expect(throws: APIError.unauthorized) {
            try await GroupService(client: client, auth: AuthDouble(), accountID: UUID()).detail(id: UUID())
        }
    }
}
