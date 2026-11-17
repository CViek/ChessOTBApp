import SwiftUI

struct MeetingDetailView: View {
    @StateObject private var model: MeetingDetailViewModel
    let workspace: MessagingWorkspace
    @Environment(\.scenePhase) private var scenePhase
    @State private var action: RequestedAction?
    @State private var showCancellation = false
    @State private var showChange = false
    @State private var proposalModel: ProposalViewModel?
    @State private var refreshRequest = 0
    private struct RequestedAction: Equatable { let id = UUID(); let action: MeetingDetailViewModel.Action; let version: Int? }
    private var active: Bool { scenePhase == .active && workspace.cache.isActive }
    init(model: MeetingDetailViewModel, workspace: MessagingWorkspace) {
        _model = StateObject(wrappedValue: model); self.workspace = workspace
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let meeting = model.meeting { content(meeting) }
                else if model.isLoading { ProgressView("Loading meeting…") }
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if let retry = model.retryAction {
                    PrimaryButton(title: "Retry action") { request(retry) }.disabled(model.isMutating).accessibilityIdentifier("meeting.retry")
                }
                if model.isMutating { ProgressView("Saving meeting…") }
            }.padding(22)
        }
        .clipped()
        .background(DesignTokens.Colors.paper).navigationTitle("Meeting Details").navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .alert("Cancel this meeting?", isPresented: $showCancellation) {
            Button("Keep Meeting", role: .cancel) {}
            Button("Cancel Meeting", role: .destructive) { request(.cancel) }
        } message: { Text("Both players will see the cancellation. Any pending change will be withdrawn.") }
        .sheet(isPresented: $showChange) {
            if let meeting = model.meeting, let proposalModel {
                NavigationStack { MeetingProposalView(model: proposalModel, peerName: meeting.peerName(ownProfileID: workspace.ownProfileID)) { _ in refreshRequest += 1 } }
            }
        }
        .task(id: active) {
            guard active else { return }
            repeat {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
        .task(id: action) { if let action { await model.perform(action.action, expectedVersion: action.version); self.action = nil } }
        .task(id: refreshRequest) { if refreshRequest > 0 { await model.refresh() } }
        .disabled(!workspace.cache.isActive)
    }
    @ViewBuilder private func content(_ meeting: Meeting) -> some View {
        Text("Chess with \(meeting.peerName(ownProfileID: workspace.ownProfileID))").font(DesignTokens.Typography.playerTitle)
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.statusTitle).font(DesignTokens.Typography.statusTitle).accessibilityIdentifier("meeting.status")
            Text(meeting.pendingRevision != nil ? (meeting.pendingProposerID == workspace.ownProfileID ? String(localized: "Waiting for the other player to respond to your change. The agreed plan is unchanged.") : String(localized: "Review the proposed change and accept or reject it. The agreed plan is unchanged until you accept.")) : meeting.statusExplanation).font(DesignTokens.Typography.notice)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 8))
        if meeting.pendingRevision != nil {
            NavigationLink {
                MeetingChangeView(model: model, workspace: workspace)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meeting.pendingProposerID == workspace.ownProfileID ? "You proposed a change" : "A change needs your response")
                        .font(DesignTokens.Typography.control)
                    Label("View proposed change", systemImage: "chevron.right").font(DesignTokens.Typography.body)
                }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).padding(16)
                    .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityIdentifier("meeting.viewChange")
            Text("Currently agreed details").font(DesignTokens.Typography.eyebrow)
        }
        MeetingFactsView(revision: meeting.revision)
        actions(meeting)
        if let route = model.conversationRoute {
            NavigationLink("Open conversation", value: route).frame(minHeight: 44).accessibilityIdentifier("meeting.conversation")
        }
    }
    private func actions(_ meeting: Meeting) -> some View {
        VStack(spacing: 12) {
            if model.canRespond {
                PrimaryButton(title: "Accept Proposal") { request(.accept, version: meeting.version) }.disabled(!model.canAccept).accessibilityIdentifier("meeting.accept")
                PrimaryButton(title: "Decline Proposal", kind: .secondary) { request(.decline, version: meeting.version) }.accessibilityIdentifier("meeting.decline")
            }
            if model.canEditInvitation {
                PrimaryButton(title: "Edit Invitation", kind: .secondary) {
                    proposalModel = workspace.proposal(conversationID: meeting.conversationID, meeting: meeting)
                    showChange = proposalModel != nil
                }.accessibilityIdentifier("meeting.editInvitation")
            }
            if model.canProposeChange {
                PrimaryButton(title: "Propose a Change", kind: .secondary) {
                    if let meeting = model.meeting {
                        proposalModel = workspace.proposal(conversationID: meeting.conversationID, meeting: meeting)
                        showChange = proposalModel != nil
                    }
                }.accessibilityIdentifier("meeting.change")
            }
            if model.canCancel && !model.canRespond {
                PrimaryButton(title: "Cancel Meeting", kind: .danger) { showCancellation = true }.accessibilityIdentifier("meeting.cancel")
            }
        }.disabled(model.isMutating)
    }
    private func request(_ value: MeetingDetailViewModel.Action, version: Int? = nil) { action = RequestedAction(action: value, version: version) }
}
