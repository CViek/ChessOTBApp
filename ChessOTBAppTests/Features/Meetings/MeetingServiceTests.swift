import Foundation
import Testing
@testable import ChessOTBApp

struct MeetingServiceTests {
    @Test func cancellationUsesVersionAndDurableRequestID() async throws {
        let id = UUID(), requestID = UUID()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/cancel_meeting")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_meeting_id"] as? String == id.uuidString)
            #expect(body["p_request_id"] as? String == requestID.uuidString)
            #expect(body["p_expected_version"] as? Int == 3)
            return (200, Data(String(decoding: Self.meetingJSON, as: UTF8.self).replacingOccurrences(of: "pending", with: "cancelled").utf8))
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let meeting = try await service.cancel(id: id, requestID: requestID, expectedVersion: 3)
        #expect(meeting.status == .cancelled)
    }

    @Test func staleResponseIsARefreshableConflict() async throws {
        let client = try HTTPStub.client { _ in
            (409, Data(#"{"code":"PT409","message":"Proposal changed; refresh before responding"}"#.utf8))
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        await #expect(throws: APIError.conflict) {
            _ = try await service.respond(id: UUID(), requestID: UUID(), expectedVersion: 1, decision: .confirmed)
        }
    }

    @Test func threadEventLinkSurvivesDecodingAndCacheRoundTrip() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json = Data(#"{"id":"50000000-0000-0000-0000-000000000001","conversation_id":"50000000-0000-0000-0000-000000000002","sender_id":"50000000-0000-0000-0000-000000000003","client_id":"50000000-0000-0000-0000-000000000004","sequence":4,"body":"Game proposed.","created_at":"2026-11-16T18:00:00Z","meeting_id":"50000000-0000-0000-0000-000000000005","meeting_version":1,"event_kind":"proposal"}"#.utf8)
        let message = try decoder.decode(Message.self, from: json)
        #expect(message.meetingID == UUID(uuidString: "50000000-0000-0000-0000-000000000005"))
        #expect(message.meetingVersion == 1)
        #expect(message.eventKind == "proposal")
        let restored = try JSONDecoder().decode(Message.self, from: JSONEncoder().encode(message))
        #expect(restored == message)
    }

    @Test func proposalSendsReviewedDetailsAndStableRequestID() async throws {
        let requestID = UUID(), threadID = UUID()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/create_meeting")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_request_id"] as? String == requestID.uuidString)
            #expect(body["p_conversation_id"] as? String == threadID.uuidString)
            #expect(body["p_time_zone"] as? String == "America/New_York")
            #expect(body["p_location"] as? String == "Library stairs")
            #expect(body["p_note"] as? String == "Bring a board")
            #expect(body["p_proposer_id"] == nil)
            #expect(body["p_recipient_id"] == nil)
            return (200, Self.meetingJSON)
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let input = MeetingProposal(startsAt: Date(timeIntervalSince1970: 4_082_674_800), timeZone: "America/New_York", location: " Library stairs \n", note: " Bring a board ")
        let meeting = try await service.create(conversationID: threadID, requestID: requestID, proposal: input)
        #expect(meeting.status == .pending)
        #expect(meeting.version == 1)
        #expect(meeting.revision.timeZone == "America/New_York")
        #expect(meeting.revision.startsAt.timeIntervalSince1970 == 1_793_511_000)
    }

    @Test func switchedAccountCannotSendOrReadMeetings() async throws {
        let client = try HTTPStub.client { _ in Issue.record("Old service must never contact the backend"); return (500, Data()) }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: UUID())
        await #expect(throws: APIError.unauthorized) { _ = try await service.list(before: nil) }
        await #expect(throws: APIError.unauthorized) { _ = try await service.detail(id: UUID()) }
        await #expect(throws: APIError.unauthorized) {
            _ = try await service.cancel(id: UUID(), requestID: UUID(), expectedVersion: 1)
        }
        await #expect(throws: APIError.unauthorized) {
            _ = try await service.respond(id: UUID(), requestID: UUID(), expectedVersion: 1, decision: .confirmed)
        }
    }

    @Test func recipientResponseIncludesExpectedVersionAndRequestID() async throws {
        let meetingID = UUID(), requestID = UUID()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/respond_to_meeting")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_meeting_id"] as? String == meetingID.uuidString)
            #expect(body["p_request_id"] as? String == requestID.uuidString)
            #expect(body["p_expected_version"] as? Int == 1)
            #expect(body["p_decision"] as? String == "declined")
            return (200, Data(String(decoding: Self.meetingJSON, as: UTF8.self).replacingOccurrences(of: "pending", with: "declined").utf8))
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let meeting = try await service.respond(id: meetingID, requestID: requestID, expectedVersion: 1, decision: .declined)
        #expect(meeting.status == .declined)
    }

    @Test func invalidPlaceAndZoneAreRejectedBeforeNetworking() async throws {
        let client = try HTTPStub.client { _ in Issue.record("Invalid proposal reached network"); return (500, Data()) }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        for input in [
            MeetingProposal(startsAt: .now, timeZone: "America/New_York", location: " \t\n", note: ""),
            MeetingProposal(startsAt: .now, timeZone: "Invented/Zone", location: "Library", note: ""),
            MeetingProposal(startsAt: .now, timeZone: "America/New_York", location: String(repeating: "x", count: 501), note: "")
        ] {
            await #expect(throws: APIError.rejected) { _ = try await service.create(conversationID: UUID(), requestID: UUID(), proposal: input) }
        }
    }

    @Test func namedZoneDoesNotCollapseDistinctDSTInstants() throws {
        let first = try MeetingTimestamp.decode("2026-11-01T01:30:00-04:00")
        let second = try MeetingTimestamp.decode("2026-11-01T01:30:00-05:00")
        #expect(second.timeIntervalSince(first) == 3600)
        #expect(abs(try MeetingTimestamp.decode("2026-11-01T05:30:00.123Z").timeIntervalSince(first) - 0.123) < 0.000_001)
    }

    @Test func listPreservesCursorAndMalformedInstantsFailDecoding() async throws {
        let client = try HTTPStub.client { request in
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_before"] as? Int == 51)
            return (200, Data(("{\"meetings\":[" + String(decoding: Self.meetingJSON, as: UTF8.self) + "],\"next_cursor\":9}").utf8))
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        let page = try await service.list(before: 51)
        #expect(page.meetings.count == 1)
        #expect(page.nextCursor == 9)
        #expect(throws: (any Error).self) { _ = try MeetingTimestamp.decode("not a timestamp") }
    }

    private static let meetingJSON = Data(#"{"id":"50000000-0000-0000-0000-000000000001","sequence":9,"conversation_id":"50000000-0000-0000-0000-000000000002","proposer_id":"50000000-0000-0000-0000-000000000003","recipient_id":"50000000-0000-0000-0000-000000000004","request_id":"50000000-0000-0000-0000-000000000005","status":"pending","version":1,"proposer_name":"A","recipient_name":"B","created_at":"2026-11-16T18:00:00Z","updated_at":"2026-11-16T18:00:00Z","revision":{"id":"50000000-0000-0000-0000-000000000006","meeting_id":"50000000-0000-0000-0000-000000000001","starts_at":"2026-11-01T05:30:00+00:00","time_zone":"America/New_York","location":"Library stairs","note":"Bring a board"}}"#.utf8)
}
