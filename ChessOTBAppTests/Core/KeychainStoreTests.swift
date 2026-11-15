import Foundation
import Testing
@testable import ChessOTBApp

struct KeychainStoreTests {
    @Test func storesRestoresAndRemovesOnlyItsOwnSession() async throws {
        let name = "dev.chessotb.tests." + UUID().uuidString
        let store = KeychainStore(service: name)
        let other = KeychainStore(service: name + ".other")
        try await store.save(AccountFixtures.session)
        try await other.save(AccountFixtures.session)
        #expect(try await KeychainStore(service: name).load() == AccountFixtures.session)
        try await store.clear()
        #expect(try await store.load() == nil)
        #expect(try await other.load() != nil)
        try await other.clear()
    }
}
