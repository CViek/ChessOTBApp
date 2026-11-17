import Foundation

nonisolated struct AppDependencies: Sendable {
    let auth: any AuthServiceProtocol
    let profiles: any ProfileServiceProtocol
    let areas: any AreaServiceProtocol
    let discovery: any DiscoveryServiceProtocol
    var client: APIClient? = nil

    @MainActor func messagingWorkspace(accountID: UUID, profileID: UUID) throws -> MessagingWorkspace {
        guard let client else { throw APIError.invalidConfiguration }
        return MessagingWorkspace(cache: try AccountCache(accountID: accountID),
                                  service: ConversationService(client: client, auth: auth, accountID: accountID), ownProfileID: profileID,
                                  meetingService: MeetingService(client: client, auth: auth, accountID: accountID))
    }

    @MainActor static func live(bundle: Bundle = .main) -> AppDependencies {
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
            return AppDependencies(auth: auth, profiles: ProfileService(client: client, auth: auth),
                                   areas: AreaService(lookup: MapKitAreaLookup(), location: DeviceLocationClient()),
                                   discovery: DiscoveryService(client: client, auth: auth), client: client)
        } catch {
            let unavailable = UnconfiguredAccountService()
            return AppDependencies(auth: unavailable, profiles: unavailable, areas: unavailable, discovery: unavailable)
        }
    }
}

/// A missing configuration is a recoverable service failure, never a local fake account.
private nonisolated struct UnconfiguredAccountService: AuthServiceProtocol, ProfileServiceProtocol, AreaServiceProtocol, DiscoveryServiceProtocol {
    func resolve(query: String) async throws -> [ApproximateArea] { throw APIError.invalidConfiguration }
    func currentArea() async throws -> [ApproximateArea] { throw APIError.invalidConfiguration }
    func loadSettings() async throws -> DiscoverySettings? { throw APIError.invalidConfiguration }
    func saveSettings(area: ApproximateArea, radius: SearchRadius) async throws -> DiscoverySettings { throw APIError.invalidConfiguration }
    func searchPlayers(settings: DiscoverySettings, cursor: String?) async throws -> PlayerPage { throw APIError.invalidConfiguration }
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
    func loadArea() async throws -> ApproximateArea? { throw APIError.invalidConfiguration }
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) async throws -> PlayerProfile { throw APIError.invalidConfiguration }
    func publicProfile(id: UUID) async throws -> PlayerProfile? { throw APIError.invalidConfiguration }
}

#if DEBUG
extension AppDependencies {
    @MainActor static var preview: AppDependencies {
        let service = PreviewAccountService()
        return AppDependencies(auth: service, profiles: service, areas: service, discovery: service)
    }
}
#endif
