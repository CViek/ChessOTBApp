#if DEBUG
import Foundation

/// Preview fixtures only. AppDependencies.live never constructs this service.
actor PreviewAccountService: AuthServiceProtocol, ProfileServiceProtocol, AreaServiceProtocol, DiscoveryServiceProtocol {
    static let exampleProfile = PlayerProfile(id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!, displayName: "Alex Morgan")
    private var profile: PlayerProfile?
    init(profile: PlayerProfile? = exampleProfile) { self.profile = profile }
    func resolve(query: String) -> [ApproximateArea] { [] }
    func currentArea() throws -> [ApproximateArea] { throw AreaError.permissionDenied }
    func loadSettings() -> DiscoverySettings? { nil }
    func saveSettings(area: ApproximateArea, radius: SearchRadius) -> DiscoverySettings { DiscoverySettings(area: area, radius: radius) }
    func searchPlayers(settings: DiscoverySettings, cursor: String?) -> PlayerPage { PlayerPage(players: [], nextCursor: nil) }
    func signIn(email: String, password: String) throws -> AuthSession { throw APIError.unavailable }
    func signUp(email: String, password: String) throws -> AuthSession? { throw APIError.unavailable }
    func verifySignup(email: String, code: String) throws -> AuthSession { throw APIError.unavailable }
    func resendSignup(email: String) throws {}
    func requestPasswordReset(email: String) throws {}
    func resetPassword(email: String, code: String, password: String) throws -> AuthSession { throw APIError.unavailable }
    func restore() -> AuthSession? { nil }
    func validSession() throws -> AuthSession { throw APIError.unauthorized }
    func signOut() {}
    func loadOwnProfile() -> PlayerProfile? { profile }
    func saveDisplayName(_ name: String) -> PlayerProfile {
        let result = PlayerProfile(id: Self.exampleProfile.id, displayName: name)
        profile = result
        return result
    }
    func loadArea() -> ApproximateArea? { nil }
    func saveArea(_ area: ApproximateArea, radius: SearchRadius) -> PlayerProfile {
        let result = PlayerProfile(id: Self.exampleProfile.id, displayName: profile?.displayName ?? "Alex Morgan", areaName: area.name)
        profile = result
        return result
    }
    func publicProfile(id: UUID) -> PlayerProfile? { profile }
}
#endif
