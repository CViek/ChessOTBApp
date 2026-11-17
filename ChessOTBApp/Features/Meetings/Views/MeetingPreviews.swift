#if DEBUG
import SwiftUI

private nonisolated struct PreviewMeetingService: MeetingServiceProtocol {
    enum State { case populated, empty, unavailable }
    let state: State
    let value: Meeting
    func detail(id: UUID) async throws -> Meeting {
        if state == .unavailable { throw APIError.network }; return value
    }
    func list(before: Int64?) async throws -> MeetingPage {
        if state == .unavailable { throw APIError.network }
        return MeetingPage(meetings: state == .empty ? [] : [value], nextCursor: nil)
    }
    func create(conversationID: UUID, requestID: UUID, proposal: MeetingProposal) async throws -> Meeting { value }
    func cancel(id: UUID, requestID: UUID, expectedVersion: Int) async throws -> Meeting { value }
    func respond(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting { value }
    func proposeChange(id: UUID, requestID: UUID, expectedVersion: Int, proposal: MeetingProposal) async throws -> Meeting { value }
    func editChange(id: UUID, requestID: UUID, expectedVersion: Int, proposal: MeetingProposal) async throws -> Meeting { value }
    func respondToChange(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting { value }
}

private struct MeetingPreview: View {
    enum Screen { case list, detail, proposal, review }
    var screen: Screen = .list
    var state: PreviewMeetingService.State = .populated
    var replacement = false
    @State private var workspace: MessagingWorkspace?
    @State private var value: Meeting?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            if let workspace, let value {
                switch screen {
                case .list:
                    if let model = workspace.meetings { MyMeetingsView(model: model, ownProfileID: workspace.ownProfileID, workspace: workspace) }
                case .detail:
                    if let model = workspace.detail(id: value.id) { MeetingDetailView(model: model, workspace: workspace) }
                case .proposal, .review:
                    if let model = workspace.proposal(conversationID: value.conversationID, meeting: nil) {
                        MeetingProposalView(model: model, peerName: "Alex Morgan") { _ in }
                    }
                }
            } else if let error { Text(error) }
            else { ProgressView() }
        }
        .task {
            do {
                let ownID = UUID(), peerID = UUID(), meetingID = UUID()
                let revision = MeetingRevision(id: UUID(), meetingID: meetingID, startsAt: .now.addingTimeInterval(86400), timeZone: "America/New_York", location: "Central Library", note: "I can bring a board.")
                let pending = MeetingRevision(id: UUID(), meetingID: meetingID, startsAt: revision.startsAt.addingTimeInterval(3600), timeZone: revision.timeZone, location: "Library reading room", note: "A quieter place.")
                let meeting = Meeting(id: meetingID, sequence: 1, conversationID: UUID(), proposerID: ownID, recipientID: peerID,
                                      requestID: UUID(), status: .confirmed, version: 2, proposerName: "Jordan", recipientName: "Alex Morgan",
                                      createdAt: "", updatedAt: "", revision: revision, pendingRevision: replacement ? pending : nil,
                                      pendingProposerID: replacement ? peerID : nil, revisions: replacement ? [revision, pending] : [revision])
                let workspace = MessagingWorkspace(cache: try AccountCache(accountID: UUID(), inMemory: true),
                                                   service: PreviewMessagingService(state: .empty, peerID: peerID), ownProfileID: ownID,
                                                   meetingService: PreviewMeetingService(state: state, value: meeting))
                if let draft = workspace.proposal(conversationID: meeting.conversationID, meeting: nil) {
                    draft.selectPlace(MeetingPlace(name: "Central Library", address: "476 5th Ave, New York, NY 10018", latitude: 40.7532, longitude: -73.9822)); draft.note = revision.note
                    if screen == .review { draft.review() }
                }
                value = meeting; self.workspace = workspace
            } catch { self.error = error.localizedDescription }
        }
    }
}

#Preview("Meetings") { MeetingPreview() }
#Preview("Empty meetings") { MeetingPreview(state: .empty) }
#Preview("Unavailable meetings") { MeetingPreview(state: .unavailable) }
#Preview("Meeting details") { MeetingPreview(screen: .detail) }
#Preview("Replacement · dark, large text") { MeetingPreview(screen: .detail, replacement: true).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#Preview("Proposal") { MeetingPreview(screen: .proposal) }
#Preview("Review proposal") { MeetingPreview(screen: .review) }
#endif
