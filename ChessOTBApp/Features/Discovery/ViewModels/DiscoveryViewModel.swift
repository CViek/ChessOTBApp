import Combine
import Foundation

@MainActor
final class DiscoveryViewModel: ObservableObject {
    @Published private(set) var settings: DiscoverySettings?
    @Published private(set) var players: [NearbyPlayer] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    let service: any DiscoveryServiceProtocol
    private var generation = UUID()
    init(service: any DiscoveryServiceProtocol) { self.service = service }

    func refresh() async {
        guard !isSaving else { return }
        let request = UUID(); generation = request
        isLoading = true; isLoadingMore = false; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let saved = try await service.loadSettings()
            try Task.checkCancellation()
            guard generation == request else { return }
            if let saved { await search(settings: saved) }
            else { settings = nil; players = []; nextCursor = nil }
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    func search(settings: DiscoverySettings) async {
        let request = UUID(); generation = request
        self.settings = settings; players = []; nextCursor = nil
        isLoading = true; isLoadingMore = false; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await service.searchPlayers(settings: settings, cursor: nil)
            try Task.checkCancellation()
            guard generation == request else { return }
            players = page.players; nextCursor = page.nextCursor
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    func loadMore() async {
        guard !isSaving, !isLoading, !isLoadingMore, let settings, let cursor = nextCursor else { return }
        let request = generation
        isLoadingMore = true; errorMessage = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await service.searchPlayers(settings: settings, cursor: cursor)
            try Task.checkCancellation()
            guard generation == request else { return }
            var ids = Set(players.map(\.id))
            players += page.players.filter { ids.insert($0.id).inserted }
            nextCursor = page.nextCursor
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    func setRadius(_ radius: SearchRadius) async -> Bool {
        guard !isSaving, let settings else { return false }
        let request = UUID(); generation = request
        isLoading = false; isLoadingMore = false
        isSaving = true; errorMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await service.saveSettings(area: settings.area, radius: radius)
            try Task.checkCancellation()
            guard generation == request else { return false }
            await search(settings: saved)
            return true
        } catch is CancellationError { return false }
        catch { if generation == request { record(error) }; return false }
    }
    func setFilters(radius: SearchRadius, rating: RatingCriteria?) async -> Bool {
        guard !isSaving, let settings else { return false }
        let request = UUID(); generation = request
        isSaving = true; isLoading = false; isLoadingMore = false; errorMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await service.saveFilters(settings: DiscoverySettings(area: settings.area, radius: radius, rating: settings.rating), rating: rating)
            try Task.checkCancellation()
            guard generation == request else { return false }
            await search(settings: saved)
            return true
        } catch is CancellationError { return false }
        catch { if generation == request { record(error) }; return false }
    }
    var filterCount: Int {
        guard let settings else { return 0 }
        return (settings.radius == .five ? 0 : 1) + (settings.rating == nil ? 0 : 1)
    }
    private func record(_ error: Error) {
        errorMessage = error.localizedDescription
        needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
    }
}
