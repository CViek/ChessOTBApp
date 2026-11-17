import Foundation

nonisolated struct Friendship: Codable, Identifiable, Equatable, Sendable {
    enum State: String, Codable, Sendable { case none, pending, accepted }
    let peerID: UUID
    let displayName: String
    let areaName: String?
    let state: State
    let requesterID: UUID?
    let version: Int
    let sequence: Int64
    var id: UUID { peerID }
    var route: ConversationRoute { ConversationRoute(peerID: peerID, displayName: displayName) }
    func canRespond(ownProfileID: UUID) -> Bool { state == .pending && requesterID == peerID && requesterID != ownProfileID }
    enum CodingKeys: String, CodingKey {
        case peerID = "peerId", requesterID = "requesterId"
        case displayName, areaName, state, version, sequence
    }
}
nonisolated struct FriendshipPage: Codable, Sendable {
    let relationships: [Friendship]
    let nextCursor: Int64?
}
nonisolated enum FriendshipAction: String, Codable, Sendable { case send, accept, decline, remove }
