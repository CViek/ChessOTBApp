import Foundation

/// Public identity only. Supabase auth user IDs and email addresses never appear here.
nonisolated struct PlayerProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    var areaName: String? = nil
    var ratings: [RatingEntry]
    var rating: RatingEntry? { ratings.first }

    init(id: UUID, displayName: String, areaName: String? = nil, rating: RatingEntry? = nil, ratings: [RatingEntry]? = nil) {
        self.id = id
        self.displayName = displayName
        self.areaName = areaName
        self.ratings = ratings ?? rating.map { [$0] } ?? []
    }

    private enum CodingKeys: String, CodingKey { case id, displayName, areaName, rating, ratings }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        displayName = try values.decode(String.self, forKey: .displayName)
        areaName = try values.decodeIfPresent(String.self, forKey: .areaName)
        ratings = try values.decodeIfPresent([RatingEntry].self, forKey: .ratings)
            ?? values.decodeIfPresent(RatingEntry.self, forKey: .rating).map { [$0] } ?? []
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(displayName, forKey: .displayName)
        try values.encodeIfPresent(areaName, forKey: .areaName)
        if !ratings.isEmpty { try values.encode(ratings, forKey: .ratings) }
    }

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
    func saveProfile(displayName: String, ratings: [RatingEntry]) async throws -> PlayerProfile
    func saveProfile(displayName: String, rating: RatingEntry?) async throws -> PlayerProfile
    func loadOwnProfile() async throws -> PlayerProfile?
    func saveDisplayName(_ name: String) async throws -> PlayerProfile
    func publicProfile(id: UUID) async throws -> PlayerProfile?
    func loadArea() async throws -> ApproximateArea?
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) async throws -> PlayerProfile
}

extension ProfileServiceProtocol {
    func saveProfile(displayName: String, ratings: [RatingEntry]) async throws -> PlayerProfile {
        guard ratings.count <= 1 else { throw APIError.unavailable }
        return try await saveProfile(displayName: displayName, rating: ratings.first)
    }
    func saveProfile(displayName: String, rating: RatingEntry?) async throws -> PlayerProfile {
        guard rating == nil else { throw APIError.unavailable }
        return try await saveDisplayName(displayName)
    }
}
