import Foundation
import Testing
import Synchronization
@testable import ChessOTBApp

struct AuthServiceTests {
    @Test func signInPersistsRecoverableSession() async throws {
        let store = MemorySessionStore()
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/auth/v1/token")
            #expect(request.url?.query == "grant_type=password")
            return (200, AccountFixtures.tokenJSON)
        }
        let service = AuthService(client: client, store: store)
        let result = try await service.signIn(email: "one@example.test", password: "test-password")
        #expect(result.user.id == AccountFixtures.userID)
        #expect(await store.load()?.refreshToken == "new-refresh")
    }

    @Test func restoreRefreshesAndPersistsRotatedTokens() async throws {
        let store = MemorySessionStore(AccountFixtures.session)
        let client = try HTTPStub.client { request in
            #expect(request.url?.query == "grant_type=refresh_token")
            return (200, AccountFixtures.tokenJSON)
        }
        let restored = try await AuthService(client: client, store: store).restore()
        #expect(restored?.accessToken == "new-access")
        #expect(await store.load()?.refreshToken == "new-refresh")
    }

    @Test func revokedSessionClearsCredentials() async throws {
        let store = MemorySessionStore(AccountFixtures.session)
        let client = try HTTPStub.client { _ in (400, Data(#"{"error_code":"refresh_token_not_found"}"#.utf8)) }
        let service = AuthService(client: client, store: store)
        #expect(try await service.restore() == nil)
        #expect(await store.load() == nil)
    }

    @Test func offlineRestoreRetainsCredentialsForRetry() async throws {
        let store = MemorySessionStore(AccountFixtures.session)
        let client = try HTTPStub.client { _ in throw URLError(.notConnectedToInternet) }
        let service = AuthService(client: client, store: store)
        await #expect(throws: APIError.network) { try await service.restore() }
        #expect(await store.load() == AccountFixtures.session)
    }

    @Test func signOutClearsLocalCredentialsWhenServerIsOffline() async throws {
        let store = MemorySessionStore(AccountFixtures.session)
        let client = try HTTPStub.client { _ in throw URLError(.notConnectedToInternet) }
        let service = AuthService(client: client, store: store)
        do { try await service.signOut() } catch { #expect(error as? APIError == .network) }
        #expect(await store.load() == nil)
        await #expect(throws: APIError.unauthorized) { try await service.validSession() }
    }

    @Test func signupAwaitingConfirmationDoesNotCreateLocalIdentity() async throws {
        let store = MemorySessionStore()
        let client = try HTTPStub.client { _ in (200, Data(#"{"id":"11111111-1111-1111-1111-111111111111"}"#.utf8)) }
        let service = AuthService(client: client, store: store)
        #expect(try await service.signUp(email: "one@example.test", password: "test-password") == nil)
        #expect(await store.load() == nil)
    }
    @Test func expiredSignOutRefreshesBeforeRevokingAndNeverPersistsNewTokens() async throws {
        let expired = AuthSession(accessToken: "expired", refreshToken: "refresh", expiresAt: .distantPast, user: AccountFixtures.session.user)
        let store = MemorySessionStore(expired)
        let paths = Mutex<[String]>([])
        let client = try HTTPStub.client { request in
            let path = request.url!.path
            paths.withLock { $0.append(path) }
            if path == "/auth/v1/token" { return (200, AccountFixtures.tokenJSON) }
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
            return (204, Data())
        }
        try await AuthService(client: client, store: store).signOut()
        #expect(paths.withLock { $0 } == ["/auth/v1/token", "/auth/v1/logout"])
        #expect(await store.load() == nil)
    }

    @Test func rejectedLogoutReportsIncompleteRevocationAfterLocalClear() async throws {
        let store = MemorySessionStore(AccountFixtures.session)
        let client = try HTTPStub.client { _ in (401, Data("{}".utf8)) }
        let service = AuthService(client: client, store: store)
        await #expect(throws: APIError.unauthorized) { try await service.signOut() }
        #expect(await store.load() == nil)
    }

    @Test func passwordResetRetriesUpdateWithoutConsumingTheCodeTwice() async throws {
        let state = Mutex<(verifications: Int, updates: Int)>((0, 0))
        let store = MemorySessionStore()
        let client = try HTTPStub.client { request in
            if request.url?.path == "/auth/v1/verify" {
                let count = state.withLock { value in value.verifications += 1; return value.verifications }
                return count == 1 ? (200, AccountFixtures.tokenJSON) : (403, Data("{}".utf8))
            }
            let count = state.withLock { value in value.updates += 1; return value.updates }
            return count == 1 ? (503, Data("{}".utf8)) : (200, Data("{}".utf8))
        }
        let service = AuthService(client: client, store: store)
        await #expect(throws: APIError.unavailable) {
            try await service.resetPassword(email: "one@example.test", code: "123456", password: "new-password")
        }
        #expect(await store.load() == nil)
        await #expect(throws: APIError.unauthorized) { try await service.validSession() }
        let result = try await service.resetPassword(email: "one@example.test", code: "123456", password: "corrected-password")
        #expect(result.user.id == AccountFixtures.userID)
        #expect(state.withLock { $0.verifications } == 1)
        #expect(await store.load()?.accessToken == "new-access")
    }

    @Test func malformedSignupResponseDoesNotClaimConfirmationWasSent() async throws {
        let store = MemorySessionStore()
        let client = try HTTPStub.client { _ in (200, Data("{}".utf8)) }
        let service = AuthService(client: client, store: store)
        await #expect(throws: APIError.invalidResponse) {
            try await service.signUp(email: "one@example.test", password: "test-password")
        }
        #expect(await store.load() == nil)
    }

}
