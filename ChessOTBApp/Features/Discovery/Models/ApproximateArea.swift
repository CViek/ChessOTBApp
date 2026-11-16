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

nonisolated enum SearchRadius: Int, Codable, CaseIterable, Sendable {
    case three = 3, five = 5, ten = 10
}

nonisolated struct DiscoverySettings: Codable, Hashable, Sendable {
    let area: ApproximateArea
    let radius: SearchRadius
}

nonisolated struct NearbyPlayer: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let areaName: String
    let distanceMiles: Int

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
