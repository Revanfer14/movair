import Foundation

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
