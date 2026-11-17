import Foundation

/// Exact details preserved through review and retries.
nonisolated struct MeetingProposal: Codable, Equatable, Sendable {
    let startsAt: Date
    let timeZone: String
    let location: String
    let note: String
    var place: MeetingPlace? = nil

    func normalized() throws -> MeetingProposal {
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard startsAt.timeIntervalSince1970.isFinite,
              timeZone == "UTC" || TimeZone.knownTimeZoneIdentifiers.contains(timeZone),
              !place.isEmpty, place.unicodeScalars.count <= 500,
              message.unicodeScalars.count <= 2_000,
              !place.contains("\0"), !message.contains("\0") else { throw APIError.rejected }
        let selected = try self.place?.validated()
        return MeetingProposal(startsAt: startsAt, timeZone: timeZone, location: selected?.summary ?? place, note: message, place: selected)
    }
}
