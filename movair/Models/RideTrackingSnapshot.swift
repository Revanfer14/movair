import Foundation
import CoreLocation

struct RideTrackingSnapshot {
    let segmentDurations: [TimeInterval]
    let elapsedDuration: TimeInterval
    let unattributedDuration: TimeInterval
    let travelledDistanceMeters: Double
    let isOffRoute: Bool
    let activeSegmentIndex: Int?
    let matchedRouteDistanceMeters: Double
    let distanceToRouteMeters: Double
    let projectedCoordinate: CLLocationCoordinate2D?
    let interpolatedSegmentFlags: [Bool]
    let travelledCoordinates: [CLLocationCoordinate2D]
    let travelledTracePoints: [RideTracePoint]
}
