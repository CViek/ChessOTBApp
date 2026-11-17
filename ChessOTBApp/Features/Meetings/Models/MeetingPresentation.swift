import Foundation

nonisolated struct MeetingRoute: Hashable, Sendable { let id: UUID }

extension Meeting {
    var statusTitle: String {
        if pendingRevision != nil && status == .confirmed { return String(localized: "Change awaiting agreement") }
        switch status {
        case .pending: return String(localized: "Awaiting agreement")
        case .confirmed: return String(localized: "Confirmed")
        case .declined: return String(localized: "Declined")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
    var statusExplanation: String {
        if pendingRevision != nil && status == .confirmed { return String(localized: "The agreed plan stays confirmed until the other player accepts the new details.") }
        switch status {
        case .pending: return String(localized: "Only the recipient can accept. Discussion alone does not confirm a meeting.")
        case .confirmed: return String(localized: "Both players agreed to this time and place.")
        case .declined: return String(localized: "This proposal was declined. Discuss another option in your conversation.")
        case .cancelled: return String(localized: "This cancellation is visible to both players.")
        }
    }
}

extension MeetingRevision {
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZone)
        formatter.dateStyle = .full; formatter.timeStyle = .short
        return formatter.string(from: startsAt)
    }
}
