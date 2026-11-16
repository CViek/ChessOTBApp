#if DEBUG
import Foundation

/// Design-time states only; the live dependency factory never constructs these services.
nonisolated struct PreviewDiscoveryService: DiscoveryServiceProtocol {
    nonisolated enum State: Sendable { case populated, empty, loading, failed }
    static let profileID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    static let area = ApproximateArea(name: "New York, NY", latitude: 40.71, longitude: -74.01, countryCode: "US")
    static let settings = DiscoverySettings(area: area, radius: .five)
    let state: State
    func loadSettings() async throws -> DiscoverySettings? { Self.settings }
    func saveSettings(area: ApproximateArea, radius: SearchRadius) async throws -> DiscoverySettings { DiscoverySettings(area: area, radius: radius) }
    func searchPlayers(settings: DiscoverySettings, cursor: String?) async throws -> PlayerPage {
        switch state {
        case .populated:
            return PlayerPage(players: [NearbyPlayer(id: PreviewDiscoveryService.profileID, displayName: "Alex Morgan", areaName: Self.area.name, distanceMiles: 2)], nextCursor: nil)
        case .empty: return PlayerPage(players: [], nextCursor: nil)
        case .failed: throw APIError.network
        case .loading:
            try await Task.sleep(for: .seconds(3600))
            return PlayerPage(players: [], nextCursor: nil)
        }
    }
}

nonisolated struct PreviewPlayerService: ProfileServiceProtocol {
    nonisolated enum State: Sendable { case populated, missing, loading, failed }
    let state: State
    func publicProfile(id: UUID) async throws -> PlayerProfile? {
        switch state {
        case .populated: return PlayerProfile(id: id, displayName: "Alex Morgan", areaName: PreviewDiscoveryService.area.name)
        case .missing: return nil
        case .failed: throw APIError.network
        case .loading:
            try await Task.sleep(for: .seconds(3600))
            return nil
        }
    }
    func loadOwnProfile() async throws -> PlayerProfile? { try await publicProfile(id: PreviewDiscoveryService.profileID) }
    func loadArea() async throws -> ApproximateArea? {
        switch state {
        case .populated: return PreviewDiscoveryService.area
        case .missing: return nil
        case .failed: throw APIError.network
        case .loading:
            try await Task.sleep(for: .seconds(3600))
            return nil
        }
    }
    func saveDisplayName(_ name: String) async throws -> PlayerProfile { throw APIError.unavailable }
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) async throws -> PlayerProfile { throw APIError.unavailable }
}
#endif
