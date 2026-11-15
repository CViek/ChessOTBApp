import Testing
@testable import ChessOTBApp

@MainActor
struct AccountSetupViewModelTests {
    @Test func invalidEmailDoesNotAuthenticate() async {
        let session = SessionViewModel(auth: AuthDouble())
        let model = AccountSetupViewModel(session: session)
        model.email = "invalid"
        model.password = "test-password"
        await model.submit()
        #expect(model.errorMessage != nil)
        #expect(session.state != .signedIn(AccountFixtures.session.user))
    }
    @Test func rejectedCredentialsPreserveEmailAndShowError() async {
        let auth = AuthDouble()
        await auth.setFailure(.invalidCredentials)
        let model = AccountSetupViewModel(session: SessionViewModel(auth: auth))
        model.email = "one@example.test"
        model.password = "wrong-password"
        await model.submit()
        #expect(model.email == "one@example.test")
        #expect(model.errorMessage != nil)
        #expect(!model.isSubmitting)
    }
    @Test func successfulSignInPublishesIdentityAndDiscardsPassword() async {
        let session = SessionViewModel(auth: AuthDouble())
        let model = AccountSetupViewModel(session: session)
        model.email = "one@example.test"
        model.password = "test-password"
        await model.submit()
        #expect(session.state == .signedIn(AccountFixtures.session.user))
        #expect(model.password.isEmpty)
    }
}
