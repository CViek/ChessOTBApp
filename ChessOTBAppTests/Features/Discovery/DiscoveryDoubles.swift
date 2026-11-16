import Foundation
@testable import ChessOTBApp

nonisolated enum DiscoveryFixtures {
    static let newYork = ApproximateArea(name: "New York, NY", latitude: 40.71283, longitude: -74.00605, countryCode: "US")
    static let boston = ApproximateArea(name: "Boston, MA", latitude: 42.36, longitude: -71.06, countryCode: "US")
    static let settings = DiscoverySettings(area: newYork, radius: .five)
    static let first = NearbyPlayer(id: UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111")!, displayName: "First player", areaName: "New York, NY", distanceMiles: 1)
    static let second = NearbyPlayer(id: UUID(uuidString: "bbbbbbbb-1111-1111-1111-111111111111")!, displayName: "Second player", areaName: "New York, NY", distanceMiles: 2)
}

@MainActor final class AreaLookupDouble: AreaLookupProtocol {
    let areas: [ApproximateArea]
    init(_ areas: [ApproximateArea]) { self.areas = areas }
    @MainActor func lookup(_ query: String) async -> [ApproximateArea] { areas }
    @MainActor func lookupCurrentArea(latitude: Double, longitude: Double) async -> [ApproximateArea] { areas }
}

@MainActor final class LocationDouble: DeviceLocationProtocol {
    let denied: Bool
    init(denied: Bool = false) { self.denied = denied }
    @MainActor func currentCoordinate() async throws -> DeviceCoordinate {
        if denied { throw AreaError.permissionDenied }
        return DeviceCoordinate(latitude: 40.71283912, longitude: -74.00605912)
    }
}

@MainActor final class DiscoveryDouble: DiscoveryServiceProtocol {
    var settings = DiscoveryFixtures.settings
    var failure: APIError?
    private var delayFirst = false
    private var pending: CheckedContinuation<PlayerPage, Never>?
    func configureDelay() { delayFirst = true }
    func isWaiting() -> Bool { pending != nil }
    func finishOldRequest() { pending?.resume(returning: PlayerPage(players: [DiscoveryFixtures.first], nextCursor: nil)); pending = nil }
    func setFailure(_ error: APIError) { failure = error }
    @MainActor func loadSettings() async -> DiscoverySettings? { settings }
    @MainActor func saveSettings(area: ApproximateArea, radius: SearchRadius) async throws -> DiscoverySettings {
        if let failure { throw failure }
        settings = DiscoverySettings(area: area, radius: radius)
        return settings
    }
    @MainActor func searchPlayers(settings: DiscoverySettings, cursor: String?) async throws -> PlayerPage {
        if let failure { throw failure }
        if delayFirst && settings.area.name == DiscoveryFixtures.newYork.name {
            return await withCheckedContinuation { pending = $0 }
        }
        if cursor == nil { return PlayerPage(players: [DiscoveryFixtures.second], nextCursor: "next") }
        return PlayerPage(players: [DiscoveryFixtures.first], nextCursor: nil)
    }
}
