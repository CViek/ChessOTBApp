import Foundation

nonisolated struct Conversation: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: UUID
    let peerID: UUID
    let displayName: String
    let preview: String?
    let updatedAt: String
    let unreadCount: Int

    var initials: String { displayName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    enum CodingKeys: String, CodingKey {
        case id, peerID = "peerId", displayName, preview, updatedAt, unreadCount
    }
}

nonisolated struct InboxCursor: Codable, Equatable, Sendable {
    let updatedAt: String
    let id: UUID
}
nonisolated struct ConversationPage: Codable, Sendable {
    let conversations: [Conversation]
    let nextCursor: InboxCursor?
}
