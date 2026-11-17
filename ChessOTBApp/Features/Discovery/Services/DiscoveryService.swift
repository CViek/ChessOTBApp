import Foundation

nonisolated protocol DiscoveryServiceProtocol: Sendable {
    func saveFilters(settings: DiscoverySettings, rating: RatingCriteria?) async throws -> DiscoverySettings
    func loadSettings() async throws -> DiscoverySettings?
    func saveSettings(area: ApproximateArea, radius: SearchRadius) async throws -> DiscoverySettings
    func searchPlayers(settings: DiscoverySettings, cursor: String?) async throws -> PlayerPage
}

nonisolated struct AreaSaveRequest: Encodable, Sendable {
    let p_name: String
    let p_latitude: Double
    let p_longitude: Double
    let p_country_code: String
    let p_radius_miles: Int
    init(area: ApproximateArea, radius: SearchRadius) throws {
        let area = try area.validated()
        p_name = area.name; p_latitude = area.latitude; p_longitude = area.longitude
        p_country_code = area.countryCode; p_radius_miles = radius.rawValue
    }
}

nonisolated struct DiscoveryService: DiscoveryServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol
    func saveFilters(settings: DiscoverySettings, rating: RatingCriteria?) async throws -> DiscoverySettings {
        let session = try await auth.validSession()
        let body = try JSONEncoder().encode(FilterRequest(p_radius_miles: settings.radius.rawValue, p_rating_kind: rating?.kind.rawValue,
                                                         p_rating_min: rating?.minimum, p_rating_max: rating?.maximum))
        return try await client.request("rest/v1/rpc/save_search_filters", method: "POST", body: body, token: session.accessToken)
    }
    private struct FilterRequest: Encodable {
        let p_radius_miles: Int
        let p_rating_kind: String?
        let p_rating_min: Int?
        let p_rating_max: Int?
    }
    func loadSettings() async throws -> DiscoverySettings? {
        let session = try await auth.validSession()
        return try await client.request("rest/v1/rpc/get_discovery_settings", method: "POST", body: Data("{}".utf8), token: session.accessToken)
    }
    func saveSettings(area: ApproximateArea, radius: SearchRadius) async throws -> DiscoverySettings {
        let body = try JSONEncoder().encode(AreaSaveRequest(area: area, radius: radius))
        let session = try await auth.validSession()
        return try await client.request("rest/v1/rpc/save_search_area", method: "POST", body: body, token: session.accessToken)
    }
    func searchPlayers(settings: DiscoverySettings, cursor: String?) async throws -> PlayerPage {
        let area = try settings.area.validated()
        let body = try JSONEncoder().encode(SearchRequest(p_latitude: area.latitude, p_longitude: area.longitude,
                                                        p_radius_miles: settings.radius.rawValue, p_cursor: cursor, p_limit: 20, p_rating_kind: settings.rating?.kind.rawValue,
                                                        p_rating_min: settings.rating?.minimum, p_rating_max: settings.rating?.maximum))
        let session = try await auth.validSession()
        return try await client.request("rest/v1/rpc/search_players", method: "POST", body: body, token: session.accessToken)
    }
    private struct SearchRequest: Encodable {
        let p_latitude: Double; let p_longitude: Double; let p_radius_miles: Int
        let p_cursor: String?; let p_limit: Int
        let p_rating_kind: String?; let p_rating_min: Int?; let p_rating_max: Int?
    }
}

extension DiscoveryServiceProtocol {
    func saveFilters(settings: DiscoverySettings, rating: RatingCriteria?) async throws -> DiscoverySettings {
        guard rating == nil else { throw APIError.unavailable }
        return try await saveSettings(area: settings.area, radius: settings.radius)
    }
}
