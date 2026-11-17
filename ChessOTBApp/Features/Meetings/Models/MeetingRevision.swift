import Foundation

nonisolated struct MeetingRevision: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let meetingID: UUID
    let startsAt: Date
    let timeZone: String
    let location: String
    let note: String
    var place: MeetingPlace? = nil

    enum CodingKeys: String, CodingKey {
        case id, meetingID = "meetingId", startsAt, timeZone, location, note, place
    }

    init(id: UUID, meetingID: UUID, startsAt: Date, timeZone: String, location: String, note: String, place: MeetingPlace? = nil) {
        self.id = id; self.meetingID = meetingID; self.startsAt = startsAt; self.timeZone = timeZone; self.location = location; self.note = note; self.place = place
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        meetingID = try values.decode(UUID.self, forKey: .meetingID)
        startsAt = try MeetingTimestamp.decode(values.decode(String.self, forKey: .startsAt))
        timeZone = try values.decode(String.self, forKey: .timeZone)
        location = try values.decode(String.self, forKey: .location)
        note = try values.decode(String.self, forKey: .note)
        place = try values.decodeIfPresent(MeetingPlace.self, forKey: .place)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(meetingID, forKey: .meetingID)
        try values.encode(MeetingTimestamp.encode(startsAt), forKey: .startsAt)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(location, forKey: .location)
        try values.encode(note, forKey: .note)
        try values.encodeIfPresent(place, forKey: .place)
    }
}

nonisolated enum MeetingTimestamp {
    static func decode(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw APIError.invalidResponse }
        return date
    }

    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
