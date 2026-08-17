import Foundation

protocol RouteExposureEstimating: Sendable {
    func estimate(routes: [ORSRoute], date: Date) async throws -> [RouteExposureEstimate]
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
        self.predictor = try predictor ?? PMPredictor()
        self.roadDataStore = roadDataStore
    }

    func estimate(routes: [ORSRoute], date: Date = Date()) async throws -> [RouteExposureEstimate] {
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

        var basePM25ByCell: [CAMSCell: Double] = [:]
        for cell in cells {
            let snapshot = try await weatherService.weather(at: cell.centroid, date: date)
            do {
                basePM25ByCell[cell] = try predictor.predict(snapshot: snapshot, date: date)
            } catch {
                throw ExposureEstimationError.modelPredictionFailed
            }
        }

        let roadDataStore = try resolvedRoadDataStore()
        return try routeSegments.map { route, segments in
            let totalSegmentDistance = segments.reduce(0) { $0 + $1.distanceMeters }
            guard totalSegmentDistance > 0 else {
                throw ExposureEstimationError.invalidRoute
            }

            let exposure = try segments.reduce(0.0) { total, segment in
                let cell = CAMSCell(coordinate: segment.midpoint)
                guard let basePM25 = basePM25ByCell[cell] else {
                    throw ExposureEstimationError.unavailableData
                }
                let attributes = try roadDataStore.attributes(for: segment.midpoint)
                let concentration = DoseCalculator.concentration(
                    basePM25: basePM25,
                    roadClass: attributes.roadClass,
                    greeneryIndex: attributes.greeneryIndex
                )
                let minutes = DoseCalculator.planningMinutes(
                    routeDurationSeconds: route.durationSeconds,
                    segmentDistanceMeters: segment.distanceMeters,
                    totalDistanceMeters: totalSegmentDistance
                )
                return total + concentration * minutes
            }

            return RouteExposureEstimate(
                routeID: route.id,
                exposure: exposure,
                doseMicrograms: DoseCalculator.doseMicrograms(exposure: exposure)
            )
        }
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
