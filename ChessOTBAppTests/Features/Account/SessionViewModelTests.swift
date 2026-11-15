import Foundation
import Testing
@testable import ChessOTBApp

@MainActor
struct SessionViewModelTests {
    @Test func restoresAuthenticatedIdentity() async {
        let model = SessionViewModel(auth: AuthDouble())
        await model.restore()
        #expect(model.state == .signedIn(AccountFixtures.session.user))
    }
    @Test func signOutRemovesAccountStateEvenWhenOffline() async throws {
        let auth = AuthDouble()
        let model = SessionViewModel(auth: auth)
        await model.restore()
        await auth.setFailure(.network)
        await model.signOut()
        #expect(model.state == .signedOut)
        #expect(model.notice != nil)
    }
    @Test func staleRestoreCannotRepopulateAfterSignOut() async throws {
        let auth = AuthDouble()
        await auth.setDelayRestore()
        let model = SessionViewModel(auth: auth)
        let task = Task { await model.restore() }
        for _ in 0..<100 {
            if await auth.isWaiting() { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard await auth.isWaiting() else {
            task.cancel()
            Issue.record("Restore never reached the auth service")
            return
        }
        await model.signOut()
        await auth.finishRestore()
        await task.value
        #expect(model.state == .signedOut)
    }
    @Test func offlineRestoreOffersRetryWithoutAssumingSignedOut() async {
        let auth = AuthDouble()
        await auth.setFailure(.network)
        let model = SessionViewModel(auth: auth)
        await model.restore()
        guard case .restoreFailed = model.state else { Issue.record("Expected recoverable restore failure"); return }
        await auth.setFailure(nil)
        await model.restore()
        #expect(model.state == .signedIn(AccountFixtures.session.user))
    }
}
