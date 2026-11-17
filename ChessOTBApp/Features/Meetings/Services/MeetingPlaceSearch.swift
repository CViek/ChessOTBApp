import Foundation
import MapKit

@MainActor protocol MeetingPlaceSearching {
    func search(_ query: String) async throws -> [MeetingPlace]
}

@MainActor final class MeetingPlaceSearch: MeetingPlaceSearching {
    func search(_ query: String) async throws -> [MeetingPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.addressFilter = MKAddressFilter(excluding: [.country, .administrativeArea, .subAdministrativeArea, .locality, .subLocality, .postalCode])
        let search = MKLocalSearch(request: request)
        let cancellation = PlaceSearchCancellation { search.cancel() }
        do {
            let places: [MeetingPlace] = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    search.start { response, error in
                        if let error { continuation.resume(throwing: error); return }
                        guard let response else { continuation.resume(throwing: APIError.unavailable); return }
                        var seen = Set<String>()
                        let places = response.mapItems.compactMap { item -> MeetingPlace? in
                            guard let address = item.address?.fullAddress, !address.isEmpty else { return nil }
                            let place = MeetingPlace(name: item.name ?? address, address: address,
                                                     latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
                            do {
                                let validated = try place.validated()
                                return seen.insert(validated.id).inserted ? validated : nil
                            } catch { return nil } // Ignore incomplete results; never invent an address.
                        }
                        continuation.resume(returning: places)
                    }
                }
            } onCancel: { Task { @MainActor in cancellation.cancel() } }
            try Task.checkCancellation()
            return places
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw APIError.network
        }
    }
}

@MainActor private final class PlaceSearchCancellation {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { action() }
}
