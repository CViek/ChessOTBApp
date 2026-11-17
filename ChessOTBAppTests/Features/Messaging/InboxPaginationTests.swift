import Foundation
import Testing
@testable import ChessOTBApp

@MainActor private final class PagedInboxDouble: ConversationServiceProtocol {
    var rows: [Conversation] = (1...3).map { n in Conversation(id: UUID(), peerID: UUID(), displayName: "Player \(n)", preview: "Message \(n)", updatedAt: "2026-11-16T10:00:0\(4-n)Z", unreadCount: n) }
    @MainActor func inboxPage(cursor: InboxCursor?) async -> ConversationPage {
        if cursor == nil { return ConversationPage(conversations: Array(rows.prefix(2)), nextCursor: InboxCursor(updatedAt: rows[1].updatedAt, id: rows[1].id)) }
        return ConversationPage(conversations: [rows[2]], nextCursor: nil)
    }
    @MainActor func inbox() async -> [Conversation] { rows }
    @MainActor func open(peerID: UUID) async -> UUID { UUID() }
    @MainActor func history(conversationID: UUID, before: Int64?) async -> MessagePage { MessagePage(messages: [], nextCursor: nil) }
    @MainActor func send(conversationID: UUID, clientID: UUID, body: String) async throws -> Message { throw APIError.network }
    @MainActor func markRead(conversationID: UUID, through: Int64) async {}
}
@MainActor struct InboxPaginationTests {
    @Test func olderThreadsAppendAndForegroundRefreshPreservesLoadedRows() async throws {
        let service = PagedInboxDouble()
        let model = InboxViewModel(service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        await model.refresh()
        #expect(model.conversations.count == 2)
        #expect(model.nextCursor != nil)
        await model.loadMore()
        #expect(model.conversations.map(\.id) == service.rows.map(\.id))
        #expect(model.nextCursor == nil)
        await model.refresh()
        #expect(model.conversations.map(\.id) == service.rows.map(\.id))
    }
    @Test func refreshUpdatesUnreadOnPreviouslyLoadedOlderThreads() async throws {
        let service = PagedInboxDouble()
        let model = InboxViewModel(service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        await model.refresh(); await model.loadMore()
        let old = service.rows[2]
        service.rows[2] = Conversation(id: old.id, peerID: old.peerID, displayName: old.displayName, preview: old.preview, updatedAt: old.updatedAt, unreadCount: 0)
        await model.refresh()
        #expect(model.conversations.last?.unreadCount == 0)
        #expect(model.nextCursor == nil)
    }
    @Test func liveServiceTransmitsAnOpaqueInboxCursor() async throws {
        let id = UUID()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/inbox_page")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_before_id"] as? String == id.uuidString)
            #expect(body["p_before_time"] as? String == "2026-11-16T10:00:00Z")
            return (200, Data(#"{"conversations":[],"next_cursor":null}"#.utf8))
        }
        let service = ConversationService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let page = try await service.inboxPage(cursor: InboxCursor(updatedAt: "2026-11-16T10:00:00Z", id: id))
        #expect(page.conversations.isEmpty)
    }
}
