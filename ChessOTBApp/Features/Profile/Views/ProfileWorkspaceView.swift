import SwiftUI

struct ProfileWorkspaceView: View {
    @StateObject private var model: ProfileViewModel
    @Environment(SessionViewModel.self) private var session
    @State private var reloadRequest = 0
    @State private var showSignOutConfirmation = false
    @State private var signOutRequested = false

    init(service: any ProfileServiceProtocol) {
        _model = StateObject(wrappedValue: ProfileViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out") { showSignOutConfirmation = true }
                            .accessibilityIdentifier("account.signOut")
                    }
                }
                .confirmationDialog("Sign out of ChessOTB?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                    Button("Sign out", role: .destructive) { signOutRequested = true }
                }
                .disabled(session.isSigningOut)
                .overlay { if session.isSigningOut { ProgressView("Signing out…").padding().background(.regularMaterial, in: .rect(cornerRadius: 12)) } }
        }
        .task(id: reloadRequest) { await model.load() }
        .task(id: signOutRequested) { if signOutRequested { await session.signOut() } }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }

    @ViewBuilder
    private var content: some View {
        if let profile = model.profile { ProfileView(model: model, profile: profile) }
        else if model.isLoading { ProgressView("Loading profile…").frame(maxWidth: .infinity, maxHeight: .infinity).background(DesignTokens.Colors.paper) }
        else if model.hasLoaded { AccountSetupView(model: model) }
        else {
            VStack(spacing: DesignTokens.Spacing.regular) {
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                PrimaryButton(title: "Retry") { reloadRequest += 1 }
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity).background(DesignTokens.Colors.paper)
        }
    }
}

#if DEBUG
#Preview("Profile workspace") {
    ProfileWorkspaceView(service: PreviewAccountService())
        .environment(SessionViewModel(auth: PreviewAccountService()))
        .environment(AppearanceSettings())
}

#endif
