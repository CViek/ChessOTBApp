import SwiftUI

struct MeetingFactsView: View {
    let revision: MeetingRevision
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Date and time", systemImage: "calendar").font(DesignTokens.Typography.eyebrow)
                    .foregroundStyle(DesignTokens.Colors.muted)
                Text(revision.formattedTime).font(DesignTokens.Typography.body)
                Text(revision.timeZone.replacingOccurrences(of: "_", with: " ")).font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.muted)
            }
            Divider()
            MeetingLocationView(location: revision.location, place: revision.place)
            if !revision.note.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meeting note").font(DesignTokens.Typography.eyebrow).foregroundStyle(DesignTokens.Colors.muted)
                    Text(revision.note).font(DesignTokens.Typography.body).textSelection(.enabled)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .foregroundStyle(DesignTokens.Colors.ink)
        .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
    }
}

struct MeetingLocationView: View {
    let location: String
    let place: MeetingPlace?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Meeting location", image: "IconPin").font(DesignTokens.Typography.eyebrow)
                .foregroundStyle(DesignTokens.Colors.muted)
            if let place {
                Text(place.name).font(DesignTokens.Typography.control).textSelection(.enabled)
                Text(place.address).font(DesignTokens.Typography.body).textSelection(.enabled)
                if let url = place.mapsURL {
                    Link(destination: url) { Label("Open in Apple Maps", systemImage: "map").frame(minHeight: 44) }
                        .font(DesignTokens.Typography.control).accessibilityIdentifier("meeting.openMaps")
                }
            } else {
                Text(location).font(DesignTokens.Typography.body).textSelection(.enabled)
                Text("No exact address was selected for this older proposal.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
#Preview("Meeting facts · dark") {
    MeetingFactsView(revision: MeetingRevision(id: UUID(), meetingID: UUID(), startsAt: .now, timeZone: "America/New_York", location: "Library", note: "Upstairs, near the entrance.", place: MeetingPlace(name: "Central Library", address: "476 5th Ave, New York, NY 10018", latitude: 40.7532, longitude: -73.9822)))
        .padding().background(DesignTokens.Colors.paper).preferredColorScheme(.dark)
}
#endif
