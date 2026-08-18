import Foundation

struct RideRecordPayload: Encodable {
    let id: String
    let routePlanID: String?
    let modelVersion: String?
    let startedAtWIB: String
    let completedAtWIB: String
    let origin: RoutePlanPayload.Coordinate
    let destination: RoutePlanPayload.Destination
    let totals: Totals
    let diagnostics: Diagnostics
    let segments: [Segment]
    let trace: [TracePoint]

    enum CodingKeys: String, CodingKey {
        case id
        case routePlanID = "route_plan_id"
        case modelVersion = "model_version"
        case startedAtWIB = "started_at_wib"
        case completedAtWIB = "completed_at_wib"
        case origin
        case destination
        case totals
        case diagnostics
        case segments
        case trace
    }

    struct Totals: Encodable {
        let totalDoseMicrograms: Double
        let attributedDurationSeconds: Double
        let unattributedDurationSeconds: Double
        let elapsedDurationSeconds: Double
        let travelledDistanceMeters: Double
        let averageSpeedKmh: Double
        let endedOffRoute: Bool

        enum CodingKeys: String, CodingKey {
            case totalDoseMicrograms = "total_dose_ug"
            case attributedDurationSeconds = "attributed_duration_s"
            case unattributedDurationSeconds = "unattributed_duration_s"
            case elapsedDurationSeconds = "elapsed_duration_s"
            case travelledDistanceMeters = "travelled_distance_m"
            case averageSpeedKmh = "average_speed_kmh"
            case endedOffRoute = "ended_off_route"
        }
    }

    struct Diagnostics: Encodable {
        let lastVentilationRate: Double
        let lastHeartRateBPM: Double
        let hourRolloverCount: Int

        enum CodingKeys: String, CodingKey {
            case lastVentilationRate = "last_ventilation_rate"
            case lastHeartRateBPM = "last_heart_rate_bpm"
            case hourRolloverCount = "hour_rollover_count"
        }
    }

    struct Segment: Encodable {
        let index: Int
        let cI: Double
        let tISeconds: Double
        let cITI: Double
        let doseMicrograms: Double
        let interpolated: Bool

        enum CodingKeys: String, CodingKey {
            case index
            case cI = "c_i"
            case tISeconds = "t_i_s"
            case cITI = "c_i_t_i"
            case doseMicrograms = "dose_ug"
            case interpolated
        }
    }

    struct TracePoint: Encodable {
        let lat: Double
        let lon: Double
        let tSeconds: Double
        let horizontalAccuracyMeters: Double
        let speedMetersPerSecond: Double

        enum CodingKeys: String, CodingKey {
            case lat
            case lon
            case tSeconds = "t_s"
            case horizontalAccuracyMeters = "acc_m"
            case speedMetersPerSecond = "spd_mps"
        }
    }
}
