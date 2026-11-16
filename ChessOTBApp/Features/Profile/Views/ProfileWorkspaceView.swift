import SwiftUI

struct ProfileWorkspaceView: View {
    @StateObject private var model: ProfileViewModel
    @Environment(SessionViewModel.self) private var session
    @State private var reloadRequest = 0
    @State private var showSignOutConfirmation = false
    @State private var signOutRequested = false
    @State private var editArea = false
    let dependencies: AppDependencies
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = StateObject(wrappedValue: ProfileViewModel(service: dependencies.profiles))
    }
    var body: some View {
        Group {
            if let profile = model.profile, profile.areaName != nil {
                TabView {
                    Tab("Discover", image: "IconDiscover") {
                        NavigationStack { NearbyPlayersView(service: dependencies.discovery, profiles: dependencies.profiles, areas: dependencies.areas) }
                    }
                    Tab("Profile", image: "IconProfile") {
                        NavigationStack {
                            ProfileView(model: model, profile: profile, editArea: { editArea = true })
                                .toolbar { signOutToolbar }
                        }
                    }
                }
            } else {
                NavigationStack { onboarding.toolbar { signOutToolbar } }
            }
        }
        .confirmationDialog("Sign out of ChessOTB?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { signOutRequested = true }
        }
        .sheet(isPresented: $editArea) {
            NavigationStack {
                SearchAreaView(purpose: .profile, areas: dependencies.areas, profiles: dependencies.profiles, discovery: dependencies.discovery) { profile, _ in
                    if let profile { model.acceptAreaProfile(profile) }
                }
            }
        }
        .disabled(session.isSigningOut)
        .overlay { if session.isSigningOut { ProgressView("Signing out…").padding().background(.regularMaterial, in: .rect(cornerRadius: 12)) } }
        .task(id: reloadRequest) { await model.load() }
        .task(id: signOutRequested) { if signOutRequested { await session.signOut() } }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    @ToolbarContentBuilder private var signOutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign out") { showSignOutConfirmation = true }.accessibilityIdentifier("account.signOut")
        }
    }
    @ViewBuilder private var onboarding: some View {
        if let profile = model.profile {
            SearchAreaView(purpose: .initialProfile, areas: dependencies.areas, profiles: dependencies.profiles, discovery: dependencies.discovery) { saved, _ in
                if let saved { model.acceptAreaProfile(saved) }
            }.id(profile.id)
        } else if model.isLoading {
            ProgressView("Loading profile…").frame(maxWidth: .infinity, maxHeight: .infinity).background(DesignTokens.Colors.paper)
        } else if model.hasLoaded { AccountSetupView(model: model) }
        else {
            VStack(spacing: 16) {
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                PrimaryButton(title: "Retry") { reloadRequest += 1 }
            }.padding().frame(maxWidth: .infinity, maxHeight: .infinity).background(DesignTokens.Colors.paper)
        }
    }
}

#if DEBUG
#Preview("Profile workspace") {
    ProfileWorkspaceView(dependencies: .preview)
        .environment(SessionViewModel(auth: PreviewAccountService())).environment(AppearanceSettings())
}
#endif
