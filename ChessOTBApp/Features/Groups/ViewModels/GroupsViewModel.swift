import Combine
import Foundation

@MainActor final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [GroupListing] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    let service: any GroupServiceProtocol
    private var generation = UUID()
    private var settings: DiscoverySettings?
    init(service: any GroupServiceProtocol) { self.service = service }
    func search(settings: DiscoverySettings) async {
        let request = UUID(); generation = request
        self.settings = settings; groups = []; nextCursor = nil
        isLoading = true; isLoadingMore = false; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await service.search(settings: settings, cursor: nil)
            try Task.checkCancellation()
            guard generation == request else { return }
            groups = page.groups; nextCursor = page.nextCursor
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    func loadMore() async {
        guard !isLoading, !isLoadingMore, let settings, let cursor = nextCursor else { return }
        let request = generation; isLoadingMore = true; errorMessage = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await service.search(settings: settings, cursor: cursor)
            try Task.checkCancellation()
            guard generation == request else { return }
            var ids = Set(groups.map(\.id))
            groups += page.groups.filter { ids.insert($0.id).inserted }; nextCursor = page.nextCursor
        } catch is CancellationError { return }
        catch { if generation == request { record(error) } }
    }
    private func record(_ error: Error) {
        errorMessage = error.localizedDescription
        needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
    }
}

@MainActor final class GroupDetailViewModel: ObservableObject {
    @Published private(set) var listing: GroupListing?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    private let service: any GroupServiceProtocol
    private var generation = UUID()
    init(service: any GroupServiceProtocol) { self.service = service }
    func load(id: UUID) async {
        let request = UUID(); generation = request
        isLoading = true; listing = nil; errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await service.detail(id: id)
            try Task.checkCancellation()
            guard generation == request else { return }
            listing = result; hasLoaded = true
        } catch is CancellationError { return }
        catch {
            guard generation == request else { return }
            errorMessage = error.localizedDescription
            needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
        }
    }
}
