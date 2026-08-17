import Foundation
import CoreLocation
import Combine

@MainActor
final class MapNavigationViewModel: ObservableObject {
    struct Instruction: Identifiable {
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
                let meters = max(10, Int((distanceRemainingMeters / 10).rounded()) * 10)
                return "\(meters) m"
            }
            let km = distanceRemainingMeters / 1000
            if km < 10 {
                return String(format: "%.1f km", km)
            }
            return String(format: "%.0f km", km)
        }
    }

    @Published var instructions: [Instruction] = []
    @Published var currentInstructionIndex: Int = 0
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
    @Published private(set) var latestHeartRateBPM: Double?

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
        isUpdatingDose = false

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
                    waypointIndex: route.coordinates.count
                )
            ]
        }
        currentInstructionIndex = 0
    }

    func process(location: CLLocation) {
        guard !isTrackingPaused, let rideTracker else { return }
        let snapshot = rideTracker.process(location: location)
        latestTrackingSnapshot = snapshot
        applyTrackingMetrics(snapshot)
        updateInstructionProgress(with: location)
        scheduleDoseUpdate(for: snapshot)
    }

    func updateHeartRate(_ bpm: Double?) {
        latestHeartRateBPM = bpm
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

        if distanceMeters < 30 && currentInstructionIndex < instructions.count - 1 {
            currentInstructionIndex += 1
            let nextTarget = instructions[currentInstructionIndex].targetCoordinate
            let nextLocation = CLLocation(latitude: nextTarget.latitude, longitude: nextTarget.longitude)
            instructions[currentInstructionIndex].distanceRemainingMeters = max(0, location.distance(from: nextLocation))
        }
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
