import SwiftUI

struct FriendsView: View {
    @ObservedObject var model: FriendsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var moreRequest = 0
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Text("Friends").font(DesignTokens.Typography.listTitle)
                Text("Stay in touch and arrange another game together.")
                    .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isLoading && model.rows.isEmpty { ProgressView("Loading friends…") }
                if !model.isLoading && model.rows.isEmpty && model.errorMessage == nil {
                    StateNotice(message: "No friends or requests yet. Open a player's profile to send a friend request.")
                }
                section("Incoming requests", rows: model.rows.filter { $0.canRespond(ownProfileID: model.ownProfileID) })
                section("Sent requests", rows: model.rows.filter { $0.state == .pending && !$0.canRespond(ownProfileID: model.ownProfileID) })
                section("Friends", rows: model.rows.filter { $0.state == .accepted })
                if model.nextCursor != nil {
                    PrimaryButton(title: "Load more friends", kind: .secondary) { moreRequest += 1 }.disabled(model.isLoading)
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
    @ViewBuilder private func section(_ title: LocalizedStringKey, rows: [Friendship]) -> some View {
        if !rows.isEmpty {
            Text(title).font(DesignTokens.Typography.sectionTitle)
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
                                .frame(maxWidth: .infinity, minHeight: 50).contentShape(.rect)
                        }
                    }
                    FriendshipActionsView(model: model, peerID: row.peerID)
                }.padding(16).background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
            }
        }
    }
}
