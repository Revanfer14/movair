import CoreLocation

protocol OpenMeteoProviding: Sendable {
    func weather(at coordinate: CLLocationCoordinate2D, date: Date) async throws -> WeatherSnapshot
}

final class OpenMeteoService: OpenMeteoProviding {
    private let session: URLSession
    private let wibTimeZone = TimeZone(identifier: "Asia/Jakarta") ?? .current

    init(session: URLSession = .shared) {
        self.session = session
    }

    func weather(at coordinate: CLLocationCoordinate2D, date: Date) async throws -> WeatherSnapshot {
        async let airQuality = requestAirQuality(at: coordinate)
        async let weather = requestWeather(at: coordinate)
        let airQualityResponse = try await airQuality
        let weatherResponse = try await weather
        let hour = hourKey(for: date)

        let airQualityIndex = airQualityResponse.hourly.time.firstIndex(of: hour)
            ?? defaultHourIndex(for: date, count: airQualityResponse.hourly.time.count)
        let weatherIndex = weatherResponse.hourly.time.firstIndex(of: hour)
            ?? defaultHourIndex(for: date, count: weatherResponse.hourly.time.count)

        guard let airQualityIndex,
              let weatherIndex,
              airQualityResponse.hourly.pm25.indices.contains(airQualityIndex),
              weatherResponse.hourly.windSpeed.indices.contains(weatherIndex),
              weatherResponse.hourly.relativeHumidity.indices.contains(weatherIndex),
              weatherResponse.hourly.temperature.indices.contains(weatherIndex) else {
            throw ExposureEstimationError.unavailableData
        }

        return WeatherSnapshot(
            basePM25: airQualityResponse.hourly.pm25[airQualityIndex],
            windSpeedMetersPerSecond: weatherResponse.hourly.windSpeed[weatherIndex],
            relativeHumidityPercent: weatherResponse.hourly.relativeHumidity[weatherIndex],
            temperatureCelsius: weatherResponse.hourly.temperature[weatherIndex],
            coordinate: coordinate
        )
    }

    private func requestAirQuality(at coordinate: CLLocationCoordinate2D) async throws -> AirQualityResponse {
        guard var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality") else {
            throw ExposureEstimationError.unavailableData
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "pm2_5"),
            URLQueryItem(name: "timezone", value: "Asia/Jakarta"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components.url else {
            throw ExposureEstimationError.unavailableData
        }
        return try await request(AirQualityResponse.self, url: url)
    }

    private func requestWeather(at coordinate: CLLocationCoordinate2D) async throws -> WeatherResponse {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw ExposureEstimationError.unavailableData
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            // URLQueryItem(name: "hourly", value: "wind_speed_10m,relative_humidity_2m"),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,relative_humidity_2m,temperature_2m"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
            URLQueryItem(name: "timezone", value: "Asia/Jakarta"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components.url else {
            throw ExposureEstimationError.unavailableData
        }
        return try await request(WeatherResponse.self, url: url)
    }

    private func request<Response: Decodable>(_ type: Response.Type, url: URL) async throws -> Response {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ExposureEstimationError.unavailableData
            }
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as ExposureEstimationError {
            throw error
        } catch {
            throw ExposureEstimationError.unavailableData
        }
    }

    private func hourKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wibTimeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return String(format: "%04d-%02d-%02dT%02d:00", components.year ?? 0, components.month ?? 0, components.day ?? 0, components.hour ?? 0)
    }

    private func defaultHourIndex(for date: Date, count: Int) -> Int? {
        guard count > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wibTimeZone
        let hour = calendar.component(.hour, from: date)
        return min(max(0, hour), count - 1)
    }

    private struct AirQualityResponse: Decodable {
        let hourly: AirQualityHourly
    }

    private struct AirQualityHourly: Decodable {
        let time: [String]
        let pm25: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case pm25 = "pm2_5"
        }
    }

    private struct WeatherResponse: Decodable {
        let hourly: WeatherHourly
    }

    private struct WeatherHourly: Decodable {
        let time: [String]
        let windSpeed: [Double]
        let relativeHumidity: [Double]
        let temperature: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case windSpeed = "wind_speed_10m"
            case relativeHumidity = "relative_humidity_2m"
            case temperature = "temperature_2m"
        }
    }
}
