//
//  PhoneConnectivityManager.swift
//  movair
//
//  Created by Jonathan Basuki on 16/08/26.
//

import Foundation
import WatchConnectivity
import Combine
import CoreLocation

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    private static let navigationUpdateMinInterval: TimeInterval = 1.0
    private static let maxRoutePointsSentToWatch = 300

    @Published private(set) var incomingAction: WCAction?
    @Published private(set) var latestHeartRateBPM: Double?

    private var session: WCSession?
    private var lastSentPayload: WatchSessionPayload?
    private var lastSentAt: Date?
    private let polylineSimplifier: PolylineSimplifying = PolylineSimplifier()

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

    func send(
        phase: NavigationPhase,
        distanceKm: Double,
        exposureUg: Int,
        elapsedMinutes: Int,
        elapsedSeconds: Int = 0,
        instructionText: String = "",
        instructionDistanceMeters: Double = 0,
        instructionStreetName: String = "",
        instructionSystemImage: String = "arrow.up",
        userLatitude: Double? = nil,
        userLongitude: Double? = nil,
        userHeadingDegrees: Double? = nil,
        force: Bool = false
    ) {
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
            elapsedMinutes: elapsedMinutes,
            elapsedSeconds: elapsedSeconds,
            instructionText: instructionText,
            instructionDistanceMeters: instructionDistanceMeters,
            instructionStreetName: instructionStreetName,
            instructionSystemImage: instructionSystemImage,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            userHeadingDegrees: userHeadingDegrees
        )

        if !force, payload == lastSentPayload { return }

        let phaseChanged = payload.phase != lastSentPayload?.phase
        if !force, !phaseChanged, let lastSentAt, Date().timeIntervalSince(lastSentAt) < Self.navigationUpdateMinInterval {
            return
        }

        lastSentPayload = payload
        lastSentAt = Date()

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
            elapsedMinutes: current.elapsedMinutes,
            elapsedSeconds: current.elapsedSeconds,
            instructionText: current.instructionText,
            instructionDistanceMeters: current.instructionDistanceMeters,
            instructionStreetName: current.instructionStreetName,
            instructionSystemImage: current.instructionSystemImage,
            userLatitude: current.userLatitude,
            userLongitude: current.userLongitude,
            userHeadingDegrees: current.userHeadingDegrees
        )
    }

    func sendRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        guard let session, session.activationState == .activated, !coordinates.isEmpty else { return }

        let simplified = polylineSimplifier.simplify(coordinates, maxPointCount: Self.maxRoutePointsSentToWatch)
        let points = simplified.map { [$0.latitude, $0.longitude] }
        let message: [String: Any] = [
            WCKeys.routePoints: points
        ]
        session.transferUserInfo(message)
    }

    func resetForNewRide() {
        lastSentPayload = nil
        lastSentAt = nil
        latestHeartRateBPM = nil
        let payload = WatchSessionPayload(
            phase: .active,
            distanceKm: 0,
            exposureUg: 0,
            elapsedMinutes: 0
        )
        lastSentPayload = payload
        lastSentAt = Date()

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

    func resetToIdle() {
        lastSentPayload = nil
        lastSentAt = nil
        latestHeartRateBPM = nil
        let payload = WatchSessionPayload(
            phase: .idle,
            distanceKm: 0,
            exposureUg: 0,
            elapsedMinutes: 0
        )
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
    static let instructionText = "instructionText"
    static let instructionDistanceMeters = "instructionDistanceMeters"
    static let instructionStreetName = "instructionStreetName"
    static let instructionSystemImage = "instructionSystemImage"
    static let userLatitude = "userLatitude"
    static let userLongitude = "userLongitude"
    static let userHeadingDegrees = "userHeadingDegrees"
    static let routePoints = "routePoints"
    static let elapsedSeconds = "elapsedSeconds"
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
    var elapsedSeconds: Int
    var instructionText: String
    var instructionDistanceMeters: Double
    var instructionStreetName: String
    var instructionSystemImage: String
    var userLatitude: Double?
    var userLongitude: Double?
    var userHeadingDegrees: Double?

    static let idle = WatchSessionPayload(
        phase: .idle,
        distanceKm: 0,
        exposureUg: 0,
        elapsedMinutes: 0
    )

    init(
        phase: WCPhase,
        distanceKm: Double,
        exposureUg: Int,
        elapsedMinutes: Int,
        elapsedSeconds: Int = 0,
        instructionText: String = "",
        instructionDistanceMeters: Double = 0,
        instructionStreetName: String = "",
        instructionSystemImage: String = "arrow.up",
        userLatitude: Double? = nil,
        userLongitude: Double? = nil,
        userHeadingDegrees: Double? = nil
    ) {
        self.phase = phase
        self.distanceKm = distanceKm
        self.exposureUg = exposureUg
        self.elapsedMinutes = elapsedMinutes
        self.elapsedSeconds = elapsedSeconds
        self.instructionText = instructionText
        self.instructionDistanceMeters = instructionDistanceMeters
        self.instructionStreetName = instructionStreetName
        self.instructionSystemImage = instructionSystemImage
        self.userLatitude = userLatitude
        self.userLongitude = userLongitude
        self.userHeadingDegrees = userHeadingDegrees
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
        self.elapsedSeconds = dictionary[WCKeys.elapsedSeconds] as? Int ?? 0
        self.instructionText = dictionary[WCKeys.instructionText] as? String ?? ""
        self.instructionDistanceMeters = dictionary[WCKeys.instructionDistanceMeters] as? Double ?? 0
        self.instructionStreetName = dictionary[WCKeys.instructionStreetName] as? String ?? ""
        self.instructionSystemImage = dictionary[WCKeys.instructionSystemImage] as? String ?? "arrow.up"
        self.userLatitude = dictionary[WCKeys.userLatitude] as? Double
        self.userLongitude = dictionary[WCKeys.userLongitude] as? Double
        self.userHeadingDegrees = dictionary[WCKeys.userHeadingDegrees] as? Double
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            WCKeys.phase: phase.rawValue,
            WCKeys.distanceKm: distanceKm,
            WCKeys.exposureUg: exposureUg,
            WCKeys.elapsedMinutes: elapsedMinutes,
            WCKeys.elapsedSeconds: elapsedSeconds,
            WCKeys.instructionText: instructionText,
            WCKeys.instructionDistanceMeters: instructionDistanceMeters,
            WCKeys.instructionStreetName: instructionStreetName,
            WCKeys.instructionSystemImage: instructionSystemImage
        ]
        dict[WCKeys.userLatitude] = userLatitude
        dict[WCKeys.userLongitude] = userLongitude
        dict[WCKeys.userHeadingDegrees] = userHeadingDegrees
        return dict
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
            print("[WatchConnectivity] Received HR from Apple Watch: \(String(format: "%.1f", heartRateBPM)) BPM")
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
                    elapsedMinutes: last.elapsedMinutes,
                    elapsedSeconds: last.elapsedSeconds,
                    instructionText: last.instructionText,
                    instructionDistanceMeters: last.instructionDistanceMeters,
                    instructionStreetName: last.instructionStreetName,
                    instructionSystemImage: last.instructionSystemImage,
                    userLatitude: last.userLatitude,
                    userLongitude: last.userLongitude,
                    userHeadingDegrees: last.userHeadingDegrees,
                    force: true
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
