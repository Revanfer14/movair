import Foundation
import Combine
import CoreLocation

@MainActor
final class WatchNavigationViewModel: ObservableObject {
    @Published var state: WatchNavigationState = .idle
    @Published var distanceKm: Double = 0
    @Published var accumulatedExposureUg: Int = 0
    @Published var elapsedMinutes: Int = 0
    @Published private(set) var heartRateBPM: Double?
    @Published private(set) var instructionText: String = ""
    @Published private(set) var instructionDistanceMeters: Double = 0
    @Published private(set) var instructionStreetName: String = ""
    @Published private(set) var instructionSystemImage: String = "arrow.up"
    @Published private(set) var userCoordinate: CLLocationCoordinate2D?
    @Published private(set) var userHeadingDegrees: Double?
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []

    private let connectivity: WatchConnectivityManager
    private let heartRateManager: WatchHeartRateManager
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var accumulatedSeconds: Int = 0
    private var activeAnchorUptime: TimeInterval?
    private var activeAnchorSeconds: Int = 0

    init(
        connectivity: WatchConnectivityManager = .shared,
        heartRateManager: WatchHeartRateManager? = nil
    ) {
        self.connectivity = connectivity
        self.heartRateManager = heartRateManager ?? WatchHeartRateManager()
        bindConnectivity()
        bindHeartRate()
    }

    private func bindConnectivity() {
        connectivity.$latestPayload
            .receive(on: RunLoop.main)
            .sink { [weak self] payload in
                self?.apply(payload: payload)
            }
            .store(in: &cancellables)

        connectivity.$routeCoordinates
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinates in
                self?.routeCoordinates = coordinates
            }
            .store(in: &cancellables)
    }

    private func bindHeartRate() {
        heartRateManager.$heartRateBPM
            .receive(on: RunLoop.main)
            .sink { [weak self] heartRateBPM in
                self?.heartRateBPM = heartRateBPM
                if let heartRateBPM {
                    self?.connectivity.sendHeartRate(heartRateBPM)
                }
            }
            .store(in: &cancellables)
    }

    private func apply(payload: WatchSessionPayload) {
        let newState: WatchNavigationState
        switch payload.phase {
        case .idle:      newState = .idle
        case .active:    newState = .active
        case .paused:    newState = .paused
        case .completed: newState = .completed
        }

        if newState == .idle {
            resetToIdle()
            return
        }

        distanceKm = payload.distanceKm
        accumulatedExposureUg = payload.exposureUg

        let isRoutineUpdateWithinActiveState = newState == state && newState == .active
        if isRoutineUpdateWithinActiveState {
            setAccumulatedSeconds(max(currentAccumulatedSeconds(), payload.elapsedSeconds))
        } else {
            setAccumulatedSeconds(payload.elapsedSeconds)
        }
        instructionText = payload.instructionText
        instructionDistanceMeters = payload.instructionDistanceMeters
        instructionStreetName = payload.instructionStreetName
        instructionSystemImage = payload.instructionSystemImage
        userHeadingDegrees = payload.userHeadingDegrees
        if let latitude = payload.userLatitude, let longitude = payload.userLongitude {
            userCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            userCoordinate = nil
        }

        if newState != state {
            state = newState
            switch newState {
            case .active:
                startTimer()
                heartRateManager.start()
            case .paused:
                stopTimer()
                heartRateManager.pause()
            case .completed:
                stopTimer()
                heartRateManager.stop()
            case .idle:
                resetToIdle()
            }
        } else if newState == .active && timer == nil {
            startTimer()
        }
    }

    func pause() {
        guard state == .active else { return }

        let frozenSeconds = currentAccumulatedSeconds()
        stopTimer()
        state = .paused
        accumulatedSeconds = frozenSeconds
        elapsedMinutes = frozenSeconds / 60
        activeAnchorUptime = nil
        heartRateManager.pause()
        connectivity.sendAction(.pause)
    }

    func resume() {
        guard state == .paused else { return }

        state = .active
        startTimer()
        heartRateManager.resume()
        connectivity.sendAction(.resume)
    }

    func finish() {
        let frozenSeconds = currentAccumulatedSeconds()
        stopTimer()
        state = .completed
        accumulatedSeconds = frozenSeconds
        elapsedMinutes = frozenSeconds / 60
        activeAnchorUptime = nil
        heartRateManager.stop()
        connectivity.sendAction(.finish)
    }

    func dismissToHome() {
    }

    var elapsedTimeLabel: String {
        let seconds = currentAccumulatedSeconds()
        let minutes = seconds / 60
        let remainderSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainderSeconds)
    }

    func resetToIdle() {
        stopTimer()
        state = .idle
        distanceKm = 0
        accumulatedExposureUg = 0
        elapsedMinutes = 0
        accumulatedSeconds = 0
        activeAnchorUptime = nil
        activeAnchorSeconds = 0
        instructionText = ""
        instructionDistanceMeters = 0
        instructionStreetName = ""
        instructionSystemImage = "arrow.up"
        userCoordinate = nil
        userHeadingDegrees = nil
        routeCoordinates = []
        heartRateManager.stop()
    }

    private func startTimer() {
        stopTimer()
        activeAnchorUptime = ProcessInfo.processInfo.systemUptime
        activeAnchorSeconds = accumulatedSeconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .active else { return }
        accumulatedSeconds = currentAccumulatedSeconds()
        elapsedMinutes = accumulatedSeconds / 60
    }

    private func currentAccumulatedSeconds() -> Int {
        guard state == .active, let activeAnchorUptime else { return accumulatedSeconds }
        let secondsSinceAnchor = ProcessInfo.processInfo.systemUptime - activeAnchorUptime
        return activeAnchorSeconds + Int(max(0, secondsSinceAnchor).rounded())
    }

    private func setAccumulatedSeconds(_ seconds: Int) {
        accumulatedSeconds = seconds
        elapsedMinutes = seconds / 60
        activeAnchorUptime = ProcessInfo.processInfo.systemUptime
        activeAnchorSeconds = seconds
    }

    deinit {
        timer?.invalidate()
    }
}
