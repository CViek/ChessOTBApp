import Foundation

actor AuthService: AuthServiceProtocol {
    private let client: APIClient
    private let store: any SessionStoreProtocol
    private var pendingRecovery: PendingRecovery?
    private var current: AuthSession?
    private var generation = 0
    private var refreshTask: Task<AuthSession, Error>?

    init(client: APIClient, store: any SessionStoreProtocol) {
        self.client = client
        self.store = store
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let stamp = generation
        let email = try AccountValidation.email(email)
        guard !password.isEmpty else { throw AccountError.invalidPassword }
        let response: TokenResponse = try await client.request("auth/v1/token", method: "POST", body: encoded(["email": email, "password": password]), query: [URLQueryItem(name: "grant_type", value: "password")])
        return try await persist(response.session(), stamp: stamp)
    }

    func signUp(email: String, password: String) async throws -> AuthSession? {
        let stamp = generation
        let email = try AccountValidation.email(email)
        try AccountValidation.password(password)
        let response: SignupResponse = try await client.request("auth/v1/signup", method: "POST", body: encoded(["email": email, "password": password]))
        if response.accessToken == nil && response.refreshToken == nil {
            guard response.id != nil || response.user != nil else { throw APIError.invalidResponse }
            return nil
        }
        guard let token = response.accessToken, !token.isEmpty,
              let refresh = response.refreshToken, !refresh.isEmpty,
              let user = response.user, let lifetime = response.expiresIn, lifetime > 0 else { throw APIError.invalidResponse }
        let session = AuthSession(accessToken: token, refreshToken: refresh, expiresAt: Date().addingTimeInterval(lifetime), user: user)
        return try await persist(session, stamp: stamp)
    }

    func verifySignup(email: String, code: String) async throws -> AuthSession {
        let stamp = generation
        let response = try await verify(email: email, code: code, type: "signup")
        return try await persist(response.session(), stamp: stamp)
    }

    func resendSignup(email: String) async throws {
        try await client.send("auth/v1/resend", body: encoded(["email": AccountValidation.email(email), "type": "signup"]))
    }

    func requestPasswordReset(email: String) async throws {
        try await client.send("auth/v1/recover", body: encoded(["email": AccountValidation.email(email)]))
    }

    func resetPassword(email: String, code: String, password: String) async throws -> AuthSession {
        let stamp = generation
        let email = try AccountValidation.email(email)
        let code = try AccountValidation.code(code)
        try AccountValidation.password(password)
        let recovery: AuthSession
        if let pending = pendingRecovery, pending.email == email, pending.code == code,
           pending.session.expiresAt.timeIntervalSinceNow > 60 {
            recovery = pending.session
        } else {
            recovery = try await verify(email: email, code: code, type: "recovery").session()
            try Task.checkCancellation()
            guard stamp == generation else { throw CancellationError() }
            pendingRecovery = PendingRecovery(email: email, code: code, session: recovery)
        }
        // The OTP has been consumed. Keep this session only in memory so a failed
        // password update can retry without treating recovery as a completed login.
        try await client.send("auth/v1/user", method: "PUT", body: encoded(["password": password]), token: recovery.accessToken)
        return try await persist(recovery, stamp: stamp)
    }

    func restore() async throws -> AuthSession? {
        let stamp = generation
        guard let saved = try await store.load() else { return nil }
        do { return try await refreshed(saved, stamp: stamp) }
        catch APIError.sessionExpired { return try await discardRevoked(stamp: stamp) }
        catch APIError.unauthorized { return try await discardRevoked(stamp: stamp) }
    }

    func validSession() async throws -> AuthSession {
        guard let current else { throw APIError.unauthorized }
        if current.expiresAt.timeIntervalSinceNow > 60 { return current }
        return try await refreshed(current, stamp: generation)
    }

    func signOut() async throws {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        let saved = current
        let recovery = pendingRecovery?.session
        current = nil
        pendingRecovery = nil
        let stored = try await store.load()
        try await store.clear()
        var revoked = Set<String>()
        for session in [saved ?? stored, recovery].compactMap({ $0 }) {
            guard revoked.insert(session.refreshToken).inserted else { continue }
            let token: String
            if session.expiresAt.timeIntervalSinceNow <= 60 {
                do {
                    let response: TokenResponse = try await client.request("auth/v1/token", method: "POST", body: encoded(["refresh_token": session.refreshToken]), query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
                    token = response.accessToken
                } catch APIError.sessionExpired { continue }
            } else { token = session.accessToken }
            // An expired JWT is not evidence that its refresh session was revoked.
            try await client.send("auth/v1/logout", token: token, query: [URLQueryItem(name: "scope", value: "local")])
        }
    }

    private func verify(email: String, code: String, type: String) async throws -> TokenResponse {
        try await client.request("auth/v1/verify", method: "POST", body: encoded(["email": AccountValidation.email(email), "token": AccountValidation.code(code), "type": type]))
    }

    private func refreshed(_ saved: AuthSession, stamp: Int) async throws -> AuthSession {
        let task: Task<AuthSession, Error>
        if let refreshTask { task = refreshTask }
        else {
            let client = client
            task = Task {
                let response: TokenResponse = try await client.request("auth/v1/token", method: "POST", body: JSONEncoder().encode(["refresh_token": saved.refreshToken]), query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
                return response.session()
            }
            refreshTask = task
        }
        defer { if stamp == generation { refreshTask = nil } }
        return try await persist(task.value, stamp: stamp)
    }

    private func persist(_ session: AuthSession, stamp: Int) async throws -> AuthSession {
        try Task.checkCancellation()
        guard stamp == generation else { throw CancellationError() }
        try await store.save(session)
        guard stamp == generation else { throw CancellationError() }
        current = session
        pendingRecovery = nil
        return session
    }

    private func discardRevoked(stamp: Int) async throws -> AuthSession? {
        guard stamp == generation else { throw CancellationError() }
        current = nil
        try await store.clear()
        return nil
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }

    private struct PendingRecovery {
        let email: String
        let code: String
        let session: AuthSession
    }

    private struct TokenResponse: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
        let user: AccountUser
        func session() -> AuthSession {
            AuthSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: Date().addingTimeInterval(expiresIn), user: user)
        }
    }

    private struct SignupResponse: Decodable, Sendable {
        let id: UUID?
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: TimeInterval?
        let user: AccountUser?
    }
}
