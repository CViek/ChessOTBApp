import Foundation

nonisolated protocol AreaLookupProtocol: Sendable {
    func lookup(_ query: String) async throws -> [ApproximateArea]
    func lookupCurrentArea(latitude: Double, longitude: Double) async throws -> [ApproximateArea]
}

nonisolated struct DeviceCoordinate: Sendable { let latitude: Double; let longitude: Double }
nonisolated protocol DeviceLocationProtocol: Sendable {
    func currentCoordinate() async throws -> DeviceCoordinate
}

nonisolated protocol AreaServiceProtocol: Sendable {
    func resolve(query: String) async throws -> [ApproximateArea]
    func currentArea() async throws -> [ApproximateArea]
}

nonisolated struct AreaService: AreaServiceProtocol {
    let lookup: any AreaLookupProtocol
    let location: any DeviceLocationProtocol
    func resolve(query: String) async throws -> [ApproximateArea] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...120).contains(query.count) else { throw AreaError.invalidQuery }
        return try normalized(await lookup.lookup(query))
    }
    func currentArea() async throws -> [ApproximateArea] {
        let coordinate = try await location.currentCoordinate()
        return try normalized(await lookup.lookupCurrentArea(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    private func normalized(_ results: [ApproximateArea]) throws -> [ApproximateArea] {
        guard !results.isEmpty else { throw AreaError.noResults }
        let domestic = results.filter { $0.countryCode == "US" }
        guard !domestic.isEmpty else { throw AreaError.outsideUS }
        var seen: Set<ApproximateArea> = []
        return try domestic.map { try $0.validated() }.filter { seen.insert($0).inserted }
    }
}
