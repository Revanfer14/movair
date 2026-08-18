import Foundation

struct RideRecord: Equatable {
    let segmentDurationsSeconds: [TimeInterval]
    let segmentConcentrations: [Double]
    let unattributedDurationSeconds: TimeInterval
    let interpolatedSegmentFlags: [Bool]
    let totalDoseMicrograms: Double
    let segmentDoseMicrograms: [Double]
    let segmentExposures: [Double]
    let modelVersion: String?
    let lastVentilationRate: Double
    let lastHeartRateBPM: Double
    let hourRolloverCount: Int

    var attributedDurationSeconds: TimeInterval {
        segmentDurationsSeconds.reduce(0, +)
    }
}
