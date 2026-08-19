import CoreLocation

protocol ReverseGeocoding {
    func placeName(for coordinate: CLLocationCoordinate2D) async throws -> String
}

enum ReverseGeocodingError: Error {
    case noResult
}

final class ReverseGeocodingService: ReverseGeocoding {
    private let geocoder = CLGeocoder()

    func placeName(for coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw ReverseGeocodingError.noResult
        }
        return Self.name(from: placemark)
    }

    private static func name(from placemark: CLPlacemark) -> String {
        if let name = placemark.name, !name.isEmpty {
            return name
        }
        if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
            return thoroughfare
        }
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            return subLocality
        }
        if let locality = placemark.locality, !locality.isEmpty {
            return locality
        }
        return "Current location"
    }
}
