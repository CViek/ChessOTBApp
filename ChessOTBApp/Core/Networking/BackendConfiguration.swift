import Foundation

nonisolated struct BackendConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    init(url: URL, publishableKey: String, allowsLocalHTTP: Bool = false) throws {
        let local = ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "")
        guard url.scheme == "https" || (allowsLocalHTTP && local && url.scheme == "http"),
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, ["", "/"].contains(url.path),
              Self.isClientKey(publishableKey) else { throw APIError.invalidConfiguration }
        self.url = url
        self.publishableKey = publishableKey
    }

    private static func isClientKey(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace) else { return false }
        if value.hasPrefix("sb_publishable_") { return value.count > "sb_publishable_".count }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return false }
        do {
            let claims = try JSONDecoder().decode(ClientClaims.self, from: data)
            return claims.role == "anon"
        } catch { return false }
    }

    private struct ClientClaims: Decodable { let role: String }
}
