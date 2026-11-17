import SwiftUI

struct MeetingProposalView: View {
    @ObservedObject var model: ProposalViewModel
    let peerName: String
    let onSent: (Meeting) -> Void
    @Environment(\.dismiss) private var dismiss
    private enum Field: Hashable { case location, note }
    @FocusState private var focusedField: Field?
    @State private var showAddressSearch = false
    @State private var reviewRequest = 0
    @State private var sendRequest = 0
    var body: some View {
        Group {
            if let reviewed = model.reviewed {
                review(reviewed)
            } else {
                form
            }
        }
        .background(DesignTokens.Colors.paper)
        .navigationTitle(model.reviewed == nil ? (model.sourceMeeting == nil ? "Propose a Game" : (model.sourceMeeting?.pendingRevision == nil ? "Propose a Change" : "Edit Change")) : "Review Proposal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(model.isSending) }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } }
        }
        .sheet(isPresented: $showAddressSearch) {
            NavigationStack { MeetingPlaceSearchView { model.selectPlace($0) } }
        }
        .task(id: reviewRequest) {
            guard reviewRequest > 0 else { return }
            // Let the native field finish its editing transaction before freezing review.
            await Task.yield()
            model.review()
        }
        .task(id: sendRequest) { if sendRequest > 0 { await model.send() } }
        .onChange(of: model.sentMeeting) { _, meeting in
            if let meeting { onSent(meeting); dismiss() }
        }
        .interactiveDismissDisabled(model.isSending)
    }
    private var form: some View {
        Form {
            Section {
                Text("Chess with \(peerName)").font(DesignTokens.Typography.sectionTitle)
                DatePicker("Date and time", selection: $model.startsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, TimeZone(identifier: model.timeZone) ?? .current).accessibilityIdentifier("meeting.date")
                Picker("Time zone", selection: $model.timeZone) {
                    ForEach(Array(Set(TimeZone.knownTimeZoneIdentifiers + ["UTC"])).sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("meeting.timeZone")
            }
            Section("Meeting location") {
                if let place = model.place {
                    Text(place.name).font(DesignTokens.Typography.control)
                    Text(place.address).font(DesignTokens.Typography.field).textSelection(.enabled)
                    if let url = place.mapsURL { Link("Open in Apple Maps", destination: url).frame(minHeight: 44) }
                } else if !model.location.isEmpty {
                    Text(model.location).font(DesignTokens.Typography.field)
                    Text("This older location needs an exact address. Search and select it below.")
                        .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                }
                Button { focusedField = nil; showAddressSearch = true } label: {
                    Label(model.place == nil ? "Search for an address" : "Change meeting address", systemImage: "magnifyingglass")
                        .frame(minHeight: 44)
                }.accessibilityIdentifier("meeting.location")
            }
            Section("Optional note") {
                TextField("Entrance, floor, what to bring…", text: $model.note, axis: .vertical)
                    .focused($focusedField, equals: .note).accessibilityIdentifier("meeting.note")
            }
            if let error = model.errorMessage { Section { AccountFeedback(message: error, isError: true) } }
            Section {
                PrimaryButton(title: "Review Proposal") { focusedField = nil; reviewRequest += 1 }
                    .disabled(!model.canReview).accessibilityIdentifier("meeting.review")
            }.listRowBackground(Color.clear)
        }.scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)
    }
    private func review(_ reviewed: ReviewedProposal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Chess with \(peerName)").font(DesignTokens.Typography.playerTitle)
                MeetingFactsView(revision: MeetingRevision(id: reviewed.requestID, meetingID: model.sourceMeeting?.id ?? reviewed.requestID,
                                                          startsAt: reviewed.proposal.startsAt, timeZone: reviewed.proposal.timeZone,
                                                          location: reviewed.proposal.location, note: reviewed.proposal.note, place: reviewed.proposal.place))
                StateNotice(message: "Sending proposes these details. The other player must accept before they become agreed.")
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isSending { ProgressView("Sending proposal…") }
                PrimaryButton(title: reviewed.attempted ? "Retry sending proposal" : "Send Proposal") { sendRequest += 1 }
                    .disabled(model.isSending).accessibilityIdentifier("meeting.send")
                PrimaryButton(title: "Edit details", kind: .secondary) { model.edit() }
                    .disabled(!model.canEdit).accessibilityIdentifier("meeting.edit")
                if reviewed.attempted {
                    Text("The send may have succeeded. Retry to check its status before editing.")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                }
            }.padding(22)
        }
    }
}
