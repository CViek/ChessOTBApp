import Foundation

nonisolated struct AppDependencies: Sendable {
    let auth: any AuthServiceProtocol
    let profiles: any ProfileServiceProtocol

    static func live(bundle: Bundle = .main) -> AppDependencies {
        do {
            guard let value = bundle.object(forInfoDictionaryKey: "ChessOTBSupabaseURL") as? String,
                  let url = URL(string: value),
                  let key = bundle.object(forInfoDictionaryKey: "ChessOTBSupabasePublishableKey") as? String else { throw APIError.invalidConfiguration }
            #if DEBUG
            let allowsLocalHTTP = true
            #else
            let allowsLocalHTTP = false
            #endif
            let configuration = try BackendConfiguration(url: url, publishableKey: key, allowsLocalHTTP: allowsLocalHTTP)
            let networkConfiguration = URLSessionConfiguration.ephemeral
            networkConfiguration.urlCache = nil
            let client = APIClient(configuration: configuration, session: URLSession(configuration: networkConfiguration))
            let namespace = (bundle.bundleIdentifier ?? "ChessOTBApp") + ".session." + url.absoluteString
            let auth = AuthService(client: client, store: KeychainStore(service: namespace))
            return AppDependencies(auth: auth, profiles: ProfileService(client: client, auth: auth))
        } catch {
            let unavailable = UnconfiguredAccountService()
            return AppDependencies(auth: unavailable, profiles: unavailable)
        }
    }
}

/// A missing configuration is a recoverable service failure, never a local fake account.
private nonisolated struct UnconfiguredAccountService: AuthServiceProtocol, ProfileServiceProtocol {
    func signIn(email: String, password: String) async throws -> AuthSession { throw APIError.invalidConfiguration }
    func signUp(email: String, password: String) async throws -> AuthSession? { throw APIError.invalidConfiguration }
    func verifySignup(email: String, code: String) async throws -> AuthSession { throw APIError.invalidConfiguration }
    func resendSignup(email: String) async throws { throw APIError.invalidConfiguration }
    func requestPasswordReset(email: String) async throws { throw APIError.invalidConfiguration }
    func resetPassword(email: String, code: String, password: String) async throws -> AuthSession { throw APIError.invalidConfiguration }
    func restore() async throws -> AuthSession? { throw APIError.invalidConfiguration }
    func validSession() async throws -> AuthSession { throw APIError.invalidConfiguration }
    func signOut() async throws {}
    func loadOwnProfile() async throws -> PlayerProfile? { throw APIError.invalidConfiguration }
    func saveDisplayName(_ name: String) async throws -> PlayerProfile { throw APIError.invalidConfiguration }
    func publicProfile(id: UUID) async throws -> PlayerProfile? { throw APIError.invalidConfiguration }
}
