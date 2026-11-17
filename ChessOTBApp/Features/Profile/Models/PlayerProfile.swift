import Foundation

/// Public identity only. Supabase auth user IDs and email addresses never appear here.
nonisolated struct PlayerProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    var areaName: String? = nil
    var rating: RatingEntry? = nil

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
    func saveProfile(displayName: String, rating: RatingEntry?) async throws -> PlayerProfile
    func loadOwnProfile() async throws -> PlayerProfile?
    func saveDisplayName(_ name: String) async throws -> PlayerProfile
    func publicProfile(id: UUID) async throws -> PlayerProfile?
    func loadArea() async throws -> ApproximateArea?
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) async throws -> PlayerProfile
}

extension ProfileServiceProtocol {
    func saveProfile(displayName: String, rating: RatingEntry?) async throws -> PlayerProfile {
        guard rating == nil else { throw APIError.unavailable }
        return try await saveDisplayName(displayName)
    }
}
