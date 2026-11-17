import Foundation

/// Coordinates describe a chosen named area and belong only in the owner's settings.
nonisolated struct ApproximateArea: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let countryCode: String
    var id: String { "\(name)|\(latitude)|\(longitude)" }

    func validated() throws -> ApproximateArea {
        guard countryCode == "US" else { throw AreaError.outsideUS }
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...120).contains(label.unicodeScalars.count), label.rangeOfCharacter(from: .controlCharacters) == nil,
              latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { throw AreaError.invalidArea }
        return ApproximateArea(name: label, latitude: (latitude * 100).rounded() / 100,
                               longitude: (longitude * 100).rounded() / 100, countryCode: "US")
    }
}

/// A whole-mile radius; old saved numeric values remain compatible.
nonisolated struct SearchRadius: RawRepresentable, Codable, Hashable, Sendable {
    static let allowedRange = 1...100
    let rawValue: Int
    init?(rawValue: Int) {
        guard Self.allowedRange.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }
    private init(knownValue: Int) { rawValue = knownValue }
    static let three = Self(knownValue: 3)
    static let five = Self(knownValue: 5)
    static let ten = Self(knownValue: 10)
    var widened: SearchRadius? {
        guard rawValue < Self.allowedRange.upperBound else { return nil }
        return Self(rawValue: min(Self.allowedRange.upperBound, rawValue * 2))
    }
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard let radius = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Distance must be 1–100 whole miles")
        }
        self = radius
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct DiscoverySettings: Codable, Hashable, Sendable {
    let area: ApproximateArea
    let radius: SearchRadius
    var rating: RatingCriteria? = nil
}

nonisolated struct NearbyPlayer: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let areaName: String
    let distanceMiles: Int
    var rating: RatingEntry? = nil
    var ratings: [RatingEntry]? = nil

    var distanceDescription: String {
        if distanceMiles < 1 { return String(localized: "Less than 1 mile") }
        if distanceMiles == 1 { return String(localized: "About 1 mile") }
        return String(localized: "About \(distanceMiles) miles")
    }
    var initials: String {
        displayName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

nonisolated struct PlayerPage: Codable, Sendable {
    let players: [NearbyPlayer]
    let nextCursor: String?
}

nonisolated enum AreaError: LocalizedError, Equatable {
    case invalidQuery, invalidArea, outsideUS, noResults, permissionDenied, locationUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidQuery: String(localized: "Enter a US city or neighborhood.")
        case .invalidArea: String(localized: "Choose a valid area from the search results.")
        case .outsideUS: String(localized: "Search currently supports US areas only.")
        case .noResults: String(localized: "No matching areas found. Add a city or state and try again.")
        case .permissionDenied: String(localized: "Location access is off. Manual search works just as well.")
        case .locationUnavailable: String(localized: "Could not find your area. Try again or enter it manually.")
        }
    }
}
