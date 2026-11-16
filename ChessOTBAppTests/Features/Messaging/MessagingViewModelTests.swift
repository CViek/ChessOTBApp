import Foundation
import SwiftData
import Testing
@testable import ChessOTBApp

@MainActor final class MessagingDouble: ConversationServiceProtocol {
    let thread = UUID()
    let peer = UUID()
    var messages: [Message] = []
    var failure = false
    var delayed = false
    var continuation: CheckedContinuation<MessagePage, Never>?
    @MainActor func open(peerID: UUID) async throws -> UUID { thread }
    @MainActor func inbox() async throws -> [Conversation] {
        if failure { throw APIError.network }
        return [Conversation(id: thread, peerID: peer, displayName: "Opponent", preview: messages.last?.body, updatedAt: "2026-11-16T10:00:00Z", unreadCount: 1)]
    }
    @MainActor func history(conversationID: UUID, before: Int64?) async throws -> MessagePage {
        if delayed { return await withCheckedContinuation { continuation = $0 } }
        if failure { throw APIError.network }
        let eligible = messages.filter { before == nil || $0.sequence < before! }
        let page = Array(eligible.suffix(50))
        return MessagePage(messages: page, nextCursor: eligible.count > 50 ? page.first?.sequence : nil)
    }
    @MainActor func send(conversationID: UUID, clientID: UUID, body: String) async throws -> Message {
        if failure { throw APIError.network }
        if let existing = messages.first(where: { $0.clientID == clientID }) { return existing }
        let value = Message(id: UUID(), conversationID: conversationID, senderID: AccountFixtures.profileID, clientID: clientID, sequence: Int64(messages.count + 1), body: body, createdAt: "2026-11-16T10:00:00Z")
        messages.append(value)
        return value
    }
    @MainActor func markRead(conversationID: UUID, through: Int64) async throws {}
}

@MainActor struct ConversationViewModelTests {
    @Test func sendingAfterOfflineIntervalDoesNotSkipInterveningHistory() async throws {
        let service = MessagingDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        service.messages = [Message(id: UUID(), conversationID: service.thread, senderID: service.peer, clientID: UUID(), sequence: 1, body: "First", createdAt: "2026-11-16T10:00:00Z")]
        let model = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        await model.refresh()
        for sequence in 2...100 {
            service.messages.append(Message(id: UUID(), conversationID: service.thread, senderID: service.peer, clientID: UUID(), sequence: Int64(sequence), body: "Offline reply \(sequence)", createdAt: "2026-11-16T10:00:00Z"))
        }
        model.draft = "Back online"
        await model.sendDraft()
        await model.refresh()
        #expect(model.messages.count == 101)
        #expect(model.messages.contains { $0.body == "Offline reply 2" })
    }
    @Test func failedTextSurvivesReopenAndRetryReconcilesAcknowledgment() async throws {
        let service = MessagingDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let model = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        await model.refresh()
        service.failure = true
        model.draft = "Hello opponent"
        await model.sendDraft()
        #expect(model.outgoing.count == 1)
        #expect(model.outgoing.first?.failed == true)
        #expect(model.draft.isEmpty)
        let clientID = try #require(model.outgoing.first?.id)
        let reopened = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        #expect(reopened.outgoing.first?.body == "Hello opponent")
        service.failure = false
        await reopened.retry(clientID)
        await reopened.refresh()
        #expect(reopened.messages.map(\.body) == ["Hello opponent"])
        #expect(reopened.outgoing.isEmpty)
    }
    @Test func blankCannotSendAndDraftsArePerPeerAndAccount() async throws {
        let service = MessagingDouble(), account = UUID()
        let cache = try AccountCache(accountID: account, inMemory: true)
        let model = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        await model.refresh()
        model.draft = "  \n "
        #expect(!model.canSend)
        await model.sendDraft()
        #expect(model.outgoing.isEmpty)
        model.draft = String(repeating: "😀", count: 4_001)
        #expect(!model.canSend)
        model.draft = "Saved draft"
        #expect(model.canSend)
        let same = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        #expect(same.draft == "Saved draft")
        let otherPeer = ConversationViewModel(peerID: UUID(), ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        #expect(otherPeer.draft.isEmpty)
        let otherCache = try AccountCache(accountID: UUID(), container: cache.container)
        let other = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: otherCache)
        #expect(other.draft.isEmpty)
    }
    @Test func deactivationRejectsLateHistoryAndCacheWrites() async throws {
        let service = MessagingDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let model = ConversationViewModel(peerID: service.peer, ownProfileID: AccountFixtures.profileID, service: service, cache: cache)
        service.delayed = true
        let task = Task { await model.refresh() }
        while service.continuation == nil { await Task.yield() }
        cache.deactivate()
        let message = Message(id: UUID(), conversationID: service.thread, senderID: service.peer, clientID: UUID(), sequence: 1, body: "Late secret", createdAt: "2026-11-16T10:00:00Z")
        service.continuation?.resume(returning: MessagePage(messages: [message], nextCursor: nil))
        await task.value
        #expect(model.messages.isEmpty)
        #expect(throws: (any Error).self) { try cache.save("secret", key: "draft") }
    }
}

@MainActor struct InboxViewModelTests {
    @Test func realRowsPersistAndOfflineRefreshKeepsCachedRowsWithError() async throws {
        let service = MessagingDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let model = InboxViewModel(service: service, cache: cache)
        await model.refresh()
        #expect(model.conversations.first?.peerID == service.peer)
        let reopened = InboxViewModel(service: service, cache: cache)
        #expect(reopened.unreadCount == 1)
        service.failure = true
        await reopened.refresh()
        #expect(reopened.conversations.count == 1)
        #expect(reopened.errorMessage != nil)
    }
}
