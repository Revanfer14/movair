import CoreLocation

struct CAMSCell: Hashable {
    let latitudeIndex: Int
    let longitudeIndex: Int

    init(coordinate: CLLocationCoordinate2D) {
        latitudeIndex = Int(floor(coordinate.latitude / Self.sizeDegrees))
        longitudeIndex = Int(floor(coordinate.longitude / Self.sizeDegrees))
    }

    var centroid: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (Double(latitudeIndex) + 0.5) * Self.sizeDegrees,
            longitude: (Double(longitudeIndex) + 0.5) * Self.sizeDegrees
        )
    }

    private static let sizeDegrees = 0.4
}
