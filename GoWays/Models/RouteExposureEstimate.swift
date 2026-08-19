import Foundation

struct RouteExposureEstimate: Equatable {
    let routeID: UUID
    let exposure: Double
    let doseMicrograms: Double
    let distanceMeters: Double
    let durationSeconds: Double
    let segments: [SegmentExposure]
}
