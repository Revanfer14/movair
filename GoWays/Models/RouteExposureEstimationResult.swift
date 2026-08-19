import Foundation

struct RouteExposureEstimationResult: Equatable {
    let routes: [RouteExposureEstimate]
    let fetchGroups: [FetchGroupExposure]
    let modelVersion: String
}
