import Foundation
import Security

nonisolated protocol SessionStoreProtocol: Sendable {
    func load() async throws -> AuthSession?
    func save(_ session: AuthSession) async throws
    func clear() async throws
}

nonisolated struct SecureStorageError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { String(localized: "Could not access secure sign-in storage. Please try again.") }
}

actor KeychainStore: SessionStoreProtocol {
    private let service: String
    init(service: String) { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "supabase-session"]
    }

    func load() throws -> AuthSession? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecureStorageError(status: status) }
        do { return try JSONDecoder().decode(AuthSession.self, from: data) }
        catch {
            // A corrupt or obsolete session must not prevent signing in again.
            try clear()
            throw APIError.sessionExpired
        }
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw SecureStorageError(status: added) }
        } else if status != errSecSuccess { throw SecureStorageError(status: status) }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureStorageError(status: status) }
    }
}
