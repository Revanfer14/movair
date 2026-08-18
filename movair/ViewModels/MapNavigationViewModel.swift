import Foundation
import CoreLocation
import Combine
import SwiftUI

@MainActor
final class MapNavigationViewModel: ObservableObject {
    struct Instruction: Identifiable, Equatable {
        let id: UUID
        var distanceRemainingMeters: Double
        let text: String
        let systemImage: String
        let targetCoordinate: CLLocationCoordinate2D
        let waypointIndex: Int

        init(
            id: UUID = UUID(),
            distanceRemainingMeters: Double,
            text: String,
            systemImage: String,
            targetCoordinate: CLLocationCoordinate2D,
            waypointIndex: Int = 0
        ) {
            self.id = id
            self.distanceRemainingMeters = distanceRemainingMeters
            self.text = text
            self.systemImage = systemImage
            self.targetCoordinate = targetCoordinate
            self.waypointIndex = waypointIndex
        }

        var distanceLabel: String {
            if distanceRemainingMeters < 1000 {
                let rounded = max(0, Int((distanceRemainingMeters / 10).rounded()) * 10)
                return "\(rounded) m"
            }
            let km = distanceRemainingMeters / 1000
            if km < 10 {
                return String(format: "%.1f km", km)
            }
            return String(format: "%.0f km", km)
        }

        static func == (lhs: Instruction, rhs: Instruction) -> Bool {
            lhs.id == rhs.id
                && lhs.distanceRemainingMeters == rhs.distanceRemainingMeters
                && lhs.text == rhs.text
                && lhs.systemImage == rhs.systemImage
                && lhs.targetCoordinate.latitude == rhs.targetCoordinate.latitude
                && lhs.targetCoordinate.longitude == rhs.targetCoordinate.longitude
                && lhs.waypointIndex == rhs.waypointIndex
        }
    }

    @Published var instructions: [Instruction] = []
    @Published var currentInstructionIndex: Int = 0
    @Published var selectedUpcomingOffset: Int = 0
    @Published var distanceKm: Double = 0
    @Published var durationMinutes: Int = 0
    @Published var averageSpeedKmh: Double = 0
    @Published var accumulatedExposureUg: Int = 0
    @Published var exposureLevel: ExposureLevel = .low
    @Published var isOffRoute: Bool = false
    @Published var unattributedDurationMinutes: Int = 0
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?
    @Published var originTitle: String = "Current location"
    @Published var destinationTitle: String = "Destination"
    @Published var startedAt: Date = Date()
    @Published var isPreparingDose = false
    @Published var hasArrivedAtDestination: Bool = false
    @Published private(set) var latestHeartRateBPM: Double?
    @Published private(set) var routeHeadingDegrees: Double?

    private var rideTracker: RideTracker?
    private var doseSession: LiveRideDoseSession?
    private var latestTrackingSnapshot: RideTrackingSnapshot?
    private var latestDoseMicrograms: Double = 0
    private var isTrackingPaused = false
    private var isUpdatingDose = false
    private var pendingDoseSnapshot: RideTrackingSnapshot?

    var currentInstruction: Instruction? {
        guard instructions.indices.contains(currentInstructionIndex) else { return nil }
        return instructions[currentInstructionIndex]
    }

    var upcomingInstructions: [Instruction] {
        guard instructions.indices.contains(currentInstructionIndex) else { return [] }
        let maxEnd = min(instructions.count, currentInstructionIndex + 3)
        return Array(instructions[currentInstructionIndex..<maxEnd])
    }

