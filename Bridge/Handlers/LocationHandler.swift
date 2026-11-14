import CoreLocation
import Foundation

final class LocationHandler: NSObject {

    private weak var bridge: AppBridge?
    private let manager = CLLocationManager()
    private var pendingId: String?

    init(bridge: AppBridge) {
        self.bridge = bridge
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func getCurrentPosition(id: String) {
        pendingId = id
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            pendingId = nil
            bridge?.respondError(id: id)
        }
    }

    func getLocationPermissionStatus(id: String) {
        let status: String
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: status = "granted"
        case .denied, .restricted: status = "denied"
        default: status = "undetermined"
        }
        bridge?.respondString(id: id, value: status)
    }
}

extension LocationHandler: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pendingId != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            if let id = pendingId { bridge?.respondError(id: id) }
            pendingId = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let id = pendingId, let location = locations.last else { return }
        pendingId = nil
        bridge?.respondObject(id: id, value: [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let id = pendingId else { return }
        pendingId = nil
        bridge?.respondError(id: id)
    }
}
