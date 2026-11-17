import Foundation

nonisolated enum RatingKind: String, Codable, CaseIterable, Hashable, Sendable {
    case chessComRapid = "chess_com_rapid", chessComBlitz = "chess_com_blitz", chessComBullet = "chess_com_bullet"
    case lichessRapid = "lichess_rapid", lichessBlitz = "lichess_blitz", lichessBullet = "lichess_bullet", lichessClassical = "lichess_classical"
    case usChessRegular = "us_chess_regular", usChessQuick = "us_chess_quick", usChessBlitz = "us_chess_blitz"
    var title: String {
        switch self {
        case .chessComRapid: String(localized: "Chess.com · Rapid")
        case .chessComBlitz: String(localized: "Chess.com · Blitz")
        case .chessComBullet: String(localized: "Chess.com · Bullet")
        case .lichessRapid: String(localized: "Lichess · Rapid")
        case .lichessBlitz: String(localized: "Lichess · Blitz")
        case .lichessBullet: String(localized: "Lichess · Bullet")
        case .lichessClassical: String(localized: "Lichess · Classical")
        case .usChessRegular: String(localized: "US Chess · Regular")
        case .usChessQuick: String(localized: "US Chess · Quick")
        case .usChessBlitz: String(localized: "US Chess · Blitz")
        }
    }
}
nonisolated struct RatingEntry: Codable, Hashable, Sendable {
    let kind: RatingKind
    let value: Int
    static func parse(kind: RatingKind, text: String) throws -> RatingEntry? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text), (1...4000).contains(value) else { throw RatingError.invalidValue }
        return RatingEntry(kind: kind, value: value)
    }
    var summary: String { String(localized: "\(value) · \(kind.title) · self-reported") }
}
nonisolated enum RatingError: LocalizedError, Equatable {
    case invalidValue, invalidCriteria
    var errorDescription: String? {
        switch self {
        case .invalidValue: String(localized: "Enter a whole-number rating from 1 to 4,000, or leave it blank.")
        case .invalidCriteria: String(localized: "Choose a rating source and format. Bounds must be 1–4,000, with minimum no greater than maximum.")
        }
    }
}
