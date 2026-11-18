import SwiftUI

struct NearbyPlayersView: View {
    @StateObject private var model: DiscoveryViewModel
    @StateObject private var groups: GroupsViewModel
    @State private var mode: Mode = .players
    private enum Mode: Hashable { case players, groups }
    private struct ReloadKey: Hashable { let mode: Mode; let retry: Int }
    private struct GroupSearchKey: Hashable {
        let mode: Mode
        let settings: DiscoverySettings?
        let retry: Int
    }
    @Environment(SessionViewModel.self) private var session
    @State private var showArea = false
    @State private var showFilters = false
    @State private var pendingAction: PendingAction?
    private enum PendingAction: Equatable {
        case search(UUID, DiscoverySettings)
        case more(UUID)
    }
    @State private var retryRequest = 0
    let workspace: MessagingWorkspace?
    let profiles: any ProfileServiceProtocol
    let areas: any AreaServiceProtocol

    init(service: any DiscoveryServiceProtocol, profiles: any ProfileServiceProtocol, areas: any AreaServiceProtocol, workspace: MessagingWorkspace? = nil, groups: any GroupServiceProtocol = UnavailableGroupService()) {
        _groups = StateObject(wrappedValue: GroupsViewModel(service: groups))
        self.workspace = workspace
        _model = StateObject(wrappedValue: DiscoveryViewModel(service: service))
        self.profiles = profiles; self.areas = areas
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("ChessOTB").font(DesignTokens.Typography.eyebrow).foregroundStyle(DesignTokens.Colors.forest)
                Text(mode == .players ? "Nearby Players" : "Nearby Groups").font(DesignTokens.Typography.listTitle).accessibilityAddTraits(.isHeader)
                Picker("Discover", selection: $mode) {
                    Text("Players").tag(Mode.players)
                    Text("Groups").tag(Mode.groups)
                }.pickerStyle(.segmented).accessibilityIdentifier("discovery.segment")
                controls
                if mode == .players, let rating = model.settings?.rating {
                    Text(rating.summary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.muted)
                }
                if mode == .groups, model.settings != nil {
                    NearbyGroupsView(model: groups, retry: { retryRequest += 1 })
                }
                if let error = model.errorMessage {
                    AccountFeedback(message: error, isError: true)
                    PrimaryButton(title: "Retry", kind: .secondary) { retryRequest += 1 }.accessibilityIdentifier("discovery.retry")
                }
                if mode == .groups, model.settings == nil, model.errorMessage == nil {
                    if model.isLoading { ProgressView("Loading search area…") }
                }
                if mode == .players {
                    if model.isLoading { skeleton }
                    else if model.players.isEmpty, model.errorMessage == nil { empty }
                    else { playerRows }
                }
            }.padding(DesignTokens.Spacing.pageInset)
        }
        .background(DesignTokens.Colors.paper)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: GroupRoute.self) { route in
            GroupDetailView(id: route.id, service: groups.service, workspace: workspace)
        }
        .navigationDestination(for: NearbyPlayer.self) { player in
            PlayerProfileView(id: player.id, distanceDescription: player.distanceDescription, service: profiles, workspace: workspace)
        }
        .sheet(isPresented: $showArea) {
            NavigationStack {
                SearchAreaView(purpose: .search, areas: areas, profiles: profiles, discovery: model.service, settings: model.settings) { _, settings in
                    if let settings { pendingAction = .search(UUID(), settings) }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersView(model: model, profiles: profiles, areas: areas) { settings in
                pendingAction = .search(UUID(), settings)
            }
        }
        .refreshable {
            await model.refresh(searchPlayers: mode == .players)
            if mode == .groups, let settings = model.settings { await groups.search(settings: settings) }
        }
        .task(id: GroupSearchKey(mode: mode, settings: model.settings, retry: retryRequest)) {
            if mode == .groups, let settings = model.settings { await groups.search(settings: settings) }
        }
        .task(id: groups.needsSignIn) { if groups.needsSignIn { await session.signOut() } }
        .task(id: ReloadKey(mode: mode, retry: retryRequest)) { await model.refresh(searchPlayers: mode == .players) }
        .task(id: pendingAction) {
            guard let action = pendingAction else { return }
            switch action {
            case .search(_, let settings): await model.search(settings: settings, searchPlayers: mode == .players)
            case .more: await model.loadMore()
            }
            // Consume completed/cancelled work so a later appearance cannot replay it.
            if pendingAction == action { pendingAction = nil }
        }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let settings = model.settings {
                Text(settings.area.name)
                    .font(DesignTokens.Typography.eyebrow)
                    .accessibilityIdentifier("discovery.areaSummary")
                Text("Within \(settings.radius.rawValue) miles")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.muted)
                    .accessibilityIdentifier("discovery.distanceChip")
            }
            PrimaryButton(title: "Search filters", kind: .secondary) {
                if mode == .groups || model.settings == nil { showArea = true }
                else { showFilters = true }
            }
            .accessibilityIdentifier("discovery.filters")
            .disabled(model.isSaving)
        }
    }
    private var playerRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(model.players) { player in
                NavigationLink(value: player) {
                    HStack(spacing: 14) {
                        InitialsAvatar(initials: player.initials)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(player.displayName).font(DesignTokens.Typography.control)
                            Text(player.areaName).font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                            RatingSummaryView(ratings: player.ratings ?? player.rating.map { [$0] } ?? [])
                            Text(player.distanceDescription).font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image("IconChevron").accessibilityHidden(true)
                    }.padding(.vertical, 14).contentShape(Rectangle())
                }.accessibilityIdentifier("discovery.player.\(player.id.uuidString.lowercased())")
                Divider()
            }
            if model.isLoadingMore { ProgressView("Loading more players…").padding() }
            else if model.nextCursor != nil {
                PrimaryButton(title: "Load more players", kind: .secondary) { pendingAction = .more(UUID()) }.padding(.top, 16).disabled(model.isSaving)
            }
        }
    }
    private var empty: some View {
        VStack(spacing: 16) {
            AreaOrbit().scaleEffect(0.7).frame(height: 115)
            Text("No players in this area yet").accessibilityIdentifier("discovery.empty").font(DesignTokens.Typography.statusTitle).multilineTextAlignment(.center)
            Text("Try a wider distance or choose another area. New players will appear here when they save a nearby profile area.")
                .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted).multilineTextAlignment(.center)
        }.padding(.vertical, 25).frame(maxWidth: .infinity)
    }
    private var skeleton: some View {
        VStack(spacing: 20) {
            ProgressView("Finding nearby players…")
            ForEach(0..<4) { _ in
                HStack(spacing: 14) {
                    Circle().fill(DesignTokens.Colors.line).frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(DesignTokens.Colors.line).frame(width: 130, height: 13)
                        RoundedRectangle(cornerRadius: 4).fill(DesignTokens.Colors.line).frame(maxWidth: .infinity).frame(height: 10)
                    }
                }.padding(.vertical, 10).accessibilityHidden(true)
            }
        }.accessibilityIdentifier("discovery.loading")
    }
}

#if DEBUG
private struct DiscoveryPreview: View {
    let state: PreviewDiscoveryService.State
    var body: some View {
        NavigationStack {
            NearbyPlayersView(service: PreviewDiscoveryService(state: state), profiles: PreviewPlayerService(state: .populated), areas: PreviewAccountService())
        }.environment(SessionViewModel(auth: PreviewAccountService()))
    }
}
#Preview("Nearby · populated") { DiscoveryPreview(state: .populated) }
#Preview("Nearby · empty, dark") { DiscoveryPreview(state: .empty).preferredColorScheme(.dark) }
#Preview("Nearby · loading") { DiscoveryPreview(state: .loading) }
#Preview("Nearby · error") { DiscoveryPreview(state: .failed) }
#Preview("Nearby · accessibility text") { DiscoveryPreview(state: .empty).dynamicTypeSize(.accessibility3) }
#endif
