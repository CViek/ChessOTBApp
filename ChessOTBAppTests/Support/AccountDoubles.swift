import Foundation
@testable import ChessOTBApp

actor AuthDouble: AuthServiceProtocol {
    var session: AuthSession? = AccountFixtures.session
    var failure: APIError?
    var delayRestore = false
    private var continuation: CheckedContinuation<AuthSession?, Never>?
    func setFailure(_ error: APIError?) { failure = error }
    func setDelayRestore() { delayRestore = true }
    func isWaiting() -> Bool { continuation != nil }
    func finishRestore() { continuation?.resume(returning: AccountFixtures.session); continuation = nil }
    func signIn(email: String, password: String) throws -> AuthSession {
        if let failure { throw failure }
        return AccountFixtures.session
    }
    func signUp(email: String, password: String) throws -> AuthSession? { try signIn(email: email, password: password) }
    func verifySignup(email: String, code: String) throws -> AuthSession { try signIn(email: email, password: "") }
    func resendSignup(email: String) throws { if let failure { throw failure } }
    func requestPasswordReset(email: String) throws { if let failure { throw failure } }
    func resetPassword(email: String, code: String, password: String) throws -> AuthSession { try signIn(email: email, password: password) }
    func restore() async throws -> AuthSession? {
        if let failure { throw failure }
        if delayRestore { return await withCheckedContinuation { continuation = $0 } }
        return session
    }
    func validSession() throws -> AuthSession {
        guard let session else { throw APIError.unauthorized }
        return session
    }
    func signOut() throws { session = nil; if let failure { throw failure } }
}

actor ProfileDouble: ProfileServiceProtocol {
    var profile: PlayerProfile? = PlayerProfile(id: AccountFixtures.profileID, displayName: "Original")
    var failure: APIError?
    func setFailure(_ error: APIError) { failure = error }
    func loadOwnProfile() throws -> PlayerProfile? {
        if let failure { throw failure }
        return profile
    }
    func saveDisplayName(_ name: String) throws -> PlayerProfile {
        if let failure { throw failure }
        let result = PlayerProfile(id: AccountFixtures.profileID, displayName: name)
        profile = result
        return result
    }
    func publicProfile(id: UUID) -> PlayerProfile? { profile }
}
