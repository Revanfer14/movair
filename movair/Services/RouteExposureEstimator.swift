import CoreLocation
import Foundation

protocol RouteExposureEstimating: Sendable {
    func estimate(routes: [ORSRoute], date: Date) async throws -> RouteExposureEstimationResult
}

actor RouteExposureEstimator: RouteExposureEstimating {
    private let segmenter: RouteSegmenting
    private let weatherService: OpenMeteoProviding
    private let predictor: PMPredicting
    private let fetchGrouper: SegmentFetchGrouping
    private var roadDataStore: RoadDataProviding?

    init(
        segmenter: RouteSegmenting = RouteSegmenter(),
        weatherService: OpenMeteoProviding = OpenMeteoService(),
        predictor: PMPredicting? = nil,
        fetchGrouper: SegmentFetchGrouping = SegmentFetchGrouper(),
        roadDataStore: RoadDataProviding? = nil
    ) throws {
        self.segmenter = segmenter
        self.weatherService = weatherService
        self.predictor = predictor ?? RemotePMPredictor()
        self.fetchGrouper = fetchGrouper
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

        let perRouteGroups = routeSegments.map { fetchGrouper.makeGroups(from: $0.1) }
        let merge = mergeGroupsAcrossRoutes(perRouteGroups)
        guard merge.references.count <= DoseConstants.maxFetchGroupsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        var snapshots: [WeatherSnapshot] = []
        snapshots.reserveCapacity(merge.references.count)
        for reference in merge.references {
            snapshots.append(try await weatherService.weather(at: reference, date: date))
        }

        let cBaseValues: [Double]
        do {
            cBaseValues = try await predictor.predict(snapshots: snapshots, date: date)
        } catch {
            throw ExposureEstimationError.modelPredictionFailed
        }
        guard cBaseValues.count == merge.references.count else {
            throw ExposureEstimationError.modelPredictionFailed
        }

        let roadDataStore = try resolvedRoadDataStore()
        let routeEstimates = try routeSegments.indices.map { routeIndex -> RouteExposureEstimate in
            let (route, segments) = routeSegments[routeIndex]
            let groups = perRouteGroups[routeIndex]
            let mergedIndicesForGroups = merge.mergedIndicesByRoute[routeIndex]
            let totalSegmentDistance = segments.reduce(0) { $0 + $1.distanceMeters }
            guard totalSegmentDistance > 0 else {
                throw ExposureEstimationError.invalidRoute
            }

            var basePM25BySegmentIndex = Array(repeating: 0.0, count: segments.count)
            var fetchGroupIndexBySegmentIndex = Array(repeating: 0, count: segments.count)
            for (groupOffset, group) in groups.enumerated() {
                let mergedIndex = mergedIndicesForGroups[groupOffset]
                for segmentIndex in group.segmentIndices {
                    basePM25BySegmentIndex[segmentIndex] = cBaseValues[mergedIndex]
                    fetchGroupIndexBySegmentIndex[segmentIndex] = mergedIndex
                }
            }

            var segmentExposures: [SegmentExposure] = []
            segmentExposures.reserveCapacity(segments.count)
            var exposure = 0.0

            for (index, segment) in segments.enumerated() {
                let cBase = basePM25BySegmentIndex[index]
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
                        fetchGroupIndex: fetchGroupIndexBySegmentIndex[index]
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

        let fetchGroups = merge.references.indices.map { index in
            FetchGroupExposure(
                index: index,
                reference: merge.references[index],
                snapshot: snapshots[index],
                cBase: cBaseValues[index],
                segmentCount: merge.segmentCounts[index]
            )
        }

        return RouteExposureEstimationResult(
            routes: routeEstimates,
            fetchGroups: fetchGroups,
            modelVersion: predictor.modelVersion ?? "unknown"
        )
    }

    private struct MergedFetchGroups {
        let references: [CLLocationCoordinate2D]
        let segmentCounts: [Int]
        let mergedIndicesByRoute: [[Int]]
    }

    private func mergeGroupsAcrossRoutes(_ perRouteGroups: [[SegmentFetchGroup]]) -> MergedFetchGroups {
        var referenceLocations: [CLLocation] = []
        var segmentCounts: [Int] = []
        var mergedIndicesByRoute: [[Int]] = []

        for groups in perRouteGroups {
            var mergedIndicesForRoute: [Int] = []
            for group in groups {
                let groupLocation = CLLocation(
                    latitude: group.referenceCoordinate.latitude,
                    longitude: group.referenceCoordinate.longitude
                )
                if let existingIndex = referenceLocations.firstIndex(where: {
                    $0.distance(from: groupLocation) <= DoseConstants.fetchGroupingRadiusMeters
                }) {
                    mergedIndicesForRoute.append(existingIndex)
                    segmentCounts[existingIndex] += group.segmentIndices.count
                } else {
                    referenceLocations.append(groupLocation)
                    segmentCounts.append(group.segmentIndices.count)
                    mergedIndicesForRoute.append(referenceLocations.count - 1)
                }
            }
            mergedIndicesByRoute.append(mergedIndicesForRoute)
        }

        return MergedFetchGroups(
            references: referenceLocations.map(\.coordinate),
            segmentCounts: segmentCounts,
            mergedIndicesByRoute: mergedIndicesByRoute
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
