import Foundation

struct PredictRow: Encodable {
    let basePM25: Double
    let windSpeed: Double
    let relativeHumidity: Double
    let hourOfDay: Int
    let isWeekend: Int
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case basePM25 = "base_pm25"
        case windSpeed = "wind_speed"
        case relativeHumidity = "relative_humidity"
        case hourOfDay = "hour_of_day"
        case isWeekend = "is_weekend"
        case latitude = "lat"
        case longitude = "lon"
    }
}
