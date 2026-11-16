import Combine
import Foundation

@MainActor final class InboxViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    let service: any ConversationServiceProtocol
    let cache: AccountCache
    private var generation = 0
    var unreadCount: Int { conversations.reduce(0) { $0 + $1.unreadCount } }

    init(service: any ConversationServiceProtocol, cache: AccountCache) {
        self.service = service; self.cache = cache
        do { conversations = try cache.load([Conversation].self, key: "inbox") ?? [] }
        catch { errorMessage = error.localizedDescription }
    }
    func refresh() async {
        guard cache.isActive else { return }
        generation += 1
        let stamp = generation
        isLoading = !hasLoaded && conversations.isEmpty
        defer { if generation == stamp { isLoading = false } }
        do {
            let rows = try await service.inbox()
            try Task.checkCancellation()
            guard cache.isActive, generation == stamp else { return }
            conversations = rows; hasLoaded = true; errorMessage = nil
            try cache.save(rows, key: "inbox")
        } catch is CancellationError { return }
        catch { if cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
}
