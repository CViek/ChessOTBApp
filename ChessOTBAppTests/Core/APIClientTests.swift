import Foundation
import Testing
@testable import ChessOTBApp

struct APIClientTests {
    nonisolated struct Reply: Decodable, Sendable { let value: Int }

    @Test func requestUsesPublishableKeyAndExplicitUserToken() async throws {
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/get_own_profile")
            #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
            #expect(request.httpMethod == "POST")
            return (200, Data(#"{"value":42}"#.utf8))
        }
        let reply: Reply = try await client.request("rest/v1/rpc/get_own_profile", method: "POST", token: "user-token")
        #expect(reply.value == 42)
    }

    @Test(arguments: [(401, APIError.unauthorized), (429, .rateLimited), (503, .unavailable)])
    func rejectsNonSuccessResponses(status: Int, expected: APIError) async throws {
        let client = try HTTPStub.client { _ in (status, Data("{}".utf8)) }
        await #expect(throws: expected) { let _: Reply = try await client.request("test") }
    }

    @Test func rejectsMalformedSuccessResponse() async throws {
        let client = try HTTPStub.client { _ in (200, Data("not JSON".utf8)) }
        await #expect(throws: APIError.invalidResponse) { let _: Reply = try await client.request("test") }
    }

    @Test func reportsOfflineWithoutPretendingSuccess() async throws {
        let client = try HTTPStub.client { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: APIError.network) { try await client.send("test") }
    }

    @Test(arguments: ["sb_secret_forbidden", "", "not-a-client-key"])
    func rejectsUnsafeOrMissingConfiguration(key: String) {
        #expect(throws: APIError.invalidConfiguration) {
            try BackendConfiguration(url: URL(string: "https://backend.example")!, publishableKey: key)
        }
    }

    @Test func rejectsHTTPOutsideExplicitLocalDevelopment() {
        #expect(throws: APIError.invalidConfiguration) {
            try BackendConfiguration(url: URL(string: "http://example.com")!, publishableKey: "sb_publishable_test", allowsLocalHTTP: true)
        }
    }
}
