import Foundation
import MapKit
import Combine

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    private struct ExposurePlaceholder {
        let exposureRangeUg: ClosedRange<Int>
        let exposureLevel: ExposureLevel
        let pollutionDeltaPercent: Int
    }

    @Published var originTitle: String = "Current location"
    @Published var destination: SelectedDestination?
    @Published var isRoundTrip: Bool = true
    @Published var routes: [RouteOption] = []
    @Published var selectedRouteID: UUID?
    @Published var isLoading: Bool = false
    @Published var routeError: String?
    @Published private(set) var originIsCurrentLocation: Bool = true

    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteID } ?? routes.first
    }

    private let routingService: ORSRouting
    private let debounceDelay: Duration = .milliseconds(300)
    private var originCoordinate: CLLocationCoordinate2D?
    private var userLocationCoordinate: CLLocationCoordinate2D?
    private var routeTask: Task<Void, Never>?

    private static let exposurePlaceholders: [ExposurePlaceholder] = [
        ExposurePlaceholder(exposureRangeUg: 130...145, exposureLevel: .moderate, pollutionDeltaPercent: -10),
        ExposurePlaceholder(exposureRangeUg: 150...165, exposureLevel: .high, pollutionDeltaPercent: 10),
        ExposurePlaceholder(exposureRangeUg: 170...185, exposureLevel: .high, pollutionDeltaPercent: 20)
    ]

    init(routingService: ORSRouting = ORSRoutingService()) {
        self.routingService = routingService
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

    /// Replace origin with a searched place and re-route.
    func updateOrigin(to place: SelectedDestination) {
        originTitle = place.title
        originCoordinate = place.coordinate
        originIsCurrentLocation = false
        regenerateRoutes()
    }

    /// Reset origin to current GPS location and re-route.
    func updateOriginToCurrentLocation() {
        guard let coordinate = userLocationCoordinate ?? originCoordinate else { return }
        originTitle = "Current location"
        originCoordinate = coordinate
        originIsCurrentLocation = true
        regenerateRoutes()
    }

    /// Replace destination with a searched place and re-route.
    func updateDestination(to place: SelectedDestination) {
        destination = place
        regenerateRoutes()
    }

    /// Swap origin ↔ destination titles and coordinates, then rebuild routes.
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
                self.applyFetchedRoutes(fetchedRoutes)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.routeError = (error as? ORSRoutingError)?.userMessage ?? ORSRoutingError.requestFailed(statusCode: 0).userMessage
                self.routes = []
                self.selectedRouteID = nil
                self.isLoading = false
            }
        }
    }

    private func applyFetchedRoutes(_ fetchedRoutes: [ORSRoute]) {
        let sorted = fetchedRoutes.sorted { $0.durationSeconds < $1.durationSeconds }
        let shortestDistance = sorted.map(\.distanceMeters).min() ?? 0

        routes = sorted.enumerated().map { index, route in
            let placeholder = Self.exposurePlaceholders[min(index, Self.exposurePlaceholders.count - 1)]
            let tripDistanceMeters = isRoundTrip ? route.distanceMeters * 2 : route.distanceMeters
            let tripDurationSeconds = isRoundTrip ? route.durationSeconds * 2 : route.durationSeconds
            let coordinates = isRoundTrip ? makeRoundTrip(route.coordinates) : route.coordinates

            return RouteOption(
                title: "Route \(index + 1)",
                distanceKm: tripDistanceMeters / 1000,
                durationMinutes: Int((tripDurationSeconds / 60).rounded()),
                exposureRangeUg: placeholder.exposureRangeUg,
                exposureLevel: placeholder.exposureLevel,
                pollutionDeltaPercent: placeholder.pollutionDeltaPercent,
                isRecommended: index == 0,
                isLonger: route.distanceMeters > shortestDistance,
                coordinates: coordinates
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
}
