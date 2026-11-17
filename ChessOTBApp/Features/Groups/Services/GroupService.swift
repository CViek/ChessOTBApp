import Foundation

nonisolated protocol GroupServiceProtocol: Sendable {
    func search(settings: DiscoverySettings, cursor: String?) async throws -> GroupPage
    func detail(id: UUID) async throws -> GroupListing?
}
nonisolated struct GroupService: GroupServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol
    let accountID: UUID
    private func token() async throws -> String {
        let session = try await auth.validSession()
        guard session.user.id == accountID else { throw APIError.unauthorized }
        try Task.checkCancellation()
        return session.accessToken
    }
    func search(settings: DiscoverySettings, cursor: String?) async throws -> GroupPage {
        let area = try settings.area.validated()
        let body = try JSONEncoder().encode(SearchRequest(p_latitude: area.latitude, p_longitude: area.longitude,
                                                         p_radius_miles: settings.radius.rawValue, p_cursor: cursor, p_limit: 20))
        return try await client.request("rest/v1/rpc/search_groups", method: "POST", body: body, token: token())
    }
    func detail(id: UUID) async throws -> GroupListing? {
        try await client.request("rest/v1/rpc/get_group_listing", method: "POST", body: JSONEncoder().encode(["p_id": id.uuidString]), token: token())
    }
    private struct SearchRequest: Encodable {
        let p_latitude: Double; let p_longitude: Double; let p_radius_miles: Int
        let p_cursor: String?; let p_limit: Int
    }
}
nonisolated struct UnavailableGroupService: GroupServiceProtocol {
    func search(settings: DiscoverySettings, cursor: String?) async throws -> GroupPage { throw APIError.invalidConfiguration }
    func detail(id: UUID) async throws -> GroupListing? { throw APIError.invalidConfiguration }
}
