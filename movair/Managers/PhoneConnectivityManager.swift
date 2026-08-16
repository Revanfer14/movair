//
//  PhoneConnectivityManager.swift
//  movair
//
//  Created by Jonathan Basuki on 16/08/26.
//


import Foundation
import WatchConnectivity
import Combine

/// Handles all WatchConnectivity traffic on the iPhone side.
/// Pushes ride state to the Watch and receives control actions (pause / resume / finish).
@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {

    static let shared = PhoneConnectivityManager()

    /// Actions coming from the Watch that the UI should react to.
    @Published private(set) var incomingAction: WCAction?

    private var session: WCSession?
    private var lastSentPayload: WatchSessionPayload?

    private override init() {
        super.init()
        activate()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    // MARK: - Push state to Watch

    /// Call this whenever NavigationPhase or metrics change on iPhone.
    func send(phase: NavigationPhase, distanceKm: Double, exposureUg: Int, elapsedMinutes: Int) {
        let wcPhase: WCPhase
        switch phase {
        case .navigating:   wcPhase = .active
        case .paused:       wcPhase = .paused
        case .tripSummary:  wcPhase = .completed
        default:            wcPhase = .idle
        }

        let payload = WatchSessionPayload(
            phase: wcPhase,
            distanceKm: distanceKm,
            exposureUg: exposureUg,
            elapsedMinutes: elapsedMinutes
        )

        // Avoid spamming identical payloads
        if payload == lastSentPayload { return }
        lastSentPayload = payload

        guard let session, session.activationState == .activated else { return }

        let dict = payload.asDictionary

        // Always keep application context up to date (Watch can read latest even if not reachable)
        do {
            try session.updateApplicationContext(dict)
        } catch {
            print("[Phone WC] updateApplicationContext error: \(error.localizedDescription)")
        }

        // If Watch is reachable, also send immediate message for snappy UI
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                print("[Phone WC] sendMessage error: \(error.localizedDescription)")
            }
        }
    }

    /// Convenience when only phase changes and metrics stay the same.
    func sendPhaseOnly(_ phase: NavigationPhase) {
        let current = lastSentPayload ?? .idle
        send(
            phase: phase,
            distanceKm: current.distanceKm,
            exposureUg: current.exposureUg,
            elapsedMinutes: current.elapsedMinutes
        )
    }

    // MARK: - Consume action (UI should call this after handling)

    func consumeAction() {
        incomingAction = nil
    }
}

// MARK: - Shared payload types (duplicated for the iOS target)

enum WCKeys {
    static let phase = "phase"
    static let distanceKm = "distanceKm"
    static let exposureUg = "exposureUg"
    static let elapsedMinutes = "elapsedMinutes"
    static let action = "action"
    static let heartRateBPM = "heartRateBPM"
}

enum WCPhase: String {
    case idle
    case active
    case paused
    case completed
}

enum WCAction: String {
    case pause
    case resume
    case finish
    case requestState
}

struct WatchSessionPayload: Equatable {
    var phase: WCPhase
    var distanceKm: Double
    var exposureUg: Int
    var elapsedMinutes: Int

    static let idle = WatchSessionPayload(
        phase: .idle,
        distanceKm: 0,
        exposureUg: 0,
        elapsedMinutes: 0
    )

    init(phase: WCPhase, distanceKm: Double, exposureUg: Int, elapsedMinutes: Int) {
        self.phase = phase
        self.distanceKm = distanceKm
        self.exposureUg = exposureUg
        self.elapsedMinutes = elapsedMinutes
    }

    init?(from dictionary: [String: Any]) {
        guard let phaseRaw = dictionary[WCKeys.phase] as? String,
              let phase = WCPhase(rawValue: phaseRaw) else {
            return nil
        }
        self.phase = phase
        self.distanceKm = dictionary[WCKeys.distanceKm] as? Double ?? 0
        self.exposureUg = dictionary[WCKeys.exposureUg] as? Int ?? 0
        self.elapsedMinutes = dictionary[WCKeys.elapsedMinutes] as? Int ?? 0
    }

    var asDictionary: [String: Any] {
        [
            WCKeys.phase: phase.rawValue,
            WCKeys.distanceKm: distanceKm,
            WCKeys.exposureUg: exposureUg,
            WCKeys.elapsedMinutes: elapsedMinutes
        ]
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[Phone WC] activation error: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for subsequent pairings
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncoming(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handleIncoming(message)
            // Reply with current state if Watch is requesting it
            if let actionRaw = message[WCKeys.action] as? String,
               actionRaw == WCAction.requestState.rawValue,
               let last = self.lastSentPayload {
                replyHandler(last.asDictionary)
            } else {
                replyHandler([:])
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handleIncoming(userInfo)
        }
    }

    @MainActor
    private func handleIncoming(_ message: [String: Any]) {
        if let heartRateBPM = message[WCKeys.heartRateBPM] as? Double {
            print("[Phone WC] Heart rate: \(Int(heartRateBPM.rounded())) bpm")
            return
        }

        guard let actionRaw = message[WCKeys.action] as? String,
              let action = WCAction(rawValue: actionRaw) else { return }

        if action == .requestState {
            // Re-push last known state
            if let last = lastSentPayload {
                send(
                    phase: phaseFrom(wcPhase: last.phase),
                    distanceKm: last.distanceKm,
                    exposureUg: last.exposureUg,
                    elapsedMinutes: last.elapsedMinutes
                )
            }
            return
        }

        incomingAction = action
    }

    private func phaseFrom(wcPhase: WCPhase) -> NavigationPhase {
        switch wcPhase {
        case .active:    return .navigating
        case .paused:    return .paused
        case .completed: return .tripSummary
        case .idle:      return .browsing
        }
    }
}
