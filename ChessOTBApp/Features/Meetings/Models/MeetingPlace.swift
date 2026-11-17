import Foundation

/// A selected venue/address, preserved with the reviewed revision rather than re-geocoded later.
nonisolated struct MeetingPlace: Codable, Equatable, Hashable, Identifiable, Sendable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var id: String { "\(latitude),\(longitude)|\(address)|\(name)" }
    var summary: String { name == address ? address : "\(name)\n\(address)" }
    func validated() throws -> MeetingPlace {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let street = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...200).contains(label.count), (1...500).contains(street.count),
              label.rangeOfCharacter(from: .controlCharacters) == nil,
              street.rangeOfCharacter(from: .controlCharacters) == nil,
              latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { throw APIError.rejected }
        return MeetingPlace(name: label, address: street, latitude: latitude, longitude: longitude)
    }
    var mapsURL: URL? {
        guard (try? validated()) != nil else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"), URLQueryItem(name: "q", value: name)]
        return components?.url
    }
}

nonisolated struct MeetingChanges {
    let timeChanged: Bool
    let locationChanged: Bool
    let noteChanged: Bool
    var isEmpty: Bool { !timeChanged && !locationChanged && !noteChanged }
    init(agreed: MeetingRevision, proposed: MeetingRevision) {
        timeChanged = agreed.startsAt != proposed.startsAt || agreed.timeZone != proposed.timeZone
        locationChanged = agreed.place != proposed.place || (agreed.place == nil && agreed.location != proposed.location)
        noteChanged = agreed.note != proposed.note
    }
}
