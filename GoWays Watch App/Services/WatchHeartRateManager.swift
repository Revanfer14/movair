import Foundation
import HealthKit
import Combine

@MainActor
final class WatchHeartRateManager: NSObject, ObservableObject {
    @Published private(set) var heartRateBPM: Double?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var isMonitoringRequested = false

    func start() {
        isMonitoringRequested = true
        guard workoutSession == nil,
              HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let workoutType = HKObjectType.workoutType()
        healthStore.requestAuthorization(toShare: [workoutType], read: [heartRateType]) { [weak self] success, _ in
            guard success else { return }
            Task { @MainActor in
                self?.beginWorkout()
            }
        }
    }

    func pause() {
        isMonitoringRequested = false
        workoutSession?.pause()
    }

    func resume() {
        isMonitoringRequested = true
        if let workoutSession {
            workoutSession.resume()
        } else {
            start()
        }
    }

    func stop() {
        isMonitoringRequested = false
        guard let workoutSession, let workoutBuilder else {
            heartRateBPM = nil
            return
        }

        workoutSession.end()
        workoutBuilder.endCollection(withEnd: Date()) { _, _ in
            workoutBuilder.discardWorkout()
        }
        self.workoutSession = nil
        self.workoutBuilder = nil
        heartRateBPM = nil
    }

    private func beginWorkout() {
        guard workoutSession == nil, isMonitoringRequested else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        do {
            let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            workoutSession.delegate = self
            workoutBuilder.delegate = self

            self.workoutSession = workoutSession
            self.workoutBuilder = workoutBuilder

            let startDate = Date()
            workoutSession.startActivity(with: startDate)
            workoutBuilder.beginCollection(withStart: startDate) { [weak self] _, error in
                if error != nil {
                    self?.stop()
                }
            }
        } catch {
            heartRateBPM = nil
        }
    }
}

extension WatchHeartRateManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.stop()
        }
    }
}

extension WatchHeartRateManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else {
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let heartRateBPM = quantity.doubleValue(for: unit)
        Task { @MainActor in
            self.heartRateBPM = heartRateBPM
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
