import Foundation

struct RoutePlanPayload: Encodable {
    let id: String
    let createdAtWIB: String
    let modelVersion: String
    let origin: Coordinate
    let destination: Coordinate
    let chosenRank: Int
    let equivalentExposure: Bool
    let weather: Weather
    let fetchGroups: [FetchGroup]
    let routes: [Route]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtWIB = "created_at_wib"
        case modelVersion = "model_version"
        case origin
        case destination
        case chosenRank = "chosen_rank"
        case equivalentExposure = "equivalent_exposure"
        case weather
        case fetchGroups = "fetch_groups"
        case routes
    }

    struct Coordinate: Encodable {
        let lat: Double
        let lon: Double
    }

    struct Weather: Encodable {
        let basePM25: Double
        let windSpeed: Double
        let relativeHumidity: Double
        let temperature: Double
        let hourOfDay: Int
        let isWeekend: Int
        let cBase: Double

        enum CodingKeys: String, CodingKey {
            case basePM25 = "base_pm25"
            case windSpeed = "wind_speed"
            case relativeHumidity = "relative_humidity"
            case temperature
            case hourOfDay = "hour_of_day"
            case isWeekend = "is_weekend"
            case cBase = "c_base"
        }
    }

    struct FetchGroup: Encodable {
        let index: Int
        let reference: Coordinate
        let basePM25: Double
        let windSpeed: Double
        let relativeHumidity: Double
        let temperature: Double
        let hourOfDay: Int
        let isWeekend: Int
        let cBase: Double
        let segmentCount: Int

        enum CodingKeys: String, CodingKey {
            case index
            case reference
            case basePM25 = "base_pm25"
            case windSpeed = "wind_speed"
            case relativeHumidity = "relative_humidity"
            case temperature
            case hourOfDay = "hour_of_day"
            case isWeekend = "is_weekend"
            case cBase = "c_base"
            case segmentCount = "segment_count"
        }
    }

    struct Route: Encodable {
        let rank: Int
        let label: String
        let distanceMeters: Double
        let durationSeconds: Double
        let exposure: Double
        let doseUg: Double
        let segments: [Segment]

        enum CodingKeys: String, CodingKey {
            case rank
            case label
            case distanceMeters = "distance_m"
            case durationSeconds = "duration_s"
            case exposure
            case doseUg = "dose_ug"
            case segments
        }
    }

    struct Segment: Encodable {
        let index: Int
        let mid: Coordinate
        let cumStartMeters: Double
        let cumEndMeters: Double
        let roadClass: Int
        let greeneryIndex: Double
        let mRoad: Double
        let mGreen: Double
        let cBase: Double
        let cI: Double
        let tISeconds: Double
        let cITI: Double
        let fetchGroupIndex: Int

        enum CodingKeys: String, CodingKey {
            case index
            case mid
            case cumStartMeters = "cum_start_m"
            case cumEndMeters = "cum_end_m"
            case roadClass = "road_class"
            case greeneryIndex = "greenery_index"
            case mRoad = "m_road"
            case mGreen = "m_green"
            case cBase = "c_base"
            case cI = "c_i"
            case tISeconds = "t_i_s"
            case cITI = "c_i_t_i"
            case fetchGroupIndex = "fetch_group_index"
        }
    }
}
