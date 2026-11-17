import SwiftUI

struct FriendshipActionsView: View {
    @ObservedObject var model: FriendsViewModel
    let peerID: UUID
    @State private var request: Request?
    @State private var confirmRemoval = false
    private struct Request: Equatable { let id = UUID(); let action: FriendshipAction }
    var body: some View {
        VStack(spacing: 10) {
            if let retry = model.pending[peerID] {
                PrimaryButton(title: "Retry friend action", kind: .secondary) { perform(retry) }
            } else if let row = model.relationships[peerID] {
                switch row.state {
                case .none:
                    PrimaryButton(title: "Add Friend", kind: .secondary) { perform(.send) }
                case .pending:
                    if row.canRespond(ownProfileID: model.ownProfileID) {
                        Text("Friend request").font(DesignTokens.Typography.eyebrow)
                        PrimaryButton(title: "Accept request") { perform(.accept) }
                        PrimaryButton(title: "Decline request", kind: .secondary) { perform(.decline) }
                    } else { Text("Request Sent").font(DesignTokens.Typography.eyebrow) }
                case .accepted:
                    Text("Friends").font(DesignTokens.Typography.eyebrow)
                    PrimaryButton(title: "Remove friend", kind: .quiet) { confirmRemoval = true }
                }
            } else if model.errorMessage != nil {
                Button("Retry friendship status") { performRefresh() }.frame(minHeight: 44)
            } else { ProgressView("Loading friendship…") }
        }
        .disabled(model.busy.contains(peerID))
        .confirmationDialog("Remove this friend?", isPresented: $confirmRemoval, titleVisibility: .visible) {
            Button("Remove friend", role: .destructive) { perform(.remove) }
        } message: { Text("Your conversations and meeting history will remain available.") }
        .task(id: request) {
            guard let request else { return }
            await model.perform(request.action, peerID: peerID)
            if self.request == request { self.request = nil }
        }
        .task(id: refreshRequest) { if refreshRequest > 0 { await model.refresh(peerID: peerID) } }
    }
    @State private var refreshRequest = 0
    private func perform(_ action: FriendshipAction) { request = Request(action: action) }
    private func performRefresh() { refreshRequest += 1 }
}

struct ProfileFriendshipView: View {
    @ObservedObject var model: FriendsViewModel
    let peerID: UUID
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 12) {
            FriendshipActionsView(model: model, peerID: peerID)
            if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            repeat {
                await model.refresh(peerID: peerID)
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
    }
}
