import Combine
import Foundation

nonisolated struct ReviewedProposal: Codable, Equatable, Sendable {
    let requestID: UUID
    let proposal: MeetingProposal
    var attempted = false
}

@MainActor final class ProposalViewModel: ObservableObject {
    @Published var startsAt = Date.now.addingTimeInterval(86400) { didSet { persist() } }
    @Published var timeZone = TimeZone.current.identifier { didSet { persist() } }
    @Published var location = "" { didSet { persist() } }
    @Published var note = "" { didSet { persist() } }
    @Published private(set) var reviewed: ReviewedProposal?
    @Published private(set) var sentMeeting: Meeting?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSending = false
    let conversationID: UUID
    @Published private(set) var sourceMeeting: Meeting?
    private let service: any MeetingServiceProtocol
    private let cache: AccountCache
    private var active = true
    private var restoring = false
    private var key: String { "proposal:" + (sourceMeeting?.id ?? conversationID).uuidString }
    var canEdit: Bool { active && cache.isActive && reviewed?.attempted != true && !isSending }
    var canReview: Bool { canEdit && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(conversationID: UUID, meeting: Meeting?, service: any MeetingServiceProtocol, cache: AccountCache) {
        self.conversationID = conversationID; sourceMeeting = meeting; self.service = service; self.cache = cache
        restoring = true
        do {
            if let draft = try cache.load(Draft.self, key: key), draft.sourceVersion == meeting?.version {
                startsAt = draft.startsAt; timeZone = draft.timeZone; location = draft.location; note = draft.note; reviewed = draft.reviewed
            } else if let meeting {
                startsAt = max(meeting.revision.startsAt, .now.addingTimeInterval(3600))
                timeZone = meeting.revision.timeZone; location = meeting.revision.location; note = meeting.revision.note
            }
        } catch { errorMessage = error.localizedDescription }
        restoring = false
    }
    func review() {
        guard canEdit else { return }
        do {
            let proposal = try MeetingProposal(startsAt: startsAt, timeZone: timeZone, location: location, note: note).normalized()
            guard startsAt > .now else { throw APIError.rejected }
            reviewed = ReviewedProposal(requestID: UUID(), proposal: proposal)
            errorMessage = nil
            try save()
        } catch { reviewed = nil; errorMessage = String(localized: "Choose a future time, a valid time zone and a place (up to 500 characters). Notes may use up to 2,000 characters.") }
    }
    func edit() {
        guard canEdit else { return }
        reviewed = nil; persist()
    }
    func send() async {
        guard active, cache.isActive, !isSending, var reviewed else { return }
        isSending = true; errorMessage = nil
        defer { isSending = false }
        do {
            reviewed.attempted = true; self.reviewed = reviewed
            try save() // A durable request ID must exist before any network side effect.
            let result: Meeting
            if let meeting = sourceMeeting {
                result = try await service.proposeChange(id: meeting.id, requestID: reviewed.requestID, expectedVersion: meeting.version, proposal: reviewed.proposal)
            } else {
                result = try await service.create(conversationID: conversationID, requestID: reviewed.requestID, proposal: reviewed.proposal)
            }
            guard active, cache.isActive, !Task.isCancelled else { return }
            sentMeeting = result
            self.reviewed = nil; location = ""; note = ""
            try save()
        } catch is CancellationError { return }
        catch {
            guard active, cache.isActive else { return }
            if let api = error as? APIError, api == .conflict, let sourceMeeting {
                do {
                    let current = try await service.detail(id: sourceMeeting.id)
                    guard active, cache.isActive, !Task.isCancelled else { return }
                    self.sourceMeeting = current; self.reviewed = nil
                    try save()
                    sentMeeting = current
                } catch {
                    guard active, cache.isActive else { return }
                    errorMessage = error.localizedDescription
                    return
                }
            } else if let api = error as? APIError, api == .rejected {
                self.reviewed?.attempted = false
            }
            errorMessage = error.localizedDescription
            persist()
        }
    }
    func deactivate() {
        active = false; restoring = true
        location = ""; note = ""; reviewed = nil; sentMeeting = nil; errorMessage = nil
    }
    private func persist() {
        guard !restoring, active, cache.isActive else { return }
        do { try save() } catch { errorMessage = error.localizedDescription }
    }
    private func save() throws {
        try cache.save(Draft(startsAt: startsAt, timeZone: timeZone, location: location, note: note, reviewed: reviewed, sourceVersion: sourceMeeting?.version), key: key)
    }
    private struct Draft: Codable {
        let startsAt: Date
        let timeZone: String
        let location: String
        let note: String
        let reviewed: ReviewedProposal?
        let sourceVersion: Int?
    }
}
