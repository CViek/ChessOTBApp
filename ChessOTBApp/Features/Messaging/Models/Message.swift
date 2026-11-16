import Foundation

nonisolated struct Message: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let clientID: UUID
    let sequence: Int64
    let body: String
    let createdAt: String
    let meetingID: UUID?
    let meetingVersion: Int?
    let eventKind: String?

    init(id: UUID, conversationID: UUID, senderID: UUID, clientID: UUID, sequence: Int64,
         body: String, createdAt: String, meetingID: UUID? = nil, meetingVersion: Int? = nil,
         eventKind: String? = nil) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.clientID = clientID
        self.sequence = sequence
        self.body = body
        self.createdAt = createdAt
        self.meetingID = meetingID
        self.meetingVersion = meetingVersion
        self.eventKind = eventKind
    }

    enum CodingKeys: String, CodingKey {
        case id, conversationID = "conversationId", senderID = "senderId", clientID = "clientId", sequence, body, createdAt
        case meetingID = "meetingId", meetingVersion, eventKind
    }
}

nonisolated struct MessagePage: Codable, Sendable {
    let messages: [Message]
    let nextCursor: Int64?
}

nonisolated struct OutgoingMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let body: String
    var failed: Bool
}

nonisolated enum MessageValidation {
    static func normalized(_ body: String) -> String? {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.count <= 4_000, !text.contains("\0") else { return nil }
        return text
    }
}
