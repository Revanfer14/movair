import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    let basePM25: Double
    let windSpeedMetersPerSecond: Double
    let relativeHumidityPercent: Double
    let temperatureCelsius: Double
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: WeatherSnapshot, rhs: WeatherSnapshot) -> Bool {
        lhs.basePM25 == rhs.basePM25
            && lhs.windSpeedMetersPerSecond == rhs.windSpeedMetersPerSecond
            && lhs.relativeHumidityPercent == rhs.relativeHumidityPercent
            && lhs.temperatureCelsius == rhs.temperatureCelsius
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
