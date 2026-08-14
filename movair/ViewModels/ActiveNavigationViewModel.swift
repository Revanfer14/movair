import Foundation
import CoreLocation
import Combine

@MainActor
final class ActiveNavigationViewModel: ObservableObject {
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

    var currentInstruction: Instruction? {
        guard instructions.indices.contains(currentInstructionIndex) else { return nil }
        return instructions[currentInstructionIndex]
    }

    func configure(with route: RouteOption) {
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
            Instruction(distanceKm: 0.8, text: "Keep right toward BXChange Mall")
        ]
        currentInstructionIndex = 0
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
