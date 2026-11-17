import SwiftUI

struct RootView: View {
    @Environment(SessionViewModel.self) private var session
    let dependencies: AppDependencies
    @State private var retryRequest = 0
    @State private var signOutRequest = 0

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                ProgressView("Restoring your session…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                VStack(spacing: 0) {
                    if let notice = session.notice { AccountFeedback(message: notice).padding(.horizontal) }
                    AccountEntryView(session: session)
                }
            case .signedIn(let user):
                ProfileWorkspaceView(dependencies: dependencies, accountID: user.id).id(user.id)
            case .restoreFailed(let message):
                restoreFailure(message)
            }
        }
        .foregroundStyle(DesignTokens.Colors.ink)
        .background(DesignTokens.Colors.paper)
        .task(id: retryRequest) { await session.restore() }
        .task(id: signOutRequest) { if signOutRequest > 0 { await session.signOut() } }
    }

    private func restoreFailure(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.regular) {
            AccountFeedback(message: message, isError: true)
            PrimaryButton(title: "Retry") { retryRequest += 1 }
            PrimaryButton(title: "Sign out on this device", kind: .quiet) { signOutRequest += 1 }
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Account entry") {
    RootView(dependencies: .preview)
        .environment(SessionViewModel(auth: PreviewAccountService()))
        .environment(AppearanceSettings())
}

#endif
