import Foundation

nonisolated protocol FriendshipServiceProtocol: Sendable {
    func relationship(peerID: UUID) async throws -> Friendship
    func list(before: Int64?) async throws -> FriendshipPage
    func mutate(peerID: UUID, action: FriendshipAction, requestID: UUID, version: Int) async throws -> Friendship
}
nonisolated struct FriendshipService: FriendshipServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol
    let accountID: UUID
    private func token() async throws -> String {
        let session = try await auth.validSession()
        guard session.user.id == accountID else { throw APIError.unauthorized }
        try Task.checkCancellation()
        return session.accessToken
    }
    func relationship(peerID: UUID) async throws -> Friendship {
        try await client.request("rest/v1/rpc/get_friendship", method: "POST", body: JSONEncoder().encode(["p_peer_id": peerID.uuidString]), token: token())
    }
    func list(before: Int64?) async throws -> FriendshipPage {
        try await client.request("rest/v1/rpc/list_friendships", method: "POST", body: JSONEncoder().encode(ListRequest(p_before: before, p_limit: 50)), token: token())
    }
    func mutate(peerID: UUID, action: FriendshipAction, requestID: UUID, version: Int) async throws -> Friendship {
        let body = try JSONEncoder().encode(MutationRequest(p_peer_id: peerID, p_action: action.rawValue, p_request_id: requestID, p_expected_version: version))
        return try await client.request("rest/v1/rpc/mutate_friendship", method: "POST", body: body, token: token())
    }
    private struct ListRequest: Encodable { let p_before: Int64?; let p_limit: Int }
    private struct MutationRequest: Encodable { let p_peer_id: UUID; let p_action: String; let p_request_id: UUID; let p_expected_version: Int }
}
