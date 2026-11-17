import Foundation

nonisolated struct MeetingCalendarDay: Identifiable {
    let id: Int
    let date: Date?
    let meetings: [Meeting]
    var hasAwaiting: Bool { meetings.contains { $0.status == .pending } }
    var hasConfirmed: Bool { meetings.contains { $0.status == .confirmed } }
}

nonisolated struct MeetingCalendarMonth {
    let date: Date
    let meetings: [Meeting]
    let now: Date
    var calendar: Calendar = .current

    var days: [MeetingCalendarDay] {
        guard let start = calendar.dateInterval(of: .month, for: date)?.start,
              let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let upcoming = meetings.filter { !$0.isHistory(at: now) }.sorted { $0.revision.startsAt < $1.revision.startsAt }
        let grouped = Dictionary(grouping: upcoming) { calendar.startOfDay(for: $0.revision.startsAt) }
        let count = ((offset + range.count + 6) / 7) * 7
        return (0..<count).map { index in
            guard index >= offset, index < offset + range.count,
                  let day = calendar.date(byAdding: .day, value: index - offset, to: start) else {
                return MeetingCalendarDay(id: index, date: nil, meetings: [])
            }
            return MeetingCalendarDay(id: index, date: day, meetings: grouped[calendar.startOfDay(for: day)] ?? [])
        }
    }
}
