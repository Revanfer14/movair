import CoreLocation

struct FetchGroupExposure: Equatable {
    let index: Int
    let reference: CLLocationCoordinate2D
    let snapshot: WeatherSnapshot
    let cBase: Double
    let segmentCount: Int

    static func == (lhs: FetchGroupExposure, rhs: FetchGroupExposure) -> Bool {
        lhs.index == rhs.index
            && lhs.reference.latitude == rhs.reference.latitude
            && lhs.reference.longitude == rhs.reference.longitude
            && lhs.snapshot == rhs.snapshot
            && lhs.cBase == rhs.cBase
            && lhs.segmentCount == rhs.segmentCount
    }
}
