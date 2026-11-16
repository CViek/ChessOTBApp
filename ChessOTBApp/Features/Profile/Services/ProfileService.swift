import Foundation

nonisolated struct ProfileService: ProfileServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol

    func loadOwnProfile() async throws -> PlayerProfile? {
        let session = try await auth.validSession()
        let profiles: [PlayerProfile] = try await client.request("rest/v1/rpc/get_own_profile", method: "POST", body: Data("{}".utf8), token: session.accessToken)
        return profiles.first
    }

    func saveDisplayName(_ name: String) async throws -> PlayerProfile {
        let name = try PlayerProfile.validatedName(name)
        let session = try await auth.validSession()
        let body = try JSONEncoder().encode(["p_display_name": name])
        let profiles: [PlayerProfile] = try await client.request("rest/v1/rpc/save_own_profile", method: "POST", body: body, token: session.accessToken)
        guard let profile = profiles.first else { throw APIError.invalidResponse }
        return profile
    }

    func publicProfile(id: UUID) async throws -> PlayerProfile? {
        let session = try await auth.validSession()
        let body = try JSONEncoder().encode(["p_profile_id": id.uuidString])
        let profiles: [PlayerProfile] = try await client.request("rest/v1/rpc/get_player_profile", method: "POST", body: body, token: session.accessToken)
        return profiles.first
    }
    func loadArea() async throws -> ApproximateArea? {
        let session = try await auth.validSession()
        return try await client.request("rest/v1/rpc/get_own_profile_area", method: "POST", body: Data("{}".utf8), token: session.accessToken)
    }
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) async throws -> PlayerProfile {
        let body = try JSONEncoder().encode(AreaSaveRequest(area: area, radius: radius))
        let session = try await auth.validSession()
        let profiles: [PlayerProfile] = try await client.request("rest/v1/rpc/save_own_profile_area", method: "POST", body: body, token: session.accessToken)
        guard let profile = profiles.first else { throw APIError.invalidResponse }
        return profile
    }

}
