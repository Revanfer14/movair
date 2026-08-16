import Foundation
import CoreLocation
import Combine

@MainActor
final class MapNavigationViewModel: ObservableObject {
    struct Instruction: Identifiable, Equatable {
        let id = UUID()
        let distanceKm: Double
        let text: String
    }

    @Published var instructions: [Instruction] = []
    @Published var currentInstructionIndex: Int = 0
    @Published var distanceKm: Double = 0
    @Published var durationMinutes: Int = 0
    @Published var averageSpeedKmh: Double = 0
    @Published var accumulatedExposureUg: Int = 0
    @Published var exposureLevel: ExposureLevel = .low
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var originTitle: String = "Current location"
    @Published var destinationTitle: String = "Destination"
    @Published var startedAt: Date = Date()

    var currentInstruction: Instruction? {
        guard instructions.indices.contains(currentInstructionIndex) else { return nil }
        return instructions[currentInstructionIndex]
    }

    func configure(
        with route: RouteOption,
        originTitle: String = "Current location",
        destinationTitle: String = "Destination"
    ) {
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        startedAt = Date()
        routeCoordinates = route.coordinates
        distanceKm = route.distanceKm
        durationMinutes = route.durationMinutes
        averageSpeedKmh = route.durationMinutes > 0
            ? (route.distanceKm / (Double(route.durationMinutes) / 60.0))
            : 0
        accumulatedExposureUg = route.exposureRangeUg.lowerBound
            + (route.exposureRangeUg.upperBound - route.exposureRangeUg.lowerBound) / 2
        exposureLevel = route.exposureLevel

        instructions = [
            Instruction(distanceKm: 3, text: "Turn left onto Jalan Damai Foresta"),
            Instruction(distanceKm: 1.2, text: "Continue straight on Boulevard Utara"),
            Instruction(distanceKm: 0.8, text: "Keep right toward \(destinationTitle)")
        ]
        currentInstructionIndex = 0
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
}
