import Foundation

protocol MovairAPI: Sendable {
    func predict(rows: [PredictRow]) async throws -> PredictResponse
    func archiveRoutePlan(_ payload: RoutePlanPayload) async throws
}

final class MovairAPIClient: MovairAPI {
    private static let requestTimeout: TimeInterval = 15

    private let session: URLSession
    private let deviceIdentity: DeviceIdentifying

    init(session: URLSession = .shared, deviceIdentity: DeviceIdentifying = DeviceIdentityProvider()) {
        self.session = session
        self.deviceIdentity = deviceIdentity
    }

    func predict(rows: [PredictRow]) async throws -> PredictResponse {
        var request = try makeRequest(path: "/predict", includeDeviceID: false)
        request.httpBody = try JSONEncoder().encode(PredictRequestBody(rows: rows))
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(PredictResponse.self, from: data)
        } catch {
            throw MovairAPIError.decodingFailed
        }
    }

    func archiveRoutePlan(_ payload: RoutePlanPayload) async throws {
        var request = try makeRequest(path: "/route-plans", includeDeviceID: true)
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await perform(request)
    }

    private func makeRequest(path: String, includeDeviceID: Bool) throws -> URLRequest {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "SERVER_BASE_URL") as? String,
              !baseURLString.isEmpty,
              let baseURL = URL(string: baseURLString) else {
            throw MovairAPIError.missingBaseURL
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if includeDeviceID {
            request.setValue(deviceIdentity.deviceID, forHTTPHeaderField: "X-Device-Id")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw MovairAPIError.timedOut
        } catch {
            throw MovairAPIError.requestFailed(statusCode: 0)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MovairAPIError.requestFailed(statusCode: 0)
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return data
        case 400:
            throw decodedInputError(from: data) ?? .invalidRequest
        case 404:
            throw MovairAPIError.notFound
        case 429:
            let retryAfter = (httpResponse.value(forHTTPHeaderField: "Retry-After")).flatMap(Int.init) ?? 60
            throw MovairAPIError.rateLimited(retryAfterSeconds: retryAfter)
        case 503:
            throw MovairAPIError.serviceUnavailable
        default:
            throw MovairAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func decodedInputError(from data: Data) -> MovairAPIError? {
        struct ServerError: Decodable { let error: String }
        guard let decoded = try? JSONDecoder().decode(ServerError.self, from: data) else {
            return nil
        }
        if decoded.error == "Nilai input tidak valid" {
            return .invalidInputValue
        }
        if decoded.error == "Permintaan terlalu besar" {
            return .payloadTooLarge
        }
        return nil
    }

    private struct PredictRequestBody: Encodable {
        let rows: [PredictRow]
    }
}
