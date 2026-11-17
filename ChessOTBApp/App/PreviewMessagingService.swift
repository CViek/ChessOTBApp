#if DEBUG
import Foundation

/// In-memory fixtures for SwiftUI previews; never created by live dependencies.
actor PreviewMessagingService: ConversationServiceProtocol {
    enum State { case populated, empty, unavailable }
    let state: State
    let peerID: UUID
    let threadID = UUID()
    private var messages: [Message] = []
    init(state: State, peerID: UUID) { self.state = state; self.peerID = peerID }
    func open(peerID: UUID) throws -> UUID {
        if state == .unavailable { throw APIError.unavailable }
        return threadID
    }
    func inbox() throws -> [Conversation] {
        if state == .unavailable { throw APIError.unavailable }
        guard state == .populated else { return [] }
        return [Conversation(id: threadID, peerID: peerID, displayName: "Alex Morgan",
                             preview: "Would Saturday afternoon work?", updatedAt: "2026-11-16T12:00:00Z", unreadCount: 2)]
    }
    func history(conversationID: UUID, before: Int64?) throws -> MessagePage {
        if state == .unavailable { throw APIError.unavailable }
        if state == .populated && messages.isEmpty {
            messages = [Message(id: UUID(), conversationID: threadID, senderID: peerID, clientID: UUID(), sequence: 1,
                                body: "Would Saturday afternoon work?", createdAt: "2026-11-16T12:00:00Z",
                                meetingID: nil, meetingVersion: nil, eventKind: nil)]
        }
        return MessagePage(messages: messages, nextCursor: nil)
    }
    func send(conversationID: UUID, clientID: UUID, body: String) throws -> Message { throw APIError.unavailable }
    func markRead(conversationID: UUID, through: Int64) {}
}
#endif
