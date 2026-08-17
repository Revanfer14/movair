import Foundation

struct RideRecord: Equatable {
    let segmentDurationsSeconds: [TimeInterval]
    let segmentConcentrations: [Double]
    let unattributedDurationSeconds: TimeInterval
    let interpolatedSegmentFlags: [Bool]
    let totalDoseMicrograms: Double

    var attributedDurationSeconds: TimeInterval {
        segmentDurationsSeconds.reduce(0, +)
    }
}
