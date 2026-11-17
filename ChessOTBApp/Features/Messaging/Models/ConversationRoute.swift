import Foundation

nonisolated struct ConversationRoute: Hashable, Sendable {
    let peerID: UUID
    let displayName: String
    var initials: String { displayName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
}
nonisolated struct PublicPlayerRoute: Hashable, Sendable { let id: UUID }
