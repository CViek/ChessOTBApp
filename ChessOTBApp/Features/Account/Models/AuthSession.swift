import Foundation

nonisolated struct AccountUser: Codable, Equatable, Sendable {
    let id: UUID
    let email: String?
}

nonisolated struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: AccountUser
}

nonisolated protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession?
    func verifySignup(email: String, code: String) async throws -> AuthSession
    func resendSignup(email: String) async throws
    func requestPasswordReset(email: String) async throws
    func resetPassword(email: String, code: String, password: String) async throws -> AuthSession
    func restore() async throws -> AuthSession?
    func validSession() async throws -> AuthSession
    func signOut() async throws
}
