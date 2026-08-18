import Foundation
import CoreLocation

struct RideTracePoint {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let horizontalAccuracy: Double
    let speed: Double
}
