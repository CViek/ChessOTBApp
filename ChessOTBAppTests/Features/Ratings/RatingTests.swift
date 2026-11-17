import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct RatingTests {
    @Test func editingMultipleRatingsPreservesOtherEntriesAndAllowsRemovingAll() async throws {
        let service = PreviewAccountService(profile: PlayerProfile(id: UUID(), displayName: "Alex", ratings: [
            RatingEntry(kind: .chessComRapid, value: 1500), RatingEntry(kind: .lichessBlitz, value: 1700)
        ]))
        let model = ProfileViewModel(service: service)
        await model.load()
        model.prepareDraft()
        #expect(model.ratingDrafts.count == 2)
        model.removeRating(id: model.ratingDrafts[0].id)
        #expect(await model.saveEdits())
        #expect(model.profile?.ratings == [RatingEntry(kind: .lichessBlitz, value: 1700)])
        model.removeRating(id: model.ratingDrafts[0].id)
        #expect(await model.saveEdits())
        #expect(model.profile?.ratings.isEmpty == true)
    }

    @Test func addingRatingsUsesUnusedKindsAndInvalidEntryPreventsSaving() async {
        let model = ProfileViewModel(service: PreviewAccountService())
        await model.load()
        model.prepareDraft()
        model.addRating()
        model.addRating()
        #expect(Set(model.ratingDrafts.map(\.kind)).count == 2)
        model.ratingDrafts[0].value = "1500"
        model.ratingDrafts[1].value = "4001"
        #expect(await model.saveEdits() == false)
        #expect(model.profile?.ratings.isEmpty == true)
        #expect(model.errorMessage != nil)
    }

    @Test func legacySingleRatingDecodesAsAList() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profile = try decoder.decode(PlayerProfile.self, from: Data(#"{"id":"99999999-9999-9999-9999-999999999999","display_name":"Alex","rating":{"kind":"chess_com_rapid","value":1500}}"#.utf8))
        #expect(profile.ratings == [RatingEntry(kind: .chessComRapid, value: 1500)])
    }
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
