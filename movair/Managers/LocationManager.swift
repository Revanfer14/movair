import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var userHeading: CLHeading?
    @Published private(set) var latestLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.headingFilter = 2
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .denied, .restricted:
            locationError = "Location access is denied. Enable it in Settings."
        @unknown default:
            break
        }
    }

    func startUpdating() {
        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        startHeadingUpdatesIfAvailable()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func startHeadingUpdatesIfAvailable() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func startRideTracking() {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.headingFilter = 2
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startUpdating()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            startUpdating()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access is denied. Enable it in Settings."
        @unknown default:
            break
        }
    }

    func stopRideTracking() {
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                self.startUpdating()
            case .denied, .restricted:
                self.locationError = "Location access is denied. Enable it in Settings."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.latestLocation = location
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.userHeading = newHeading.headingAccuracy >= 0 ? newHeading : nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
}
