import SwiftUI

struct PlayerProfileView: View {
    let id: UUID
    let distanceDescription: String?
    let workspace: MessagingWorkspace?
    @StateObject private var model: PlayerProfileViewModel
    @Environment(SessionViewModel.self) private var session
    @State private var retry = 0
    init(id: UUID, distanceDescription: String? = nil, service: any ProfileServiceProtocol, workspace: MessagingWorkspace? = nil) {
        self.workspace = workspace
        self.id = id; self.distanceDescription = distanceDescription
        _model = StateObject(wrappedValue: PlayerProfileViewModel(service: service))
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let profile = model.profile {
                    VStack(spacing: 16) {
                        InitialsAvatar(initials: profile.initials, size: .large)
                        Text(profile.displayName).font(DesignTokens.Typography.playerTitle).accessibilityIdentifier("player.displayName")
                        if let area = profile.areaName {
                            Label { Text(area) } icon: { Image("IconPin").accessibilityHidden(true) }
                                .font(DesignTokens.Typography.notice)
                        }
                        if let distanceDescription { Text(distanceDescription).font(DesignTokens.Typography.caption) }
                    }.frame(maxWidth: .infinity).padding(28).background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 12))
                    RatingSummaryView(ratings: profile.ratings)
                    StateNotice(message: "Nearby means this player has chosen an area near your search. It doesn't mean they're available to play right now.")
                    if let workspace, profile.id != workspace.ownProfileID {
                        NavigationLink(value: ConversationRoute(peerID: profile.id, displayName: profile.displayName)) {
                            Text("Message to Arrange a Game").font(DesignTokens.Typography.control)
                                .frame(maxWidth: .infinity, minHeight: 50).padding(.horizontal, 18)
                                .foregroundStyle(DesignTokens.Colors.paper).background(DesignTokens.Colors.forest, in: .rect(cornerRadius: 12))
                        }.accessibilityIdentifier("player.message")
                        if let friends = workspace.friends {
                            ProfileFriendshipView(model: friends, peerID: profile.id)
                        }
                    }
                } else if model.isLoading { ProgressView("Loading player…") }
                else if let error = model.errorMessage {
                    AccountFeedback(message: error, isError: true)
                    PrimaryButton(title: "Retry") { retry += 1 }
                } else if model.hasLoaded { StateNotice(message: "This player's profile is no longer available.") }
            }.padding(22)
        }.background(DesignTokens.Colors.paper).navigationTitle("Player profile").navigationBarTitleDisplayMode(.inline)
            .task(id: retry) { await model.load(id: id) }
            .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
}

#if DEBUG
private struct PlayerPreview: View {
    let state: PreviewPlayerService.State
    var body: some View {
        NavigationStack {
            PlayerProfileView(id: PreviewAccountService.exampleProfile.id, distanceDescription: String(localized: "About 2 miles"), service: PreviewPlayerService(state: state))
        }.environment(SessionViewModel(auth: PreviewAccountService()))
    }
}
#Preview("Player · populated") { PlayerPreview(state: .populated) }
#Preview("Player · missing") { PlayerPreview(state: .missing) }
#Preview("Player · loading, dark") { PlayerPreview(state: .loading).preferredColorScheme(.dark) }
#Preview("Player · error") { PlayerPreview(state: .failed) }
#endif
