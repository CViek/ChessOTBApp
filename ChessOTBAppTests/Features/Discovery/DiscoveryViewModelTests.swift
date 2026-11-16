import Foundation
import Testing
@testable import ChessOTBApp

@MainActor
struct DiscoveryViewModelTests {
    @Test func loadsSavedSearchAndAppendsNextPage() async {
        let model = DiscoveryViewModel(service: DiscoveryDouble())
        await model.refresh()
        #expect(model.players.map(\.id) == [DiscoveryFixtures.second.id])
        await model.loadMore()
        #expect(model.players.map(\.id) == [DiscoveryFixtures.second.id, DiscoveryFixtures.first.id])
        #expect(model.nextCursor == nil)
    }
    @Test func staleSearchCannotOverwriteANewerArea() async throws {
        let service = DiscoveryDouble()
        service.configureDelay()
        let model = DiscoveryViewModel(service: service)
        let old = Task { await model.search(settings: DiscoveryFixtures.settings) }
        for _ in 0..<100 {
            if service.isWaiting() { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard service.isWaiting() else { old.cancel(); Issue.record("Old request did not start"); return }
        await model.search(settings: DiscoverySettings(area: DiscoveryFixtures.boston, radius: .three))
        service.finishOldRequest()
        await old.value
        #expect(model.settings?.area.name == "Boston, MA")
        #expect(model.players.map(\.id) == [DiscoveryFixtures.second.id])
    }
    @Test func failedRadiusSavePreservesCommittedSearchSettings() async {
        let service = DiscoveryDouble()
        let model = DiscoveryViewModel(service: service)
        await model.refresh()
        service.setFailure(.network)
        #expect(await model.setRadius(.ten) == false)
        #expect(model.settings?.radius == .five)
        #expect(model.errorMessage != nil)
    }
}

@MainActor private final class OverlappingDiscoveryService: DiscoveryServiceProtocol {
    var failSettings = false
    var delayRadius = false
    var pendingPage: CheckedContinuation<PlayerPage, Never>?
    var pendingRadius: CheckedContinuation<DiscoverySettings, Never>?
    @MainActor func loadSettings() async throws -> DiscoverySettings? {
        if failSettings { throw APIError.network }
        return DiscoveryFixtures.settings
    }
    @MainActor func saveSettings(area: ApproximateArea, radius: SearchRadius) async -> DiscoverySettings {
        if delayRadius { return await withCheckedContinuation { pendingRadius = $0 } }
        return DiscoverySettings(area: area, radius: radius)
    }
    @MainActor func searchPlayers(settings: DiscoverySettings, cursor: String?) async -> PlayerPage {
        if cursor != nil { return await withCheckedContinuation { pendingPage = $0 } }
        return PlayerPage(players: [DiscoveryFixtures.second], nextCursor: "next")
    }
    func finishPage() { pendingPage?.resume(returning: PlayerPage(players: [DiscoveryFixtures.first], nextCursor: nil)); pendingPage = nil }
    func finishRadius() { pendingRadius?.resume(returning: DiscoverySettings(area: DiscoveryFixtures.newYork, radius: .ten)); pendingRadius = nil }
}

extension DiscoveryViewModelTests {
    @Test func failedRefreshClearsAnObsoletePaginationSpinner() async throws {
        let service = OverlappingDiscoveryService()
        let model = DiscoveryViewModel(service: service)
        await model.refresh()
        let paging = Task { await model.loadMore() }
        for _ in 0..<100 {
            if service.pendingPage != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard service.pendingPage != nil else { paging.cancel(); Issue.record("Page did not start"); return }
        service.failSettings = true
        await model.refresh()
        service.finishPage(); await paging.value
        #expect(model.isLoadingMore == false)
        #expect(model.players.map(\.id) == [DiscoveryFixtures.second.id])
        #expect(model.errorMessage != nil)
    }
    @Test func anOlderRadiusSaveCannotReplaceANewerArea() async throws {
        let service = OverlappingDiscoveryService()
        let model = DiscoveryViewModel(service: service)
        await model.refresh(); service.delayRadius = true
        let radiusSave = Task { await model.setRadius(.ten) }
        for _ in 0..<100 {
            if service.pendingRadius != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard service.pendingRadius != nil else { radiusSave.cancel(); Issue.record("Radius save did not start"); return }
        let newer = DiscoverySettings(area: DiscoveryFixtures.boston, radius: .three)
        await model.search(settings: newer)
        service.finishRadius()
        #expect(await radiusSave.value == false)
        #expect(model.settings == newer)
    }
}
