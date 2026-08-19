import Foundation

enum DoseConstants {
    static let ventilationRateCubicMetersPerMinute = 0.040
    static let arterialRoadMultiplier = 1.25
    static let collectorRoadMultiplier = 1.15
    static let localRoadMultiplier = 1.00
    static let greeneryReductionFactor = 0.05
    static let equivalentExposureThreshold = 0.20
    static let detourCapFactor = 1.5
    static let maxFetchGroupsPerRequest = 8
    static let fetchGroupingRadiusMeters = 20_000.0
    static let segmentLengthMeters = 200.0
    static let forwardTransitionBufferMeters = 20.0
    static let offRouteDistanceMeters = 50.0
    static let routeJoinDistanceMeters = 25.0
    static let offRouteGraceSeconds: TimeInterval = 15
    static let backwardTransitionConfirmCount = 3
    static let maxPredictRowsPerRequest = 64
    static let maxArchivedSegments = 2000
    static let serverRequestTimeout: TimeInterval = 15
    static let traceMinimumSpacingMeters = 15.0
    static let traceMaximumPointCount = 3000
    static let traceMaximumAccuracyMeters = 50.0
    static let minimumMovementMeters = 5.0
    static let localMatchWindowMeters = 150.0
    static let localMatchInitialRadiusSegments = 5
    static let traceBreakDistanceMeters = 150.0
    static let pendingRideRecordRetentionSeconds: TimeInterval = 30 * 24 * 3600
}
