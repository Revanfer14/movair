import Foundation
import Combine

@MainActor
final class WatchNavigationViewModel: ObservableObject {
    @Published var state: WatchNavigationState = .idle
    @Published var distanceKm: Double = 0
    @Published var accumulatedExposureUg: Int = 0
    @Published var elapsedMinutes: Int = 0
    @Published private(set) var heartRateBPM: Double?

    private let connectivity: WatchConnectivityManager
    private let heartRateManager: WatchHeartRateManager
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var accumulatedSeconds: Int = 0

    init(
        connectivity: WatchConnectivityManager = .shared,
        heartRateManager: WatchHeartRateManager? = nil
    ) {
        self.connectivity = connectivity
        self.heartRateManager = heartRateManager ?? WatchHeartRateManager()
        bindConnectivity()
        bindHeartRate()
    }

    // Connectivity binding
    private func bindConnectivity() {
        connectivity.$latestPayload
            .receive(on: RunLoop.main)
            .sink { [weak self] payload in
                self?.apply(payload: payload)
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

        // Update metrics from iPhone
        distanceKm = payload.distanceKm
        accumulatedExposureUg = payload.exposureUg

        // Sync elapsed only when it makes sense (don't jump backwards aggressively)
        if payload.elapsedMinutes >= elapsedMinutes {
            elapsedMinutes = payload.elapsedMinutes
            accumulatedSeconds = payload.elapsedMinutes * 60
        }

        // Handle state transition + timer
        if newState != state {
            state = newState
            switch newState {
            case .active:
                startTimer()
                heartRateManager.start()
            case .paused:
                stopTimer()
                heartRateManager.pause()
            case .completed, .idle:
                stopTimer()
                heartRateManager.stop()
            }
        } else if newState == .active {
            // Ensure timer is running if we stay active
            if timer == nil { startTimer() }
        }
    }

    // User actions (sent to iPhone)
    func pause() {
        guard state == .active else { return }

        stopTimer()
        state = .paused
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
        stopTimer()
        state = .completed
        heartRateManager.stop()
        connectivity.sendAction(.finish)
    }

    func dismissToHome() {
        // no-op on VM; ContentView handles the visual dismiss
    }

    func resetToIdle() {
        stopTimer()
        state = .idle
        distanceKm = 0
        accumulatedExposureUg = 0
        elapsedMinutes = 0
        accumulatedSeconds = 0
        heartRateManager.stop()
    }

    // Timer
    private func startTimer() {
        stopTimer()
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
        accumulatedSeconds += 1
        elapsedMinutes = accumulatedSeconds / 60
    }

    deinit {
        timer?.invalidate()
    }
}
