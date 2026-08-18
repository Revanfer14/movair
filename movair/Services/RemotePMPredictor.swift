import Foundation
internal import _LocationEssentials


final class RemotePMPredictor: PMPredicting, @unchecked Sendable {
    private let api: MovairAPI
    private(set) var modelVersion: String?

    init(api: MovairAPI = MovairAPIClient()) {
        self.api = api
    }

    func predict(snapshot: WeatherSnapshot, date: Date) async throws -> Double {
        let results = try await predict(snapshots: [snapshot], date: date)
        guard let first = results.first else {
            throw ExposureEstimationError.modelPredictionFailed
        }
        return first
    }

    func predict(snapshots: [WeatherSnapshot], date: Date) async throws -> [Double] {
        guard !snapshots.isEmpty else { return [] }
        guard snapshots.count <= DoseConstants.maxPredictRowsPerRequest else {
            throw ExposureEstimationError.routeOutsideValidatedCoverage
        }

        let rows = snapshots.map { snapshot in
            PredictRow(
                basePM25: snapshot.basePM25,
                windSpeed: snapshot.windSpeedMetersPerSecond,
                relativeHumidity: snapshot.relativeHumidityPercent,
                hourOfDay: WIBTime.hourOfDay(for: date),
                isWeekend: WIBTime.isWeekend(for: date),
                latitude: snapshot.coordinate.latitude,
                longitude: snapshot.coordinate.longitude
            )
        }

        let response: PredictResponse
        do {
            response = try await api.predict(rows: rows)
        } catch let error as MovairAPIError {
            switch error {
            case .rateLimited, .serviceUnavailable, .timedOut:
                throw ExposureEstimationError.unavailableData
            default:
                throw ExposureEstimationError.modelPredictionFailed
            }
        }

        guard response.cBase.count == rows.count else {
            throw ExposureEstimationError.modelPredictionFailed
        }

        modelVersion = response.modelVersion
        return response.cBase
    }
}
