import SwiftUI

struct MyMeetingsView: View {
    @StateObject private var model: MyMeetingsViewModel
    let ownProfileID: UUID
    let workspace: MessagingWorkspace
    @Environment(\.scenePhase) private var scenePhase
    @State private var history = false
    @State private var moreRequest = 0
    private var active: Bool { scenePhase == .active && workspace.cache.isActive }
    init(model: MyMeetingsViewModel, ownProfileID: UUID, workspace: MessagingWorkspace) {
        _model = StateObject(wrappedValue: model); self.ownProfileID = ownProfileID; self.workspace = workspace
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Text("My Meetings").font(DesignTokens.Typography.listTitle).fixedSize(horizontal: false, vertical: true)
                    Picker("Meetings", selection: $history) { Text("Upcoming").tag(false); Text("History").tag(true) }
                        .pickerStyle(.segmented).frame(minHeight: 44)
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    if model.isLoading { ProgressView("Loading meetings…") }
                    let rows = model.visible(history: history, at: context.date)
                    if rows.isEmpty && !model.isLoading { emptyState }
                    ForEach(rows) { meeting in
                        NavigationLink(value: MeetingRoute(id: meeting.id)) { card(meeting) }
                            .buttonStyle(.plain).accessibilityIdentifier("meeting.row.\(meeting.id.uuidString.lowercased())")
                    }
                    if model.nextCursor != nil {
                        PrimaryButton(title: "Load more meetings", kind: .secondary) { moreRequest += 1 }.disabled(model.isLoading)
                    }
                }.padding(22)
            }
        }
        .background(DesignTokens.Colors.paper).navigationTitle("Meetings").navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .task(id: active) {
            guard active else { return }
            repeat {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
        .task(id: moreRequest) { if moreRequest > 0 { await model.loadMore() } }
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(history ? "No meeting history" : "No upcoming meetings").font(DesignTokens.Typography.statusTitle)
            Text(history ? "Past, declined and cancelled arrangements appear here. Past meetings do not imply a game was played." : "Propose a game from a conversation. Both players must agree to confirm it.")
                .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
        }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 24)
    }
    private func card(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meeting.statusTitle).font(DesignTokens.Typography.eyebrow)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
            Text("Chess with \(meeting.peerName(ownProfileID: ownProfileID))").font(DesignTokens.Typography.sectionTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text(meeting.revision.formattedTime).font(DesignTokens.Typography.field).fixedSize(horizontal: false, vertical: true)
            Text(meeting.revision.location).font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.lineLimit(nil).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(DesignTokens.Colors.line, lineWidth: 1) }
    }
}
