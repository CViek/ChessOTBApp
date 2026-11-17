import Combine
import Foundation

@MainActor final class MeetingDetailViewModel: ObservableObject {
    @Published private(set) var meeting: Meeting?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published private(set) var retryAction: Action?
    let id: UUID
    let ownProfileID: UUID
    private let service: any MeetingServiceProtocol
    private let cache: AccountCache
    private var active = true
    private var generation = 0
    private var mutation: Mutation?
    nonisolated enum Action: String, Codable, Sendable { case accept, decline, acceptChange, declineChange, cancel }
    private struct Mutation: Codable { let action: Action; let requestID: UUID; let version: Int }
    private var key: String { "meeting-action:" + id.uuidString }
    var canRespond: Bool { meeting?.status == .pending && meeting?.recipientID == ownProfileID && mutation == nil }
    var canAccept: Bool { canRespond && (meeting?.revision.startsAt ?? .distantPast) > .now }
    var canRespondToChange: Bool { meeting?.status == .confirmed && meeting?.pendingRevision != nil && meeting?.pendingProposerID != ownProfileID && mutation == nil }
    var canAcceptChange: Bool { canRespondToChange && (meeting?.pendingRevision?.startsAt ?? .distantPast) > .now }
    var canEditInvitation: Bool { meeting?.status == .pending && meeting?.proposerID == ownProfileID && mutation == nil }
    var canProposeChange: Bool { meeting?.status == .confirmed && meeting?.pendingRevision == nil && mutation == nil }
    var canCancel: Bool { (meeting?.status == .pending || meeting?.status == .confirmed) && mutation == nil }
    var conversationRoute: ConversationRoute? {
        guard let meeting else { return nil }
        return ConversationRoute(peerID: meeting.peerID(ownProfileID: ownProfileID), displayName: meeting.peerName(ownProfileID: ownProfileID))
    }
    init(id: UUID, ownProfileID: UUID, service: any MeetingServiceProtocol, cache: AccountCache) {
        self.id = id; self.ownProfileID = ownProfileID; self.service = service; self.cache = cache
        do { mutation = try cache.load(Optional<Mutation>.self, key: key) ?? nil; retryAction = mutation?.action }
        catch { errorMessage = error.localizedDescription }
    }
    func refresh() async {
        guard active, cache.isActive else { return }
        generation += 1; let stamp = generation
        isLoading = meeting == nil
        defer { if generation == stamp { isLoading = false } }
        do {
            let result = try await service.detail(id: id)
            guard active, cache.isActive, !Task.isCancelled, generation == stamp else { return }
            apply(result)
            if mutation == nil { errorMessage = nil }
        } catch is CancellationError { return }
        catch { if active, cache.isActive, generation == stamp { errorMessage = error.localizedDescription } }
    }
    func perform(_ action: Action, expectedVersion: Int? = nil) async {
        guard active, cache.isActive, !isMutating, let meeting else { return }
        if let mutation, mutation.action != action { return }
        if mutation == nil, let expectedVersion, expectedVersion != meeting.version {
            errorMessage = String(localized: "The meeting details changed while you were reviewing them. Review the latest details before responding.")
            return
        }
        isMutating = true; errorMessage = nil
        defer { isMutating = false }
        do {
            let request = mutation ?? Mutation(action: action, requestID: UUID(), version: meeting.version)
            try cache.save(request, key: key)
            mutation = request; retryAction = action
            let result: Meeting
            switch action {
            case .cancel: result = try await service.cancel(id: id, requestID: request.requestID, expectedVersion: request.version)
            case .accept, .decline:
                result = try await service.respond(id: id, requestID: request.requestID, expectedVersion: request.version, decision: action == .accept ? .confirmed : .declined)
            case .acceptChange, .declineChange:
                result = try await service.respondToChange(id: id, requestID: request.requestID, expectedVersion: request.version, decision: action == .acceptChange ? .confirmed : .declined)
            }
            guard active, cache.isActive, !Task.isCancelled else { return }
            apply(result)
            try clearMutation()
            await refresh() // Receipts can describe an older acknowledgement; fetch current state.
        } catch is CancellationError { return }
        catch {
            guard active, cache.isActive else { return }
            let message = error.localizedDescription
            if let api = error as? APIError, api == .conflict || api == .rejected {
                do { try clearMutation() } catch { errorMessage = error.localizedDescription; return }
                await refresh()
            }
            errorMessage = message
        }
    }
    func deactivate() { active = false; generation += 1; meeting = nil; errorMessage = nil; mutation = nil; retryAction = nil }
    private func clearMutation() throws {
        try cache.save(Optional<Mutation>.none, key: key)
        mutation = nil; retryAction = nil
    }
    private func apply(_ result: Meeting) {
        if result.version >= (meeting?.version ?? 0) { meeting = result }
    }
}
