import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    enum State: Equatable {
        case restoring, signedOut, signedIn(AccountUser), restoreFailed(String)
    }
    private(set) var state: State = .restoring
    private(set) var isSigningOut = false
    private(set) var notice: String?
    let auth: any AuthServiceProtocol
    private var version = 0

    init(auth: any AuthServiceProtocol) { self.auth = auth }

    func restore() async {
        version += 1
        let stamp = version
        state = .restoring
        do {
            let session = try await auth.restore()
            try Task.checkCancellation()
            guard version == stamp else { return }
            state = session.map { .signedIn($0.user) } ?? .signedOut
        } catch is CancellationError { return }
        catch {
            guard version == stamp else { return }
            if error as? APIError == .sessionExpired { state = .signedOut }
            else { state = .restoreFailed(error.localizedDescription) }
        }
    }

    func authenticate(email: String, password: String, createAccount: Bool) async throws -> Bool {
        version += 1
        let stamp = version
        notice = nil
        let result = try await (createAccount ? auth.signUp(email: email, password: password) : auth.signIn(email: email, password: password))
        try accept(result, stamp: stamp)
        return result != nil
    }

    func verifySignup(email: String, code: String) async throws {
        let stamp = version
        try await accept(auth.verifySignup(email: email, code: code), stamp: stamp)
    }

    func resetPassword(email: String, code: String, password: String) async throws {
        let stamp = version
        try await accept(auth.resetPassword(email: email, code: code, password: password), stamp: stamp)
    }

    func signOut() async {
        version += 1
        let stamp = version
        isSigningOut = true
        notice = nil
        defer { isSigningOut = false }
        do {
            try await auth.signOut()
            guard version == stamp else { return }
            state = .signedOut
        }
        catch {
            guard version == stamp else { return }
            if error is SecureStorageError { state = .restoreFailed(error.localizedDescription) }
            else {
                state = .signedOut
                notice = String(localized: "Signed out on this device. The server session could not be revoked.")
            }
        }
    }

    private func accept(_ session: AuthSession?, stamp: Int) throws {
        try Task.checkCancellation()
        guard version == stamp else { throw CancellationError() }
        state = session.map { .signedIn($0.user) } ?? .signedOut
    }
}
