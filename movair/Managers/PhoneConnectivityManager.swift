//
//  PhoneConnectivityManager.swift
//  movair
//
//  Created by Jonathan Basuki on 16/08/26.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published private(set) var incomingAction: WCAction?
    @Published private(set) var latestHeartRateBPM: Double?

    private var session: WCSession?
    private var lastSentPayload: WatchSessionPayload?

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(phase: NavigationPhase, distanceKm: Double, exposureUg: Int, elapsedMinutes: Int) {
        let wcPhase: WCPhase
        switch phase {
        case .navigating:
            wcPhase = .active
        case .paused:
            wcPhase = .paused
        case .tripSummary:
            wcPhase = .completed
        default:
            wcPhase = .idle
        }

        let payload = WatchSessionPayload(
            phase: wcPhase,
            distanceKm: distanceKm,
            exposureUg: exposureUg,
            elapsedMinutes: elapsedMinutes
        )

        if payload == lastSentPayload { return }
        lastSentPayload = payload

        guard let session, session.activationState == .activated else { return }

        let dict = payload.asDictionary

        do {
            try session.updateApplicationContext(dict)
        } catch {
        }

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendPhaseOnly(_ phase: NavigationPhase) {
        let current = lastSentPayload ?? .idle
        send(
            phase: phase,
            distanceKm: current.distanceKm,
            exposureUg: current.exposureUg,
            elapsedMinutes: current.elapsedMinutes
        )
    }

    func consumeAction() {
        incomingAction = nil
    }

    func resetHeartRate() {
        latestHeartRateBPM = nil
    }
}

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

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
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
            latestHeartRateBPM = heartRateBPM
            return
        }

        guard let actionRaw = message[WCKeys.action] as? String,
              let action = WCAction(rawValue: actionRaw) else { return }

        if action == .requestState {
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
        case .active:
            return .navigating
        case .paused:
            return .paused
        case .completed:
            return .tripSummary
        case .idle:
            return .browsing
        }
    }
}
