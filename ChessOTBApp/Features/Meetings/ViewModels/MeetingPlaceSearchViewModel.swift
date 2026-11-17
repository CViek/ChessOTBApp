import Combine
import Foundation

@MainActor final class MeetingPlaceSearchViewModel: ObservableObject {
    @Published var query = "" { didSet { generation += 1; results = []; errorMessage = nil; hasSearched = false; isLoading = false } }
    @Published private(set) var results: [MeetingPlace] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasSearched = false
    private var generation = 0
    private let service: any MeetingPlaceSearching
    init(service: any MeetingPlaceSearching = MeetingPlaceSearch()) { self.service = service }
    func search() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else { return }
        let stamp = generation
        isLoading = true; errorMessage = nil
        defer { if generation == stamp { isLoading = false } }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let places = try await service.search(query)
            try Task.checkCancellation()
            guard generation == stamp else { return }
            results = places; hasSearched = true
        } catch is CancellationError { return }
        catch { if generation == stamp { errorMessage = String(localized: "Could not search addresses. Check your connection and try again.") } }
    }
}
