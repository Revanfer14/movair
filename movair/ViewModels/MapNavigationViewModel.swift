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
        let snapshot = rideTracker.process(location: location)
        latestTrackingSnapshot = snapshot
        applyTrackingMetrics(snapshot)
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
