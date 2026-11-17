import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct MeetingPresentationTests {
    @Test func pastDraftCannotProceedToReview() throws {
        let model = ProposalViewModel(conversationID: UUID(), meeting: nil, service: MeetingDouble(), cache: try AccountCache(accountID: UUID(), inMemory: true))
        model.location = "Library"; model.startsAt = .distantPast
        model.selectPlace(MeetingUsabilityTests.place); model.review()
        #expect(model.reviewed == nil)
        #expect(model.errorMessage != nil)
    }
    @Test func persistedRetryCanRecoverReceiptAfterMeetingTime() async throws {
        let response = try JSONEncoder().encode(MeetingDouble.meeting())
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/create_meeting")
            return (200, response)
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        _ = try await service.create(conversationID: UUID(), requestID: UUID(), proposal: MeetingProposal(startsAt: .distantPast, timeZone: "UTC", location: "Library", note: ""))
    }
    @Test func reviewBackAndRelaunchPreserveOwnedDraft() throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let service = MeetingDouble()
        let thread = UUID()
        let model = ProposalViewModel(conversationID: thread, meeting: nil, service: service, cache: cache)
        model.location = " Library "; model.note = "Board"; model.startsAt = .now.addingTimeInterval(86400)
        model.selectPlace(MeetingUsabilityTests.place); model.review()
        #expect(model.reviewed?.proposal.location == MeetingUsabilityTests.place.summary)
        let request = model.reviewed?.requestID
        let restored = ProposalViewModel(conversationID: thread, meeting: nil, service: service, cache: cache)
        #expect(restored.reviewed?.requestID == request)
        #expect(restored.note == "Board")
        restored.edit()
        #expect(restored.reviewed == nil)
        #expect(restored.location == MeetingUsabilityTests.place.summary)
    }
    @Test func failedSendRetainsExactReviewedRequestUntilRetry() async throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let service = MeetingDouble(); service.failCreate = true
        let model = ProposalViewModel(conversationID: UUID(), meeting: nil, service: service, cache: cache)
        model.location = "Library"; model.selectPlace(MeetingUsabilityTests.place); model.review()
        await model.send()
        let request = model.reviewed?.requestID
        #expect(model.errorMessage != nil)
        model.edit()
        #expect(model.reviewed?.requestID == request)
        service.failCreate = false
        await model.send()
        #expect(service.requests.count == 2 && Set(service.requests).count == 1)
        #expect(model.sentMeeting != nil)
    }
    @Test func staleChangeRefreshPreservesDraftForCurrentVersion() async throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let service = MeetingDouble()
        let original = MeetingDouble.meeting(status: .confirmed)
        service.value = Meeting(id: original.id, sequence: original.sequence, conversationID: original.conversationID, proposerID: original.proposerID, recipientID: original.recipientID, requestID: original.requestID, status: .confirmed, version: 2, proposerName: "A", recipientName: "B", createdAt: "", updatedAt: "", revision: original.revision)
        service.changeConflict = true
        let model = ProposalViewModel(conversationID: original.conversationID, meeting: original, service: service, cache: cache)
        model.location = "My edited place"; model.selectPlace(MeetingUsabilityTests.place); model.review(); await model.send()
        #expect(model.sentMeeting?.version == 2)
        let reopened = ProposalViewModel(conversationID: original.conversationID, meeting: service.value, service: service, cache: cache)
        #expect(reopened.place == MeetingUsabilityTests.place)
    }
    @Test func historyClassifiesPastUnansweredAndTerminalWithoutClaimingPlayed() throws {
        let past = MeetingDouble.meeting(startsAt: .distantPast)
        let future = MeetingDouble.meeting(startsAt: .distantFuture)
        #expect(past.isHistory(at: .now))
        #expect(!future.isHistory(at: .now))
        #expect(MeetingDouble.meeting(status: .cancelled, startsAt: .distantFuture).isHistory(at: .now))
    }
    @Test func deactivationDiscardsSuspendedDetailResult() async throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let service = MeetingDouble(); service.pauseDetail = true
        let model = MeetingDetailViewModel(id: UUID(), ownProfileID: UUID(), service: service, cache: cache)
        let task = Task { await model.refresh() }
        while service.continuation == nil { await Task.yield() }
        model.deactivate(); cache.deactivate()
        service.continuation?.resume(returning: MeetingDouble.meeting())
        await task.value
        #expect(model.meeting == nil)
    }
    @Test func declineChangeKeepsConfirmedPlanAndOwnChangeCannotBeAccepted() async throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let own = UUID(), service = MeetingDouble()
        service.value = MeetingDouble.meeting(status: .confirmed, pendingProposerID: own)
        let model = MeetingDetailViewModel(id: service.value.id, ownProfileID: own, service: service, cache: cache)
        await model.refresh()
        #expect(!model.canRespondToChange)
        #expect(!model.canProposeChange)
        #expect(model.canCancel)
    }
}

@MainActor final class MeetingDouble: MeetingServiceProtocol {
    var value = meeting()
    var requests: [UUID] = []
    var editRequests: [UUID] = []
    var invitationEdits: [UUID] = []
    var responseRequests: [UUID] = []
    var failCreate = false
    var pauseDetail = false
    var changeConflict = false
    var continuation: CheckedContinuation<Meeting, any Error>?
    @MainActor func create(conversationID: UUID, requestID: UUID, proposal: MeetingProposal) async throws -> Meeting {
        requests.append(requestID)
        if failCreate { throw URLError(.networkConnectionLost) }
        return value
    }
    @MainActor func detail(id: UUID) async throws -> Meeting {
        if pauseDetail { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return value
    }
    @MainActor func list(before: Int64?) async throws -> MeetingPage { MeetingPage(meetings: [value], nextCursor: nil) }
    @MainActor func cancel(id: UUID, requestID: UUID, expectedVersion: Int) async throws -> Meeting { value }
    @MainActor func respond(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting { responseRequests.append(requestID); return value }
    @MainActor func proposeChange(id: UUID, requestID: UUID, expectedVersion: Int, proposal: MeetingProposal) async throws -> Meeting {
        if changeConflict { throw APIError.conflict }; return value
    }
    @MainActor func editInvitation(id: UUID, requestID: UUID, expectedVersion: Int, proposal: MeetingProposal) async throws -> Meeting { invitationEdits.append(requestID); return value }
    @MainActor func editChange(id: UUID, requestID: UUID, expectedVersion: Int, proposal: MeetingProposal) async throws -> Meeting { editRequests.append(requestID); return value }
    @MainActor func respondToChange(id: UUID, requestID: UUID, expectedVersion: Int, decision: MeetingDecision) async throws -> Meeting { responseRequests.append(requestID); return value }
    static func meeting(status: MeetingStatus = .pending, startsAt: Date = .distantFuture, pendingProposerID: UUID? = nil) -> Meeting {
        let id = UUID()
        let revision = MeetingRevision(id: UUID(), meetingID: id, startsAt: startsAt, timeZone: "UTC", location: "Library", note: "")
        return Meeting(id: id, sequence: 1, conversationID: UUID(), proposerID: UUID(), recipientID: UUID(), requestID: UUID(), status: status, version: 1, proposerName: "A", recipientName: "B", createdAt: "", updatedAt: "", revision: revision, pendingRevision: pendingProposerID == nil ? nil : revision, pendingProposerID: pendingProposerID, revisions: [revision])
    }
}
