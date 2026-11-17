import SwiftUI

struct GroupDetailView: View {
    let id: UUID
    let workspace: MessagingWorkspace?
    @StateObject private var model: GroupDetailViewModel
    @Environment(SessionViewModel.self) private var session
    @State private var retry = 0
    init(id: UUID, service: any GroupServiceProtocol, workspace: MessagingWorkspace?) {
        self.id = id; self.workspace = workspace
        _model = StateObject(wrappedValue: GroupDetailViewModel(service: service))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let group = model.listing { detail(group) }
                else if model.isLoading { ProgressView("Loading group…").frame(maxWidth: .infinity) }
                else if let error = model.errorMessage {
                    AccountFeedback(message: error, isError: true)
                    PrimaryButton(title: "Retry") { retry += 1 }
                } else if model.hasLoaded {
                    StateNotice(message: "This group listing is no longer available. Return to Discover for nearby listings.")
                }
            }.padding(DesignTokens.Spacing.pageInset)
        }.background(DesignTokens.Colors.paper).navigationTitle("Group details").navigationBarTitleDisplayMode(.inline)
            .task(id: retry) { await model.load(id: id) }
            .refreshable { await model.load(id: id) }
            .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    @ViewBuilder private func detail(_ group: GroupListing) -> some View {
        VStack(spacing: 14) {
            GroupGlyph(large: true)
            Text(group.name).font(DesignTokens.Typography.groupTitle).multilineTextAlignment(.center).accessibilityIdentifier("groups.name")
            Label(group.areaName, image: "IconPin").font(DesignTokens.Typography.notice)
        }.frame(maxWidth: .infinity).padding(.vertical, 18)
        Text(group.description).font(DesignTokens.Typography.body)
        if let contact = group.contact {
            VStack(alignment: .leading, spacing: 8) {
                Text("Designated contact").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                NavigationLink(value: PublicPlayerRoute(id: contact.id)) {
                    Text(contact.displayName).font(DesignTokens.Typography.control).frame(minHeight: 44)
                }.accessibilityIdentifier("groups.contactProfile")
                Text("Contact for introductions and local play questions.").font(DesignTokens.Typography.notice)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 12))
            if let workspace, contact.id != workspace.ownProfileID {
                NavigationLink(value: contact.conversationRoute) {
                    Text("Message Contact").font(DesignTokens.Typography.control)
                        .frame(maxWidth: .infinity, minHeight: 50).padding(.horizontal, 18)
                        .foregroundStyle(DesignTokens.Colors.paper).background(DesignTokens.Colors.forest, in: .rect(cornerRadius: 12))
                }.accessibilityIdentifier("groups.messageContact")
            }
        } else {
            StateNotice(message: "This group's contact is currently unavailable. Pull down to check again later or choose another listing.")
        }
        if let introduction = group.introduction {
            VStack(alignment: .leading, spacing: 10) {
                Text("Introduction").font(DesignTokens.Typography.eyebrow)
                Text(introduction.text).font(DesignTokens.Typography.notice)
                NavigationLink(value: PublicPlayerRoute(id: introduction.player.id)) {
                    Text("View \(introduction.player.displayName)’s Profile").font(DesignTokens.Typography.control).frame(minHeight: 44)
                }.accessibilityIdentifier("groups.introductionProfile")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 12))
        }
        Text("Groups are listings, not events. ChessOTB does not manage membership, registration, or group chat.")
            .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
    }
}

#if DEBUG
#Preview("Group · unavailable") {
    NavigationStack { GroupDetailView(id: UUID(), service: UnavailableGroupService(), workspace: nil) }
        .environment(SessionViewModel(auth: PreviewAccountService()))
}
#endif

#if DEBUG
private nonisolated struct GroupPreviewService: GroupServiceProtocol {
    enum State: Sendable { case populated, missing, loading, failed }
    let state: State
    func detail(id: UUID) async throws -> GroupListing? {
        switch state {
        case .missing: return nil
        case .loading: try await Task.sleep(for: .seconds(3600)); return nil
        case .failed: throw APIError.unavailable
        case .populated:
            return GroupListing(id: id, name: "Preview chess group", areaName: "New York, NY", description: "A preview of a verified local listing.",
                                contact: GroupPerson(id: UUID(), displayName: "Preview contact"), introduction: nil)
        }
    }
    func search(settings: DiscoverySettings, cursor: String?) async throws -> GroupPage {
        let listing = try await detail(id: UUID())
        return GroupPage(groups: listing.map { [$0] } ?? [], nextCursor: nil)
    }
}
private struct GroupPreview: View {
    let state: GroupPreviewService.State
    var body: some View {
        NavigationStack { GroupDetailView(id: UUID(), service: GroupPreviewService(state: state), workspace: nil) }
            .environment(SessionViewModel(auth: PreviewAccountService()))
    }
}
#Preview("Group · populated") { GroupPreview(state: .populated) }
#Preview("Group · missing, dark") { GroupPreview(state: .missing).preferredColorScheme(.dark) }
#Preview("Group · loading") { GroupPreview(state: .loading) }
#Preview("Group · failed") { GroupPreview(state: .failed) }
#endif
