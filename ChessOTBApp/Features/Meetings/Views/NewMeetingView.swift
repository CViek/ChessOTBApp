import SwiftUI

struct NewMeetingView: View {
    @ObservedObject var friends: FriendsViewModel
    @StateObject private var model: NewMeetingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFriend: Friendship?
    @State private var more = 0
    let onSent: (Meeting) -> Void
    init(friends: FriendsViewModel, workspace: MessagingWorkspace, onSent: @escaping (Meeting) -> Void) {
        self.friends = friends; self.onSent = onSent
        _model = StateObject(wrappedValue: NewMeetingViewModel(workspace: workspace))
    }
    var body: some View {
        Group {
            if let proposal = model.proposal, let peerName = model.peerName {
                MeetingProposalView(model: proposal, peerName: peerName) { meeting in onSent(meeting); dismiss() }
            } else {
                picker
            }
        }
    }
    private var picker: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("Who would you like to play?").font(DesignTokens.Typography.sectionTitle)
                Text("Choose a friend and propose a time and place. They will need to accept your proposal.")
                    .font(DesignTokens.Typography.body).foregroundStyle(DesignTokens.Colors.muted)
                if let error = model.errorMessage ?? friends.errorMessage { AccountFeedback(message: error, isError: true) }
                if friends.isLoading { ProgressView("Loading friends…") }
                let accepted = friends.rows.filter { $0.state == .accepted }
                if accepted.isEmpty && !friends.isLoading {
                    StateNotice(message: "No friends to choose yet. Send or accept a friend request from Friends, or propose a game from a conversation.")
                }
                ForEach(accepted) { friend in
                    Button { selectedFriend = friend } label: {
                        HStack(spacing: 14) {
                            InitialsAvatar(initials: friend.route.initials)
                            Text(friend.displayName).font(DesignTokens.Typography.control)
                            Spacer()
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }.frame(minHeight: 56).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityIdentifier("meeting.chooseFriend.\(friend.peerID.uuidString.lowercased())")
                    Divider()
                }
                if friends.nextCursor != nil {
                    PrimaryButton(title: "Load more friends", kind: .secondary) { more += 1 }.disabled(friends.isLoading)
                }
                if model.isOpening { ProgressView("Opening proposal…") }
            }.padding(22)
        }
        .background(DesignTokens.Colors.paper).navigationTitle("Choose a friend").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .refreshable { await friends.refresh() }
        .task { await friends.refresh() }
        .task(id: selectedFriend) {
            if let selectedFriend { await model.select(selectedFriend); self.selectedFriend = nil }
        }
        .task(id: more) { if more > 0 { await friends.loadMore() } }
        .disabled(model.isOpening)
    }
}
