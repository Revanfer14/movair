import Foundation

protocol RouteExposureEstimating {
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
        predictor: PMPredicting? = nil
    ) throws {
        self.segmenter = segmenter
        self.weatherService = weatherService
        self.predictor = try predictor ?? PMPredictor()
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
        guard cells.count <= 8 else {
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

            let weightedConcentrationMinutes = try segments.reduce(0.0) { total, segment in
                let cell = CAMSCell(coordinate: segment.midpoint)
                guard let basePM25 = basePM25ByCell[cell] else {
                    throw ExposureEstimationError.unavailableData
                }
                let attributes = try roadDataStore.attributes(for: segment.midpoint)
                let concentration = basePM25 * roadMultiplier(for: attributes.roadClass) * greenMultiplier(for: attributes.greeneryIndex)
                let minutes = route.durationSeconds / 60 * (segment.distanceMeters / totalSegmentDistance)
                return total + concentration * minutes
            }

            return RouteExposureEstimate(
                routeID: route.id,
                doseMicrograms: weightedConcentrationMinutes * 0.040
            )
        }
    }

    private func resolvedRoadDataStore() throws -> RoadDataProviding {
        if let roadDataStore {
            return roadDataStore
        }
        let roadDataStore = try RoadDataStore()
        self.roadDataStore = roadDataStore
        return roadDataStore
    }

    private func roadMultiplier(for roadClass: Int) -> Double {
        switch roadClass {
        case 2: return 1.25
        case 3: return 1.15
        default: return 1.0
        }
    }

    private func greenMultiplier(for greeneryIndex: Double) -> Double {
        1 - 0.05 * greeneryIndex
    }
}
