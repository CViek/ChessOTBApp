import CoreLocation
import Foundation

@MainActor
final class DeviceLocationClient: NSObject, DeviceLocationProtocol, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<DeviceCoordinate, Error>?
    private var timeout: Task<Void, Never>?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    @MainActor func currentCoordinate() async throws -> DeviceCoordinate {
        try Task.checkCancellation()
        guard continuation == nil else { throw AreaError.locationUnavailable }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(20)) }
                    catch { return }
                    self?.finish(.failure(AreaError.locationUnavailable))
                }
                requestWhenAuthorized()
            }
        } onCancel: { Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) } }
    }
    private func requestWhenAuthorized() {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(.failure(AreaError.permissionDenied))
        @unknown default: finish(.failure(AreaError.locationUnavailable))
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { requestWhenAuthorized() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              abs(location.timestamp.timeIntervalSinceNow) < 60 else { return }
        finish(.success(DeviceCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)))
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure((error as? CLError)?.code == .denied ? AreaError.permissionDenied : AreaError.locationUnavailable))
    }
    private func finish(_ result: Result<DeviceCoordinate, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel(); timeout = nil; manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }
}
