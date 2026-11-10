import CoreLocation
import Foundation

final class LocationHandler: NSObject {

    private weak var bridge: AppBridge?
    private let manager = CLLocationManager()
    private var pending: (method: String, eventId: String)?

    init(bridge: AppBridge) {
        self.bridge = bridge
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func getCurrentPosition(method: String, eventId: String) {
        pending = (method, eventId)
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            pending = nil
            bridge?.respondError(method: method, eventId: eventId)
        }
    }

    func getLocationPermissionStatus(method: String, eventId: String) {
        let status: String
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: status = "granted"
        case .denied, .restricted: status = "denied"
        default: status = "undetermined"
        }
        bridge?.respondString(method: method, eventId: eventId, value: status)
    }
}

extension LocationHandler: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pending != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            if let p = pending { bridge?.respondError(method: p.method, eventId: p.eventId) }
            pending = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let p = pending, let location = locations.last else { return }
        pending = nil
        bridge?.respondObject(method: p.method, eventId: p.eventId, value: [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let p = pending else { return }
        pending = nil
        bridge?.respondError(method: p.method, eventId: p.eventId)
    }
}
