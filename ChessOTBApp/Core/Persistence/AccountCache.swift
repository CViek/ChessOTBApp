import Foundation
import SwiftData

@Model final class AccountCacheEntry {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

/// Each signed-in workspace owns a partition; deactivated instances refuse all writes.
@MainActor final class AccountCache {
    let accountID: UUID
    let container: ModelContainer
    private let context: ModelContext
    private(set) var isActive = true

    init(accountID: UUID, inMemory: Bool = false) throws {
        let configuration = ModelConfiguration("Messaging", isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: AccountCacheEntry.self, configurations: configuration)
        self.accountID = accountID; self.container = container
        context = ModelContext(container)
    }
    init(accountID: UUID, container: ModelContainer) throws {
        self.accountID = accountID; self.container = container; context = ModelContext(container)
    }
    func load<Value: Decodable>(_ type: Value.Type, key: String) throws -> Value? {
        guard isActive else { throw CancellationError() }
        guard let row = try entry(key) else { return nil }
        return try JSONDecoder().decode(type, from: row.payload)
    }
    func save<Value: Encodable>(_ value: Value, key: String) throws {
        guard isActive else { throw CancellationError() }
        let data = try JSONEncoder().encode(value)
        if let row = try entry(key) { row.payload = data }
        else { context.insert(AccountCacheEntry(key: scoped(key), payload: data)) }
        try context.save()
    }
    func deactivate() { isActive = false }
    private func scoped(_ key: String) -> String { accountID.uuidString + ":" + key }
    private func entry(_ key: String) throws -> AccountCacheEntry? {
        let fullKey = scoped(key)
        var request = FetchDescriptor<AccountCacheEntry>(predicate: #Predicate { $0.key == fullKey })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
