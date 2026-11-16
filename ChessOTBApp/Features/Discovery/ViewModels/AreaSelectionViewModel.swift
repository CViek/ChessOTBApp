import Combine
import Foundation

@MainActor
final class AreaSelectionViewModel: ObservableObject {
    enum Purpose { case initialProfile, profile, search }
    @Published var query = "" {
        didSet {
            if query != oldValue { generation = UUID(); candidates = []; selected = nil; isResolving = false; errorMessage = nil }
        }
    }
    @Published var radius: SearchRadius = .five
    @Published private(set) var candidates: [ApproximateArea] = []
    @Published private(set) var selected: ApproximateArea?
    @Published private(set) var isResolving = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    @Published private(set) var savedProfile: PlayerProfile?
    @Published private(set) var savedSettings: DiscoverySettings?
    @Published private(set) var didSave = false
    private var generation = UUID()
    let purpose: Purpose
    let areas: any AreaServiceProtocol
    let profiles: any ProfileServiceProtocol
    let discovery: any DiscoveryServiceProtocol
    init(purpose: Purpose, areas: any AreaServiceProtocol, profiles: any ProfileServiceProtocol, discovery: any DiscoveryServiceProtocol, settings: DiscoverySettings? = nil) {
        self.purpose = purpose; self.areas = areas; self.profiles = profiles; self.discovery = discovery
        if let settings { query = settings.area.name; radius = settings.radius; selected = settings.area; candidates = [settings.area] }
    }
    func resolve(currentLocation: Bool = false) async {
        guard !isSaving else { return }
        let request = UUID(); generation = request
        isResolving = true; errorMessage = nil; candidates = []; selected = nil
        defer { if generation == request { isResolving = false } }
        do {
            let results = try await (currentLocation ? areas.currentArea() : areas.resolve(query: query))
            try Task.checkCancellation()
            guard generation == request else { return }
            candidates = results
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    func select(_ area: ApproximateArea) {
        guard !isSaving, candidates.contains(area) else { return }
        selected = area; errorMessage = nil
    }
    func save() async -> Bool {
        guard !isSaving, !isResolving, let selected else { return false }
        isSaving = true; errorMessage = nil
        defer { isSaving = false }
        do {
            let area = try selected.validated()
            switch purpose {
            case .initialProfile, .profile: savedProfile = try await profiles.saveArea(area, radius: radius)
            case .search: savedSettings = try await discovery.saveSettings(area: area, radius: radius)
            }
            try Task.checkCancellation()
            didSave = true
            return true
        } catch is CancellationError { return false }
        catch { record(error); return false }
    }
    func loadInitial() async {
        guard purpose == .profile else { return }
        let request = generation
        isResolving = true
        defer { if generation == request { isResolving = false } }
        do {
            let area = try await profiles.loadArea()
            try Task.checkCancellation()
            guard generation == request, let area else { return }
            query = area.name; candidates = [area]; selected = area; isResolving = false
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    private func record(_ error: Error) {
        errorMessage = error.localizedDescription
        needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
    }
}
