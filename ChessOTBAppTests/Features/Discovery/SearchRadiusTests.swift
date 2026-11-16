import Foundation
import Testing
@testable import ChessOTBApp

struct SearchRadiusTests {
    @Test(arguments: [1, 7, 12, 37, 99, 100])
    func supportsWholeMileValuesBeyondTheOldPresets(_ miles: Int) throws {
        let radius = try #require(SearchRadius(rawValue: miles))
        #expect(radius.rawValue == miles)
        let data = try JSONEncoder().encode(radius)
        #expect(try JSONDecoder().decode(Int.self, from: data) == miles)
        #expect(try JSONDecoder().decode(SearchRadius.self, from: data) == radius)
    }
    @Test(arguments: [-1, 0, 101, 1000])
    func rejectsDistancesOutsideTheSupportedRange(_ miles: Int) {
        #expect(SearchRadius(rawValue: miles) == nil)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SearchRadius.self, from: Data(String(miles).utf8))
        }
    }
    @Test func wideningUsesTheActualCustomRadiusAndStopsAtTheLimit() throws {
        #expect(try #require(SearchRadius(rawValue: 7)).widened?.rawValue == 14)
        #expect(try #require(SearchRadius(rawValue: 75)).widened?.rawValue == 100)
        #expect(SearchRadius.three.widened?.rawValue == 6)
        #expect(try #require(SearchRadius(rawValue: 100)).widened == nil)
    }

}
