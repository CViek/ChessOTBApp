import SwiftUI

struct ProfileWorkspaceView: View {
    @StateObject private var model: ProfileViewModel
    @Environment(SessionViewModel.self) private var session
    @State private var reloadRequest = 0
    @State private var showSignOutConfirmation = false
    @State private var signOutRequested = false
    @State private var editArea = false
    @State private var messaging: MessagingWorkspace?
    @State private var workspaceError: String?
    @State private var workspaceReload = 0
    private struct WorkspaceLoadKey: Hashable {
        let profileID: UUID?
        let areaName: String?
        let reload: Int
    }
    let accountID: UUID
    let dependencies: AppDependencies
    init(dependencies: AppDependencies, accountID: UUID = UUID()) {
        self.accountID = accountID
        self.dependencies = dependencies
        _model = StateObject(wrappedValue: ProfileViewModel(service: dependencies.profiles))
    }
    var body: some View {
        Group {
            if let profile = model.profile, profile.areaName != nil, let messaging {
                TabView {
                    Tab("Discover", image: "IconDiscover") {
                        NavigationStack {
                            NearbyPlayersView(service: dependencies.discovery, profiles: dependencies.profiles, areas: dependencies.areas, workspace: messaging)
                                .modifier(MessagingDestinations(workspace: messaging, profiles: dependencies.profiles))
                        }
                    }
                    Tab("Inbox", image: "IconInbox") {
                        NavigationStack {
                            InboxView(model: messaging.inbox).modifier(MessagingDestinations(workspace: messaging, profiles: dependencies.profiles))
                        }
                    }
                    if let meetings = messaging.meetings {
                        Tab("Meetings", image: "IconMeetings") {
                            NavigationStack {
                                MyMeetingsView(model: meetings, ownProfileID: profile.id, workspace: messaging)
                                    .modifier(MessagingDestinations(workspace: messaging, profiles: dependencies.profiles))
                            }
                        }
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
        .task(id: WorkspaceLoadKey(profileID: model.profile?.id, areaName: model.profile?.areaName, reload: workspaceReload)) {
            guard let profile = model.profile, profile.areaName != nil, messaging == nil else { return }
            do {
                let workspace = try dependencies.messagingWorkspace(accountID: accountID, profileID: profile.id)
                try Task.checkCancellation()
                guard session.registerAccountCleanup(accountID: accountID, handler: { workspace.deactivate() }) else { workspace.deactivate(); return }
                messaging = workspace; workspaceError = nil
            } catch is CancellationError { return }
            catch { workspaceError = error.localizedDescription }
        }
        .task(id: signOutRequested) { if signOutRequested { await session.signOut() } }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    @ToolbarContentBuilder private var signOutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign out") { showSignOutConfirmation = true }.accessibilityIdentifier("account.signOut")
        }
    }
    @ViewBuilder private var onboarding: some View {
        if let profile = model.profile, profile.areaName != nil {
            VStack(spacing: 16) {
                if let workspaceError {
                    AccountFeedback(message: workspaceError, isError: true)
                    PrimaryButton(title: "Retry") { self.workspaceError = nil; workspaceReload += 1 }
                }
                else { ProgressView("Opening your workspace…") }
            }.padding().navigationTitle("ChessOTB")
        } else if let profile = model.profile {
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
