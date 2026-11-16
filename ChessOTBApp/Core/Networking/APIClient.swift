import Foundation

nonisolated struct APIClient: Sendable {
    let configuration: BackendConfiguration
    let session: URLSession

    init(configuration: BackendConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func request<Response: Decodable & Sendable>(
        _ path: String, method: String = "GET", body: Data? = nil,
        token: String? = nil, query: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await execute(path, method: method, body: body, token: token, query: query)
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch { throw APIError.invalidResponse }
    }

    func send(_ path: String, method: String = "POST", body: Data? = nil,
              token: String? = nil, query: [URLQueryItem] = []) async throws {
        _ = try await execute(path, method: method, body: body, token: token, query: query)
    }

    private func execute(_ path: String, method: String, body: Data?, token: String?, query: [URLQueryItem]) async throws -> Data {
        try Task.checkCancellation()
        var components = URLComponents(url: configuration.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.invalidConfiguration }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard (200..<300).contains(response.statusCode) else { throw responseError(status: response.statusCode, data: data) }
            return data
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.network
        }
    }

    private func responseError(status: Int, data: Data) -> APIError {
        let code: String?
        do { code = try JSONDecoder().decode(ServerError.self, from: data).errorCode }
        catch { code = nil } // Non-JSON gateway failures are mapped by status below.
        switch code {
        case "invalid_credentials": return .invalidCredentials
        case "email_not_confirmed": return .emailNotConfirmed
        case "refresh_token_not_found", "refresh_token_already_used", "session_not_found", "user_banned", "user_not_found": return .sessionExpired
        default: break
        }
        switch status {
        case 401, 403: return .unauthorized
        case 409: return .conflict
        case 429: return .rateLimited
        case 500...599: return .unavailable
        default: return .rejected
        }
    }

    private struct ServerError: Decodable {
        let errorCode: String?
        enum CodingKeys: String, CodingKey { case errorCode = "error_code" }
    }
}
