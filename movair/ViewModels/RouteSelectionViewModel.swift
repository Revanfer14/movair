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

    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteID } ?? routes.first
    }

    private var originCoordinate: CLLocationCoordinate2D?

    func configure(origin: CLLocationCoordinate2D?, destination: SelectedDestination) {
        originCoordinate = origin
        self.destination = destination
        regenerateRoutes()
    }

    func setRoundTrip(_ value: Bool) {
        guard isRoundTrip != value else { return }
        isRoundTrip = value
        regenerateRoutes()
    }

    func selectRoute(_ route: RouteOption) {
        selectedRouteID = route.id
    }

    private func regenerateRoutes() {
        guard let origin = originCoordinate, let destination else {
            routes = []
            selectedRouteID = nil
            return
        }

        isLoading = true
        // Dummy routes relative to origin → destination (BSD-area style loop)
        let dest = destination.coordinate
        let midLat = (origin.latitude + dest.latitude) / 2
        let midLon = (origin.longitude + dest.longitude) / 2

        let cleanerCoords: [CLLocationCoordinate2D] = [
            origin,
            CLLocationCoordinate2D(latitude: midLat + 0.012, longitude: midLon - 0.008),
            CLLocationCoordinate2D(latitude: midLat + 0.018, longitude: midLon + 0.004),
            dest
        ]

        let longerCoords: [CLLocationCoordinate2D] = [
            origin,
            CLLocationCoordinate2D(latitude: midLat - 0.006, longitude: midLon - 0.015),
            CLLocationCoordinate2D(latitude: midLat + 0.004, longitude: midLon - 0.02),
            CLLocationCoordinate2D(latitude: midLat + 0.014, longitude: midLon - 0.006),
            dest
        ]

        let balancedCoords: [CLLocationCoordinate2D] = [
            origin,
            CLLocationCoordinate2D(latitude: midLat + 0.004, longitude: midLon + 0.012),
            CLLocationCoordinate2D(latitude: midLat + 0.01, longitude: midLon + 0.006),
            dest
        ]

        if isRoundTrip {
            routes = [
                RouteOption(
                    title: "Cleaner Route",
                    distanceKm: 42,
                    durationMinutes: 170,
                    exposureRangeUg: 150...160,
                    exposureLevel: .high,
                    pollutionDeltaPercent: -10,
                    isRecommended: true,
                    coordinates: makeRoundTrip(cleanerCoords)
                ),
                RouteOption(
                    title: "Longer Route",
                    distanceKm: 47,
                    durationMinutes: 195,
                    exposureRangeUg: 170...185,
                    exposureLevel: .high,
                    pollutionDeltaPercent: 20,
                    isLonger: true,
                    coordinates: makeRoundTrip(longerCoords)
                ),
                RouteOption(
                    title: "Shorter Route",
                    distanceKm: 35,
                    durationMinutes: 140,
                    exposureRangeUg: 130...145,
                    exposureLevel: .moderate,
                    pollutionDeltaPercent: 5,
                    coordinates: makeRoundTrip(balancedCoords)
                )
            ]
        } else {
            routes = [
                RouteOption(
                    title: "Cleaner Route",
                    distanceKm: 20,
                    durationMinutes: 95,
                    exposureRangeUg: 80...90,
                    exposureLevel: .moderate,
                    pollutionDeltaPercent: -10,
                    isRecommended: true,
                    coordinates: cleanerCoords
                ),
                RouteOption(
                    title: "Longer Route",
                    distanceKm: 23,
                    durationMinutes: 110,
                    exposureRangeUg: 100...115,
                    exposureLevel: .moderate,
                    pollutionDeltaPercent: 22,
                    isLonger: true,
                    coordinates: longerCoords
                ),
                RouteOption(
                    title: "Shorter Route",
                    distanceKm: 18,
                    durationMinutes: 80,
                    exposureRangeUg: 70...85,
                    exposureLevel: .low,
                    pollutionDeltaPercent: 0,
                    coordinates: balancedCoords
                )
            ]
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
