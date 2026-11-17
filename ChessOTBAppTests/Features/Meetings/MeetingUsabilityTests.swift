import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct MeetingUsabilityTests {
    nonisolated static let place = MeetingPlace(name: "Central Library", address: "476 5th Ave, New York, NY 10018, United States", latitude: 40.7532, longitude: -73.9822)

    @Test func mapsLinkPreservesExactCoordinateAndEscapesName() throws {
        let place = MeetingPlace(name: "Library & café", address: Self.place.address, latitude: 40.7532, longitude: -73.9822)
        let url = try #require(place.mapsURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(url.host == "maps.apple.com")
        #expect(items?.first(where: { $0.name == "ll" })?.value == "40.7532,-73.9822")
        #expect(items?.first(where: { $0.name == "q" })?.value == "Library & café")
        #expect(throws: (any Error).self) { _ = try MeetingPlace(name: "X", address: "", latitude: 400, longitude: 0).validated() }
    }
    @Test func onlyChangedFieldsAppearInReplacement() {
        let old = MeetingRevision(id: UUID(), meetingID: UUID(), startsAt: .distantFuture, timeZone: "UTC", location: "Old", note: "Board", place: Self.place)
        let replacement = MeetingRevision(id: UUID(), meetingID: old.meetingID, startsAt: old.startsAt, timeZone: old.timeZone, location: "New", note: old.note,
                                         place: MeetingPlace(name: "Other Library", address: "1 Main St, New York, NY", latitude: 40.7, longitude: -74))
        let change = MeetingChanges(agreed: old, proposed: replacement)
        #expect(!change.timeChanged)
        #expect(change.locationChanged)
        #expect(!change.noteChanged)
    }
    @Test func reviewRequiresSelectedAddressAndPersistsItAcrossRelaunchAndRetry() async throws {
        let cache = try AccountCache(accountID: UUID(), inMemory: true), service = MeetingDouble(), thread = UUID()
        let draft = ProposalViewModel(conversationID: thread, meeting: nil, service: service, cache: cache)
        draft.location = "SAC"
        #expect(!draft.canReview)
        draft.selectPlace(Self.place)
        #expect(draft.canReview)
        draft.review()
        let restored = ProposalViewModel(conversationID: thread, meeting: nil, service: service, cache: cache)
        #expect(restored.place == Self.place)
        #expect(restored.reviewed?.proposal.place == Self.place)
        service.failCreate = true
        await restored.send()
        #expect(restored.reviewed?.proposal.place == Self.place)
    }
    @Test func addressChangesInvalidateSelection() throws {
        let model = ProposalViewModel(conversationID: UUID(), meeting: nil, service: MeetingDouble(), cache: try AccountCache(accountID: UUID(), inMemory: true))
        model.selectPlace(Self.place)
        model.location = "Another place"
        #expect(model.place == nil)
        #expect(!model.canReview)
    }
    @Test func exactPlaceIsInTheReviewedTransport() async throws {
        let response = try JSONEncoder().encode(MeetingDouble.meeting())
        let client = try HTTPStub.client { request in
            #expect(request.url?.path == "/rest/v1/rpc/create_meeting_with_place")
            let body = try #require(JSONSerialization.jsonObject(with: HTTPStub.body(request)) as? [String: Any])
            let place = try #require(body["p_place"] as? [String: Any])
            #expect(place["address"] as? String == Self.place.address)
            #expect(place["latitude"] as? Double == 40.7532)
            return (200, response)
        }
        let service = MeetingService(client: client, auth: AuthDouble(), accountID: AccountFixtures.userID)
        _ = try await service.create(conversationID: UUID(), requestID: UUID(), proposal: MeetingProposal(startsAt: .distantFuture, timeZone: "UTC", location: Self.place.summary, note: "Upstairs", place: Self.place))
    }
    @Test func senderEditsPendingRevisionWithoutCreatingAnotherMeeting() async throws {
        let own = UUID(), service = MeetingDouble()
        var meeting = MeetingDouble.meeting(status: .confirmed, pendingProposerID: own)
        meeting.pendingRevision?.place = Self.place
        let model = ProposalViewModel(conversationID: meeting.conversationID, meeting: meeting, service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        #expect(model.place == Self.place)
        model.note = "Meet upstairs"
        model.review()
        await model.send()
        #expect(model.sentMeeting != nil)
        #expect(service.requests.isEmpty)
        #expect(service.editRequests.count == 1)
    }
    @Test func newProposalFromMeetingsUsesAcceptedFriendsConversation() async throws {
        let conversation = MessagingDouble(), friendship = MeetingFriendDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let workspace = MessagingWorkspace(cache: cache, service: conversation, ownProfileID: UUID(), meetingService: MeetingDouble(), friendshipService: friendship)
        let proposal = try await workspace.proposalForFriend(peerID: conversation.peer)
        #expect(proposal.conversationID == conversation.thread)
        friendship.state = .pending
        await #expect(throws: APIError.rejected) { _ = try await workspace.proposalForFriend(peerID: conversation.peer) }
        workspace.deactivate()
        await #expect(throws: APIError.unauthorized) { _ = try await workspace.proposalForFriend(peerID: conversation.peer) }
    }
    @Test func responseCannotAcceptAChangeEditedSinceItWasDisplayed() async throws {
        let own = UUID(), service = MeetingDouble()
        let meeting = MeetingDouble.meeting(status: .confirmed, pendingProposerID: UUID())
        service.value = meeting
        let model = MeetingDetailViewModel(id: meeting.id, ownProfileID: own, service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        await model.refresh()
        let displayedVersion = meeting.version
        service.value = Meeting(id: meeting.id, sequence: meeting.sequence, conversationID: meeting.conversationID, proposerID: meeting.proposerID, recipientID: meeting.recipientID, requestID: meeting.requestID, status: .confirmed, version: displayedVersion + 1, proposerName: "A", recipientName: "B", createdAt: "", updatedAt: "", revision: meeting.revision, pendingRevision: meeting.pendingRevision, pendingProposerID: meeting.pendingProposerID)
        await model.refresh()
        await model.perform(.acceptChange, expectedVersion: displayedVersion)
        #expect(service.responseRequests.isEmpty)
        #expect(model.errorMessage != nil)
    }
    @Test func editingLocationPreservesAnAgreedTimeLessThanAnHourAway() throws {
        let meeting = MeetingDouble.meeting(status: .confirmed, startsAt: .now.addingTimeInterval(600))
        let model = ProposalViewModel(conversationID: meeting.conversationID, meeting: meeting, service: MeetingDouble(), cache: try AccountCache(accountID: UUID(), inMemory: true))
        #expect(model.startsAt == meeting.revision.startsAt)
    }
    @Test func onlySenderCanEditAnUnansweredInvitation() async throws {
        let service = MeetingDouble(), meeting = MeetingDouble.meeting()
        service.value = meeting
        let sender = MeetingDetailViewModel(id: meeting.id, ownProfileID: meeting.proposerID, service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        let recipient = MeetingDetailViewModel(id: meeting.id, ownProfileID: meeting.recipientID, service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        await sender.refresh(); await recipient.refresh()
        #expect(sender.canEditInvitation)
        #expect(!recipient.canEditInvitation)
        let draft = ProposalViewModel(conversationID: meeting.conversationID, meeting: meeting, service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        draft.selectPlace(Self.place); draft.note = "Meet by the entrance"; draft.review()
        await draft.send()
        #expect(service.invitationEdits.count == 1)
        #expect(service.requests.isEmpty)
        #expect(draft.sentMeeting?.status == .pending)
    }
    @Test func meetingFiltersSeparatePendingConfirmedAndHistoryAndSelectedDay() async throws {
        let service = MeetingDouble()
        let model = MyMeetingsViewModel(service: service, cache: try AccountCache(accountID: UUID(), inMemory: true))
        let now = Date.now
        service.value = MeetingDouble.meeting(startsAt: now.addingTimeInterval(86400))
        await model.refresh()
        #expect(model.visible(section: .awaiting, at: now).count == 1)
        #expect(model.visible(section: .confirmed, at: now).isEmpty)
        #expect(model.visible(section: .awaiting, at: now, on: now).isEmpty)
        #expect(model.visible(section: .awaiting, at: now, on: service.value.revision.startsAt).count == 1)
        service.value = MeetingDouble.meeting(status: .confirmed, startsAt: now.addingTimeInterval(86400))
        await model.refresh()
        #expect(model.visible(section: .awaiting, at: now).isEmpty)
        #expect(model.visible(section: .confirmed, at: now).count == 1)
        #expect(model.visible(section: .history, at: now).isEmpty)
    }
    @Test func calendarHighlightsBothStatusesAndRoutesEveryMeetingOnADay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.firstWeekday = 2
        let date = try MeetingTimestamp.decode("2026-11-19T16:00:00Z")
        let awaiting = MeetingDouble.meeting(startsAt: date)
        let confirmed = MeetingDouble.meeting(status: .confirmed, startsAt: date.addingTimeInterval(3600))
        let cancelled = MeetingDouble.meeting(status: .cancelled, startsAt: date)
        let month = MeetingCalendarMonth(date: date, meetings: [awaiting, confirmed, cancelled], now: date.addingTimeInterval(-86400), calendar: calendar)
        let day = try #require(month.days.first { $0.date.map { calendar.isDate($0, inSameDayAs: date) } ?? false })
        #expect(day.hasAwaiting && day.hasConfirmed)
        #expect(day.meetings.map(\.id) == [awaiting.id, confirmed.id])
        #expect(month.days.filter { $0.date != nil }.count == 30)
        #expect(month.days.prefix(6).allSatisfy { $0.date == nil })
    }
    @Test func staleAddressResultsCannotReplaceANewerQuery() async {
        let lookup = DelayedMeetingLookup()
        let model = MeetingPlaceSearchViewModel(service: lookup)
        model.query = "Library"
        let task = Task { await model.search() }
        while lookup.continuation == nil { await Task.yield() }
        model.query = "Another address"
        lookup.continuation?.resume(returning: [Self.place])
        await task.value
        #expect(model.results.isEmpty)
        #expect(!model.hasSearched)
    }

}


@MainActor private final class MeetingFriendDouble: FriendshipServiceProtocol {
    var state: Friendship.State = .accepted
    @MainActor func relationship(peerID: UUID) async throws -> Friendship { Friendship(peerID: peerID, displayName: "Friend", areaName: nil, state: state, requesterID: nil, version: 1, sequence: 1) }
    @MainActor func list(before: Int64?) async throws -> FriendshipPage { FriendshipPage(relationships: [], nextCursor: nil) }
    @MainActor func mutate(peerID: UUID, action: FriendshipAction, requestID: UUID, version: Int) async throws -> Friendship { try await relationship(peerID: peerID) }
}
@MainActor private final class DelayedMeetingLookup: MeetingPlaceSearching {
    var continuation: CheckedContinuation<[MeetingPlace], Never>?
    func search(_ query: String) async throws -> [MeetingPlace] { await withCheckedContinuation { continuation = $0 } }
}
