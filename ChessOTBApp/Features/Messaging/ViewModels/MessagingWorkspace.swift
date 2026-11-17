import Foundation

@MainActor final class MessagingWorkspace {
    let cache: AccountCache
    let service: any ConversationServiceProtocol
    let ownProfileID: UUID
    let inbox: InboxViewModel
    let meetingService: (any MeetingServiceProtocol)?
    let meetings: MyMeetingsViewModel?
    let friends: FriendsViewModel?
    private var details: [UUID: MeetingDetailViewModel] = [:]
    private var proposals: [String: ProposalViewModel] = [:]
    private var threads: [UUID: ConversationViewModel] = [:]
    init(cache: AccountCache, service: any ConversationServiceProtocol, ownProfileID: UUID, meetingService: (any MeetingServiceProtocol)? = nil, friendshipService: (any FriendshipServiceProtocol)? = nil) {
        self.cache = cache; self.service = service; self.ownProfileID = ownProfileID
        self.meetingService = meetingService
        friends = friendshipService.map { FriendsViewModel(service: $0, cache: cache, ownProfileID: ownProfileID) }
        meetings = meetingService.map { MyMeetingsViewModel(service: $0, cache: cache) }
        inbox = InboxViewModel(service: service, cache: cache)
    }
    func conversation(peerID: UUID) -> ConversationViewModel {
        if let existing = threads[peerID] { return existing }
        let model = ConversationViewModel(peerID: peerID, ownProfileID: ownProfileID, service: service, cache: cache)
        threads[peerID] = model
        return model
    }
    func detail(id: UUID) -> MeetingDetailViewModel? {
        guard let meetingService else { return nil }
        if let model = details[id] { return model }
        let model = MeetingDetailViewModel(id: id, ownProfileID: ownProfileID, service: meetingService, cache: cache)
        details[id] = model; return model
    }
    func proposal(conversationID: UUID, meeting: Meeting?) -> ProposalViewModel? {
        guard let meetingService else { return nil }
        let key = (meeting?.id ?? conversationID).uuidString + ":" + String(meeting?.version ?? 0)
        if let model = proposals[key], model.sentMeeting == nil { return model }
        let model = ProposalViewModel(conversationID: conversationID, meeting: meeting, service: meetingService, cache: cache)
        proposals[key] = model; return model
    }
    func deactivate() {
        cache.deactivate()
        inbox.deactivate()
        meetings?.deactivate()
        friends?.deactivate()
        for model in details.values { model.deactivate() }
        for model in proposals.values { model.deactivate() }
        details.removeAll(); proposals.removeAll()
        for model in threads.values { model.deactivate() }
        threads.removeAll()
    }
}
