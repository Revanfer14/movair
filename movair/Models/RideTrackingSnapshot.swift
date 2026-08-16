import Foundation

struct RideTrackingSnapshot {
    let segmentDurations: [TimeInterval]
    let elapsedDuration: TimeInterval
    let unattributedDuration: TimeInterval
    let travelledDistanceMeters: Double
    let isOffRoute: Bool
}
