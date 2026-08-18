import Foundation

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