    func configure(
        with route: RouteOption,
        originTitle: String = "Current location",
        destinationTitle: String = "Destination",
        originCoordinate: CLLocationCoordinate2D? = nil,
        destinationCoordinate: CLLocationCoordinate2D? = nil
    ) async throws {
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.originCoordinate = originCoordinate ?? route.coordinates.first
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
        isTrackingPaused = false
        distanceKm = 0
        durationMinutes = 0
        averageSpeedKmh = 0
        accumulatedExposureUg = 0
        latestDoseMicrograms = 0
        exposureLevel = .low
        isOffRoute = false
        unattributedDurationMinutes = 0
        latestTrackingSnapshot = nil
        pendingDoseSnapshot = nil
        latestHeartRateBPM = nil
        hasArrivedAtDestination = false
        isUpdatingDose = false

        if let first = route.coordinates.first, let userCoord = self.originCoordinate {
            let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            let startLoc = CLLocation(latitude: first.latitude, longitude: first.longitude)
            let distanceToStart = userLoc.distance(from: startLoc)
            if distanceToStart > 12 {
                routeHeadingDegrees = Self.calculateBearing(from: userCoord, to: first)
            } else if route.coordinates.count >= 2 {
                routeHeadingDegrees = Self.calculateBearing(from: route.coordinates[0], to: route.coordinates[1])
            } else {
                routeHeadingDegrees = nil
            }
        } else if route.coordinates.count >= 2 {
            routeHeadingDegrees = Self.calculateBearing(from: route.coordinates[0], to: route.coordinates[1])
        } else {
            routeHeadingDegrees = nil
        }

        let segments = RouteSegmenter().makeSegments(from: route.coordinates)
        guard !segments.isEmpty else {
            throw ExposureEstimationError.invalidRoute
        }

        isPreparingDose = true
        defer { isPreparingDose = false }

        let ventilationProvider = HealthKitVentilationRateProvider()
        let session = try await LiveRideDoseSession(
            segments: segments,
            ventilationRateProvider: ventilationProvider
        )
        try await session.prepare(date: Date())
        doseSession = session
        rideTracker = RideTracker(segments: segments)

        if !route.steps.isEmpty {
            instructions = route.steps.map { step in
                Instruction(
                    distanceRemainingMeters: step.distanceMeters,
                    text: step.text,
                    systemImage: step.systemImage,
                    targetCoordinate: step.coordinate,
                    waypointIndex: step.waypointIndex
                )
            }
        } else {
            let startCoord = route.coordinates.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            let endCoord = route.coordinates.last ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            instructions = [
                Instruction(
                    distanceRemainingMeters: route.distanceKm * 1000,
                    text: "Head toward \(destinationTitle)",
                    systemImage: "location.north.fill",
                    targetCoordinate: endCoord,
                    waypointIndex: 0
                ),
                Instruction(
                    distanceRemainingMeters: 0,
                    text: "Arrive at \(destinationTitle)",
                    systemImage: "flag.fill",
                    targetCoordinate: endCoord,
                    waypointIndex: max(0, route.coordinates.count - 1)
                )
            ]
        }
        currentInstructionIndex = 0
        selectedUpcomingOffset = 0

        if let initialSnapshot = rideTracker?.snapshot() {
            scheduleDoseUpdate(for: initialSnapshot)
        }
    }

    func process(location: CLLocation) {
        guard !isTrackingPaused, let rideTracker else { return }
        let snapshot = rideTracker.process(location: location)
        latestTrackingSnapshot = snapshot
        applyTrackingMetrics(snapshot)
        updateInstructionProgress(with: location)
        updateRouteHeading(with: location)
        scheduleDoseUpdate(for: snapshot)
    }

    func updateHeartRate(_ bpm: Double?) {
        latestHeartRateBPM = bpm
        if let bpm {
            print("[MapNavigationViewModel] Realtime HR Updated: \(String(format: "%.1f", bpm)) BPM -> Recalculating Live Inhaled Dose")
        }
        if let latestTrackingSnapshot {
            scheduleDoseUpdate(for: latestTrackingSnapshot)
        }
    }

    func pauseTracking() {
        isTrackingPaused = true
    }

