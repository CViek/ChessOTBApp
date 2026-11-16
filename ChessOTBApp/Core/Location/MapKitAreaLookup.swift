import Foundation
import MapKit

/// Address filtering admits cities/neighborhoods, never a street-address search result.
@MainActor
final class MapKitAreaLookup: AreaLookupProtocol {
    @MainActor func lookup(_ query: String) async throws -> [ApproximateArea] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        request.addressFilter = MKAddressFilter(including: [.locality, .subLocality])
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                                            span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 180))
        let search = MKLocalSearch(request: request)
        let cancellation = MapCancellation { search.cancel() }
        do {
            let results: [ApproximateArea] = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    search.start { response, error in
                        if let error { continuation.resume(throwing: error); return }
                        guard let response else { continuation.resume(throwing: AreaError.noResults); return }
                        let areas = response.mapItems.compactMap { item -> ApproximateArea? in
                            guard let address = item.addressRepresentations, let city = address.cityWithContext else { return nil }
                            let name = item.name ?? city
                            let label = name == address.cityName || name == city ? city : "\(name), \(city)"
                            return ApproximateArea(name: label, latitude: item.location.coordinate.latitude,
                                                   longitude: item.location.coordinate.longitude, countryCode: address.region?.identifier ?? "")
                        }
                        continuation.resume(returning: areas)
                    }
                }
            } onCancel: { Task { @MainActor in cancellation.cancel() } }
            try Task.checkCancellation()
            return results
        } catch is CancellationError { throw CancellationError() }
        catch { throw AreaError.locationUnavailable }
    }

    @MainActor func lookupCurrentArea(latitude: Double, longitude: Double) async throws -> [ApproximateArea] {
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: latitude, longitude: longitude))
        else { throw AreaError.locationUnavailable }
        let cancellation = MapCancellation { request.cancel() }
        let city: String
        do {
            city = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    request.getMapItems { items, error in
                        if let error { continuation.resume(throwing: error); return }
                        guard let address = items?.first?.addressRepresentations, let city = address.cityWithContext
                        else { continuation.resume(throwing: AreaError.noResults); return }
                        guard address.region?.identifier == "US" else { continuation.resume(throwing: AreaError.outsideUS); return }
                        continuation.resume(returning: city)
                    }
                }
            } onCancel: { Task { @MainActor in cancellation.cancel() } }
            try Task.checkCancellation()
        } catch is CancellationError { throw CancellationError() }
        catch let error as AreaError { throw error }
        catch { throw AreaError.locationUnavailable }
        // Resolve the named city again: a reverse result can contain the device's exact location.
        return try await lookup(city)
    }
}

/// Keeps cancellation on the same actor as MapKit completion callbacks.
@MainActor private final class MapCancellation {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { action() }
}
