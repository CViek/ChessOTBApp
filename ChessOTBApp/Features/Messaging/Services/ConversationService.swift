import Foundation

nonisolated protocol ConversationServiceProtocol: Sendable {
    func open(peerID: UUID) async throws -> UUID
    func inboxPage(cursor: InboxCursor?) async throws -> ConversationPage
    func inbox() async throws -> [Conversation]
    func history(conversationID: UUID, before: Int64?) async throws -> MessagePage
    func send(conversationID: UUID, clientID: UUID, body: String) async throws -> Message
    func markRead(conversationID: UUID, through: Int64) async throws
}

nonisolated struct ConversationService: ConversationServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol
    let accountID: UUID

    private func token() async throws -> String {
        let session = try await auth.validSession()
        guard session.user.id == accountID else { throw APIError.unauthorized }
        try Task.checkCancellation()
        return session.accessToken
    }
    func open(peerID: UUID) async throws -> UUID {
        try await client.request("rest/v1/rpc/open_conversation", method: "POST",
                                 body: JSONEncoder().encode(OpenRequest(p_peer_id: peerID)), token: token())
    }
    func inboxPage(cursor: InboxCursor?) async throws -> ConversationPage {
        try await client.request("rest/v1/rpc/inbox_page", method: "POST",
                                 body: JSONEncoder().encode(InboxRequest(p_before_time: cursor?.updatedAt, p_before_id: cursor?.id, p_limit: 30)), token: token())
    }
    private struct InboxRequest: Encodable {
        let p_before_time: String?; let p_before_id: UUID?; let p_limit: Int
    }
    func inbox() async throws -> [Conversation] {
        try await client.request("rest/v1/rpc/list_conversations", method: "POST", body: Data("{}".utf8), token: token())
    }
    func history(conversationID: UUID, before: Int64?) async throws -> MessagePage {
        try await client.request("rest/v1/rpc/message_history", method: "POST",
                                 body: JSONEncoder().encode(HistoryRequest(p_conversation_id: conversationID, p_before: before, p_limit: 50)), token: token())
    }
    func send(conversationID: UUID, clientID: UUID, body: String) async throws -> Message {
        guard let body = MessageValidation.normalized(body) else { throw APIError.rejected }
        return try await client.request("rest/v1/rpc/send_message", method: "POST",
                                        body: JSONEncoder().encode(SendRequest(p_conversation_id: conversationID, p_client_id: clientID, p_body: body)), token: token())
    }
    func markRead(conversationID: UUID, through: Int64) async throws {
        try await client.send("rest/v1/rpc/mark_conversation_read", body: JSONEncoder().encode(ReadRequest(p_conversation_id: conversationID, p_through: through)), token: token())
    }
    private struct OpenRequest: Encodable { let p_peer_id: UUID }
    private struct HistoryRequest: Encodable { let p_conversation_id: UUID; let p_before: Int64?; let p_limit: Int }
    private struct SendRequest: Encodable { let p_conversation_id: UUID; let p_client_id: UUID; let p_body: String }
    private struct ReadRequest: Encodable { let p_conversation_id: UUID; let p_through: Int64 }
}

nonisolated extension ConversationServiceProtocol {
    func inboxPage(cursor: InboxCursor?) async throws -> ConversationPage {
        ConversationPage(conversations: try await inbox(), nextCursor: nil)
    }
}
