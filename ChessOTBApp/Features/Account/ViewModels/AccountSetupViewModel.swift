import Combine
import Foundation

@MainActor
final class AccountSetupViewModel: ObservableObject {
    enum Mode { case signIn, signUp, confirmEmail, recoveryEmail, resetPassword }
    @Published var email = ""
    @Published var password = ""
    @Published var code = ""
    @Published private(set) var mode: Mode = .signIn
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    private let session: SessionViewModel

    init(session: SessionViewModel) { self.session = session }

    var title: String {
        switch mode {
        case .signIn: String(localized: "Welcome back")
        case .signUp: String(localized: "Create your account")
        case .confirmEmail: String(localized: "Confirm your email")
        case .recoveryEmail, .resetPassword: String(localized: "Reset your password")
        }
    }

    var actionTitle: String {
        switch mode {
        case .signIn: String(localized: "Sign in")
        case .signUp: String(localized: "Create account")
        case .confirmEmail: String(localized: "Confirm email")
        case .recoveryEmail: String(localized: "Send reset code")
        case .resetPassword: String(localized: "Save new password")
        }
    }

    func changeMode(_ mode: Mode) {
        guard !isSubmitting else { return }
        self.mode = mode
        discardSecrets()
        errorMessage = nil
        infoMessage = nil
    }

    func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        defer { isSubmitting = false }
        do {
            email = try AccountValidation.email(email)
            switch mode {
            case .signIn, .signUp:
                if mode == .signUp { try AccountValidation.password(password) }
                else if password.isEmpty { throw AccountError.invalidPassword }
                let signedIn = try await session.authenticate(email: email, password: password, createAccount: mode == .signUp)
                discardSecrets()
                if !signedIn {
                    mode = .confirmEmail
                    infoMessage = String(localized: "Enter the code sent to your email. If you already have an account, sign in instead.")
                }
            case .confirmEmail:
                try await session.verifySignup(email: email, code: code)
                discardSecrets()
            case .recoveryEmail:
                try await session.auth.requestPasswordReset(email: email)
                try Task.checkCancellation()
                mode = .resetPassword
                infoMessage = String(localized: "If an account exists for this email, a reset code has been sent.")
            case .resetPassword:
                try await session.resetPassword(email: email, code: code, password: password)
                discardSecrets()
            }
        } catch is CancellationError { return }
        catch {
            if error as? APIError == .emailNotConfirmed { mode = .confirmEmail; discardSecrets() }
            errorMessage = error.localizedDescription
        }
    }

    func resendCode() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            if mode == .confirmEmail { try await session.auth.resendSignup(email: email) }
            else { try await session.auth.requestPasswordReset(email: email) }
            try Task.checkCancellation()
            infoMessage = String(localized: "A new code has been requested. Check your email.")
        } catch is CancellationError { return }
        catch { errorMessage = error.localizedDescription }
    }

    func discardSecrets() { password = ""; code = "" }
}
