import Combine
import Foundation

@MainActor final class ConversationViewModel: ObservableObject {
    @Published var draft = "" {
        didSet {
            guard cache.isActive else { return }
            do { try drafts.save(draft, peerID: peerID) }
            catch { errorMessage = error.localizedDescription }
        }
    }
    @Published private(set) var messages: [Message] = []
    @Published private(set) var outgoing: [OutgoingMessage] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var nextCursor: Int64?
    @Published private(set) var conversationID: UUID?
    let peerID: UUID
    let ownProfileID: UUID
    private let service: any ConversationServiceProtocol
    private let cache: AccountCache
    private let drafts: MessageDraftStore
    private var generation = 0
    private var synchronizedSequence: Int64?
    private var sending: Set<UUID> = []
    var canSend: Bool { cache.isActive && conversationID != nil && MessageValidation.normalized(draft) != nil }
    private var key: String { "history:" + peerID.uuidString }

    init(peerID: UUID, ownProfileID: UUID, service: any ConversationServiceProtocol, cache: AccountCache) {
        self.peerID = peerID; self.ownProfileID = ownProfileID; self.service = service; self.cache = cache
        drafts = MessageDraftStore(cache: cache)
        do {
            if let saved = try cache.load(Snapshot.self, key: key) {
                conversationID = saved.conversationID; messages = saved.messages; nextCursor = saved.nextCursor
                synchronizedSequence = saved.synchronizedSequence
                outgoing = saved.outgoing.map { OutgoingMessage(id: $0.id, body: $0.body, failed: true) }
            }
            draft = try drafts.load(peerID: peerID)
        } catch { errorMessage = error.localizedDescription }
    }
    func deactivate() {
        generation += 1
        messages = []; outgoing = []; draft = ""; conversationID = nil
        nextCursor = nil; synchronizedSequence = nil
        errorMessage = nil; isLoading = false; isLoadingMore = false
    }
    func refresh() async {
        guard cache.isActive else { return }
        generation += 1
        let stamp = generation
        isLoading = conversationID == nil
        defer { if generation == stamp { isLoading = false } }
        do {
            let id: UUID
            if let conversationID { id = conversationID } else { id = try await service.open(peerID: peerID) }
            try check(stamp)
            conversationID = id
            let previousNewest = synchronizedSequence
            var page = try await service.history(conversationID: id, before: nil)
            try check(stamp)
            var fetched = page.messages
            let initialCursor = page.nextCursor
            // Catch up every intervening page after a long offline interval.
            while let newest = previousNewest, let cursor = page.nextCursor,
                  let oldest = page.messages.first?.sequence, oldest > newest {
                page = try await service.history(conversationID: id, before: cursor)
                try check(stamp)
                fetched.append(contentsOf: page.messages)
            }
            if previousNewest == nil { nextCursor = initialCursor }
            merge(fetched)
            synchronizedSequence = fetched.map(\.sequence).max() ?? previousNewest
            errorMessage = nil
            try persist()
            if let through = fetched.map(\.sequence).max() {
                try await service.markRead(conversationID: id, through: through)
                try check(stamp)
            }
        } catch is CancellationError { return }
        catch { if cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
    func loadMore() async {
        guard let id = conversationID, let cursor = nextCursor, !isLoadingMore, cache.isActive else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await service.history(conversationID: id, before: cursor)
            try Task.checkCancellation()
            guard cache.isActive else { return }
            merge(page.messages); nextCursor = page.nextCursor; errorMessage = nil
            try persist()
        } catch is CancellationError { return }
        catch { if cache.isActive { errorMessage = error.localizedDescription } }
    }
    func sendDraft() async {
        guard canSend, let text = MessageValidation.normalized(draft) else { return }
        let pending = OutgoingMessage(id: UUID(), body: text, failed: false)
        outgoing.append(pending)
        do { try persist() }
        catch { outgoing.removeAll { $0.id == pending.id }; errorMessage = error.localizedDescription; return }
        draft = ""
        await retry(pending.id)
    }
    func retry(_ clientID: UUID) async {
        guard let id = conversationID, let pending = outgoing.first(where: { $0.id == clientID }),
              cache.isActive, !sending.contains(clientID) else { return }
        sending.insert(clientID)
        defer { sending.remove(clientID) }
        updatePending(clientID, failed: false)
        do {
            let confirmed = try await service.send(conversationID: id, clientID: clientID, body: pending.body)
            try Task.checkCancellation()
            guard cache.isActive else { return }
            merge([confirmed]); errorMessage = nil
            try persist()
        } catch {
            guard cache.isActive else { return }
            updatePending(clientID, failed: true)
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
            do { try persist() } catch { errorMessage = error.localizedDescription }
        }
    }
    private func updatePending(_ id: UUID, failed: Bool) {
        if let index = outgoing.firstIndex(where: { $0.id == id }) { outgoing[index].failed = failed }
    }
    private func merge(_ confirmed: [Message]) {
        var byID = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for message in confirmed where message.conversationID == conversationID { byID[message.id] = message }
        messages = byID.values.sorted { $0.sequence < $1.sequence }
        let acknowledged = Set(messages.filter { $0.senderID == ownProfileID }.map(\.clientID))
        outgoing.removeAll { acknowledged.contains($0.id) }
    }
    private func check(_ stamp: Int) throws {
        try Task.checkCancellation()
        guard cache.isActive, generation == stamp else { throw CancellationError() }
    }
    private func persist() throws {
        try cache.save(Snapshot(conversationID: conversationID, messages: messages, outgoing: outgoing, nextCursor: nextCursor, synchronizedSequence: synchronizedSequence), key: key)
    }
    private struct Snapshot: Codable {
        let conversationID: UUID?
        let messages: [Message]
        let outgoing: [OutgoingMessage]
        let nextCursor: Int64?
        let synchronizedSequence: Int64?
    }
}
