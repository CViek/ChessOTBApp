import SwiftUI

struct ConversationView: View {
    let route: ConversationRoute
    let workspace: MessagingWorkspace
    @StateObject private var model: ConversationViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionViewModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composing: Bool
    @State private var action: Action?
    @State private var showProposal = false
    @State private var sentRoute: MeetingRoute?
    private enum Action: Equatable { case send(UUID), retry(UUID), older(UUID) }
    private var active: Bool { scenePhase == .active && !session.isSigningOut && workspace.cache.isActive }
    init(route: ConversationRoute, workspace: MessagingWorkspace) {
        self.route = route; self.workspace = workspace
        _model = StateObject(wrappedValue: workspace.conversation(peerID: route.peerID))
    }
    var body: some View {
        history
            .background(DesignTokens.Colors.paper).navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .sheet(isPresented: $showProposal) {
                if let id = model.conversationID, let proposal = workspace.proposal(conversationID: id, meeting: nil) {
                    NavigationStack { MeetingProposalView(model: proposal, peerName: route.displayName) { sentRoute = MeetingRoute(id: $0.id) } }
                }
            }
            .navigationDestination(item: $sentRoute) { route in
                if let detail = workspace.detail(id: route.id) { MeetingDetailView(model: detail, workspace: workspace) }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavigationLink(value: PublicPlayerRoute(id: route.peerID)) {
                        HStack(spacing: 8) {
                            InitialsAvatar(initials: route.initials, size: .small)
                            Text(route.displayName).font(DesignTokens.Typography.eyebrow)
                        }.frame(minHeight: 44)
                    }.accessibilityLabel("View \(route.displayName)'s profile").accessibilityIdentifier("chat.peerProfile")
                }
                if composing {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer(); Button("Done") { composing = false }.accessibilityIdentifier("chat.done")
                    }
                }
            }
            .task(id: active) {
                guard active else { return }
                repeat {
                    await model.refresh()
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                } while !Task.isCancelled
            }
            .task(id: action) {
                guard let request = action else { return }
                switch request {
                case .send: await model.sendDraft()
                case .retry(let id): await model.retry(id)
                case .older: await model.loadMore()
                }
                if action == request { action = nil }
            }
    }
    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if workspace.meetingService != nil {
                        PrimaryButton(title: "Propose a Game", kind: .secondary) { showProposal = true }
                            .disabled(model.conversationID == nil).accessibilityIdentifier("meeting.propose")
                    }
                    StateNotice(message: "Discussion doesn't confirm a meeting. Agree on the details together.")
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    if model.isLoading { ProgressView("Loading messages…") }
                    if model.nextCursor != nil {
                        PrimaryButton(title: "Load older messages", kind: .quiet) { action = .older(UUID()) }.disabled(model.isLoadingMore)
                    }
                    ForEach(model.messages) { message in
                        if let meetingID = message.meetingID {
                            NavigationLink(value: MeetingRoute(id: meetingID)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message.body).font(DesignTokens.Typography.eyebrow)
                                    Text("View meeting details").font(DesignTokens.Typography.caption)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(DesignTokens.Colors.avatarInk)
                                    .background(DesignTokens.Colors.notationPaper, in: .rect(cornerRadius: 3))
                                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(DesignTokens.Colors.slipBorder, lineWidth: 1) }
                            }.buttonStyle(.plain).id(message.id).accessibilityIdentifier("chat.meeting.\(meetingID.uuidString.lowercased())")
                        } else {
                            MessageBubble(bodyText: message.body, mine: message.senderID == workspace.ownProfileID).id(message.id)
                        }
                    }
                    ForEach(model.outgoing) { outgoing in
                        VStack(alignment: .trailing, spacing: 4) {
                            MessageBubble(bodyText: outgoing.body, mine: true)
                            if outgoing.failed {
                                Button("Not sent. Retry") { action = .retry(outgoing.id) }
                                    .frame(minHeight: 44).accessibilityIdentifier("chat.retry.\(outgoing.id.uuidString)")
                            } else { Text("Sending…").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted) }
                        }.id(outgoing.id)
                    }
                    if !model.isLoading && model.messages.isEmpty && model.outgoing.isEmpty {
                        Text("Start your conversation here.").font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                    }
                }.padding(22)
            }
            .defaultScrollAnchor(.bottom).scrollDismissesKeyboard(.interactively)
            .refreshable { await model.refresh() }
            .onChange(of: model.messages.last?.id) { _, id in
                if let id { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $model.draft, axis: .vertical)
                .font(DesignTokens.Typography.field).lineLimit(1...6).focused($composing)
                .padding(12).background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
                .accessibilityIdentifier("chat.draft")
            Button { action = .send(UUID()) } label: {
                Image("IconSend").frame(width: 44, height: 44)
                    .foregroundStyle(DesignTokens.Colors.paper).background(DesignTokens.Colors.forest, in: .circle)
            }.accessibilityLabel("Send message").accessibilityIdentifier("chat.send").disabled(!model.canSend)
        }.padding(.horizontal, 16).padding(.vertical, 10)
            .background(DesignTokens.Colors.paper).overlay(alignment: .top) { Divider() }
            .disabled(!workspace.cache.isActive || session.isSigningOut)
    }
}

struct MessageBubble: View {
    let bodyText: String
    let mine: Bool
    var body: some View {
        HStack {
            if mine { Spacer(minLength: 32) }
            Text(bodyText).font(DesignTokens.Typography.field).textSelection(.enabled).padding(14)
                .foregroundStyle(mine ? DesignTokens.Colors.paper : DesignTokens.Colors.ink)
                .background(mine ? DesignTokens.Colors.forest : DesignTokens.Colors.surface,
                            in: .rect(topLeadingRadius: 14, bottomLeadingRadius: mine ? 14 : 4,
                                      bottomTrailingRadius: mine ? 4 : 14, topTrailingRadius: 14))
            if !mine { Spacer(minLength: 32) }
        }
    }
}
