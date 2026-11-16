import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct AreaServiceTests {
    @Test func deniedLocationStillAllowsManualAreaLookup() async throws {
        let service = AreaService(lookup: AreaLookupDouble([DiscoveryFixtures.newYork]), location: LocationDouble(denied: true))
        await #expect(throws: AreaError.permissionDenied) { try await service.currentArea() }
        let results = try await service.resolve(query: "New York")
        #expect(results.count == 1)
        #expect(results.first?.latitude == 40.71)
        #expect(results.first?.longitude == -74.01)
    }
    @Test func ambiguityIsReturnedForExplicitSelection() async throws {
        let service = AreaService(lookup: AreaLookupDouble([DiscoveryFixtures.newYork, DiscoveryFixtures.boston]), location: LocationDouble())
        #expect(try await service.resolve(query: "City").count == 2)
    }
    @Test func foreignAreasAreNotReturnedAsUSResults() async throws {
        let foreign = ApproximateArea(name: "Toronto", latitude: 43.65, longitude: -79.38, countryCode: "CA")
        let service = AreaService(lookup: AreaLookupDouble([foreign]), location: LocationDouble())
        await #expect(throws: AreaError.outsideUS) { try await service.resolve(query: "Toronto") }
    }
    @Test func blankQueryDoesNotResolveAnArea() async {
        let service = AreaService(lookup: AreaLookupDouble([DiscoveryFixtures.newYork]), location: LocationDouble())
        await #expect(throws: AreaError.invalidQuery) { try await service.resolve(query: "   ") }
    }
    @Test func invalidCoordinatesCannotBeSavedAsAnArea() {
        let invalid = ApproximateArea(name: "Invalid", latitude: .nan, longitude: 200, countryCode: "US")
        #expect(throws: AreaError.invalidArea) { try invalid.validated() }
    }
}
