import Foundation
import Testing
@testable import ChessOTBApp

struct FriendshipTests {
    @Test func onlyIncomingPendingRequestsExposeResponseActions() {
        let own = UUID(), peer = UUID()
        let outgoing = Friendship(peerID: peer, displayName: "Peer", areaName: nil, state: .pending, requesterID: own, version: 1, sequence: 1)
        let incoming = Friendship(peerID: peer, displayName: "Peer", areaName: nil, state: .pending, requesterID: peer, version: 1, sequence: 1)
        #expect(!outgoing.canRespond(ownProfileID: own))
        #expect(incoming.canRespond(ownProfileID: own))
    }
    @Test func relationshipDecodesPublicIdentityAndState() throws {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let row = try decoder.decode(Friendship.self, from: Data(#"{"peer_id":"80000000-0000-0000-0000-000000000001","display_name":"Peer","area_name":null,"state":"accepted","requester_id":null,"version":4,"sequence":10}"#.utf8))
        #expect(row.state == .accepted)
        #expect(row.version == 4)
    }
}
