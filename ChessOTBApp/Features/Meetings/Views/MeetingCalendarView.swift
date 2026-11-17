import SwiftUI

struct MeetingCalendarView: View {
    let meetings: [Meeting]
    let now: Date
    let onSelect: (Date, [Meeting]) -> Void
    @State private var displayedMonth = Date.now
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Previous month")
                Spacer(minLength: 4)
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(DesignTokens.Typography.sectionTitle).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }.accessibilityLabel("Next month")
            }.buttonStyle(.plain)
            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(0..<7, id: \.self) { index in
                    let weekday = (calendar.firstWeekday - 1 + index) % 7
                    Text(calendar.shortStandaloneWeekdaySymbols[weekday])
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                        .lineLimit(1).minimumScaleFactor(0.6).accessibilityHidden(true)
                }
                ForEach(MeetingCalendarMonth(date: displayedMonth, meetings: meetings, now: now).days) { day in
                    if let date = day.date {
                        Button { onSelect(date, day.meetings) } label: {
                            Text(date, format: .dateTime.day())
                                .font(.body.weight(day.meetings.isEmpty ? .regular : .bold))
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(DesignTokens.Colors.ink)
                                .background { highlight(day) }
                                .contentShape(.rect)
                        }.buttonStyle(.plain).disabled(day.meetings.isEmpty)
                            .accessibilityLabel(dayDescription(day, date: date))
                            .accessibilityHint(day.meetings.isEmpty ? "" : "Open meeting details")
                            .accessibilityIdentifier("meetings.calendar.day.\(calendar.component(.day, from: date))")
                    } else {
                        Color.clear.frame(height: 48).accessibilityHidden(true)
                    }
                }
            }
        }.padding(14)
            .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
            .accessibilityIdentifier("meetings.calendar")
    }
    @ViewBuilder private func highlight(_ day: MeetingCalendarDay) -> some View {
        if day.hasAwaiting || day.hasConfirmed {
            HStack(spacing: 0) {
                if day.hasAwaiting { Color.orange.opacity(0.38) }
                if day.hasConfirmed { Color.blue.opacity(0.38) }
            }.clipShape(.rect(cornerRadius: 8))
        }
    }
    private func moveMonth(_ offset: Int) {
        guard let first = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
              let next = calendar.date(byAdding: .month, value: offset, to: first) else { return }
        displayedMonth = next
    }
    private func dayDescription(_ day: MeetingCalendarDay, date: Date) -> String {
        let label = date.formatted(date: .complete, time: .omitted)
        if day.hasAwaiting && day.hasConfirmed { return String(localized: "\(label), awaiting and confirmed meetings") }
        if day.hasAwaiting { return String(localized: "\(label), awaiting agreement") }
        if day.hasConfirmed { return String(localized: "\(label), confirmed meetings") }
        return label
    }
}

#if DEBUG
#Preview("Month calendar") { MeetingCalendarView(meetings: [], now: .now) { _, _ in }.padding() }
#endif
