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
        case clearRating(UUID)
        case radius(UUID, SearchRadius)
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
                if let settings = model.settings {
                    Button { if mode == .groups { showArea = true } else { showFilters = true } } label: {
                        Text("Within \(settings.radius.rawValue) miles")
                            .font(DesignTokens.Typography.caption).padding(.horizontal, 14).padding(.vertical, 10)
                            .background(DesignTokens.Colors.sage, in: .capsule)
                    }.frame(minHeight: 44).accessibilityIdentifier("discovery.distanceChip")
                }
                if mode == .players, let rating = model.settings?.rating {
                    Button { pendingAction = .clearRating(UUID()) } label: {
                        HStack { Text(rating.summary); Image(systemName: "xmark").accessibilityHidden(true) }
                            .font(DesignTokens.Typography.caption).padding(12)
                            .background(DesignTokens.Colors.sage, in: .capsule)
                    }.accessibilityLabel("Remove rating filter: \(rating.summary)").disabled(model.isSaving)
                        .accessibilityIdentifier("discovery.ratingChip")
                }
                if mode == .groups, model.settings != nil {
                    NearbyGroupsView(model: groups, canWiden: model.settings?.radius.widened != nil,
                                     widen: { if let radius = model.settings?.radius.widened { pendingAction = .radius(UUID(), radius) } },
                                     changeArea: { showArea = true }, retry: { retryRequest += 1 })
                }
                if let error = model.errorMessage {
                    AccountFeedback(message: error, isError: true)
                    PrimaryButton(title: "Retry", kind: .secondary) { retryRequest += 1 }.accessibilityIdentifier("discovery.retry")
                }
                if mode == .groups, model.settings == nil, model.errorMessage == nil {
                    if model.isLoading { ProgressView("Loading search area…") }
                    else { PrimaryButton(title: "Change search area", kind: .secondary) { showArea = true } }
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
        .sheet(isPresented: $showFilters) { SearchFiltersView(model: model) }
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
            case .clearRating: if let radius = model.settings?.radius { _ = await model.setFilters(radius: radius, rating: nil) }
            case .radius(_, let radius): _ = await model.setRadius(radius, searchPlayers: mode == .players)
            }
            // Consume completed/cancelled work so a later appearance cannot replay it.
            if pendingAction == action { pendingAction = nil }
        }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    private var visibleFilterCount: Int {
        mode == .groups ? (model.settings == nil || model.settings?.radius == .five ? 0 : 1) : model.filterCount
    }
    private var controls: some View {
        HStack(spacing: 10) {
            Button { showArea = true } label: {
                HStack(spacing: 10) {
                    Image("IconPin").accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.settings?.area.name ?? String(localized: "Choose search area")).font(DesignTokens.Typography.eyebrow)
                        if let radius = model.settings?.radius {
                            Text("Within \(radius.rawValue) miles").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image("IconChevron").accessibilityHidden(true)
                }.padding(12).frame(minHeight: 56)
                    .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(DesignTokens.Colors.line))
            }.accessibilityIdentifier("discovery.area")
            Button { if mode == .groups { showArea = true } else { showFilters = true } } label: {
                VStack(spacing: 2) {
                    Image("IconTune").accessibilityHidden(true)
                    if visibleFilterCount > 0 { Text("\(visibleFilterCount)").font(DesignTokens.Typography.caption) }
                }.padding(12).frame(minWidth: 56, minHeight: 56)
                    .foregroundStyle(DesignTokens.Colors.paper).background(DesignTokens.Colors.forest, in: .rect(cornerRadius: 11))
            }.accessibilityLabel(mode == .groups ? "Group search area and distance" : "Search filters").accessibilityIdentifier("discovery.filters")
                .disabled(model.settings == nil)
        }
        .disabled(model.isSaving)
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
            if let radius = model.settings?.radius.widened {
                PrimaryButton(title: "Widen search distance") {
                    pendingAction = .radius(UUID(), radius)
                }.disabled(model.isSaving)
                    .accessibilityIdentifier("discovery.widen")
            }
            if model.settings?.rating != nil {
                PrimaryButton(title: "Remove rating filter", kind: .secondary) { pendingAction = .clearRating(UUID()) }.disabled(model.isSaving)
            }
            PrimaryButton(title: "Change search area", kind: .secondary) { showArea = true }.disabled(model.isSaving)
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
