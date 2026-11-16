import Foundation

/// The reviewed payload. Date/past-answer policy is a separate entrance decision;
/// these structural checks do not imply that a particular date is schedulable.
nonisolated struct MeetingProposal: Equatable, Sendable {
    let startsAt: Date
    let timeZone: String
    let location: String
    let note: String

    func normalized() throws -> MeetingProposal {
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard startsAt.timeIntervalSince1970.isFinite,
              timeZone == "UTC" || TimeZone.knownTimeZoneIdentifiers.contains(timeZone),
              !place.isEmpty, place.unicodeScalars.count <= 500,
              message.unicodeScalars.count <= 2_000,
              !place.contains("\0"), !message.contains("\0") else { throw APIError.rejected }
        return MeetingProposal(startsAt: startsAt, timeZone: timeZone, location: place, note: message)
    }
}
