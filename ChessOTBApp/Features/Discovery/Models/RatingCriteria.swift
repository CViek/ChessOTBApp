import Foundation

nonisolated struct RatingCriteria: Codable, Hashable, Sendable {
    let kind: RatingKind
    let minimum: Int?
    let maximum: Int?
    static func parse(kind: RatingKind?, minimum: String, maximum: String) throws -> RatingCriteria? {
        let low = minimum.trimmingCharacters(in: .whitespacesAndNewlines)
        let high = maximum.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kind else {
            guard low.isEmpty, high.isEmpty else { throw RatingError.invalidCriteria }
            return nil
        }
        do {
            let lower = try RatingEntry.parse(kind: kind, text: low)?.value
            let upper = try RatingEntry.parse(kind: kind, text: high)?.value
            guard (lower ?? 1) <= (upper ?? 4000) else { throw RatingError.invalidCriteria }
            return RatingCriteria(kind: kind, minimum: lower, maximum: upper)
        } catch { throw RatingError.invalidCriteria }
    }
    func matches(_ rating: RatingEntry?) -> Bool {
        guard let rating, rating.kind == kind else { return false }
        return rating.value >= (minimum ?? 1) && rating.value <= (maximum ?? 4000)
    }
    var summary: String { String(localized: "\(kind.title) · \(minimum ?? 1)–\(maximum ?? 4000)") }
}
