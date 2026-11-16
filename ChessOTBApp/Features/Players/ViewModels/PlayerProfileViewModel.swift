import Combine
import Foundation

@MainActor final class PlayerProfileViewModel: ObservableObject {
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    let service: any ProfileServiceProtocol
    init(service: any ProfileServiceProtocol) { self.service = service }
    func load(id: UUID) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.publicProfile(id: id)
            try Task.checkCancellation()
            profile = result; hasLoaded = true
        } catch is CancellationError { return }
        catch {
            errorMessage = error.localizedDescription
            needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
        }
    }
}
