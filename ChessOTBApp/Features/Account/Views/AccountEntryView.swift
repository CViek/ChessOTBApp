import SwiftUI

struct AccountEntryView: View {
    @StateObject private var model: AccountSetupViewModel
    @State private var action: Action?
    private enum Action: Hashable { case submit(UUID), resend(UUID) }

    init(session: SessionViewModel) {
        _model = StateObject(wrappedValue: AccountSetupViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.regular) {
                introduction
                accountForm
                accountActions
            }
            .padding(DesignTokens.Spacing.setupInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignTokens.Colors.paper)
        .task(id: action) {
            switch action {
            case .submit: await model.submit()
            case .resend: await model.resendCode()
            case nil: break
            }
        }
        .onDisappear { model.discardSecrets() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            BoardMark().padding(.bottom, DesignTokens.Spacing.regular)
            Text("ChessOTB").font(DesignTokens.Typography.eyebrow).foregroundStyle(DesignTokens.Colors.oxblood)
            Text("Find the player across the board.")
                .font(DesignTokens.Typography.setupTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("foundation.title")
            Text("Meet nearby chess players, talk first, then agree on a time and place together.")
                .foregroundStyle(DesignTokens.Colors.muted)
        }
    }

    private var accountForm: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.regular) {
            Text(model.title).font(DesignTokens.Typography.sectionTitle).accessibilityAddTraits(.isHeader)
            if model.mode == .confirmEmail || model.mode == .resetPassword {
                Text(model.email).font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                AccountField(title: "Email code", text: $model.code, kind: .code, identifier: "account.code")
            } else {
                AccountField(title: "Email", text: $model.email, kind: .email, identifier: "account.email")
            }
            if model.mode == .signIn || model.mode == .signUp || model.mode == .resetPassword {
                AccountField(title: model.mode == .resetPassword ? "New password" : "Password", text: $model.password,
                             kind: model.mode == .signIn ? .password : .newPassword, identifier: "account.password")
            }
            if model.mode == .signUp || model.mode == .resetPassword {
                Text("Use at least 8 characters. Your email and password stay off your public profile.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            }
            if let message = model.errorMessage { AccountFeedback(message: message, isError: true) }
            if let message = model.infoMessage { AccountFeedback(message: message) }
            if model.isSubmitting { ProgressView("Please wait…").frame(maxWidth: .infinity) }
            PrimaryButton(title: LocalizedStringKey(model.actionTitle)) { action = .submit(UUID()) }
                .accessibilityIdentifier("account.submit")
        }
        .disabled(model.isSubmitting)
    }

    private var accountActions: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            if model.mode == .signIn {
                PrimaryButton(title: "Create account", kind: .secondary) { model.changeMode(.signUp) }
                    .accessibilityIdentifier("account.create")
                PrimaryButton(title: "Forgot password?", kind: .quiet) { model.changeMode(.recoveryEmail) }
                    .accessibilityIdentifier("account.forgot")
            } else {
                if model.mode == .confirmEmail || model.mode == .resetPassword {
                    PrimaryButton(title: "Resend code", kind: .secondary) { action = .resend(UUID()) }
                }
                PrimaryButton(title: "Back to sign in", kind: .quiet) { model.changeMode(.signIn) }
                    .accessibilityIdentifier("account.back")
            }
        }.disabled(model.isSubmitting)
    }
}

#if DEBUG
#Preview("Sign in") {
    AccountEntryView(session: SessionViewModel(auth: PreviewAccountService()))
}

#endif