    func resumeTracking() {
        isTrackingPaused = false
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
            isMeasuredExposure: true,
            unattributedDurationMinutes: unattributedDurationMinutes,
            coordinates: routeCoordinates,
            completedAt: completedAt
        )
    }

    func makeRideRecord() async -> RideRecord? {
        guard let doseSession, let snapshot = latestTrackingSnapshot ?? rideTracker?.snapshot() else {
            return nil
        }
        return await doseSession.makeRideRecord(
            from: snapshot,
            doseMicrograms: latestDoseMicrograms
        )
    }

    func goToPreviousInstruction() {
        if selectedUpcomingOffset > 0 {
            selectedUpcomingOffset -= 1
        } else if currentInstructionIndex > 0 {
            currentInstructionIndex -= 1
            selectedUpcomingOffset = 0
        }
    }

    func goToNextInstruction() {
        if selectedUpcomingOffset < upcomingInstructions.count - 1 {
            selectedUpcomingOffset += 1
        } else if currentInstructionIndex < instructions.count - 1 {
            currentInstructionIndex += 1
            selectedUpcomingOffset = 0
        }
    }

    func setInstructionOffset(_ offset: Int) {
        guard upcomingInstructions.indices.contains(offset) else { return }
        selectedUpcomingOffset = offset
    }

    private func applyTrackingMetrics(_ snapshot: RideTrackingSnapshot) {
        distanceKm = snapshot.travelledDistanceMeters / 1000
        durationMinutes = Int(snapshot.elapsedDuration / 60)
        unattributedDurationMinutes = Int((snapshot.unattributedDuration / 60).rounded())
        isOffRoute = snapshot.isOffRoute
        guard snapshot.elapsedDuration > 0 else {
            averageSpeedKmh = 0
            return
        }
        averageSpeedKmh = distanceKm / (snapshot.elapsedDuration / 3600)
    }

    private func updateInstructionProgress(with location: CLLocation) {
        guard instructions.indices.contains(currentInstructionIndex) else { return }

        let currentTarget = instructions[currentInstructionIndex].targetCoordinate
        let targetLocation = CLLocation(latitude: currentTarget.latitude, longitude: currentTarget.longitude)
        let distanceMeters = location.distance(from: targetLocation)
        instructions[currentInstructionIndex].distanceRemainingMeters = max(0, distanceMeters)

        if distanceMeters < 25 && currentInstructionIndex < instructions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentInstructionIndex += 1
                selectedUpcomingOffset = 0
            }
            let nextTarget = instructions[currentInstructionIndex].targetCoordinate
            let nextLocation = CLLocation(latitude: nextTarget.latitude, longitude: nextTarget.longitude)
            instructions[currentInstructionIndex].distanceRemainingMeters = max(0, location.distance(from: nextLocation))
        }

        let maxUpcoming = min(instructions.count, currentInstructionIndex + 3)
        for index in (currentInstructionIndex + 1)..<maxUpcoming {
            let target = instructions[index].targetCoordinate
            let stepLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
            instructions[index].distanceRemainingMeters = max(0, location.distance(from: stepLocation))
        }

        checkDestinationArrival(with: location)
    }

    private func checkDestinationArrival(with location: CLLocation) {
        guard !hasArrivedAtDestination else { return }

        if let dest = destinationCoordinate {
            let destLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let distanceToDestination = location.distance(from: destLoc)
            if distanceToDestination <= 40 {
                hasArrivedAtDestination = true
                return
            }
        }

        if currentInstructionIndex == instructions.count - 1 && instructions[currentInstructionIndex].distanceRemainingMeters <= 30 {
            hasArrivedAtDestination = true
        }
    }

    private func updateRouteHeading(with location: CLLocation) {
        guard routeCoordinates.count >= 2 else { return }

        if let firstCoord = routeCoordinates.first, currentInstructionIndex == 0 {
            let firstLoc = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
            let distanceToStart = location.distance(from: firstLoc)
            if distanceToStart > 12 {
                routeHeadingDegrees = Self.calculateBearing(from: location.coordinate, to: firstCoord)
                return
            }
        }

        var closestIndex = 0
        var minDistance: CLLocationDistance = .greatestFiniteMagnitude

        for i in 0..<(routeCoordinates.count - 1) {
            let p1 = routeCoordinates[i]
            let p2 = routeCoordinates[i + 1]
            let mid = CLLocationCoordinate2D(
                latitude: (p1.latitude + p2.latitude) / 2,
                longitude: (p1.longitude + p2.longitude) / 2
            )
            let d = location.distance(from: CLLocation(latitude: mid.latitude, longitude: mid.longitude))
            if d < minDistance {
                minDistance = d
                closestIndex = i
            }
        }

        let fromCoord = routeCoordinates[closestIndex]
        let toIndex = min(routeCoordinates.count - 1, closestIndex + 1)
        let toCoord = routeCoordinates[toIndex]

        let calculatedBearing = Self.calculateBearing(from: fromCoord, to: toCoord)
        if location.course >= 0 && location.speed > 1.2 {
            routeHeadingDegrees = location.course
        } else {
            routeHeadingDegrees = calculatedBearing
        }
    }

    private static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private func scheduleDoseUpdate(for snapshot: RideTrackingSnapshot) {
        pendingDoseSnapshot = snapshot
        guard !isUpdatingDose else { return }
        isUpdatingDose = true

        Task { [weak self] in
            while let self, let currentSnapshot = self.pendingDoseSnapshot, let doseSession = self.doseSession {
                self.pendingDoseSnapshot = nil
                let heartRate = self.latestHeartRateBPM ?? 0
                do {
                    let liveDose = try await doseSession.apply(
                        snapshot: currentSnapshot,
                        date: Date(),
                        heartRateBPM: heartRate
                    )
                    self.latestDoseMicrograms = liveDose.doseMicrograms
                    self.accumulatedExposureUg = max(0, Int(liveDose.doseMicrograms.rounded()))
                    self.exposureLevel = ExposureLevel.from(exposureUg: self.accumulatedExposureUg)
                    self.isOffRoute = liveDose.isOffRoute
                    self.unattributedDurationMinutes = Int(
                        (liveDose.unattributedDurationSeconds / 60).rounded()
                    )
                } catch {
                }
            }
            self?.isUpdatingDose = false
        }
    }
}
