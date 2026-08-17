import Foundation

protocol RouteExposureEstimating: Sendable {
    func estimate(routes: [ORSRoute], date: Date) async throws -> RouteExposureEstimationResult
}

actor RouteExposureEstimator: RouteExposureEstimating {
    private let segmenter: RouteSegmenting
    private let weatherService: OpenMeteoProviding
    private let predictor: PMPredicting
    private var roadDataStore: RoadDataProviding?

    init(
        segmenter: RouteSegmenting = RouteSegmenter(),
        weatherService: OpenMeteoProviding = OpenMeteoService(),
        predictor: PMPredicting? = nil,
        roadDataStore: RoadDataProviding? = nil
    ) throws {
        self.segmenter = segmenter
        self.weatherService = weatherService
        // self.predictor = try predictor ?? PMPredictor()
        self.predictor = predictor ?? RemotePMPredictor()
        self.roadDataStore = roadDataStore
    }

    func estimate(routes: [ORSRoute], date: Date = Date()) async throws -> RouteExposureEstimationResult {
        let routeSegments = try routes.map { route in
            let segments = segmenter.makeSegments(from: route.coordinates)
            guard !segments.isEmpty else {
                throw ExposureEstimationError.invalidRoute
            }
            return (route, segments)
        }

        let cells = Set(routeSegments.flatMap { $0.1.map { CAMSCell(coordinate: $0.midpoint) } })
        guard cells.count <= DoseConstants.maxCAMSCellsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        let orderedCells = cells.sorted { lhs, rhs in
            lhs.latitudeIndex == rhs.latitudeIndex
                ? lhs.longitudeIndex < rhs.longitudeIndex
                : lhs.latitudeIndex < rhs.latitudeIndex
        }
        let fetchGroupIndexByCell = Dictionary(uniqueKeysWithValues: orderedCells.enumerated().map { ($1, $0) })

        var snapshotsByCell: [CAMSCell: WeatherSnapshot] = [:]
        for cell in orderedCells {
            snapshotsByCell[cell] = try await weatherService.weather(at: cell.centroid, date: date)
        }

        // let snapshots = orderedCells.map { snapshotsByCell[$0]! }
        let snapshots = orderedCells.compactMap { snapshotsByCell[$0] }
        guard snapshots.count == orderedCells.count else {
            throw ExposureEstimationError.unavailableData
        }

        let cBaseValues: [Double]
        do {
            cBaseValues = try await predictor.predict(snapshots: snapshots, date: date)
        } catch {
            throw ExposureEstimationError.modelPredictionFailed
        }
        guard cBaseValues.count == orderedCells.count else {
            throw ExposureEstimationError.modelPredictionFailed
        }
        let cBaseByCell = Dictionary(uniqueKeysWithValues: zip(orderedCells, cBaseValues))

        var segmentCountByCell: [CAMSCell: Int] = [:]
        for (_, segments) in routeSegments {
            for segment in segments {
                let cell = CAMSCell(coordinate: segment.midpoint)
                segmentCountByCell[cell, default: 0] += 1
            }
        }

        let roadDataStore = try resolvedRoadDataStore()
        let routeEstimates = try routeSegments.map { route, segments -> RouteExposureEstimate in
            let totalSegmentDistance = segments.reduce(0) { $0 + $1.distanceMeters }
            guard totalSegmentDistance > 0 else {
                throw ExposureEstimationError.invalidRoute
            }

            var segmentExposures: [SegmentExposure] = []
            segmentExposures.reserveCapacity(segments.count)
            var exposure = 0.0

            for (index, segment) in segments.enumerated() {
                let cell = CAMSCell(coordinate: segment.midpoint)
                guard let cBase = cBaseByCell[cell] else {
                    throw ExposureEstimationError.unavailableData
                }
                let attributes = try roadDataStore.attributes(for: segment.midpoint)
                let roadMultiplier = DoseCalculator.roadMultiplier(for: attributes.roadClass)
                let greenMultiplier = DoseCalculator.greenMultiplier(for: attributes.greeneryIndex)
                let concentration = DoseCalculator.concentration(
                    basePM25: cBase,
                    roadClass: attributes.roadClass,
                    greeneryIndex: attributes.greeneryIndex
                )
                let minutes = DoseCalculator.planningMinutes(
                    routeDurationSeconds: route.durationSeconds,
                    segmentDistanceMeters: segment.distanceMeters,
                    totalDistanceMeters: totalSegmentDistance
                )
                let concentrationTimesDuration = concentration * minutes
                exposure += concentrationTimesDuration

                segmentExposures.append(
                    SegmentExposure(
                        index: index,
                        midpoint: segment.midpoint,
                        cumulativeStartMeters: segment.startDistanceMeters,
                        cumulativeEndMeters: segment.endDistanceMeters,
                        roadClass: attributes.roadClass,
                        greeneryIndex: attributes.greeneryIndex,
                        roadMultiplier: roadMultiplier,
                        greenMultiplier: greenMultiplier,
                        cBase: cBase,
                        concentration: concentration,
                        durationSeconds: minutes * 60,
                        concentrationTimesDuration: concentrationTimesDuration,
                        fetchGroupIndex: fetchGroupIndexByCell[cell] ?? 0
                    )
                )
            }

            return RouteExposureEstimate(
                routeID: route.id,
                exposure: exposure,
                doseMicrograms: DoseCalculator.doseMicrograms(exposure: exposure),
                distanceMeters: route.distanceMeters,
                durationSeconds: route.durationSeconds,
                segments: segmentExposures
            )
        }

        let fetchGroups = orderedCells.enumerated().map { index, cell in
            FetchGroupExposure(
                index: index,
                reference: cell.centroid,
                snapshot: snapshotsByCell[cell] ?? WeatherSnapshot(basePM25: 0, windSpeedMetersPerSecond: 0, relativeHumidityPercent: 0, temperatureCelsius: 0, coordinate: cell.centroid),
                cBase: cBaseByCell[cell] ?? 0,
                segmentCount: segmentCountByCell[cell] ?? 0
            )
        }

        return RouteExposureEstimationResult(
            routes: routeEstimates,
            fetchGroups: fetchGroups,
            modelVersion: predictor.modelVersion ?? "unknown"
        )
    }

    private func resolvedRoadDataStore() throws -> RoadDataProviding {
        if let roadDataStore {
            return roadDataStore
        }
        if let shared = RoadDataStore.shared {
            self.roadDataStore = shared
            return shared
        }
        let roadDataStore = try RoadDataStore()
        self.roadDataStore = roadDataStore
        return roadDataStore
    }
}
