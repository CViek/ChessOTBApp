import Combine
import Foundation

@MainActor final class InboxViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var nextCursor: InboxCursor?
    let service: any ConversationServiceProtocol
    let cache: AccountCache
    private var generation = 0
    var unreadCount: Int { conversations.reduce(0) { $0 + $1.unreadCount } }
    init(service: any ConversationServiceProtocol, cache: AccountCache) {
        self.service = service; self.cache = cache
        do {
            if let saved = try cache.load(Snapshot.self, key: "paged-inbox") {
                conversations = saved.rows; nextCursor = saved.cursor
            } else { conversations = try cache.load([Conversation].self, key: "inbox") ?? [] }
        } catch { errorMessage = error.localizedDescription }
    }
    func deactivate() {
        generation += 1; conversations = []; nextCursor = nil
        errorMessage = nil; isLoading = false; isLoadingMore = false; hasLoaded = false
    }
    func refresh() async {
        guard cache.isActive else { return }
        generation += 1; let stamp = generation
        isLoading = !hasLoaded && conversations.isEmpty; isLoadingMore = false
        defer { if generation == stamp { isLoading = false } }
        do {
            var page = try await service.inboxPage(cursor: nil)
            var fetched = page.conversations
            let targetCount = max(conversations.count, page.conversations.count)
            while fetched.count < targetCount, let cursor = page.nextCursor {
                try Task.checkCancellation()
                page = try await service.inboxPage(cursor: cursor)
                fetched += page.conversations
            }
            try Task.checkCancellation()
            guard cache.isActive, generation == stamp else { return }
            var ids = Set<UUID>()
            conversations = fetched.filter { ids.insert($0.id).inserted }
            nextCursor = page.nextCursor
            hasLoaded = true; errorMessage = nil
            try persist()
        } catch is CancellationError { return }
        catch { if cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
    func loadMore() async {
        guard cache.isActive, !isLoadingMore, let cursor = nextCursor else { return }
        let stamp = generation; isLoadingMore = true
        defer { if generation == stamp { isLoadingMore = false } }
        do {
            let page = try await service.inboxPage(cursor: cursor)
            try Task.checkCancellation()
            guard cache.isActive, generation == stamp else { return }
            let updates = Dictionary(page.conversations.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
            conversations = conversations.map { updates[$0.id] ?? $0 }
            var ids = Set(conversations.map(\.id))
            conversations += page.conversations.filter { ids.insert($0.id).inserted }
            nextCursor = page.nextCursor; errorMessage = nil; try persist()
        } catch is CancellationError { return }
        catch { if cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
    private func persist() throws { try cache.save(Snapshot(rows: conversations, cursor: nextCursor), key: "paged-inbox") }
    private struct Snapshot: Codable { let rows: [Conversation]; let cursor: InboxCursor? }
}
