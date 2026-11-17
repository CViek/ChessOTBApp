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
    private struct RequestedAction: Equatable { let id = UUID(); let action: MeetingDetailViewModel.Action }
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
                Button("Refresh") { refreshRequest += 1 }.frame(minHeight: 44)
            }.padding(22)
        }
        .background(DesignTokens.Colors.paper).navigationTitle("Meeting Details").navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .confirmationDialog("Cancel this meeting?", isPresented: $showCancellation, titleVisibility: .visible) {
            Button("Cancel Meeting", role: .destructive) { request(.cancel) }.accessibilityIdentifier("meeting.confirmCancel")
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
        .task(id: action) { if let action { await model.perform(action.action); self.action = nil } }
        .task(id: refreshRequest) { if refreshRequest > 0 { await model.refresh() } }
        .disabled(!workspace.cache.isActive)
    }
    @ViewBuilder private func content(_ meeting: Meeting) -> some View {
        Text("Chess with \(meeting.peerName(ownProfileID: workspace.ownProfileID))").font(DesignTokens.Typography.playerTitle)
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.statusTitle).font(DesignTokens.Typography.statusTitle).accessibilityIdentifier("meeting.status")
            Text(meeting.statusExplanation).font(DesignTokens.Typography.notice)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 8))
        if meeting.pendingRevision != nil { Text("Agreed details").font(DesignTokens.Typography.eyebrow) }
        MeetingFactsView(revision: meeting.revision)
        if let pending = meeting.pendingRevision {
            Text("Proposed new details").font(DesignTokens.Typography.eyebrow)
            MeetingFactsView(revision: pending)
        }
        actions
        if let route = model.conversationRoute {
            NavigationLink("Open conversation", value: route).frame(minHeight: 44).accessibilityIdentifier("meeting.conversation")
        }
        if let history = meeting.revisions, history.count > 1 {
            DisclosureGroup("Proposal history") {
                ForEach(history) { revision in
                    VStack(alignment: .leading) {
                        if revision.id == meeting.revision.id { Text("Current agreed details").font(DesignTokens.Typography.caption) }
                        else if revision.id == meeting.pendingRevision?.id { Text("Awaiting agreement").font(DesignTokens.Typography.caption) }
                        else { Text("Previous proposal").font(DesignTokens.Typography.caption) }
                        MeetingFactsView(revision: revision)
                    }.padding(.vertical, 8)
                }
            }
        }
    }
    private var actions: some View {
        VStack(spacing: 12) {
            if model.canRespond {
                PrimaryButton(title: "Accept Proposal") { request(.accept) }.disabled(!model.canAccept).accessibilityIdentifier("meeting.accept")
                PrimaryButton(title: "Decline Proposal", kind: .secondary) { request(.decline) }.accessibilityIdentifier("meeting.decline")
            }
            if model.canRespondToChange {
                PrimaryButton(title: "Accept New Details") { request(.acceptChange) }.disabled(!model.canAcceptChange).accessibilityIdentifier("meeting.acceptChange")
                PrimaryButton(title: "Decline Change", kind: .secondary) { request(.declineChange) }.accessibilityIdentifier("meeting.declineChange")
            }
            if model.canProposeChange {
                PrimaryButton(title: "Propose a Change", kind: .secondary) {
                    if let meeting = model.meeting {
                        proposalModel = workspace.proposal(conversationID: meeting.conversationID, meeting: meeting)
                        showChange = proposalModel != nil
                    }
                }.accessibilityIdentifier("meeting.change")
            }
            if model.canCancel {
                PrimaryButton(title: "Cancel Meeting", kind: .danger) { showCancellation = true }.accessibilityIdentifier("meeting.cancel")
            }
        }.disabled(model.isMutating)
    }
    private func request(_ value: MeetingDetailViewModel.Action) { action = RequestedAction(action: value) }
}
