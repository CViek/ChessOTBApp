import Foundation

nonisolated enum MeetingStatus: String, Codable, Sendable {
    case pending, confirmed, declined, cancelled
}

nonisolated enum MeetingDecision: String, Codable, Sendable {
    case confirmed, declined
}

nonisolated struct Meeting: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let sequence: Int64
    let conversationID: UUID
    let proposerID: UUID
    let recipientID: UUID
    let requestID: UUID
    let status: MeetingStatus
    let version: Int
    let proposerName: String
    let recipientName: String
    let createdAt: String
    let updatedAt: String
    let revision: MeetingRevision

    var pendingRevision: MeetingRevision? = nil
    var pendingProposerID: UUID? = nil
    var revisions: [MeetingRevision]? = nil

    func isHistory(at now: Date) -> Bool {
        status == .declined || status == .cancelled || max(revision.startsAt, pendingRevision?.startsAt ?? revision.startsAt) <= now
    }
    func peerID(ownProfileID: UUID) -> UUID { proposerID == ownProfileID ? recipientID : proposerID }
    func peerName(ownProfileID: UUID) -> String { proposerID == ownProfileID ? recipientName : proposerName }

    enum CodingKeys: String, CodingKey {
        case id, sequence, status, version, proposerName, recipientName, createdAt, updatedAt, revision, pendingRevision, revisions
        case pendingProposerID = "pendingProposerId"
        case conversationID = "conversationId", proposerID = "proposerId"
        case recipientID = "recipientId", requestID = "requestId"
    }
}

nonisolated struct MeetingPage: Codable, Sendable {
    let meetings: [Meeting]
    let nextCursor: Int64?
}
