import CoreLocation

struct SegmentExposure: Equatable {
    let index: Int
    let midpoint: CLLocationCoordinate2D
    let cumulativeStartMeters: Double
    let cumulativeEndMeters: Double
    let roadClass: Int
    let greeneryIndex: Double
    let roadMultiplier: Double
    let greenMultiplier: Double
    let cBase: Double
    let concentration: Double
    let durationSeconds: Double
    let concentrationTimesDuration: Double
    let fetchGroupIndex: Int

    static func == (lhs: SegmentExposure, rhs: SegmentExposure) -> Bool {
        lhs.index == rhs.index
            && lhs.midpoint.latitude == rhs.midpoint.latitude
            && lhs.midpoint.longitude == rhs.midpoint.longitude
            && lhs.cumulativeStartMeters == rhs.cumulativeStartMeters
            && lhs.cumulativeEndMeters == rhs.cumulativeEndMeters
            && lhs.roadClass == rhs.roadClass
            && lhs.greeneryIndex == rhs.greeneryIndex
            && lhs.roadMultiplier == rhs.roadMultiplier
            && lhs.greenMultiplier == rhs.greenMultiplier
            && lhs.cBase == rhs.cBase
            && lhs.concentration == rhs.concentration
            && lhs.durationSeconds == rhs.durationSeconds
            && lhs.concentrationTimesDuration == rhs.concentrationTimesDuration
            && lhs.fetchGroupIndex == rhs.fetchGroupIndex
    }
}
