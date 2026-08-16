import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    @Published private(set) var latestPayload: WatchSessionPayload = .idle
    @Published private(set) var isReachable: Bool = false

    private var session: WCSession?
    private var lastHeartRateSentAt: Date?

    private override init() {
        super.init()
        activate()
    }

    // Activation
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    // Send actions to iPhone
    func sendAction(_ action: WCAction) {
        guard let session, session.activationState == .activated else { return }

        let message: [String: Any] = [WCKeys.action: action.rawValue]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("[Watch WC] sendMessage error: \(error.localizedDescription)")
            }
        } else {
            // Fallback: queue it so iPhone gets it when reachable
            session.transferUserInfo(message)
        }
    }

    func requestCurrentState() {
        sendAction(.requestState)
    }

    func sendHeartRate(_ heartRateBPM: Double) {
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            return
        }

        let now = Date()
        if let lastHeartRateSentAt, now.timeIntervalSince(lastHeartRateSentAt) < 5 {
            return
        }
        lastHeartRateSentAt = now

        session.sendMessage([WCKeys.heartRateBPM: heartRateBPM], replyHandler: nil) { error in
            print("[Watch WC] heart-rate send error: \(error.localizedDescription)")
        }
    }

    // Apply incoming payload
    private func apply(payload: WatchSessionPayload) {
        latestPayload = payload
    }
}

// WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                print("[Watch WC] activation error: \(error.localizedDescription)")
            }
            self.isReachable = session.isReachable

            // Ask iPhone for current state as soon as we are ready
            if activationState == .activated {
                self.requestCurrentState()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestCurrentState()
            }
        }
    }

    // Application context (most recent state)
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            if let payload = WatchSessionPayload(from: applicationContext) {
                self.apply(payload: payload)
            }
        }
    }

    // Immediate message
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let payload = WatchSessionPayload(from: message) {
                self.apply(payload: payload)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            if let payload = WatchSessionPayload(from: message) {
                self.apply(payload: payload)
            }
            replyHandler([:])
        }
    }

    // User info transfer (fallback)
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            if let payload = WatchSessionPayload(from: userInfo) {
                self.apply(payload: payload)
            }
        }
    }
}
