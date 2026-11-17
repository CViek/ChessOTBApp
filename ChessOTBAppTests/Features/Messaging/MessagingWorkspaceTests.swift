import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct MessagingWorkspaceTests {
    @Test func entryPointsForTheSamePeerShareDraftAndHistory() async throws {
        let service = MessagingDouble()
        let cache = try AccountCache(accountID: UUID(), inMemory: true)
        let workspace = MessagingWorkspace(cache: cache, service: service, ownProfileID: AccountFixtures.profileID)
        let profileEntry = workspace.conversation(peerID: service.peer)
        let inboxEntry = workspace.conversation(peerID: service.peer)
        await profileEntry.refresh()
        profileEntry.draft = "Same thread, same draft"
        #expect(inboxEntry.draft == "Same thread, same draft")
        #expect(inboxEntry.conversationID == service.thread)
    }
    @Test func deactivationClearsVisibleAccountDataButPreservesOwnedDraftForNextLogin() async throws {
        let service = MessagingDouble(), accountID = UUID()
        let cache = try AccountCache(accountID: accountID, inMemory: true)
        service.messages = [Message(id: UUID(), conversationID: service.thread, senderID: service.peer, clientID: UUID(), sequence: 1, body: "Private history", createdAt: "2026-11-16T10:00:00Z")]
        let workspace = MessagingWorkspace(cache: cache, service: service, ownProfileID: AccountFixtures.profileID)
        let model = workspace.conversation(peerID: service.peer)
        await model.refresh(); await workspace.inbox.refresh()
        model.draft = "Private draft"
        workspace.deactivate()
        #expect(!cache.isActive)
        #expect(model.messages.isEmpty)
        #expect(model.outgoing.isEmpty)
        #expect(model.draft.isEmpty)
        #expect(workspace.inbox.conversations.isEmpty)
        let reopened = try AccountCache(accountID: accountID, container: cache.container)
        #expect(try MessageDraftStore(cache: reopened).load(peerID: service.peer) == "Private draft")
    }
    @Test func signOutRunsOnlyTheCurrentAccountsCleanup() async {
        let session = SessionViewModel(auth: AuthDouble())
        await session.restore()
        var cleared = false
        #expect(!session.registerAccountCleanup(accountID: UUID()) { Issue.record("Wrong account cleanup") })
        #expect(session.registerAccountCleanup(accountID: AccountFixtures.userID) { cleared = true })
        await session.signOut()
        #expect(cleared)
    }
}
