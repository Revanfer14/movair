import Foundation

enum DoseCalculator {
    static func roadMultiplier(for roadClass: Int) -> Double {
        switch roadClass {
        case 2:
            return DoseConstants.arterialRoadMultiplier
        case 3:
            return DoseConstants.collectorRoadMultiplier
        default:
            return DoseConstants.localRoadMultiplier
        }
    }

    static func greenMultiplier(for greeneryIndex: Double) -> Double {
        1 - DoseConstants.greeneryReductionFactor * greeneryIndex
    }

    static func concentration(
        basePM25: Double,
        roadClass: Int,
        greeneryIndex: Double
    ) -> Double {
        basePM25 * roadMultiplier(for: roadClass) * greenMultiplier(for: greeneryIndex)
    }

    static func planningMinutes(
        routeDurationSeconds: Double,
        segmentDistanceMeters: Double,
        totalDistanceMeters: Double
    ) -> Double {
        guard totalDistanceMeters > 0 else { return 0 }
        return routeDurationSeconds / 60 * (segmentDistanceMeters / totalDistanceMeters)
    }

    static func exposure(
        concentrations: [Double],
        durationsMinutes: [Double]
    ) -> Double {
        zip(concentrations, durationsMinutes).reduce(0) { partial, pair in
            partial + pair.0 * pair.1
        }
    }

    static func doseMicrograms(
        exposure: Double,
        ventilationRate: Double = DoseConstants.ventilationRateCubicMetersPerMinute
    ) -> Double {
        ventilationRate * exposure
    }
}
