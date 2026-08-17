import Foundation

struct RouteExposureEstimate: Equatable {
    let routeID: UUID
    let exposure: Double
    let doseMicrograms: Double
}
