import SwiftUI

struct InboxView: View {
    @ObservedObject var model: InboxViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionViewModel.self) private var session
    @State private var moreRequest: UUID?
    private var active: Bool { scenePhase == .active && !session.isSigningOut && model.cache.isActive }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Inbox").font(DesignTokens.Typography.listTitle).accessibilityAddTraits(.isHeader)
                Text("Conversations stay here between arrangements.").font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isLoading { ProgressView("Loading conversations…") }
                else if model.conversations.isEmpty {
                    StateNotice(message: "No conversations yet. Open a nearby player's profile to start arranging a game.")
                }
                threads
                if model.isLoadingMore { ProgressView("Loading older conversations…") }
                else if model.nextCursor != nil {
                    PrimaryButton(title: "Load older conversations", kind: .secondary) { moreRequest = UUID() }
                }
            }.padding(22)
        }
        .background(DesignTokens.Colors.paper).navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .task(id: active) {
            guard active else { return }
            repeat {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
        .task(id: moreRequest) {
            guard let request = moreRequest else { return }
            await model.loadMore()
            if moreRequest == request { moreRequest = nil }
        }
    }
    private var threads: some View {
        LazyVStack(spacing: 0) {
            ForEach(model.conversations) { thread in
                NavigationLink(value: ConversationRoute(peerID: thread.peerID, displayName: thread.displayName)) {
                    HStack(spacing: 14) {
                        InitialsAvatar(initials: thread.initials)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(thread.displayName).font(DesignTokens.Typography.control)
                            Text(thread.preview ?? String(localized: "Start a conversation"))
                                .font(DesignTokens.Typography.caption).lineLimit(2).foregroundStyle(DesignTokens.Colors.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if thread.unreadCount > 0 {
                            Text("\(thread.unreadCount)").font(DesignTokens.Typography.caption).padding(8)
                                .foregroundStyle(DesignTokens.Colors.paper).background(DesignTokens.Colors.forest, in: .capsule)
                                .accessibilityLabel("\(thread.unreadCount) unread messages")
                        }
                    }.padding(.vertical, 14).contentShape(Rectangle())
                }.accessibilityIdentifier("inbox.thread.\(thread.id.uuidString.lowercased())")
                Divider()
            }
        }
    }
}
