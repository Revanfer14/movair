import Foundation
import MapKit
import Combine

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var originTitle: String = "Current location"
    @Published var destination: SelectedDestination?
    @Published var isRoundTrip: Bool = true
    @Published var routes: [RouteOption] = []
    @Published var selectedRouteID: UUID?
    @Published var isLoading: Bool = false
    @Published var routeError: String?
    @Published private(set) var originIsCurrentLocation: Bool = true

    var currentOriginCoordinate: CLLocationCoordinate2D? { originCoordinate }

    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteID } ?? routes.first
    }

    private let routingService: ORSRouting
    private var exposureEstimator: RouteExposureEstimating?
    private let debounceDelay: Duration = .milliseconds(300)
    private var originCoordinate: CLLocationCoordinate2D?
    private var userLocationCoordinate: CLLocationCoordinate2D?
    private var routeTask: Task<Void, Never>?
    private var lastEstimationResult: RouteExposureEstimationResult?
    private var lastOrigin: CLLocationCoordinate2D?
    private var lastDestination: CLLocationCoordinate2D?
    private var lastEstimationDate: Date?

    init(
        routingService: ORSRouting = ORSRoutingService(),
        exposureEstimator: RouteExposureEstimating? = nil
    ) {
        self.routingService = routingService
        self.exposureEstimator = exposureEstimator
    }

    func configure(origin: CLLocationCoordinate2D?, destination: SelectedDestination) {
        originCoordinate = origin
        userLocationCoordinate = origin
        self.destination = destination
        originTitle = "Current location"
        originIsCurrentLocation = true
        regenerateRoutes()
    }

    func updateUserLocation(_ coordinate: CLLocationCoordinate2D?) {
        userLocationCoordinate = coordinate
        if originIsCurrentLocation, let coordinate {
            originCoordinate = coordinate
        }
    }

    func setRoundTrip(_ value: Bool) {
        guard isRoundTrip != value else { return }
        isRoundTrip = value
        regenerateRoutes()
    }

    func selectRoute(_ route: RouteOption) {
        selectedRouteID = route.id
    }

    func retry() {
        regenerateRoutes()
    }

    func updateOrigin(to place: SelectedDestination) {
        originTitle = place.title
        originCoordinate = place.coordinate
        originIsCurrentLocation = false
        regenerateRoutes()
    }

    func updateOriginToCurrentLocation() {
        guard let coordinate = userLocationCoordinate ?? originCoordinate else { return }
        originTitle = "Current location"
        originCoordinate = coordinate
        originIsCurrentLocation = true
        regenerateRoutes()
    }

    func updateDestination(to place: SelectedDestination) {
        destination = place
        regenerateRoutes()
    }

    func swapEndpoints() {
        guard let destination, let originCoordinate else { return }

        let previousOriginTitle = originTitle
        let previousOriginCoordinate = originCoordinate
        let previousWasCurrent = originIsCurrentLocation
        let previousDestination = destination

        originTitle = previousDestination.title
        self.originCoordinate = previousDestination.coordinate
        originIsCurrentLocation = false

        self.destination = SelectedDestination(
            title: previousOriginTitle,
            subtitle: previousWasCurrent ? "Current location" : "",
            coordinate: previousOriginCoordinate
        )

        regenerateRoutes()
    }

    private func regenerateRoutes() {
        routeTask?.cancel()

        guard let origin = originCoordinate, let destination else {
            routes = []
            selectedRouteID = nil
            return
        }

        isLoading = true
        routeError = nil

        routeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.debounceDelay)
            guard !Task.isCancelled else { return }

            do {
                let fetchedRoutes = try await self.routingService.fetchRoutes(from: origin, to: destination.coordinate)
                guard !Task.isCancelled else { return }
                let routesForPlanning = self.detourEligibleRoutes(from: self.routesForPlanning(from: fetchedRoutes))
                let estimator = try await self.resolvedExposureEstimator()
                let estimationDate = Date()
                let result = try await estimator.estimate(routes: routesForPlanning, date: estimationDate)
                guard !Task.isCancelled else { return }
                self.lastOrigin = origin
                self.lastDestination = destination.coordinate
                self.lastEstimationDate = estimationDate
                self.applyFetchedRoutes(routesForPlanning, result: result)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.routeError = (error as? ORSRoutingError)?.userMessage
                    ?? (error as? ExposureEstimationError)?.userMessage
                    ?? ORSRoutingError.requestFailed(statusCode: 0).userMessage
                self.routes = []
                self.selectedRouteID = nil
                self.isLoading = false
            }
        }
    }

    private func applyFetchedRoutes(_ fetchedRoutes: [ORSRoute], result: RouteExposureEstimationResult) {
        lastEstimationResult = result
        let estimates = result.routes
        let estimatesByRouteID = Dictionary(uniqueKeysWithValues: estimates.map { ($0.routeID, $0) })
        let lowestExposure = fetchedRoutes.compactMap { estimatesByRouteID[$0.id]?.exposure }.min() ?? 0
        let highestExposure = fetchedRoutes.compactMap { estimatesByRouteID[$0.id]?.exposure }.max() ?? 0
        let hasEquivalentExposure = lowestExposure == 0
            ? highestExposure == 0
            : (highestExposure - lowestExposure) / lowestExposure < DoseConstants.equivalentExposureThreshold
        let ranked = fetchedRoutes.sorted { lhs, rhs in
            if hasEquivalentExposure {
                return lhs.durationSeconds < rhs.durationSeconds
            }
            let lhsExposure = estimatesByRouteID[lhs.id]?.exposure ?? .greatestFiniteMagnitude
            let rhsExposure = estimatesByRouteID[rhs.id]?.exposure ?? .greatestFiniteMagnitude
            if lhsExposure == rhsExposure {
                return lhs.durationSeconds < rhs.durationSeconds
            }
            return lhsExposure < rhsExposure
        }
        let shortestDistance = ranked.map(\.distanceMeters).min() ?? 0
        let lowestDose = fetchedRoutes.compactMap { estimatesByRouteID[$0.id]?.doseMicrograms }.min() ?? 0
        let cleanerDistance = ranked.first?.distanceMeters ?? 0

        routes = ranked.enumerated().map { index, route in
            let dose = estimatesByRouteID[route.id]?.doseMicrograms ?? 0
            let isRecommended = index == 0

            let title: String = {
                if isRecommended {
                    return "Cleaner Route"
                } else if route.distanceMeters > cleanerDistance {
                    return "Longer Route"
                } else if route.distanceMeters < cleanerDistance {
                    return "Shorter Route"
                } else {
                    return "Alternative Route"
                }
            }()

            return RouteOption(
                id: route.id,
                title: title,
                distanceKm: route.distanceMeters / 1000,
                durationMinutes: Int((route.durationSeconds / 60).rounded()),
                exposureRangeUg: exposureRange(for: dose),
                exposureLevel: ExposureLevel.from(exposureUg: Int(dose.rounded())),
                pollutionDeltaPercent: pollutionDeltaPercent(dose: dose, comparedTo: lowestDose),
                hasEquivalentExposure: hasEquivalentExposure,
                isRecommended: isRecommended,
                isLonger: route.distanceMeters > shortestDistance,
                coordinates: route.coordinates,
                steps: route.steps
            )
        }

        selectedRouteID = routes.first(where: { $0.isRecommended })?.id ?? routes.first?.id
        isLoading = false
    }

    private func makeRoundTrip(_ outbound: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard outbound.count >= 2 else { return outbound }
        let returnPath = outbound.dropLast().reversed()
        return outbound + returnPath
    }

    private func makeRoundTripSteps(from steps: [RouteStep], outboundCount: Int) -> [RouteStep] {
        guard !steps.isEmpty else { return [] }
        var allSteps = steps
        if let last = steps.last {
            let turnAround = RouteStep(
                distanceMeters: 50,
                durationSeconds: 15,
                maneuverType: 9,
                text: "Turn around and head back toward \(originTitle)",
                streetName: last.streetName,
                coordinate: last.coordinate,
                waypointIndex: outboundCount
            )
            allSteps.append(turnAround)
        }
        return allSteps
    }

    private func routesForPlanning(from routes: [ORSRoute]) -> [ORSRoute] {
        guard isRoundTrip else { return routes }
        return routes.map { route in
            let roundTripCoordinates = makeRoundTrip(route.coordinates)
            let roundTripSteps = makeRoundTripSteps(from: route.steps, outboundCount: route.coordinates.count)
            return ORSRoute(
                id: route.id,
                coordinates: roundTripCoordinates,
                distanceMeters: route.distanceMeters * 2,
                durationSeconds: route.durationSeconds * 2,
                steps: roundTripSteps
            )
        }
    }

    private func detourEligibleRoutes(from routes: [ORSRoute]) -> [ORSRoute] {
        guard let fastestDuration = routes.map(\.durationSeconds).min() else { return [] }
        return routes.filter { $0.durationSeconds <= fastestDuration * DoseConstants.detourCapFactor }
    }

    private func resolvedExposureEstimator() async throws -> RouteExposureEstimating {
        if let exposureEstimator {
            return exposureEstimator
        }
        let exposureEstimator = try RouteExposureEstimator()
        self.exposureEstimator = exposureEstimator
        return exposureEstimator
    }

    private func exposureRange(for dose: Double) -> ClosedRange<Int> {
        let lowerBound = max(0, Int((dose * 0.9).rounded(.down)))
        let upperBound = max(lowerBound, Int((dose * 1.1).rounded(.up)))
        return lowerBound...upperBound
    }

    private func pollutionDeltaPercent(dose: Double, comparedTo fastestDose: Double) -> Int {
        guard fastestDose > 0 else { return 0 }
        return Int((((dose - fastestDose) / fastestDose) * 100).rounded())
    }

    func routePlanPayload(chosenRouteID: UUID) -> RoutePlanPayload? {
        guard let result = lastEstimationResult,
              let origin = lastOrigin,
              let destination = lastDestination,
              let firstFetchGroup = result.fetchGroups.first,
              !result.routes.isEmpty else {
            return nil
        }

        let date = lastEstimationDate ?? Date()
        let rankByRouteID = Dictionary(uniqueKeysWithValues: routes.enumerated().map { ($1.id, $0 + 1) })
        let labelByRouteID = Dictionary(uniqueKeysWithValues: routes.map { ($0.id, $0.title) })

        guard let chosenRank = rankByRouteID[chosenRouteID] else {
            return nil
        }

        let payloadRoutes = result.routes.compactMap { estimate -> RoutePlanPayload.Route? in
            guard let rank = rankByRouteID[estimate.routeID] else { return nil }
            let segments = estimate.segments.map { segment in
                RoutePlanPayload.Segment(
                    index: segment.index,
                    mid: RoutePlanPayload.Coordinate(lat: segment.midpoint.latitude, lon: segment.midpoint.longitude),
                    cumStartMeters: segment.cumulativeStartMeters,
                    cumEndMeters: segment.cumulativeEndMeters,
                    roadClass: segment.roadClass,
                    greeneryIndex: segment.greeneryIndex,
                    mRoad: segment.roadMultiplier,
                    mGreen: segment.greenMultiplier,
                    cBase: segment.cBase,
                    cI: segment.concentration,
                    tISeconds: segment.durationSeconds,
                    cITI: segment.concentrationTimesDuration,
                    fetchGroupIndex: segment.fetchGroupIndex
                )
            }
            return RoutePlanPayload.Route(
                rank: rank,
                label: labelByRouteID[estimate.routeID] ?? "Route \(rank)",
                distanceMeters: estimate.distanceMeters,
                durationSeconds: estimate.durationSeconds,
                exposure: estimate.exposure,
                doseUg: estimate.doseMicrograms,
                segments: segments
            )
        }

        guard !payloadRoutes.isEmpty else { return nil }

        let fetchGroups = result.fetchGroups.map { group in
            RoutePlanPayload.FetchGroup(
                index: group.index,
                reference: RoutePlanPayload.Coordinate(lat: group.reference.latitude, lon: group.reference.longitude),
                basePM25: group.snapshot.basePM25,
                windSpeed: group.snapshot.windSpeedMetersPerSecond,
                relativeHumidity: group.snapshot.relativeHumidityPercent,
                temperature: group.snapshot.temperatureCelsius,
                hourOfDay: WIBTime.hourOfDay(for: date),
                isWeekend: WIBTime.isWeekend(for: date),
                cBase: group.cBase,
                segmentCount: group.segmentCount
            )
        }

        let weather = RoutePlanPayload.Weather(
            basePM25: firstFetchGroup.snapshot.basePM25,
            windSpeed: firstFetchGroup.snapshot.windSpeedMetersPerSecond,
            relativeHumidity: firstFetchGroup.snapshot.relativeHumidityPercent,
            temperature: firstFetchGroup.snapshot.temperatureCelsius,
            hourOfDay: WIBTime.hourOfDay(for: date),
            isWeekend: WIBTime.isWeekend(for: date),
            cBase: firstFetchGroup.cBase
        )

        return RoutePlanPayload(
            id: UUID().uuidString,
            createdAtWIB: WIBTime.iso8601String(for: date),
            modelVersion: result.modelVersion,
            origin: RoutePlanPayload.Coordinate(lat: origin.latitude, lon: origin.longitude),
            destination: RoutePlanPayload.Coordinate(lat: destination.latitude, lon: destination.longitude),
            chosenRank: chosenRank,
            equivalentExposure: routes.first?.hasEquivalentExposure ?? false,
            weather: weather,
            fetchGroups: fetchGroups,
            routes: payloadRoutes
        )
    }
}
