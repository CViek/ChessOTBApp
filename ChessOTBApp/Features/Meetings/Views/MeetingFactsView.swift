import SwiftUI

struct MeetingFactsView: View {
    let revision: MeetingRevision
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(revision.formattedTime).font(DesignTokens.Typography.sectionTitle)
            Text(revision.timeZone).font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.avatarInk.opacity(0.8))
            Label { Text(revision.location).textSelection(.enabled) } icon: { Image("IconPin") }
            if !revision.note.isEmpty { Text(revision.note).font(DesignTokens.Typography.field).textSelection(.enabled) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .foregroundStyle(DesignTokens.Colors.avatarInk)
        .background(DesignTokens.Colors.notationPaper, in: .rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(DesignTokens.Colors.reviewBorder, lineWidth: 1) }
    }
}
