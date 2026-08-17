import CoreML

protocol PMPredicting {
    func predict(snapshot: WeatherSnapshot, date: Date) throws -> Double
}

final class PMPredictor: PMPredicting {
    private let model: CleanRoutePM25
    private let wibTimeZone: TimeZone

    init() throws {
        guard let wibTimeZone = TimeZone(identifier: "Asia/Jakarta") else {
            throw ExposureEstimationError.modelPredictionFailed
        }
        self.wibTimeZone = wibTimeZone
        model = try CleanRoutePM25(configuration: MLModelConfiguration())
    }

    func predict(snapshot: WeatherSnapshot, date: Date) throws -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wibTimeZone
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let output = try model.prediction(
            base_pm25: snapshot.basePM25,
            wind_speed: snapshot.windSpeedMetersPerSecond,
            relative_humidity: snapshot.relativeHumidityPercent,
            hour_of_day: Double(hour),
            is_weekend: isWeekend ? 1 : 0
        )
        return max(0, expm1(output.pm25_log))
    }
}
