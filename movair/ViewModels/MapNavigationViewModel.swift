import Foundation
import CoreLocation
import Combine

@MainActor
final class MapNavigationViewModel: ObservableObject {
    struct Instruction: Identifiable, Equatable {
        let id: UUID
        let distanceKm: Double
        let text: String
        let systemImage: String

        init(
            id: UUID = UUID(),
            distanceKm: Double,
            text: String,
            systemImage: String
        ) {
            self.id = id
            self.distanceKm = distanceKm
            self.text = text
            self.systemImage = systemImage
        }
    }

    @Published var instructions: [Instruction] = []
    @Published var currentInstructionIndex: Int = 0
    @Published var distanceKm: Double = 0
    @Published var durationMinutes: Int = 0
    @Published var averageSpeedKmh: Double = 0
    @Published var accumulatedExposureUg: Int = 0
    @Published var exposureLevel: ExposureLevel = .low
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?
    @Published var originTitle: String = "Current location"
    @Published var destinationTitle: String = "Destination"
    @Published var startedAt: Date = Date()

    private var rideTracker: RideTracker?
    private var isTrackingPaused = false

    var currentInstruction: Instruction? {
        guard instructions.indices.contains(currentInstructionIndex) else { return nil }
        return instructions[currentInstructionIndex]
    }

    func configure(
        with route: RouteOption,
        originTitle: String = "Current location",
        destinationTitle: String = "Destination",
        originCoordinate: CLLocationCoordinate2D? = nil,
        destinationCoordinate: CLLocationCoordinate2D? = nil
    ) {
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.originCoordinate = originCoordinate ?? route.coordinates.first
        // Prefer explicit destination; for round-trip polyline (returns to start) use midpoint
        if let destinationCoordinate {
            self.destinationCoordinate = destinationCoordinate
        } else if route.coordinates.count >= 2 {
            let first = route.coordinates.first!
            let last = route.coordinates.last!
            let returnedToStart = abs(first.latitude - last.latitude) < 0.0005
                && abs(first.longitude - last.longitude) < 0.0005
            if returnedToStart {
                self.destinationCoordinate = route.coordinates[route.coordinates.count / 2]
            } else {
                self.destinationCoordinate = last
            }
        } else {
            self.destinationCoordinate = nil
        }
        startedAt = Date()
        routeCoordinates = route.coordinates
        let segments = RouteSegmenter().makeSegments(from: route.coordinates)
        rideTracker = RideTracker(segments: segments)
        isTrackingPaused = false
        distanceKm = 0
        durationMinutes = 0
        averageSpeedKmh = 0
        accumulatedExposureUg = route.exposureRangeUg.lowerBound
            + (route.exposureRangeUg.upperBound - route.exposureRangeUg.lowerBound) / 2
        exposureLevel = route.exposureLevel

        instructions = [
            Instruction(
                distanceKm: 3,
                text: "Turn left onto Jalan Damai Foresta",
                systemImage: "arrow.turn.up.left"
            ),
            Instruction(
                distanceKm: 1.2,
                text: "Continue straight on Boulevard Utara",
                systemImage: "arrow.up"
            ),
            Instruction(
                distanceKm: 0.8,
                text: "Keep right toward \(destinationTitle)",
                systemImage: "arrow.turn.up.right"
            )
        ]
        currentInstructionIndex = 0
    }

    func process(location: CLLocation) {
        guard !isTrackingPaused, let rideTracker else { return }
        apply(rideTracker.process(location: location))
    }

    func pauseTracking() {
        isTrackingPaused = true
    }

    func resumeTracking() {
        isTrackingPaused = false
    }

    private func apply(_ snapshot: RideTrackingSnapshot) {
        distanceKm = snapshot.travelledDistanceMeters / 1000
        durationMinutes = Int(snapshot.elapsedDuration / 60)
        guard snapshot.elapsedDuration > 0 else {
            averageSpeedKmh = 0
            return
        }
        averageSpeedKmh = distanceKm / (snapshot.elapsedDuration / 3600)
    }

    func makeTripSummary(completedAt: Date = Date()) -> TripSummary {
        TripSummary(
            originTitle: originTitle,
            destinationTitle: destinationTitle,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            averageSpeedKmh: averageSpeedKmh,
            exposureUg: accumulatedExposureUg,
            exposureLevel: exposureLevel,
            coordinates: routeCoordinates,
            completedAt: completedAt
        )
    }

    func goToPreviousInstruction() {
        guard currentInstructionIndex > 0 else { return }
        currentInstructionIndex -= 1
    }

    func goToNextInstruction() {
        guard currentInstructionIndex < instructions.count - 1 else { return }
        currentInstructionIndex += 1
    }

    func setInstructionIndex(_ index: Int) {
        guard instructions.indices.contains(index) else { return }
        currentInstructionIndex = index
    }
}
