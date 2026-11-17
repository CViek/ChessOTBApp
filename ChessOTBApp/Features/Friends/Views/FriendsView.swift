import SwiftUI

struct FriendsView: View {
    @ObservedObject var model: FriendsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var moreRequest = 0
    @State private var showingRequests = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Text("Friends").font(DesignTokens.Typography.listTitle)
                Text("Stay in touch and arrange another game together.")
                    .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                Picker("Friends and requests", selection: $showingRequests) {
                    Text("Friends").tag(false)
                    Text("Requests").tag(true)
                }.pickerStyle(.segmented).frame(minHeight: 44)
                    .accessibilityIdentifier("friends.sections")
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isLoading && model.rows.isEmpty { ProgressView("Loading friends…") }
                if showingRequests {
                    let requests = model.rows.filter { $0.state == .pending }
                    if !model.isLoading && requests.isEmpty && model.errorMessage == nil {
                        StateNotice(message: "No friend requests. Incoming and sent requests appear here.")
                    }
                    section("Incoming requests", rows: requests.filter { $0.canRespond(ownProfileID: model.ownProfileID) })
                    section("Sent requests", rows: requests.filter { !$0.canRespond(ownProfileID: model.ownProfileID) })
                } else {
                    let friends = model.rows.filter { $0.state == .accepted }
                    if !model.isLoading && friends.isEmpty && model.errorMessage == nil {
                        StateNotice(message: "No friends yet. Open a player's profile to send a friend request.")
                    }
                    section(nil, rows: friends)
                }
                if model.nextCursor != nil {
                    PrimaryButton(title: showingRequests ? "Load more requests" : "Load more friends", kind: .secondary) { moreRequest += 1 }.disabled(model.isLoading)
                }
            }.padding(22)
        }.background(DesignTokens.Colors.paper).navigationTitle("Friends").navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.refresh() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                repeat {
                    await model.refresh()
                    do { try await Task.sleep(for: .seconds(3)) } catch { return }
                } while !Task.isCancelled
            }
            .task(id: moreRequest) { if moreRequest > 0 { await model.loadMore() } }
    }
    @ViewBuilder private func section(_ title: LocalizedStringKey?, rows: [Friendship]) -> some View {
        if !rows.isEmpty {
            if let title { Text(title).font(DesignTokens.Typography.sectionTitle) }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink(value: PublicPlayerRoute(id: row.peerID)) {
                        HStack(spacing: 14) {
                            InitialsAvatar(initials: row.route.initials)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(row.displayName).font(DesignTokens.Typography.control)
                                if let area = row.areaName { Text(area).font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted) }
                            }
                            Spacer(); Image("IconChevron").accessibilityHidden(true)
                        }.frame(minHeight: 50).contentShape(.rect)
                    }.buttonStyle(.plain)
                    if row.state == .accepted {
                        NavigationLink(value: row.route) {
                            Text("Open conversation / arrange a game").font(DesignTokens.Typography.control)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    } else {
                        FriendshipActionsView(model: model, peerID: row.peerID)
                    }
                }.padding(16).background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
            }
        }
    }
}
