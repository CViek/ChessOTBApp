import Foundation
import Synchronization
@testable import ChessOTBApp

final class HTTPStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    static let handlers = Mutex<[String: Handler]>([:])

    static func client(handler: @escaping Handler) throws -> APIClient {
        let host = UUID().uuidString.lowercased() + ".test"
        handlers.withLock { $0[host] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPStub.self]
        let backend = try BackendConfiguration(url: URL(string: "https://" + host)!, publishableKey: "sb_publishable_test")
        return APIClient(configuration: backend, session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = Self.handlers.withLock { $0[request.url!.host!]! }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

actor MemorySessionStore: SessionStoreProtocol {
    var session: AuthSession?
    init(_ session: AuthSession? = nil) { self.session = session }
    func load() -> AuthSession? { session }
    func save(_ session: AuthSession) { self.session = session }
    func clear() { session = nil }
}

nonisolated enum AccountFixtures {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let profileID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    static let session = AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), user: AccountUser(id: userID, email: "one@example.test"))
    static let tokenJSON = Data(#"{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600,"user":{"id":"11111111-1111-1111-1111-111111111111","email":"one@example.test"}}"#.utf8)
}
