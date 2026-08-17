import Foundation

enum DoseConstants {
    static let ventilationRateCubicMetersPerMinute = 0.040
    static let arterialRoadMultiplier = 1.25
    static let collectorRoadMultiplier = 1.15
    static let localRoadMultiplier = 1.00
    static let greeneryReductionFactor = 0.05
    static let equivalentExposureThreshold = 0.20
    static let detourCapFactor = 1.5
    static let maxCAMSCellsPerRequest = 8
    static let segmentLengthMeters = 200.0
    static let forwardTransitionBufferMeters = 20.0
    static let offRouteDistanceMeters = 50.0
    static let offRouteGraceSeconds: TimeInterval = 15
    static let backwardTransitionConfirmCount = 3
}
