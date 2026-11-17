import Foundation

nonisolated struct GroupPerson: Codable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    var conversationRoute: ConversationRoute { ConversationRoute(peerID: id, displayName: displayName) }
}
nonisolated struct GroupIntroduction: Codable, Hashable, Sendable {
    let text: String
    let player: GroupPerson
}
nonisolated struct GroupListing: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let areaName: String
    let description: String
    let contact: GroupPerson?
    let introduction: GroupIntroduction?
    var distanceMiles: Int? = nil
    var distanceDescription: String? {
        guard let distanceMiles else { return nil }
        if distanceMiles < 1 { return String(localized: "Less than 1 mile") }
        if distanceMiles == 1 { return String(localized: "About 1 mile") }
        return String(localized: "About \(distanceMiles) miles")
    }
}
nonisolated struct GroupPage: Codable, Sendable {
    let groups: [GroupListing]
    let nextCursor: String?
}
nonisolated struct GroupRoute: Hashable, Sendable { let id: UUID }
