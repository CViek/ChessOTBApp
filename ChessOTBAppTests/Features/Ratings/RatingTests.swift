import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct RatingTests {
    @Test func optionalRatingValidatesWholeNumbersAndBounds() throws {
        #expect(try RatingEntry.parse(kind: .chessComRapid, text: " ") == nil)
        #expect(try RatingEntry.parse(kind: .chessComRapid, text: " 1500 ")?.value == 1500)
        for input in ["0", "4001", "1500.5", "-1", "abc"] {
            #expect(throws: RatingError.invalidValue) { try RatingEntry.parse(kind: .chessComRapid, text: input) }
        }
    }
    @Test func criteriaRequireComparableKeyAndValidInclusiveBounds() throws {
        #expect(try RatingCriteria.parse(kind: nil, minimum: "", maximum: "") == nil)
        #expect(throws: RatingError.invalidCriteria) { try RatingCriteria.parse(kind: nil, minimum: "1000", maximum: "") }
        #expect(throws: RatingError.invalidCriteria) { try RatingCriteria.parse(kind: .lichessRapid, minimum: "1600", maximum: "1400") }
        let parsed = try RatingCriteria.parse(kind: .lichessRapid, minimum: "1500", maximum: "")
        let criteria = try #require(parsed)
        #expect(criteria.matches(RatingEntry(kind: .lichessRapid, value: 1500)))
        #expect(!criteria.matches(RatingEntry(kind: .chessComRapid, value: 1500)))
        #expect(!criteria.matches(nil))
    }

}
