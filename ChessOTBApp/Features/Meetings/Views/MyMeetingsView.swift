import SwiftUI

struct MyMeetingsView: View {
    @StateObject private var model: MyMeetingsViewModel
    let ownProfileID: UUID
    let workspace: MessagingWorkspace
    @Environment(\.scenePhase) private var scenePhase
    @State private var showNewMeeting = false
    @State private var sentRoute: MeetingRoute?
    @State private var sentRequest = 0
    @State private var section: MeetingListSection = .awaiting
    @State private var calendarView = false
    private struct SelectedCalendarDay: Identifiable {
        let id = UUID()
        let date: Date
        let meetings: [Meeting]
    }
    @State private var selectedCalendarDay: SelectedCalendarDay?
    @State private var calendarRoute: MeetingRoute?
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
                    Picker("Meeting view", selection: $calendarView) {
                        Label("List", systemImage: "list.bullet").tag(false)
                        Label("Calendar", systemImage: "calendar").tag(true)
                    }.pickerStyle(.segmented).frame(minHeight: 44)
                        .accessibilityIdentifier("meetings.viewMode")
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    if model.isLoading { ProgressView("Loading meetings…") }
                    if calendarView {
                        MeetingCalendarView(meetings: model.meetings, now: context.date) { date, meetings in
                            if meetings.count == 1, let meeting = meetings.first {
                                sentRoute = MeetingRoute(id: meeting.id)
                            } else if !meetings.isEmpty {
                                selectedCalendarDay = SelectedCalendarDay(date: date, meetings: meetings)
                            }
                        }
                    } else {
                        Picker("Meeting status", selection: $section) {
                            Text("Awaiting").tag(MeetingListSection.awaiting)
                            Text("Confirmed").tag(MeetingListSection.confirmed)
                        }.pickerStyle(.segmented).frame(minHeight: 44)
                            .accessibilityIdentifier("meetings.statusFilter")
                        let rows = model.visible(section: section, at: context.date)
                        if rows.isEmpty && !model.isLoading { emptyState }
                        ForEach(rows) { meeting in
                            NavigationLink(value: MeetingRoute(id: meeting.id)) { card(meeting) }
                                .buttonStyle(.plain).accessibilityIdentifier("meeting.row.\(meeting.id.uuidString.lowercased())")
                        }
                        if model.nextCursor != nil {
                            PrimaryButton(title: "Load more meetings", kind: .secondary) { moreRequest += 1 }.disabled(model.isLoading)
                        }
                    }
                }.padding(22)
            }.clipped()
        }
        .background(DesignTokens.Colors.paper).navigationTitle("Meetings").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if workspace.friends != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewMeeting = true } label: { Label("Propose a Game", systemImage: "plus") }
                        .accessibilityIdentifier("meetings.new")
                }
            }
        }
        .sheet(isPresented: $showNewMeeting) {
            if let friends = workspace.friends {
                NavigationStack {
                    NewMeetingView(friends: friends, workspace: workspace) { meeting in
                        showNewMeeting = false; sentRoute = MeetingRoute(id: meeting.id); sentRequest += 1
                    }
                }
            }
        }
        .navigationDestination(item: $sentRoute) { route in
            if let detail = workspace.detail(id: route.id) { MeetingDetailView(model: detail, workspace: workspace) }
        }
        .sheet(item: $selectedCalendarDay, onDismiss: {
            if let calendarRoute { sentRoute = calendarRoute; self.calendarRoute = nil }
        }) { day in
            NavigationStack {
                List(day.meetings) { meeting in
                    Button {
                        calendarRoute = MeetingRoute(id: meeting.id)
                        selectedCalendarDay = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(meeting.peerName(ownProfileID: ownProfileID)).font(DesignTokens.Typography.control)
                            Text(meeting.revision.formattedTime).font(DesignTokens.Typography.notice)
                            Text(meeting.statusTitle).font(DesignTokens.Typography.caption)
                        }.padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                }
                .navigationTitle(day.date.formatted(date: .abbreviated, time: .omitted))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { selectedCalendarDay = nil } } }
            }.presentationDetents([.medium, .large])
        }
        .task(id: calendarView) {
            guard calendarView else { return }
            await model.refresh()
            await loadCalendarPages()
        }
        .task(id: sentRequest) { if sentRequest > 0 { await model.refresh() } }
        .refreshable { await model.refresh(); if calendarView { await loadCalendarPages() } }
        .task(id: active) {
            guard active else { return }
            repeat {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            } while !Task.isCancelled
        }
        .task(id: moreRequest) { if moreRequest > 0 { await model.loadMore() } }
    }
    private func loadCalendarPages() async {
        while !Task.isCancelled, workspace.cache.isActive, let cursor = model.nextCursor {
            await model.loadMore()
            if model.nextCursor == cursor { break }
        }
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section == .awaiting ? "No invitations awaiting agreement" : "No confirmed meetings")
                .font(DesignTokens.Typography.statusTitle)
            Text("Tap + to propose a game with a friend, or start from a conversation. Both players must agree to confirm it.")
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
