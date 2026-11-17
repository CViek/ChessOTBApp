import Combine
import Foundation

@MainActor final class MyMeetingsViewModel: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var nextCursor: Int64?
    private let service: any MeetingServiceProtocol
    private let cache: AccountCache
    private var active = true
    private var generation = 0
    init(service: any MeetingServiceProtocol, cache: AccountCache) { self.service = service; self.cache = cache }
    func visible(history: Bool, at now: Date) -> [Meeting] {
        meetings.filter { $0.isHistory(at: now) == history }.sorted { history ? $0.revision.startsAt > $1.revision.startsAt : $0.revision.startsAt < $1.revision.startsAt }
    }
    func refresh() async {
        guard active, cache.isActive else { return }
        generation += 1; let stamp = generation
        isLoading = meetings.isEmpty
        defer { if generation == stamp { isLoading = false } }
        do {
            // Re-fetch every previously loaded page, so old arrangements can move between segments.
            var page = try await service.list(before: nil)
            var fetched = page.meetings
            let targetCount = max(meetings.count, 50)
            while fetched.count < targetCount, let cursor = page.nextCursor {
                try Task.checkCancellation()
                page = try await service.list(before: cursor); fetched += page.meetings
            }
            guard active, cache.isActive, !Task.isCancelled, stamp == generation else { return }
            meetings = fetched; nextCursor = page.nextCursor; errorMessage = nil
        } catch is CancellationError { return }
        catch { if active, cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
    func loadMore() async {
        guard active, cache.isActive, let cursor = nextCursor, !isLoading else { return }
        let stamp = generation; isLoading = true
        defer { if generation == stamp { isLoading = false } }
        do {
            let page = try await service.list(before: cursor)
            guard active, cache.isActive, !Task.isCancelled, generation == stamp else { return }
            let existing = Set(meetings.map(\.id))
            meetings += page.meetings.filter { !existing.contains($0.id) }; nextCursor = page.nextCursor; errorMessage = nil
        } catch is CancellationError { return }
        catch { if active, cache.isActive { errorMessage = error.localizedDescription } }
    }
    func deactivate() { active = false; generation += 1; meetings = []; nextCursor = nil; errorMessage = nil }
}
