import SwiftUI

/// Shows just the current proposed differences. Historical revisions stay out of the decision flow.
struct MeetingChangeView: View {
    @ObservedObject var model: MeetingDetailViewModel
    let workspace: MessagingWorkspace
    @Environment(\.scenePhase) private var scenePhase
    private struct RequestedAction: Equatable { let id = UUID(); let action: MeetingDetailViewModel.Action; let version: Int }
    @State private var action: RequestedAction?
    @State private var showEdit = false
    @State private var proposalModel: ProposalViewModel?
    @State private var reload = 0
    private var active: Bool { scenePhase == .active && workspace.cache.isActive }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let meeting = model.meeting, let proposed = meeting.pendingRevision {
                        changes(meeting, proposed: proposed, now: context.date)
                    } else {
                        Text("No pending change").font(DesignTokens.Typography.sectionTitle)
                        Text("This change has already been handled. Return to meeting details to see the agreed plan.")
                            .font(DesignTokens.Typography.body)
                    }
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    if let retry = model.retryAction {
                        PrimaryButton(title: "Retry action") { action = RequestedAction(action: retry, version: model.meeting?.version ?? 0) }.disabled(model.isMutating)
                    }
                    if model.isMutating { ProgressView("Saving change…") }
                }.padding(22)
            }.clipped().refreshable { await model.refresh() }
        }
        .background(DesignTokens.Colors.paper).navigationTitle("Proposed change").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            if let proposalModel, let meeting = model.meeting {
                NavigationStack { MeetingProposalView(model: proposalModel, peerName: meeting.peerName(ownProfileID: workspace.ownProfileID)) { _ in reload += 1 } }
            }
        }
        .task(id: active) {
            guard active else { return }
            repeat {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
        .task(id: reload) { if reload > 0 { await model.refresh() } }
        .task(id: action) {
            guard let action else { return }
            await model.perform(action.action, expectedVersion: action.version)
            self.action = nil
        }
        .disabled(!workspace.cache.isActive)
    }
    @ViewBuilder private func changes(_ meeting: Meeting, proposed: MeetingRevision, now: Date) -> some View {
        let sentByMe = meeting.pendingProposerID == workspace.ownProfileID
        let differences = MeetingChanges(agreed: meeting.revision, proposed: proposed)
        Text(sentByMe ? "You proposed a change" : "\(meeting.peerName(ownProfileID: workspace.ownProfileID)) proposed a change")
            .font(DesignTokens.Typography.sectionTitle).fixedSize(horizontal: false, vertical: true)
        Text(sentByMe ? "Waiting for the other player. You can edit your proposed change." : "Accept these changes or keep your currently agreed plan.")
            .font(DesignTokens.Typography.body).foregroundStyle(DesignTokens.Colors.muted)
        VStack(alignment: .leading, spacing: 20) {
            if differences.timeChanged {
                VStack(alignment: .leading, spacing: 8) {
                    Label("New date and time", systemImage: "calendar").font(DesignTokens.Typography.eyebrow)
                    Text(proposed.formattedTime).font(DesignTokens.Typography.body)
                    Text(proposed.timeZone.replacingOccurrences(of: "_", with: " ")).font(DesignTokens.Typography.caption)
                }
            }
            if differences.locationChanged { MeetingLocationView(location: proposed.location, place: proposed.place) }
            if differences.noteChanged {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Updated note").font(DesignTokens.Typography.eyebrow)
                    Text(proposed.note.isEmpty ? String(localized: "Meeting note removed") : proposed.note)
                        .font(DesignTokens.Typography.body).textSelection(.enabled)
                }
            }
            if differences.isEmpty { Text("The proposed details match your agreed plan.").font(DesignTokens.Typography.body) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
        Text("Everything else stays as agreed.").font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
        if proposed.startsAt <= now {
            StateNotice(message: sentByMe ? "The proposed time has passed. Edit the change and choose a future time." : "The proposed time has passed and cannot be accepted. Reject the change to keep the original plan and propose another time.")
        }
        if sentByMe {
            PrimaryButton(title: "Edit Change") {
                proposalModel = workspace.proposal(conversationID: meeting.conversationID, meeting: meeting)
                showEdit = proposalModel != nil
            }.disabled(model.isMutating || model.retryAction != nil).accessibilityIdentifier("meeting.editChange")
        } else if model.canRespondToChange {
            PrimaryButton(title: "Accept Change") { action = RequestedAction(action: .acceptChange, version: meeting.version) }
                .disabled(model.isMutating || proposed.startsAt <= now).accessibilityIdentifier("meeting.acceptChange")
            PrimaryButton(title: "Reject Change", kind: .secondary) { action = RequestedAction(action: .declineChange, version: meeting.version) }
                .disabled(model.isMutating).accessibilityIdentifier("meeting.declineChange")
        }
    }
}
