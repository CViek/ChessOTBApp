import Foundation

/// Public identity only. Supabase auth user IDs and email addresses never appear here.
nonisolated struct PlayerProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String

    static func validatedName(_ value: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(name.unicodeScalars.count),
              name.rangeOfCharacter(from: .controlCharacters) == nil else { throw AccountError.invalidName }
        return name
    }

    var initials: String {
        displayName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

nonisolated protocol ProfileServiceProtocol: Sendable {
    func loadOwnProfile() async throws -> PlayerProfile?
    func saveDisplayName(_ name: String) async throws -> PlayerProfile
    func publicProfile(id: UUID) async throws -> PlayerProfile?
}
