import CoreLocation

struct RouteSegment {
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let midpoint: CLLocationCoordinate2D
    let distanceMeters: Double
    let startDistanceMeters: Double
    let endDistanceMeters: Double
}
