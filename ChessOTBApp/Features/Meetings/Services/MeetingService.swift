import Foundation

nonisolated protocol MeetingServiceProtocol: Sendable {
    func cancel(id: UUID, requestID: UUID, expectedVersion: Int) async throws -> Meeting
    func create(conversationID: UUID, requestID: UUID, proposal: MeetingProposal) async throws -> Meeting
    func detail(id: UUID) async throws -> Meeting
    func list(before: Int64?) async throws -> MeetingPage
    func respond(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting
}

nonisolated struct MeetingService: MeetingServiceProtocol {
    let client: APIClient
    let auth: any AuthServiceProtocol
    let accountID: UUID

    private func token() async throws -> String {
        let session = try await auth.validSession()
        guard session.user.id == accountID else { throw APIError.unauthorized }
        try Task.checkCancellation()
        return session.accessToken
    }

    func create(conversationID: UUID, requestID: UUID, proposal: MeetingProposal) async throws -> Meeting {
        let proposal = try proposal.normalized()
        let payload = CreateRequest(p_conversation_id: conversationID, p_request_id: requestID,
                                    p_starts_at: MeetingTimestamp.encode(proposal.startsAt), p_time_zone: proposal.timeZone,
                                    p_location: proposal.location, p_note: proposal.note)
        return try await client.request("rest/v1/rpc/create_meeting", method: "POST",
                                        body: JSONEncoder().encode(payload), token: token())
    }

    func detail(id: UUID) async throws -> Meeting {
        try await client.request("rest/v1/rpc/get_meeting", method: "POST",
                                 body: JSONEncoder().encode(DetailRequest(p_meeting_id: id)), token: token())
    }

    func list(before: Int64?) async throws -> MeetingPage {
        try await client.request("rest/v1/rpc/list_meetings", method: "POST",
                                 body: JSONEncoder().encode(ListRequest(p_before: before, p_limit: 50)), token: token())
    }

    func respond(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting {
        try await client.request("rest/v1/rpc/respond_to_meeting", method: "POST",
                                 body: JSONEncoder().encode(ResponseRequest(p_meeting_id: id, p_request_id: requestID,
                                                                           p_expected_version: expectedVersion, p_decision: decision.rawValue)), token: token())
    }

    func cancel(id: UUID, requestID: UUID, expectedVersion: Int) async throws -> Meeting {
        try await client.request("rest/v1/rpc/cancel_meeting", method: "POST",
                                 body: JSONEncoder().encode(CancelRequest(p_meeting_id: id, p_request_id: requestID,
                                                                         p_expected_version: expectedVersion)), token: token())
    }

    private struct CancelRequest: Encodable {
        let p_meeting_id: UUID
        let p_request_id: UUID
        let p_expected_version: Int
    }
    private struct CreateRequest: Encodable {
        let p_conversation_id: UUID
        let p_request_id: UUID
        let p_starts_at: String
        let p_time_zone: String
        let p_location: String
        let p_note: String
    }
    private struct DetailRequest: Encodable { let p_meeting_id: UUID }
    private struct ListRequest: Encodable { let p_before: Int64?; let p_limit: Int }
    private struct ResponseRequest: Encodable {
        let p_meeting_id: UUID
        let p_request_id: UUID
        let p_expected_version: Int
        let p_decision: String
    }
}
