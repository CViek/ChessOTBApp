import Foundation
import Testing
@testable import ChessOTBApp

struct ConversationServiceTests {
    @Test func sendsStableClientIDAndNeverAcceptsAnOwnerFromPayload() async throws {
        let thread = UUID(), clientID = UUID()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/send_message")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try JSONSerialization.jsonObject(with: HTTPStub.body(request)) as! [String: Any]
            #expect(body["p_client_id"] as? String == clientID.uuidString)
            #expect(body["p_conversation_id"] as? String == thread.uuidString)
            #expect(body["p_body"] as? String == "Hello")
            #expect(body["p_sender_id"] == nil)
            return (200, Data("{\"id\":\"\(UUID())\",\"conversation_id\":\"\(thread)\",\"sender_id\":\"\(AccountFixtures.profileID)\",\"client_id\":\"\(clientID)\",\"sequence\":1,\"body\":\"Hello\",\"created_at\":\"2026-11-16T10:00:00Z\"}".utf8))
        }
        let service = ConversationService(client: client, auth: AuthDouble(), accountID: AccountFixtures.session.user.id)
        let message = try await service.send(conversationID: thread, clientID: clientID, body: "Hello")
        #expect(message.clientID == clientID)
        #expect(message.sequence == 1)
    }
    @Test func changedAccountCannotUseOldService() async throws {
        let client = try HTTPStub.client { _ in Issue.record("Old account must not issue a request"); return (500, Data()) }
        let service = ConversationService(client: client, auth: AuthDouble(), accountID: UUID())
        await #expect(throws: APIError.unauthorized) { _ = try await service.inbox() }
    }
}
