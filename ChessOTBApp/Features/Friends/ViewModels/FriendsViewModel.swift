import Combine
import Foundation

@MainActor final class FriendsViewModel: ObservableObject {
    @Published private(set) var relationships: [UUID: Friendship] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var nextCursor: Int64?
    @Published private(set) var busy: Set<UUID> = []
    @Published private(set) var pending: [UUID: FriendshipAction] = [:]
    private var listedIDs: [UUID] = []
    private var requests: [UUID: Request] = [:]
    private var active = true
    private var generation = 0
    let ownProfileID: UUID
    private let service: any FriendshipServiceProtocol
    private let cache: AccountCache
    private struct Request: Codable { let action: FriendshipAction; let id: UUID; let version: Int }
    var rows: [Friendship] { listedIDs.compactMap { relationships[$0] }.filter { $0.state != .none }.sorted { $0.sequence > $1.sequence } }
    init(service: any FriendshipServiceProtocol, cache: AccountCache, ownProfileID: UUID) {
        self.service = service; self.cache = cache; self.ownProfileID = ownProfileID
        do {
            requests = try cache.load([UUID: Request].self, key: "friendship-actions") ?? [:]
            pending = requests.mapValues(\.action)
        } catch { errorMessage = error.localizedDescription }
    }
    func refresh(peerID: UUID) async {
        guard active, cache.isActive else { return }
        do {
            let result = try await service.relationship(peerID: peerID)
            guard active, cache.isActive, !Task.isCancelled else { return }
            apply(result)
        } catch is CancellationError { return }
        catch { if active, cache.isActive { errorMessage = error.localizedDescription } }
    }
    func refresh() async {
        guard active, cache.isActive, !isLoading else { return }
        generation += 1; let stamp = generation
        isLoading = true
        defer { if generation == stamp { isLoading = false } }
        do {
            var page = try await service.list(before: nil)
            var fetched = page.relationships
            while fetched.count < listedIDs.count, let cursor = page.nextCursor {
                try Task.checkCancellation()
                page = try await service.list(before: cursor); fetched += page.relationships
            }
            guard active, cache.isActive, !Task.isCancelled, stamp == generation else { return }
            for row in fetched { apply(row) }
            listedIDs = fetched.map(\.peerID); nextCursor = page.nextCursor
            if requests.isEmpty { errorMessage = nil }
        } catch is CancellationError { return }
        catch { if active, cache.isActive { errorMessage = error.localizedDescription } }
    }
    func loadMore() async {
        guard active, cache.isActive, !isLoading, let cursor = nextCursor else { return }
        let stamp = generation; isLoading = true
        defer { if generation == stamp { isLoading = false } }
        do {
            let page = try await service.list(before: cursor)
            guard active, cache.isActive, !Task.isCancelled, stamp == generation else { return }
            for row in page.relationships {
                apply(row)
                if !listedIDs.contains(row.peerID) { listedIDs.append(row.peerID) }
            }
            nextCursor = page.nextCursor
        } catch is CancellationError { return }
        catch { if active, cache.isActive { errorMessage = error.localizedDescription } }
    }
    func perform(_ action: FriendshipAction, peerID: UUID) async {
        guard active, cache.isActive, !busy.contains(peerID), let row = relationships[peerID] else { return }
        if let request = requests[peerID], request.action != action { return }
        busy.insert(peerID); errorMessage = nil
        defer { busy.remove(peerID) }
        do {
            let request = requests[peerID] ?? Request(action: action, id: UUID(), version: row.version)
            requests[peerID] = request; pending[peerID] = request.action
            try persist() // Persist before sending to recover a lost acknowledgement.
            let result = try await service.mutate(peerID: peerID, action: request.action, requestID: request.id, version: request.version)
            guard active, cache.isActive, !Task.isCancelled else { return }
            apply(result)
            if result.state != .none, !listedIDs.contains(peerID) { listedIDs.append(peerID) }
            try clear(peerID)
            await refresh(peerID: peerID)
        } catch is CancellationError { return }
        catch {
            guard active, cache.isActive else { return }
            if let api = error as? APIError, api == .conflict || api == .rejected {
                do { try clear(peerID) } catch { errorMessage = error.localizedDescription; return }
                await refresh(peerID: peerID)
            }
            errorMessage = error.localizedDescription
        }
    }
    func deactivate() {
        active = false; generation += 1
        relationships = [:]; listedIDs = []; requests = [:]; pending = [:]; busy = []; errorMessage = nil
    }
    private func apply(_ row: Friendship) {
        if row.version >= (relationships[row.peerID]?.version ?? 0) { relationships[row.peerID] = row }
    }
    private func clear(_ peerID: UUID) throws {
        var updated = requests; updated.removeValue(forKey: peerID)
        try cache.save(updated, key: "friendship-actions")
        requests = updated; pending.removeValue(forKey: peerID)
    }
    private func persist() throws { try cache.save(requests, key: "friendship-actions") }
}
