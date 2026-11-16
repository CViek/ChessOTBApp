import Foundation

@MainActor struct MessageDraftStore {
    let cache: AccountCache
    func load(peerID: UUID) throws -> String { try cache.load(String.self, key: "draft:" + peerID.uuidString) ?? "" }
    func save(_ text: String, peerID: UUID) throws { try cache.save(text, key: "draft:" + peerID.uuidString) }
}
